import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cen_wallet.dart';
import 'keystore.dart';
import 'mining_isolate.dart';
import 'mining_readout.dart';
import 'mining_service.dart';

/// The local mining engine: drives the foreground service that runs the native
/// `celenium_scan` worker, tracks share counts and session state, and enforces
/// the 24-hour session hard-stop.
///
/// This is the real miner. It replaces the dead HTTP bridge path
/// (`POST /api/mining`) that the screen used to drive: the phone hashes against
/// the VPS pool at `5.178.98.100:5556` and submits shares directly.
///
/// The hashing itself runs in [MiningTaskHandler] inside an Android foreground
/// service, so mining keeps running when the app is swiped away. This engine is
/// only the app-side controller: it starts/stops the service, receives worker
/// events back over the plugin channel, and derives the display estimate.
///
/// One instance lives in [_MinerHomeState] for the app's lifetime so the
/// session survives route changes. It is a [ChangeNotifier] so the owning state
/// rebuilds on every mutation without a callback.
class MiningEngine extends ChangeNotifier {
  MiningEngine() {
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  /// The pool the phone submits shares to. Hard-coded on purpose: this address
  /// is a configuration detail the user should not have to set.\n
  static const String host = '5.178.98.100';
  static const int port = 5556;

  /// Distinguishes this device in the pool's worker list. Kept stable so a
  /// reconnect reuses the same worker slot.
  static const String workerName = 'phone';

  /// The session hard-stop. After this the service is stopped and the toggle
  /// returns to OFF; the user must tap again to open a fresh session.
  static const Duration sessionLimit = Duration(hours: 24);

  /// SharedPreferences key for the session start, so the 24-hour hard-stop
  /// survives the app being swiped away: the timer lives in this isolate, but
  /// the start time must outlive it for [resume] to re-enforce the limit.
  static const String _sessionStartPref = 'mining_session_start_ms';

  /// Pradha yang dikredit per share diterima, dalam satuan terkecil koin.
  /// 1 share = 1 pradha, langsung dikredit tanpa ambang minimum — reward
  /// menitik sekecil mungkin dan tidak menunggu akumulasi jutaan pradha.
  /// Ini hanya angka estimasi sesi; payout on-chain tetap dari block subsidy
  /// saat pool menemukan block, bukan dari nilai ini.
  static const int _pradhaPerShare = 1;

  bool _mining = false; // user intent (toggle state)
  bool _running = false; // a service worker is actually spawned/hashing
  bool _serviceInit = false; // `initMiningService` has run once

  final Keystore _keystore = Keystore();

  // Memoized so startup address resolution and a first mining tap share one
  // future (and one generated phrase) instead of racing two generations.
  Future<CenWallet>? _walletFuture;

  String status = MinerStatus.idle;
  double? hashrate; // H/s
  int? accepted; // accepted shares
  int? rejected; // rejected shares
  String? error;
  String? jobId;
  double? difficulty;
  String? address; // "cen69:…" payout address
  int? earnedPradha; // Σ pradha dikredit dari share diterima (1 pradha/share)

  int? _sessionStartMillis;
  Timer? _limitTimer;

  /// Snapshot the screen renders. Kept cheap: built on demand, no I/O.
  MiningReadout get readout {
    final active = status == MinerStatus.mining;
    return MiningReadout(
      hashrateGhs: hashrate == null ? null : hashrate! / 1e9,
      difficulty: difficulty,
      workerName: _shortAddress,
      address: address,
      earnedPradha: earnedPradha,
      shares: accepted,
      // The local worker reports rejected shares; the readout's `stale` slot
      // feeds the acceptance-rate denominator, matching bridge semantics.
      stale: rejected,
      invalid: 0,
      sessionBlocks: null,
      totalBlocks: null,
      latestBlockHash: null,
      latestBlockTime: null,
      bridgeUptime: null,
      sessionUptime: _sessionUptimeSeconds,
      active: active,
      miningEnabled: _mining,
      miningAvailable: true,
      status: status,
    );
  }

  /// Flips mining on/off. Idempotent: calling with the current state is a
  /// no-op so the screen can call it from a bool toggle without bookkeeping.
  Future<void> setMining(bool enabled) async {
    if (enabled == _mining) return;
    if (enabled) {
      await _start();
    } else {
      await _stop();
    }
  }

  /// Re-attaches UI state when the app is reopened while the service is still
  /// hashing in the background. Best-effort: if the service is running the
  /// toggle flips back to ON and shows "mining" until the next worker event
  /// reports fresh numbers.
  Future<void> resume() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        final start = await _readSessionStart();
        if (start != null &&
            DateTime.now().millisecondsSinceEpoch - start >=
                sessionLimit.inMilliseconds) {
          // The service outlived its 24-hour window while the app was closed.
          // Stop it now and surface the same "limit reached" state the timer
          // would have produced, leaving the toggle OFF for a re-tap.
          _mining = false;
          _running = false;
          status = MinerStatus.limitReached;
          await _stopService();
          await _clearSessionStart();
          notifyListeners();
          return;
        }
        _sessionStartMillis = start ?? DateTime.now().millisecondsSinceEpoch;
        _mining = true;
        _running = true;
        if (status != MinerStatus.mining && status != MinerStatus.connecting) {
          status = MinerStatus.mining;
        }
        _armLimitTimer();
        notifyListeners();
      }
    } on Object {
      // Service check unavailable (e.g. early init). Stay idle.
    }
  }

  /// Derives the payout address from the locally stored recovery phrase so it
  /// always matches the wallet tab, the backup flow and the send flow. On a
  /// first run there is no phrase yet, so one is created (and kept in the
  /// keystore); the address is then stable and recoverable from that point on.
  Future<void> resolveAddress() async {
    if (address != null) return;
    try {
      final wallet = await _resolveWallet();
      address = wallet.address;
      notifyListeners();
    } on Object {
      // Leave [address] null; the wallet tab falls back to its empty state.
    }
  }

  /// The single wallet used everywhere: the recovery phrase.
  ///
  /// It used to be derived from the device identity (Android ID / IP), which
  /// produced a *different* address from the phrase the user backs up — mining
  /// paid out to an address the wallet could not spend, and the send flow's
  /// key check failed. The phrase is generated on first use and never
  /// regenerated, so the miner, wallet, backup and send all agree on one key.
  Future<CenWallet> _resolveWallet() async {
    final cached = _walletFuture;
    if (cached != null) return cached;

    final future = _resolveWalletImpl();
    _walletFuture = future;
    try {
      return await future;
    } on Object {
      // Forget the failed future so a later retry (keystore or wordlist asset
      // recovered) can start fresh instead of replaying the same error.
      _walletFuture = null;
      rethrow;
    }
  }

  Future<CenWallet> _resolveWalletImpl() async {
    final phrase = await _keystore.readPhrase();
    if (phrase != null && phrase.isNotEmpty) {
      return CenWallet.fromMnemonic(
        Mnemonic.fromPhrase(phrase),
        CenNetwork.mainnet,
      );
    }
    // First run: create and persist a fresh phrase. The backup screen reads
    // this same phrase from the keystore, so the words the user writes down
    // can never diverge from the address mining pays into.
    final wordlist = await loadBip39Wordlist(rootBundle);
    final mnemonic = generateMnemonic(wordlist: wordlist);
    await _keystore.savePhrase(mnemonic.phrase);
    return CenWallet.fromMnemonic(mnemonic, CenNetwork.mainnet);
  }

  Future<void> _start() async {
    _mining = true;

    CenWallet wallet;
    try {
      wallet = await _resolveWallet();
    } on Object {
      _mining = false;
      status = MinerStatus.needsWallet;
      error = 'wallet';
      notifyListeners();
      return;
    }

    address = wallet.address;
    accepted = null;
    rejected = null;
    error = null;
    hashrate = null;
    status = MinerStatus.connecting;
    _sessionStartMillis = DateTime.now().millisecondsSinceEpoch;
    await _persistSessionStart(_sessionStartMillis!);
    _armLimitTimer();
    await _beginService(wallet.address);
    notifyListeners();
  }

  Future<void> _stop() async {
    _mining = false;
    _running = false;
    final wasService = await _stopService();
    if (wasService) {
      status = MinerStatus.stopped;
    }
    await _clearSessionStart();
    notifyListeners();
  }

  void _onLimit() {
    if (!_running) return;
    _mining = false;
    status = MinerStatus.limitReached;
    unawaited(_stopService());
    unawaited(_clearSessionStart());
    notifyListeners();
  }

  // --- foreground service plumbing ---------------------------------------

  Future<void> _ensureService() async {
    if (_serviceInit) return;
    initMiningService();
    _serviceInit = true;
    try {
      final req = await FlutterForegroundTask.requestNotificationPermission();
      if (req != NotificationPermission.granted) {
        // Android 13+ may deny the drawer entry; the service still runs, just
        // with a hidden notification for this session.\n
      }
    } on Object {
      // Permission flow is best-effort; the service starts regardless.
    }
  }

  Future<void> _beginService(String addr) async {
    await _ensureService();
    await FlutterForegroundTask.saveData(
      key: kMiningConfigKey,
      value: jsonEncode(<String, dynamic>{
        'address': addr,
        'host': host,
        'port': port,
        'worker': workerName,
      }),
    );

    ServiceRequestResult result;
    if (await FlutterForegroundTask.isRunningService) {
      result = await FlutterForegroundTask.restartService();
    } else {
      result = await FlutterForegroundTask.startService(
        serviceId: 1,
        notificationTitle: 'Celenium Miner',
        notificationText: 'Mining CEN in the background',
        callback: miningStartCallback,
      );
    }

    if (result is ServiceRequestFailure) {
      _mining = false;
      _running = false;
      status = MinerStatus.error;
      error = 'service: ${result.error}';
      _limitTimer?.cancel();
      _limitTimer = null;
      _sessionStartMillis = null;
      await _clearSessionStart();
      return;
    }
    _running = true;
  }

  Future<bool> _stopService() async {
    _limitTimer?.cancel();
    _limitTimer = null;
    _sessionStartMillis = null;
    hashrate = null;
    earnedPradha = null;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.sendDataToTask(const JsonEncoder().convert(<String, dynamic>{'cmd': 'stop'}));
        await FlutterForegroundTask.stopService();
        return true;
      }
    } on Object {
      // Service may already be gone; nothing to clean up.
    }
    return false;
  }

  // --- event handling -----------------------------------------------------

  void _onTaskData(Object data) {
    if (data is! String) return;
    Map<String, dynamic>? map;
    try {
      map = jsonDecode(data) as Map<String, dynamic>;
    } on Object {
      return;
    }
    final state = map['state'];
    if (state is! String) return;
    _onEvent(MinerEvent(
      state: state,
      hashrate: _asDouble(map['hashrate']),
      shares: _asInt(map['shares']),
      rejected: _asInt(map['rejected']),
      error: map['error'] as String?,
      jobId: map['jobId'] as String?,
      difficulty: _asDouble(map['difficulty']),
    ));
  }

  void _onEvent(MinerEvent ev) {
    switch (ev.state) {
      case 'connecting':
        status = MinerStatus.connecting;
        break;
      case 'mining':
        status = MinerStatus.mining;
        hashrate = ev.hashrate ?? hashrate;
        accepted = ev.shares ?? accepted;
        rejected = ev.rejected ?? rejected;
        jobId = ev.jobId ?? jobId;
        difficulty = ev.difficulty ?? difficulty;
        _updateEstimate();
        break;
      case 'error':
        status = MinerStatus.error;
        error = ev.error;
        hashrate = null;
        accepted = ev.shares;
        rejected = ev.rejected;
        _mining = false;
        _running = false;
        break;
      case 'stopped':
        if (_running) {
          status = MinerStatus.stopped;
          accepted = ev.shares;
          rejected = ev.rejected;
          hashrate = null;
          _mining = false;
          _running = false;
        }
        break;
    }
    notifyListeners();
  }

  void _updateEstimate() {
    final acc = accepted;
    if (acc == null) return;
    earnedPradha = acc * _pradhaPerShare;
  }

  static double? _asDouble(Object? v) => v is num ? v.toDouble() : (v == null ? null : double.tryParse(v.toString()));
  static int? _asInt(Object? v) => v is num ? v.toInt() : (v == null ? null : int.tryParse(v.toString()));

  // --- stop === helpers ---------------------------------------------------

  void _armLimitTimer() {
    _limitTimer?.cancel();
    final start = _sessionStartMillis;
    final elapsedMs =
        start == null ? 0 : DateTime.now().millisecondsSinceEpoch - start;
    final remaining = sessionLimit - Duration(milliseconds: elapsedMs);
    if (remaining <= Duration.zero) {
      _onLimit();
      return;
    }
    _limitTimer = Timer(remaining, _onLimit);
  }

  Future<void> _persistSessionStart(int ms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_sessionStartPref, ms);
    } on Object {
      // Best-effort: the in-memory timer still guards the current run.
    }
  }

  Future<int?> _readSessionStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_sessionStartPref);
    } on Object {
      return null;
    }
  }

  Future<void> _clearSessionStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionStartPref);
    } on Object {
      // Nothing to roll back if preferences are unavailable.
    }
  }

  int? get _sessionUptimeSeconds {
    final start = _sessionStartMillis;
    if (start == null) return null;
    return ((DateTime.now().millisecondsSinceEpoch - start) / 1000).floor();
  }

  String? get _shortAddress {
    final addr = address;
    if (addr == null) return null;
    if (addr.length <= 26) return addr;
    return '${addr.substring(0, 14)}…${addr.substring(addr.length - 8)}';
  }

  /// On app shutdown the service is deliberately left running — that is the
  /// whole point of the foreground model. We only stop listening for events.
  @override
  void dispose() {
    _limitTimer?.cancel();
    _limitTimer = null;
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }
}
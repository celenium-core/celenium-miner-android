import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'cen_wallet.dart';
import 'device_identity.dart';
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

  /// Post-Era0 mainnet block reward, in CEN per block, per the whitepaper's
  /// emission schedule. Used only to translate accepted shares into a rough
  /// "you have earned ~X CEN" figure on the mining screen.
  static const double _cenPerBlock = 0.0136656;

  /// CEN credited per accepted difficulty-1 share. Derived: a share worth
  /// `difficulty` diff-1 units earns `difficulty / (total_diff_per_block)`
  /// of a block reward. With a nominal network difficulty near 1 in early
  /// Era-0, one diff-1 share ≈ one block-equivalent of work.
  static const double _cenPerShareAtDiff1 = _cenPerBlock;

  bool _mining = false; // user intent (toggle state)
  bool _running = false; // a service worker is actually spawned/hashing
  bool _serviceInit = false; // `initMiningService` has run once

  String status = MinerStatus.idle;
  double? hashrate; // H/s
  int? accepted; // accepted shares
  int? rejected; // rejected shares
  String? error;
  String? jobId;
  double? difficulty;
  String? address; // "cen69:…" payout address
  double? estimatedCen; // Σ shares × difficulty × per-share reward

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
      estimatedCen: estimatedCen,
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
        _mining = true;
        _running = true;
        if (status != MinerStatus.mining && status != MinerStatus.connecting) {
          status = MinerStatus.mining;
        }
        notifyListeners();
      }
    } on Object {
      // Service check unavailable (e.g. early init). Stay idle.
    }
  }

  /// Derives the payout address from the device identity (Android ID, or IP on
  /// desktop/dev) without starting anything, so the wallet tab shows it before
  /// the first mining session. Nothing to restore: the same device always
  /// yields the same address.
  Future<void> resolveAddress() async {
    if (address != null) return;
    final seed = await deviceIdentitySeed();
    try {
      final wallet = deriveDeviceWallet(seed, CenNetwork.mainnet);
      address = wallet.address;
      notifyListeners();
    } on Object {
      // Leave [address] null; the wallet tab falls back to its empty state.
    }
  }

  Future<void> _start() async {
    _mining = true;

    final seed = await deviceIdentitySeed();
    CenWallet wallet;
    try {
      wallet = deriveDeviceWallet(seed, CenNetwork.mainnet);
    } on Object {
      _mining = false;
      status = MinerStatus.error;
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
    notifyListeners();
  }

  void _onLimit() {
    if (!_running) return;
    _mining = false;
    status = MinerStatus.limitReached;
    _stopService();
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
      return;
    }
    _running = true;
  }

  Future<bool> _stopService() async {
    _limitTimer?.cancel();
    _limitTimer = null;
    _sessionStartMillis = null;
    hashrate = null;
    estimatedCen = null;
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
    final diff = difficulty;
    if (acc == null || diff == null) return;
    estimatedCen = acc * diff * _cenPerShareAtDiff1;
  }

  static double? _asDouble(Object? v) => v is num ? v.toDouble() : (v == null ? null : double.tryParse(v.toString()));
  static int? _asInt(Object? v) => v is num ? v.toInt() : (v == null ? null : int.tryParse(v.toString()));

  // --- stop === helpers ---------------------------------------------------

  void _armLimitTimer() {
    _limitTimer?.cancel();
    _limitTimer = Timer(sessionLimit, _onLimit);
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
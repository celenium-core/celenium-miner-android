import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'cen_wallet.dart';
import 'keystore.dart';
import 'mining_isolate.dart';
import 'mining_readout.dart';

/// The local mining engine: owns the background isolate that runs the native
/// `celenium_scan` worker, tracks share counts and session state, and enforces
/// the 24-hour session hard-stop.
///
/// This is the real miner. It replaces the dead HTTP bridge path
/// (`POST /api/mining`) that the screen used to drive: the phone hashes against
/// the VPS pool at `5.178.98.100:5556` and submits shares directly.
///
/// The engine lives in [_MinerHomeState] (one instance for the app's lifetime)
/// so the session survives route changes. The screen reads [readout] to render
/// and flips [setMining] to start/stop. It is a [ChangeNotifier] so the owning
/// state rebuilds on every status/hashrate/share mutation without a callback.
class MiningEngine extends ChangeNotifier {
  MiningEngine({required Keystore keys}) : _keys = keys;

  /// The pool the phone submits shares to. Hard-coded on purpose: exposure of
  /// this address is a configuration detail the user should not have to set.
  static const String host = '5.178.98.100';
  static const int port = 5556;

  /// Distinguishes this device in the pool's worker list. Kept stable so a
  /// reconnect reuses the same worker slot.
  static const String workerName = 'phone';

  /// The session hard-stop. After this the isolate is stopped and the toggle
  /// returns to OFF; the user must tap again to open a fresh session.
  static const Duration sessionLimit = Duration(hours: 24);

  final Keystore _keys;

  Isolate? _isolate;
  ReceivePort? _report;
  SendPort? _toMiner;

  bool _mining = false; // user intent (toggle state)
  bool _running = false; // an isolate is actually spawned/hashing

  String status = MinerStatus.idle;
  double? hashrate; // H/s
  int? accepted; // accepted shares
  int? rejected; // rejected shares
  String? error;
  String? jobId;
  double? difficulty;
  String? address; // "cen69:…" payout address

  int? _sessionStartMillis;
  Timer? _limitTimer;

  /// Snapshot the screen renders. Kept cheap: built on demand, no I/O.
  MiningReadout get readout {
    final active = status == MinerStatus.mining;
    return MiningReadout(
      hashrateGhs: hashrate == null ? null : hashrate! / 1e9,
      difficulty: difficulty,
      workerName: _shortAddress,
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

  Future<void> _start() async {
    _mining = true;

    final phrase = await _keys.readPhrase();
    if (phrase == null || phrase.trim().isEmpty) {
      _mining = false;
      status = MinerStatus.needsWallet;
      notifyListeners();
      return;
    }

    CenWallet wallet;
    try {
      wallet = CenWallet.fromMnemonic(
        Mnemonic.fromPhrase(phrase.trim()),
        CenNetwork.mainnet,
      );
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
    await _spawn(wallet.address);
    notifyListeners();
  }

  Future<void> _stop() async {
    _mining = false;
    if (!_running) return;
    status = MinerStatus.stopped;
    await _teardown();
    notifyListeners();
  }

  void _onLimit() {
    if (!_running) return;
    _mining = false;
    status = MinerStatus.limitReached;
    _teardown();
    notifyListeners();
  }

  Future<void> _spawn(String addr) async {
    _running = true;
    final report = ReceivePort();
    final controlCompleter = Completer<SendPort>();
    report.listen((message) {
      if (message is SendPort) {
        controlCompleter.complete(message);
      } else if (message is MinerEvent) {
        _onEvent(message);
      }
    });
    _report = report;
    _isolate = await Isolate.spawn(minerIsolateEntry, report.sendPort);
    final toMiner = await controlCompleter.future;
    _toMiner = toMiner;
    toMiner.send(StartCommand(
      address: addr,
      host: host,
      port: port,
      workerName: workerName,
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
        break;
      case 'error':
        status = MinerStatus.error;
        error = ev.error;
        hashrate = null;
        accepted = ev.shares;
        rejected = ev.rejected;
        _mining = false;
        _running = false;
        _releaseIsolate();
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

  Future<void> _teardown() async {
    _running = false;
    _limitTimer?.cancel();
    _limitTimer = null;
    _sessionStartMillis = null;
    hashrate = null;
    final toMiner = _toMiner;
    final isolate = _isolate;
    final report = _report;
    _toMiner = null;
    _isolate = null;
    _report = null;

    if (toMiner != null) {
      try {
        toMiner.send(const StopCommand());
      } on Object {
        // The isolate may already be gone; the hard kill below covers it.
      }
    }
    if (isolate != null) {
      // Give the worker a beat to release its native memory on the message,
      // then hard-kill so no isolate lingers past the toggle.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      isolate.kill(priority: Isolate.immediate);
    }
    report?.close();
  }

  /// Drops the isolate handles after a self-terminating event (an error), so a
  /// fresh toggle spawns clean state. The report port is closed a microtask
  /// later: closing it synchronously from inside its own listener would cut
  /// the current dispatch short.
  void _releaseIsolate() {
    _limitTimer?.cancel();
    _limitTimer = null;
    _sessionStartMillis = null;
    final report = _report;
    final isolate = _isolate;
    _report = null;
    _isolate = null;
    _toMiner = null;
    isolate?.kill(priority: Isolate.immediate);
    if (report != null) scheduleMicrotask(report.close);
  }

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

  /// Synchronous teardown for app shutdown: kill immediately (no 500 ms grace —
  /// nothing else uses the isolate), close the report port so no late event
  /// notifies a disposed listener, then hand back to [ChangeNotifier.dispose].
  @override
  void dispose() {
    _limitTimer?.cancel();
    _limitTimer = null;
    final toMiner = _toMiner;
    final isolate = _isolate;
    final report = _report;
    _toMiner = null;
    _isolate = null;
    _report = null;
    try {
      toMiner?.send(const StopCommand());
    } on Object {
      // The isolate may already be gone; the kill below is the backstop.
    }
    isolate?.kill(priority: Isolate.immediate);
    report?.close();
    super.dispose();
  }
}
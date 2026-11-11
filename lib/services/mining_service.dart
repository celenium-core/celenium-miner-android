import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'mining_isolate.dart';

/// SharedPreferences key the engine writes before starting the service so the
/// handler's [onStart] can rebuild the worker's [StartCommand] without the UI
/// isolate being alive.
const String kMiningConfigKey = 'mining_config';

/// One-time Android config for the foreground service: notification channel,
/// wakelock policy, and no periodic `onRepeatEvent` (the hashing loop runs in
/// its own isolate and pushes updates as they happen).
void initMiningService() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'cen_mining',
      channelName: 'Celenium Miner',
      channelDescription: 'Mining CEN continues in the background',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      allowWakeLock: true,
      allowWifiLock: true,
      // A mining session that is supposed to run for a day must come back on
      // its own: after a device reboot or an app update the plugin's receivers
      // restart the service with the saved config instead of waiting for the
      // user to reopen the app.
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
    ),
  );
}

/// Top-level callback passed to [FlutterForegroundTask.startService]. The
/// plugin requires a top-level or static function so it can spin up the
/// handler inside its own background isolate.
@pragma('vm:entry-point')
void miningStartCallback() {
  FlutterForegroundTask.setTaskHandler(MiningTaskHandler());
}

/// Owns the hashing isolate inside the foreground service and relays its
/// [MinerEvent]s to the UI isolate as JSON over the plugin channel. Because
/// this runs in the service's isolate — not the activity's — mining survives
/// the app being swiped away or the activity being destroyed in the background.
class MiningTaskHandler extends TaskHandler {
  ReceivePort? _report;
  SendPort? _toMiner;
  Isolate? _isolate;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final raw = await FlutterForegroundTask.getData(key: kMiningConfigKey);
    if (raw is! String || raw.isEmpty) return;
    await _spawn(raw);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op: the worker isolate drives its own cadence.
  }

  @override
  void onReceiveData(Object data) {
    if (data is! String) return;
    Map<String, dynamic>? map;
    try {
      map = jsonDecode(data) as Map<String, dynamic>;
    } on Object {
      return;
    }
    switch (map['cmd']) {
      case 'start':
        final config = map['config'];
        if (config is String) _spawn(config);
        break;
      case 'stop':
        _stopWorker();
        break;
    }
  }

  Future<void> _spawn(String configJson) async {
    _stopWorker();

    StartCommand cmd;
    try {
      final map = jsonDecode(configJson) as Map<String, dynamic>;
      cmd = StartCommand(
        address: map['address'] as String,
        host: map['host'] as String,
        port: map['port'] as int,
        workerName: map['worker'] as String,
      );
    } on Object {
      _reportEvent(const MinerEvent(state: 'error', error: 'config'));
      return;
    }

    final report = ReceivePort();
    _report = report;
    final control = Completer<SendPort>();
    report.listen((message) {
      if (message is SendPort) {
        if (!control.isCompleted) control.complete(message);
      } else if (message is MinerEvent) {
        _reportEvent(message);
      }
    });

    try {
      _isolate = await Isolate.spawn(minerIsolateEntry, report.sendPort);
      final toMiner = await control.future.timeout(const Duration(seconds: 5));
      _toMiner = toMiner;
      toMiner.send(cmd);
    } on Object catch (e) {
      _reportEvent(MinerEvent(state: 'error', error: 'spawn: $e'));
    }
  }

  void _reportEvent(MinerEvent event) {
    FlutterForegroundTask.sendDataToMain(jsonEncode(<String, dynamic>{
      'state': event.state,
      'hashrate': event.hashrate,
      'shares': event.shares,
      'rejected': event.rejected,
      'error': event.error,
      'jobId': event.jobId,
      'difficulty': event.difficulty,
    }));
  }

  void _stopWorker() {
    final toMiner = _toMiner;
    final isolate = _isolate;
    final report = _report;
    _toMiner = null;
    _isolate = null;
    _report = null;
    try {
      toMiner?.send(const StopCommand());
    } on Object {
      // Worker may already be gone; the kill below is the backstop.
    }
    isolate?.kill(priority: Isolate.immediate);
    report?.close();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _stopWorker();
  }
}
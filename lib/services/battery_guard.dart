import 'package:flutter/services.dart';

/// Battery-optimisation status, read from the platform.
///
/// Android's Doze defers CPU work for any app the system has not exempted, so
/// an overnight mining run can stall even while the foreground service holds
/// its wakelock. The exemption is the one lever that stops that.
class BatteryGuard {
  BatteryGuard._();

  static const MethodChannel _channel = MethodChannel('celenium/device');

  /// True when the system has already exempted this app.
  static Future<bool> isExempt() async {
    try {
      return await _channel.invokeMethod<bool>('batteryExempt') ?? false;
    } on Object {
      // A desktop build or a channel-less test has no such setting; report
      // exempt so the prompt never appears where it cannot help.
      return true;
    }
  }

  /// Opens the system dialog that grants the exemption.
  static Future<void> requestExemption() async {
    try {
      await _channel.invokeMethod<void>('requestBatteryExemption');
    } on Object {
      // The user can still grant it by hand in Settings.
    }
  }
}

import 'dart:io';

import 'package:flutter/services.dart';

const OptionalMethodChannel _channel = OptionalMethodChannel('celenium/device');

/// A stable per-device string that seeds the mining payout address.
///
/// Android ID wins: it is stable across reboots and needs no permission. IMEI
/// is blocked on Android 10+, so Android ID is the closest practical stand-in.
/// Non-loopback IPv4 addresses cover desktop/dev runs and devices with no ID.
Future<String> deviceIdentitySeed() async {
  String? androidId;
  try {
    androidId = await _channel.invokeMethod<String>('androidId');
  } on Object {
    androidId = null;
  }
  if (androidId != null && androidId.isNotEmpty) {
    return 'android-id:$androidId';
  }
  final ips = await _ipv4Addresses();
  if (ips.isNotEmpty) {
    return 'ip:${ips.join(',')}';
  }
  return 'unknown-device';
}

Future<List<String>> _ipv4Addresses() async {
  final out = <String>[];
  try {
    final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) out.add(addr.address);
      }
    }
  } on Object {
    // Enumeration is best-effort; an empty list simply falls through.
  }
  return out;
}
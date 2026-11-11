import 'dart:io';

import 'package:flutter/services.dart';

const OptionalMethodChannel _channel = OptionalMethodChannel('celenium/device');

/// A stable per-device string that seeds the mining payout address.
///
/// Android ID wins: it is stable across reboots and needs no permission. IMEI
/// is blocked on Android 10+, so Android ID is the closest practical stand-in.
/// Non-loopback IPv4 addresses cover desktop/dev runs and devices with no ID.
Future<String> deviceIdentitySeed() async {
  final androidId = await _androidId();
  if (androidId != null && androidId.isNotEmpty) {
    return 'android-id:$androidId';
  }
  final ips = await _ipv4Addresses();
  if (ips.isNotEmpty) {
    return 'ip:${ips.join(',')}';
  }
  return 'unknown-device';
}

/// One-line device label for the profile card: the LAN address first (the
/// value a user can match against their router), then the Android ID that
/// actually anchors the payout key — IMEI itself is off-limits to apps.
Future<String?> deviceIdentityLabel() async {
  final parts = <String>[];
  final ips = await _ipv4Addresses();
  if (ips.isNotEmpty) parts.add('IP ${ips.first}');
  final androidId = await _androidId();
  if (androidId != null && androidId.isNotEmpty) parts.add('ID $androidId');
  return parts.isEmpty ? null : parts.join(' · ');
}

Future<String?> _androidId() async {
  try {
    return await _channel.invokeMethod<String>('androidId');
  } on Object {
    return null;
  }
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
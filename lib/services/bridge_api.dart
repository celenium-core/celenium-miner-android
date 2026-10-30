import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bridge.dart';

/// Client for the Celenium stratum bridge HTTP API.
///
/// The bridge serves `GET /api/status` and `GET /api/stats` on its web
/// dashboard port. Both return plain JSON and set
/// `Access-Control-Allow-Origin: *`, so no special headers are needed.
class BridgeApi {
  BridgeApi({required this.baseUrl});

  /// Base URL, for example `http://127.0.0.1:3030`. No trailing slash.
  final String baseUrl;

  static const Duration timeout = Duration(seconds: 5);

  Future<BridgeStatus> fetchStatus() async {
    final body = await _get('/api/status');
    final parsed = BridgeStatus.tryParse(body);
    if (parsed == null) {
      throw const FormatException('Bridge returned an unexpected status body');
    }
    return parsed;
  }

  Future<BridgeStats> fetchStats() async {
    final body = await _get('/api/stats');
    final parsed = BridgeStats.tryParse(body);
    if (parsed == null) {
      throw const FormatException('Bridge returned an unexpected stats body');
    }
    return parsed;
  }

  Future<MinerSnapshot> fetchSnapshot() async {
    // Status and stats are independent, so fetch them together.
    final results = await Future.wait([
      _tryFetch(fetchStatus),
      _tryFetch(fetchStats),
    ]);
    return MinerSnapshot(
      status: results[0] as BridgeStatus?,
      stats: results[1] as BridgeStats?,
    );
  }

  Future<Object?> _tryFetch(Future<Object?> Function() call) async {
    try {
      return await call();
    } on Object {
      return null;
    }
  }

  Future<Object?> _get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw HttpException('Bridge returned HTTP ${response.statusCode} for $path');
    }
    return jsonDecode(response.body);
  }
}

/// Thrown when the bridge answers but not with a usable response.
class HttpException implements Exception {
  const HttpException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Normalises user input into a base URL the client can use.
///
/// Accepts `127.0.0.1:3030`, `http://127.0.0.1:3030`, and
/// `http://127.0.0.1:3030/`. Returns null when nothing usable remains.
String? normaliseBaseUrl(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return null;
  if (!value.startsWith('http://') && !value.startsWith('https://')) {
    value = 'http://$value';
  }
  value = value.replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return null;
  return value;
}

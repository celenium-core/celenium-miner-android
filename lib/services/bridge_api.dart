import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bridge.dart';

/// Client for the Celenium stratum bridge HTTP API.
///
/// The bridge serves `GET /api/status`, `GET /api/stats`,
/// `GET /api/balance`, and `POST /api/send` on its web dashboard port. All
/// return plain JSON and set `Access-Control-Allow-Origin: *`, so no special
/// headers are needed.
class BridgeApi {
  BridgeApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// Base URL, for example `http://127.0.0.1:3030`. No trailing slash.
  final String baseUrl;

  /// Injected for tests; the app uses the default client, which shares a
  /// single pooled connection set across calls.
  final http.Client _client;

  static const Duration timeout = Duration(seconds: 5);

  /// A send does several node round-trips (UTXO lookup, sign, submit), so it
  /// gets a wider budget than the one-shot reads.
  static const Duration sendTimeout = Duration(seconds: 20);

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

  /// `GET /api/balance?address=...` — the account balance in pradha.
  ///
  /// Returns `null` when the node is unreachable, the address is unknown, or
  /// the bridge answers an error body. Addresses are bech32 plus a `celenium:`
  /// HRP (URL-safe), so the value is sent raw and the query stays a plain
  /// `address=` pair.
  Future<AccountBalance?> fetchBalance(String address) async {
    final body = await _get('/api/balance?address=$address');
    return AccountBalance.tryParse(body);
  }

  /// `POST /api/send` — submit a signed transfer and return its transaction id.
  ///
  /// The bridge signs with [privateKeyHex] (the local wallet's secret, supplied
  /// per request and never stored). [amountPradha] is the value sent; the fee
  /// is added on top, so the spending UTXO must cover both.
  Future<SendResult> sendCoins({
    required String from,
    required String to,
    required int amountPradha,
    required String privateKeyHex,
    int feePradha = 1000000,
  }) async {
    final body = await _post('/api/send', {
      'from': from,
      'to': to,
      'amountPradha': amountPradha,
      'feePradha': feePradha,
      'privateKeyHex': privateKeyHex,
    });
    final parsed = SendResult.tryParse(body);
    if (parsed == null) {
      throw const FormatException('Bridge returned an unexpected send body');
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
    final response = await _client.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw HttpException(
        'Bridge returned HTTP ${response.statusCode} for $path',
      );
    }
    return jsonDecode(response.body);
  }

  Future<Object?> _post(String path, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(sendTimeout);
    if (response.statusCode != 200) {
      throw HttpException(
        'Bridge returned HTTP ${response.statusCode} for $path',
      );
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
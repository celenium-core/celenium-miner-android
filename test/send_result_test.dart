// Functional coverage for the send WIRE path: the `POST /api/send` request
// shape and `SendResult` response parsing. The UI decision (sheet vs
// "unavailable" dialog) is pinned in wallet_functions_test.dart; this locks
// the actual transfer submission — the request body the bridge receives and
// how a txid or a rejection comes back — which had no test before.
library;

import 'dart:convert';

import 'package:celenium_miner/models/bridge.dart';
import 'package:celenium_miner/services/bridge_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const from = 'cen69:qz0p8x7m2v5n3w9r4t6y8u1i5o7p9a2s3d4f6g8h7j6k5l9';
  const to = 'cen69:qzl9m8n7b6v5c4x3z2a1s0d9f8g7h6j5k4l3k2j1h0g9f8d7s6';

  group('SendResult.tryParse', () {
    test('accepts a transaction id and reports ok', () {
      final result = SendResult.tryParse({'txid': 'deadbeef'})!;
      expect(result.ok, isTrue);
      expect(result.txid, 'deadbeef');
      expect(result.error, isNull);
    });

    test('accepts an error body without inventing a txid', () {
      final result = SendResult.tryParse({'error': 'insufficient funds'})!;
      expect(result.ok, isFalse);
      expect(result.txid, isNull);
      expect(result.error, 'insufficient funds');
    });

    test('rejects a body with neither txid nor error', () {
      expect(SendResult.tryParse({'foo': 'bar'}), isNull);
      expect(SendResult.tryParse({'txid': null, 'error': null}), isNull);
      expect(SendResult.tryParse(null), isNull);
    });
  });

  group('BridgeApi.sendCoins', () {
    test('POSTs the signed transfer and parses the txid', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'txid': 'deadbeef'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = BridgeApi(baseUrl: 'http://127.0.0.1:3030', client: client);
      final result = await api.sendCoins(
        from: from,
        to: to,
        amountPradha: 500000000,
        // Fake key: the mock bridge never validates the secret.
        privateKeyHex: '1'.padLeft(64, '0'),
      );

      expect(result.ok, isTrue);
      expect(result.txid, 'deadbeef');
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/send');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['from'], from);
      expect(body['to'], to);
      expect(body['amountPradha'], 500000000);
      expect(body['feePradha'], 1000000); // the fixed 0.01 CEN fee default
      expect(body['privateKeyHex'], isNotEmpty);
    });

    test('surfaces the bridge rejection as a result, not a throw', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'error': 'insufficient funds'}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final api = BridgeApi(baseUrl: 'http://127.0.0.1:3030', client: client);
      final result = await api.sendCoins(
        from: from,
        to: to,
        amountPradha: 1,
        privateKeyHex: '1'.padLeft(64, '0'),
      );

      expect(result.ok, isFalse);
      expect(result.error, 'insufficient funds');
    });

    test('throws on a body that is neither txid nor error', () async {
      final client = MockClient(
        (request) async => http.Response('{}', 200),
      );

      final api = BridgeApi(baseUrl: 'http://127.0.0.1:3030', client: client);
      expect(
        () => api.sendCoins(
          from: from,
          to: to,
          amountPradha: 1,
          privateKeyHex: '1'.padLeft(64, '0'),
        ),
        throwsFormatException,
      );
    });

    test('throws HttpException when the bridge answers a non-200', () async {
      final client = MockClient(
        (request) async => http.Response('busy', 500),
      );

      final api = BridgeApi(baseUrl: 'http://127.0.0.1:3030', client: client);
      expect(
        () => api.sendCoins(
          from: from,
          to: to,
          amountPradha: 1,
          privateKeyHex: '1'.padLeft(64, '0'),
        ),
        throwsA(isA<HttpException>()),
      );
    });
  });
}
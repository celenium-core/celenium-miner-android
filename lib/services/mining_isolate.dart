import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'miner_native.dart';

/// A stratum share-mining worker that runs entirely inside a background
/// isolate so the native `celenium_scan` work never blocks the UI thread.
///
/// Protocol notes (all verified byte-for-byte against the VPS bridge at
/// `5.178.98.100:5556`):
///
///   * `mining.subscribe`  -> `[true, "EthereumStratum/1.0.0"]`
///   * `mining.set_extranonce` -> `["XX"]` hex, 4 chars (2-byte u16, the high
///     16 bits of the nonce)
///   * `mining.set_difficulty` -> `[d]` (double)
///   * `mining.notify`      -> `{ "id": job_id, "params": [ job_id_str,
///     [u64 LE x4], timestamp_ms ] }`
///   * `mining.submit`      -> `[ "<addr>.<worker>", job_id_str, nonce_hex ]`
///     where `nonce_hex` is the full nonce as 16 hex chars.
///
/// The notify `head` and `timestamp` are 64-bit integers that can exceed
/// 2^63, so `dart:convert`'s `jsonDecode` is deliberately NOT used for them —
/// it would smash the value into a lossy `double`. Fields are parsed with
/// regex and built into `BigInt` instead.
final RegExp _notifyRe = RegExp(
  r'"method"\s*:\s*"mining.notify".*?"params"\s*:\s*\[\s*"([^"]*)"\s*,\s*\['
  r'\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\]\s*,\s*(\d+)\s*\]',
);
final RegExp _difficultyRe = RegExp(
  r'"method"\s*:\s*"mining.set_difficulty".*?"params"\s*:\s*\[\s*([0-9.eE+-]+)\s*\]',
);
final RegExp _extranonceRe = RegExp(
  r'"method"\s*:\s*"mining.set_extranonce".*?"params"\s*:\s*\[\s*"([0-9a-fA-F]+)"\s*\]',
);

final BigInt _maxTarget = (BigInt.one << 224) - BigInt.one;
final BigInt _oneEg = BigInt.from(1000000000000000000); // 1e18

/// Command sent from the engine isolate to this isolate.
class StartCommand {
  const StartCommand({
    required this.address,
    required this.host,
    required this.port,
    required this.workerName,
  });

  final String address; // "cen69:…" mainnet payout address
  final String host;
  final int port;
  final String workerName;
}

class StopCommand {
  const StopCommand();
}

/// A periodic status report from this isolate back to the engine.
class MinerEvent {
  const MinerEvent({
    required this.state,
    this.hashrate,
    this.shares,
    this.rejected,
    this.error,
    this.jobId,
    this.difficulty,
  });

  /// `connecting`, `mining`, `stopped`, or `error`.
  final String state;
  final double? hashrate; // H/s
  final int? shares;
  final int? rejected;
  final String? error;
  final String? jobId;
  final double? difficulty;
}

/// One job, parsed from a `mining.notify` message.
class _Job {
  const _Job({
    required this.prePowHash,
    required this.timestamp,
    required this.jobId,
  });

  final Uint8List prePowHash; // 32 bytes little-endian
  final int timestamp;
  final String jobId;
}

/// Isolate entry point. Sends its control [SendPort] back to the engine as the
/// first message, then runs the mining loop for the first [StartCommand] it
/// receives.
void minerIsolateEntry(SendPort reportPort) {
  final control = ReceivePort();
  reportPort.send(control.sendPort);
  var stop = false;
  final started = Completer<StartCommand>();
  control.listen((message) {
    if (message is StartCommand) {
      if (!started.isCompleted) started.complete(message);
    } else if (message is StopCommand) {
      stop = true;
    }
  });

  started.future.then((command) async {
    await _mine(command, reportPort, () => stop);
    control.close();
  });
}

/// `maxTarget * 1e18 / trunc(diff * 1e18)`, exactly as the bridge's
/// `diff_to_target_standard`. Uses BigInt integer arithmetic so the result is
/// bit-identical to the Rust `BigUint` computation.
BigInt _diffToTarget(double diff) {
  if (diff <= 0) return _maxTarget;
  final scaled = (diff * 1e18).floor();
  if (scaled <= 0) return _maxTarget;
  final numerator = _maxTarget * _oneEg;
  return numerator ~/ BigInt.from(scaled);
}

/// The share target as a 32-byte little-endian array. The bridge accepts a
/// share only when `pow_value < pool_target` (strict), while the native
/// engine matches `<=`; subtracting one reconciles the two.
Uint8List _targetLe(double diff) {
  final target = _diffToTarget(diff) - BigInt.one;
  final out = Uint8List(32);
  if (target <= BigInt.zero) return out;
  var x = target;
  for (var i = 0; i < 32; i++) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x >>= 8;
  }
  return out;
}

Future<void> _mine(StartCommand cmd, SendPort report, bool Function() stopped) async {
  void send(MinerEvent event) => report.send(event);

  send(const MinerEvent(state: 'connecting'));

  final native = MinerNative.load();
  if (native == null) {
    send(const MinerEvent(state: 'error', error: 'native lib not found'));
    return;
  }

  final Socket socket;
  try {
    socket =
        await Socket.connect(cmd.host, cmd.port, timeout: const Duration(seconds: 15));
    socket.setOption(SocketOption.tcpNoDelay, true);
  } on Object catch (e) {
    send(MinerEvent(state: 'error', error: 'connect: $e'));
    return;
  }

  final worker = '${cmd.address}.${cmd.workerName}';
  socket.add(utf8.encode(jsonEncode({
    'id': 1,
    'method': 'mining.subscribe',
    'params': ['celenium-miner/1.0.0', null],
  }) + '\n'));
  socket.add(utf8.encode(jsonEncode({
    'id': 2,
    'method': 'mining.authorize',
    'params': [worker, 'x'],
  }) + '\n'));

  // Shared, mutation-visible state. The socket listener and the scan loop run
  // on the same isolate, so these are safe to touch from both.
  var extranonce = 0; // high 16 bits of the nonce
  var diff = 1.0;
  var revision = 0;
  _Job? job;
  var submitted = 0; // accepted shares
  var rejected = 0;
  var socketClosed = false;
  String pending = '';

  void onLine(String line) {
    if (_notifyRe.hasMatch(line)) {
      final m = _notifyRe.firstMatch(line)!;
      final prePow = Uint8List(32);
      final bd = ByteData.view(prePow.buffer);
      _writeU64Le(bd, 0, BigInt.parse(m.group(2)!));
      _writeU64Le(bd, 8, BigInt.parse(m.group(3)!));
      _writeU64Le(bd, 16, BigInt.parse(m.group(4)!));
      _writeU64Le(bd, 24, BigInt.parse(m.group(5)!));
      final ts = BigInt.parse(m.group(6)!).toInt();
      job = _Job(prePowHash: prePow, timestamp: ts, jobId: m.group(1)!);
      revision++;
      return;
    }

    final diffMatch = _difficultyRe.firstMatch(line);
    if (diffMatch != null) {
      final d = double.tryParse(diffMatch.group(1)!);
      if (d != null && d > 0) {
        diff = d;
        revision++;
      }
      return;
    }

    final extranonceMatch = _extranonceRe.firstMatch(line);
    if (extranonceMatch != null) {
      extranonce = int.parse(extranonceMatch.group(1)!, radix: 16);
      revision++;
      return;
    }

    // A response to one of our own `mining.submit` calls (id >= 1000). The
    // handshake ids (1, 2) fall below that threshold and are ignored.
    if (!line.contains('"method"')) {
      final idMatch = RegExp(r'"id"\s*:\s*(\d+)').firstMatch(line);
      if (idMatch != null) {
        final id = int.tryParse(idMatch.group(1)!);
        if (id != null && id >= 1000) {
          if (RegExp(r'"result"\s*:\s*true').hasMatch(line)) {
            submitted++;
          } else {
            rejected++;
          }
        }
      }
    }
  }

  socket.listen(
    (data) {
      pending += utf8.decode(data, allowMalformed: true);
      int idx;
      while ((idx = pending.indexOf('\n')) >= 0) {
        final line = pending.substring(0, idx).trim();
        pending = pending.substring(idx + 1);
        if (line.isNotEmpty) onLine(line);
      }
    },
    onError: (_) => socketClosed = true,
    onDone: () => socketClosed = true,
  );

  const chunk = 200000;
  final sw = Stopwatch()..start();
  var windowHashes = 0;
  var windowStart = sw.elapsed;
  var nonceCursor = 0;
  var builtRevision = -1;
  var submitId = 1000;
  PowWorker? powWorker;
  final foundPow = Uint8List(32);

  try {
    while (!stopped() && !socketClosed) {
      if (job == null) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        continue;
      }

      if (powWorker == null || builtRevision != revision) {
        powWorker?.dispose();
        powWorker = native.newWorker(job!.prePowHash, job!.timestamp);
        builtRevision = revision;
        nonceCursor = extranonce << 48;
        windowHashes = 0;
        sw.reset();
        windowStart = sw.elapsed;
      }

      final found = powWorker.scan(_targetLe(diff), nonceCursor, chunk, foundPow);
      nonceCursor += chunk;
      windowHashes += chunk;

      if (found != kNoNonce) {
        final nonceHex =
            BigInt.from(found).toUnsigned(64).toRadixString(16).padLeft(16, '0');
        socket.add(utf8.encode(jsonEncode({
          'id': submitId++,
          'method': 'mining.submit',
          'params': [worker, job!.jobId, nonceHex],
        }) + '\n'));
      }

      final elapsed = sw.elapsed;
      if (elapsed - windowStart >= const Duration(seconds: 1)) {
        final ms = (elapsed - windowStart).inMilliseconds;
        final hps = ms == 0 ? 0.0 : windowHashes * 1000.0 / ms;
        send(MinerEvent(
          state: 'mining',
          hashrate: hps,
          shares: submitted,
          rejected: rejected,
          jobId: job!.jobId,
          difficulty: diff,
        ));
        windowHashes = 0;
        windowStart = elapsed;
      }

      // Yield to the event loop so socket frames and the stop command are
      // delivered between scan chunks.
      await Future<void>.delayed(Duration.zero);
    }
  } finally {
    powWorker?.dispose();
    socket.destroy();
  }

  send(MinerEvent(
    state: socketClosed && !stopped() ? 'error' : 'stopped',
    shares: submitted,
    rejected: rejected,
    error: socketClosed && !stopped() ? 'connection lost' : null,
  ));
}

void _writeU64Le(ByteData bd, int offset, BigInt value) {
  final u = value.toUnsigned(64);
  for (var i = 0; i < 8; i++) {
    bd.setUint8(offset + i, (u >> (8 * i)).toInt() & 0xff);
  }
}
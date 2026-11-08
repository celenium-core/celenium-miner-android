import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Dart bindings to `libcelenium_miner.so`, the native kHeavyHash PoW engine.
///
/// The four C ABI symbols mirror the Rust side of
/// `consensus/core/src/poW.rs`:
///
///   * a job is the pair (`pre_pow_hash`, `timestamp`);
///   * hashing one nonce is
///     `Matrix::heavy_hash(PowHash::finalize_with_nonce(nonce))`;
///   * a nonce is valid when the 32-byte little-endian pow value is
///     `<=` the requested target.
///
/// `cargo` builds the same tree into `libcelenium_miner.so` for
/// arm64-v8a / armeabi-v7a / x86_64 and it is shipped under
/// `android/app/src/main/jniLibs/<abi>/`.
typedef _WorkerNewNative = Pointer<Void> Function(Pointer<Uint8>, Uint64);
typedef _WorkerNewDart = Pointer<Void> Function(Pointer<Uint8>, int);
typedef _ScanNative = Uint64 Function(
    Pointer<Void>, Pointer<Uint8>, Uint64, Uint64, Pointer<Uint64>, Pointer<Uint8>);
typedef _ScanDart = int Function(
    Pointer<Void>, Pointer<Uint8>, int, int, Pointer<Uint64>, Pointer<Uint8>);
typedef _WorkerFreeNative = Void Function(Pointer<Void>);
typedef _WorkerFreeDart = void Function(Pointer<Void>);

/// The value `celenium_scan` returns when no nonce in the scanned range hashes
/// low enough: `u64::MAX` (`0xffff_ffff_ffff_ffff`). dart:ffi surfaces a
/// `Uint64` return as a *signed* 64-bit Dart `int`, so that bit pattern is -1.
const int kNoNonce = -1;

/// Loaded-once wrapper around the native library. `null` means the `.so` is
/// not present (desktop builds do not bundle it), in which case the miner is
/// simply unavailable.
class MinerNative {
  MinerNative._(this._new, this._scan, this._free);

  final _WorkerNewDart _new;
  final _ScanDart _scan;
  final _WorkerFreeDart _free;

  static MinerNative? _cached;

  static MinerNative? load() {
    if (_cached != null) return _cached;
    try {
      final lib = DynamicLibrary.open('libcelenium_miner.so');
      final workerNew = lib
          .lookupFunction<_WorkerNewNative, _WorkerNewDart>('celenium_worker_new');
      final scan = lib.lookupFunction<_ScanNative, _ScanDart>('celenium_scan');
      final free = lib
          .lookupFunction<_WorkerFreeNative, _WorkerFreeDart>('celenium_worker_free');
      _cached = MinerNative._(workerNew, scan, free);
      return _cached;
    } on Object {
      return null;
    }
  }

  /// Builds a native worker for one job. [prePowHash] must be 32 bytes.
  PowWorker newWorker(Uint8List prePowHash, int timestamp) {
    assert(prePowHash.length == 32);
    final buf = calloc.allocate<Uint8>(32);
    buf.asTypedList(32).setAll(0, prePowHash);
    final ptr = _new(buf, timestamp);
    calloc.free(buf);
    return PowWorker._(this, ptr);
  }
}

class PowWorker {
  PowWorker._(this._native, this._ptr);

  final MinerNative _native;
  final Pointer<Void> _ptr;
  bool _freed = false;

  /// Scans [iterations] nonce values starting at [startNonce], testing each
  /// against a 32-byte little-endian [targetLe]. Returns the winning nonce, or
  /// [kNoNonce] when none matched. [outPow] (32 bytes) receives the matching
  /// pow value on success.
  int scan(Uint8List targetLe, int startNonce, int iterations, Uint8List outPow) {
    final target = calloc.allocate<Uint8>(32);
    target.asTypedList(32).setAll(0, targetLe);
    final nonceOut = calloc.allocate<Uint64>(8);
    final powOut = calloc.allocate<Uint8>(32);
    final result =
        _native._scan(_ptr, target, startNonce, iterations, nonceOut, powOut);
    if (result != kNoNonce) {
      outPow.setAll(0, powOut.asTypedList(32));
    }
    calloc.free(target);
    calloc.free(nonceOut);
    calloc.free(powOut);
    return result;
  }

  void dispose() {
    if (_freed) return;
    _freed = true;
    _native._free(_ptr);
  }
}
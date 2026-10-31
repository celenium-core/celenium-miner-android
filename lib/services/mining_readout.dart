import '../models/bridge.dart';

/// Display values for the mining screen, derived from a bridge snapshot.
///
/// Everything here comes from the bridge. Nothing is estimated: when the
/// bridge has not answered, the fields stay null and the screen shows an
/// honest state instead of a zero.
class MiningReadout {
  const MiningReadout({
    this.hashrateGhs,
    this.difficulty,
    this.workerName,
    this.shares,
    this.stale,
    this.invalid,
    this.sessionBlocks,
    this.totalBlocks,
    this.latestBlockHash,
    this.latestBlockTime,
    this.active = false,
  });

  /// Live hashrate in GH/s.
  final double? hashrateGhs;

  /// Share difficulty currently assigned to this worker.
  final double? difficulty;

  /// Worker name reported by the bridge.
  final String? workerName;

  final int? shares;
  final int? stale;
  final int? invalid;

  /// Blocks accepted in this session.
  final int? sessionBlocks;

  /// Blocks mined across the whole pool, per the bridge.
  final int? totalBlocks;

  final String? latestBlockHash;
  final String? latestBlockTime;

  /// True when the bridge reports a worker actually hashing.
  final bool active;

  static const MiningReadout empty = MiningReadout(active: false);

  /// Share acceptance rate in 0..1, or null when no shares have been
  /// submitted. This is what the dial shows: the fraction of submitted work
  /// the network counted.
  double? get acceptanceRate {
    final accepted = sessionBlocks ?? 0;
    final rejected = (stale ?? 0) + (invalid ?? 0);
    final total = accepted + rejected;
    if (total == 0) return null;
    return accepted / total;
  }

  factory MiningReadout.from(MinerSnapshot snapshot) {
    final stats = snapshot.stats;
    if (stats == null) return empty;

    final cpu = stats.internalCpu;
    final workers = stats.workers;

    // Prefer the bridge's own CPU aggregate; fall back to summing workers so
    // a pool without the internal miner still reports something.
    final hashrate = cpu?.hashrateGhs ?? _sumWorkers(workers, (w) => w.hashrate);
    final shares = cpu?.shares ?? _sumIntWorkers(workers, (w) => w.shares);
    final stale = cpu?.stale ?? _sumIntWorkers(workers, (w) => w.stale);
    final invalid = cpu?.invalid ?? _sumIntWorkers(workers, (w) => w.invalid);
    final sessionBlocks = cpu?.blocksAccepted ?? _sumIntWorkers(workers, (w) => w.blocks);

    final primary = workers.isNotEmpty ? workers.first : null;
    final latest = stats.blocks.isNotEmpty ? stats.blocks.first : null;

    final active = hashrate > 0 || (primary?.status?.toLowerCase().contains('active') ?? false);

    return MiningReadout(
      hashrateGhs: hashrate > 0 ? hashrate : null,
      difficulty: primary?.currentDifficulty?.toDouble(),
      workerName: primary?.worker,
      shares: shares > 0 ? shares : null,
      stale: stale > 0 ? stale : null,
      invalid: invalid > 0 ? invalid : null,
      sessionBlocks: sessionBlocks > 0 ? sessionBlocks : null,
      totalBlocks: stats.totalBlocks > 0 ? stats.totalBlocks : null,
      latestBlockHash: latest?.hash,
      latestBlockTime: latest?.timestamp,
      active: active,
    );
  }
}

double _sumWorkers(List<WorkerInfo> workers, double Function(WorkerInfo) pick) {
  var total = 0.0;
  for (final w in workers) {
    total += pick(w);
  }
  return total;
}

int _sumIntWorkers(List<WorkerInfo> workers, int Function(WorkerInfo) pick) {
  var total = 0;
  for (final w in workers) {
    total += pick(w);
  }
  return total;
}

/// Formats a GH/s reading into the unit that keeps the number readable.
///
/// A small rig hashes in MH/s; showing 0.0042 GH/s wastes the reader's
/// attention on zeros. The unit is always stated, never implied.
String formatHashrate(double ghs) {
  if (ghs <= 0) return '0 H/s';
  if (ghs < 1) return '${(ghs * 1000).toStringAsFixed(1)} MH/s';
  if (ghs < 1000) return '${ghs.toStringAsFixed(2)} GH/s';
  return '${(ghs / 1000).toStringAsFixed(2)} TH/s';
}

/// Shortens a 64-character hash for a single log line.
String shortHash(String hash, {int head = 8, int tail = 6}) {
  if (hash.length <= head + tail + 1) return hash;
  return '${hash.substring(0, head)}…${hash.substring(hash.length - tail)}';
}

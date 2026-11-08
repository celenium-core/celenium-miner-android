import '../models/bridge.dart';

/// Canonical mining-session states shared by the engine, the isolate and the
/// screen. The isolated worker reports the first four; the engine adds
/// [`idle`, `needsWallet`, `limitReached`] around them before any isolate runs.
abstract final class MinerStatus {
  static const String idle = 'idle';
  static const String connecting = 'connecting';
  static const String mining = 'mining';
  static const String stopped = 'stopped';
  static const String error = 'error';
  static const String needsWallet = 'needs_wallet';
  static const String limitReached = 'limit_reached';
}

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
    this.address,
    this.estimatedCen,
    this.shares,
    this.stale,
    this.invalid,
    this.sessionBlocks,
    this.totalBlocks,
    this.latestBlockHash,
    this.latestBlockTime,
    this.bridgeUptime,
    this.active = false,
    this.miningEnabled = false,
    this.miningAvailable = false,
    this.status,
    this.sessionUptime,
  });

  /// Live hashrate in GH/s.
  final double? hashrateGhs;

  /// Share difficulty currently assigned to this worker.
  final double? difficulty;

  /// Worker name reported by the bridge.
  final String? workerName;

  /// Full payout address (`cen69:…`) derived from the wallet by the local
  /// engine. Distinct from [workerName], which is the shortened pool label.
  final String? address;

  /// Estimated CEN mined this session from the engine's share math. A display
  /// estimate only — never a settlement amount.
  final double? estimatedCen;

  final int? shares;
  final int? stale;
  final int? invalid;

  /// Blocks accepted in this session.
  final int? sessionBlocks;

  /// Blocks mined across the whole pool, per the bridge.
  final int? totalBlocks;

  final String? latestBlockHash;
  final String? latestBlockTime;

  /// How long the bridge itself has been up, in seconds.
  final int? bridgeUptime;

  /// True when the bridge reports a worker actually hashing.
  final bool active;

  /// Whether the bridge's internal miner is switched on right now.
  final bool miningEnabled;

  /// Whether the bridge exposes a start/stop control at all.
  final bool miningAvailable;

  /// Which mining-session state this readout reflects, or null when the value
  /// came from a legacy bridge snapshot (no local engine lifecycle).
  final String? status;

  /// How long the current mining session has run, in seconds. Distinct from
  /// [bridgeUptime], which is the pool bridge's own uptime.
  final int? sessionUptime;

  static const MiningReadout empty = MiningReadout(active: false);

  /// Share acceptance rate in 0..1, or null when no shares have been
  /// submitted. This is what the dial shows: the fraction of submitted work
  /// the network counted.
  double? get acceptanceRate {
    // The local engine reports accepted shares in `shares` (a phone worker has
    // no pool-level block count); a bridge snapshot reports them in
    // `sessionBlocks`. Either source fills the same slot.
    final accepted = sessionBlocks ?? shares ?? 0;
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
    final hashrate =
        cpu?.hashrateGhs ?? _sumWorkers(workers, (w) => w.hashrate);
    final shares = cpu?.shares ?? _sumIntWorkers(workers, (w) => w.shares);
    final stale = cpu?.stale ?? _sumIntWorkers(workers, (w) => w.stale);
    final invalid = cpu?.invalid ?? _sumIntWorkers(workers, (w) => w.invalid);
    final sessionBlocks =
        cpu?.blocksAccepted ?? _sumIntWorkers(workers, (w) => w.blocks);

    final primary = workers.isNotEmpty ? workers.first : null;
    final latest = stats.blocks.isNotEmpty ? stats.blocks.first : null;

    final active =
        hashrate > 0 ||
        (primary?.status?.toLowerCase().contains('active') ?? false);

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
      bridgeUptime: stats.bridgeUptime,
      active: active,
      miningEnabled: snapshot.miningEnabled,
      miningAvailable: snapshot.miningAvailable,
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
/// attention on zeros. The local Android worker hashes in kH/s, so the scale
/// reaches down to H/s. The unit is always stated, never implied.
String formatHashrate(double ghs) {
  if (ghs <= 0) return '0 H/s';
  if (ghs < 1e-6) return '${(ghs * 1e9).round()} H/s';
  if (ghs < 1e-3) return '${(ghs * 1e6).toStringAsFixed(1)} kH/s';
  if (ghs < 1) return '${(ghs * 1000).toStringAsFixed(1)} MH/s';
  if (ghs < 1000) return '${ghs.toStringAsFixed(2)} GH/s';
  return '${(ghs / 1000).toStringAsFixed(2)} TH/s';
}

/// Shortens a 64-character hash for a single log line.
String shortHash(String hash, {int head = 8, int tail = 6}) {
  if (hash.length <= head + tail + 1) return hash;
  return '${hash.substring(0, head)}…${hash.substring(hash.length - tail)}';
}

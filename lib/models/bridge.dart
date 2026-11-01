/// Models for the Celenium stratum bridge HTTP API.
///
/// These mirror the JSON the bridge serves on its web dashboard port:
/// `GET /api/status` and `GET /api/stats`. Field names match the server's
/// serde output, which is why several are camelCase.
library;

/// `GET /api/status`
class BridgeStatus {
  final String celeniumdAddress;
  final String celeniumdVersion;
  final int instances;
  final String webBind;

  const BridgeStatus({
    required this.celeniumdAddress,
    required this.celeniumdVersion,
    required this.instances,
    required this.webBind,
  });

  static BridgeStatus? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return BridgeStatus(
      celeniumdAddress: json['celeniumd_address'] as String? ?? '',
      celeniumdVersion: json['celeniumd_version'] as String? ?? '',
      instances: (json['instances'] as num?)?.toInt() ?? 0,
      webBind: json['web_bind'] as String? ?? '',
    );
  }
}

/// `internalCpu` inside `GET /api/stats`. Null when no internal miner runs.
class InternalCpuStats {
  final double hashrateGhs;
  final int hashesTried;
  final int blocksSubmitted;
  final int blocksAccepted;
  final int shares;
  final int stale;
  final int invalid;
  final String wallet;

  const InternalCpuStats({
    required this.hashrateGhs,
    required this.hashesTried,
    required this.blocksSubmitted,
    required this.blocksAccepted,
    required this.shares,
    required this.stale,
    required this.invalid,
    required this.wallet,
  });

  static InternalCpuStats? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return InternalCpuStats(
      hashrateGhs: (json['hashrateGhs'] as num?)?.toDouble() ?? 0,
      hashesTried: (json['hashesTried'] as num?)?.toInt() ?? 0,
      blocksSubmitted: (json['blocksSubmitted'] as num?)?.toInt() ?? 0,
      blocksAccepted: (json['blocksAccepted'] as num?)?.toInt() ?? 0,
      shares: (json['shares'] as num?)?.toInt() ?? 0,
      stale: (json['stale'] as num?)?.toInt() ?? 0,
      invalid: (json['invalid'] as num?)?.toInt() ?? 0,
      wallet: json['wallet'] as String? ?? '',
    );
  }
}

class WorkerInfo {
  final String instance;
  final String worker;
  final String wallet;
  final double hashrate;
  final int shares;
  final int stale;
  final int invalid;
  final int blocks;
  final int? lastSeen;
  final String? status;
  final double? currentDifficulty;
  final int? sessionUptime;

  const WorkerInfo({
    required this.instance,
    required this.worker,
    required this.wallet,
    required this.hashrate,
    required this.shares,
    required this.stale,
    required this.invalid,
    required this.blocks,
    this.lastSeen,
    this.status,
    this.currentDifficulty,
    this.sessionUptime,
  });

  static WorkerInfo? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return WorkerInfo(
      instance: json['instance'] as String? ?? '',
      worker: json['worker'] as String? ?? '',
      wallet: json['wallet'] as String? ?? '',
      hashrate: (json['hashrate'] as num?)?.toDouble() ?? 0,
      shares: (json['shares'] as num?)?.toInt() ?? 0,
      stale: (json['stale'] as num?)?.toInt() ?? 0,
      invalid: (json['invalid'] as num?)?.toInt() ?? 0,
      blocks: (json['blocks'] as num?)?.toInt() ?? 0,
      lastSeen: (json['lastSeen'] as num?)?.toInt(),
      status: json['status'] as String?,
      currentDifficulty: (json['currentDifficulty'] as num?)?.toDouble(),
      sessionUptime: (json['sessionUptime'] as num?)?.toInt(),
    );
  }
}

class BlockInfo {
  final String instance;
  final String worker;
  final String wallet;
  final String timestamp;
  final String hash;

  const BlockInfo({
    required this.instance,
    required this.worker,
    required this.wallet,
    required this.timestamp,
    required this.hash,
  });

  static BlockInfo? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return BlockInfo(
      instance: json['instance'] as String? ?? '',
      worker: json['worker'] as String? ?? '',
      wallet: json['wallet'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      hash: json['hash'] as String? ?? '',
    );
  }
}

/// `GET /api/stats`
class BridgeStats {
  final int totalBlocks;
  final int totalShares;
  final int networkHashrate;
  final double networkDifficulty;
  final int networkBlockCount;
  final int activeWorkers;
  final InternalCpuStats? internalCpu;
  final List<BlockInfo> blocks;
  final List<WorkerInfo> workers;
  final int? bridgeUptime;

  const BridgeStats({
    required this.totalBlocks,
    required this.totalShares,
    required this.networkHashrate,
    required this.networkDifficulty,
    required this.networkBlockCount,
    required this.activeWorkers,
    required this.internalCpu,
    required this.blocks,
    required this.workers,
    this.bridgeUptime,
  });

  static BridgeStats? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final rawBlocks = json['blocks'];
    final rawWorkers = json['workers'];
    // A non-list where a list belongs means the API shape changed. Treat the
    // whole body as unusable rather than reporting a false zero, which would
    // read as "no blocks found" and hide a broken bridge.
    if (rawBlocks != null && rawBlocks is! List) return null;
    if (rawWorkers != null && rawWorkers is! List) return null;
    final blocks =
        (rawBlocks as List?)
            ?.whereType<Object?>()
            .map(BlockInfo.tryParse)
            .whereType<BlockInfo>()
            .toList() ??
        const <BlockInfo>[];
    final workers =
        (rawWorkers as List?)
            ?.whereType<Object?>()
            .map(WorkerInfo.tryParse)
            .whereType<WorkerInfo>()
            .toList() ??
        const <WorkerInfo>[];
    return BridgeStats(
      totalBlocks: (json['totalBlocks'] as num?)?.toInt() ?? 0,
      totalShares: (json['totalShares'] as num?)?.toInt() ?? 0,
      networkHashrate: (json['networkHashrate'] as num?)?.toInt() ?? 0,
      networkDifficulty: (json['networkDifficulty'] as num?)?.toDouble() ?? 0,
      networkBlockCount: (json['networkBlockCount'] as num?)?.toInt() ?? 0,
      activeWorkers: (json['activeWorkers'] as num?)?.toInt() ?? 0,
      internalCpu: InternalCpuStats.tryParse(json['internalCpu']),
      blocks: blocks,
      workers: workers,
      bridgeUptime: (json['bridgeUptime'] as num?)?.toInt(),
    );
  }
}

/// A snapshot of everything the app shows, fetched together.
class MinerSnapshot {
  final BridgeStatus? status;
  final BridgeStats? stats;

  const MinerSnapshot({this.status, this.stats});

  /// True when the bridge reports an internal CPU miner is running.
  bool get isMining => stats?.internalCpu != null;

  /// Local hashrate in GH/s, or 0 when not mining.
  double get hashrateGhs => stats?.internalCpu?.hashrateGhs ?? 0;

  int get blocksAccepted => stats?.internalCpu?.blocksAccepted ?? 0;
  int get blocksSubmitted => stats?.internalCpu?.blocksSubmitted ?? 0;
  int get shares => stats?.internalCpu?.shares ?? 0;
  int get stale => stats?.internalCpu?.stale ?? 0;
  int get invalid => stats?.internalCpu?.invalid ?? 0;
}

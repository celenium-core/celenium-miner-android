import 'package:flutter/material.dart';

import '../models/bridge.dart';
import '../theme/tokens.dart';

/// A log of what the app observed, newest first.
///
/// Entries come from real polling events only. There is no filler: a quiet
/// bridge produces a short log that says so.
class LogScreen extends StatelessWidget {
  const LogScreen({required this.entries, super.key});

  final List<LogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        Text('Activity', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: Space.xs),
        Text(
          'Observed while polling the bridge.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Space.lg),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(Space.xl),
            decoration: BoxDecoration(
              color: Palette.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: Palette.surfaceHigh),
            ),
            child: Text(
              'Nothing logged yet. Connection changes and newly accepted '
              'blocks are recorded here.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(
                      entry.time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFeatures: Type.tabular,
                          ),
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: entry.isError ? Palette.danger : Palette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      entry.message,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// One observed event.
class LogEntry {
  const LogEntry({
    required this.time,
    required this.message,
    this.isError = false,
  });

  final String time;
  final String message;
  final bool isError;
}

/// Builds log entries from consecutive snapshots, so only real transitions
/// are recorded rather than a line per poll.
List<LogEntry> diffSnapshots({
  required MinerSnapshot? previous,
  required MinerSnapshot current,
  required bool wasConnected,
  required bool isConnected,
  required String clock,
}) {
  final entries = <LogEntry>[];

  if (isConnected != wasConnected) {
    entries.add(LogEntry(
      time: clock,
      message: isConnected
          ? 'Bridge reachable at ${current.status?.webBind ?? "configured address"}'
          : 'Bridge unreachable',
      isError: !isConnected,
    ));
  }
  if (!isConnected) return entries;

  final blocks = current.blocksAccepted;
  final prevBlocks = previous?.blocksAccepted ?? 0;
  if (blocks > prevBlocks) {
    entries.add(LogEntry(
      time: clock,
      message: 'Block accepted (${blocks - prevBlocks} new, $blocks total)',
    ));
  }

  final wasMining = previous?.isMining ?? false;
  if (current.isMining != wasMining) {
    entries.add(LogEntry(
      time: clock,
      message: current.isMining
          ? 'Internal CPU miner started'
          : 'Internal CPU miner stopped',
    ));
  }

  final stale = current.stale;
  final prevStale = previous?.stale ?? 0;
  if (stale > prevStale) {
    entries.add(LogEntry(
      time: clock,
      message: '${stale - prevStale} stale share(s) reported',
      isError: true,
    ));
  }

  return entries;
}

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/bridge.dart';
import '../theme/layout.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/cen_ui.dart';

/// A log of what the app observed, newest first.
///
/// Entries come from real polling events only. There is no filler: a quiet
/// bridge produces a short log that says so.
class LogScreen extends StatelessWidget {
  const LogScreen({required this.entries, super.key});

  final List<LogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.logTitle)),
      body: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(Palette.lg),
              child: CenEmpty(reason: l10n.logEmpty),
            )
          : CenContent(
              child: ListView.builder(
                padding: const EdgeInsets.all(Palette.lg),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Palette.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 66,
                          child: Text(
                            entry.time,
                            style: TypeScale.monoMuted(context, size: 10),
                          ),
                        ),
                        const SizedBox(width: Palette.sm),
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                            color: entry.isError ? Palette.red : Palette.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: Palette.md),
                        Expanded(
                          child: Text(
                            entry.message,
                            style: TypeScale.label(context).copyWith(
                              color: entry.isError
                                  ? Palette.red
                                  : Palette.creamDim,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
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
///
/// The messages are localised, so [l10n] is passed in rather than read from a
/// context: this runs in the polling loop, which outlives any one frame.
List<LogEntry> diffSnapshots({
  required AppLocalizations l10n,
  required MinerSnapshot? previous,
  required MinerSnapshot current,
  required bool wasConnected,
  required bool isConnected,
  required String clock,
}) {
  final entries = <LogEntry>[];

  if (isConnected != wasConnected) {
    entries.add(
      LogEntry(
        time: clock,
        message: isConnected
            ? l10n.logBridgeReachable(
                current.status?.webBind ?? 'configured address',
              )
            : l10n.logBridgeUnreachable,
        isError: !isConnected,
      ),
    );
  }
  if (!isConnected) return entries;

  final blocks = current.blocksAccepted;
  final prevBlocks = previous?.blocksAccepted ?? 0;
  if (blocks > prevBlocks) {
    entries.add(
      LogEntry(
        time: clock,
        message: l10n.logBlockAccepted(blocks - prevBlocks, blocks),
      ),
    );
  }

  final wasMining = previous?.isMining ?? false;
  if (current.isMining != wasMining) {
    entries.add(
      LogEntry(
        time: clock,
        message: current.isMining
            ? l10n.logMinerStarted
            : l10n.logMinerStopped,
      ),
    );
  }

  final stale = current.stale;
  final prevStale = previous?.stale ?? 0;
  if (stale > prevStale) {
    entries.add(
      LogEntry(
        time: clock,
        message: l10n.logStaleShares(stale - prevStale),
        isError: true,
      ),
    );
  }

  return entries;
}

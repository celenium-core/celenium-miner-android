import 'package:flutter/foundation.dart';

/// One error the app intercepted instead of dying on.
class CaughtError {
  const CaughtError(this.time, this.message);

  final String time;
  final String message;
}

/// Errors caught instead of dying on, newest first, bounded so a runaway
/// error loop cannot grow the list without limit.
///
/// The log screen shows this above the poll log: if the user felt something
/// break, the story of what broke should be where they look.
final List<CaughtError> crashJournal = [];

const int crashJournalLimit = 20;

/// Records one caught error. Safe to call from anywhere, including before
/// the first frame.
void recordCaughtError(Object error, {StackTrace? stack}) {
  final now = DateTime.now();
  final h = now.hour.toString().padLeft(2, '0');
  final m = now.minute.toString().padLeft(2, '0');
  final s = now.second.toString().padLeft(2, '0');
  crashJournal.insert(0, CaughtError('$h:$m:$s', error.toString()));
  if (crashJournal.length > crashJournalLimit) {
    crashJournal.removeRange(crashJournalLimit, crashJournal.length);
  }
  debugPrint('caught: $error');
  if (stack != null) debugPrint('$stack');
}

/// Points both root error hooks at the journal.
///
/// The platform hook returning true is the point: an unhandled async error
/// that no listener caught would otherwise take the process down, and the
/// user never gets to see why. Nothing here hides the error - it just lets
/// the app live long enough to show it.
void installCrashHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    recordCaughtError(details.exceptionAsString(), stack: details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    recordCaughtError(error, stack: stack);
    return true;
  };
}

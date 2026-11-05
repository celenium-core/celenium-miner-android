import 'dart:ui' show PlatformDispatcher;

import 'package:celenium_miner/services/ad_units.dart';
import 'package:celenium_miner/services/crash_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(crashJournal.clear);

  test('recorded errors land newest first', () {
    recordCaughtError(StateError('first'));
    recordCaughtError(StateError('second'));

    expect(crashJournal.length, 2);
    expect(crashJournal.first.message, contains('second'));
    expect(crashJournal.last.message, contains('first'));
  });

  test('the journal keeps only the newest errors', () {
    for (var i = 0; i < crashJournalLimit + 5; i++) {
      recordCaughtError(StateError('error $i'));
    }

    expect(crashJournal.length, crashJournalLimit);
    expect(
      crashJournal.first.message,
      contains('error ${crashJournalLimit + 4}'),
    );
    expect(crashJournal.last.message, contains('error 5'));
  });

  test('the installed platform handler swallows the error and records it', () {
    installCrashHandlers();

    final swallowed = PlatformDispatcher.instance.onError!(
      StateError('boom'),
      StackTrace.current,
    );

    expect(swallowed, isTrue);
    expect(crashJournal.single.message, contains('boom'));
  });

  test('ads never start on a platform without the SDK', () async {
    expect(adsSupported, isFalse);
    await expectLater(ensureAdsReady(), completes);
  });
}

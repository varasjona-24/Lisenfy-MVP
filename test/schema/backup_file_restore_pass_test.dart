import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/settings/application/backup_file_restore_pass.dart';

void main() {
  test('logical restore and SQLite locators extract and verify once', () async {
    final pass = BackupFileRestorePass();
    var extractions = 0;
    var validations = 0;
    Future<void> restore() async {
      extractions++;
      validations++;
    }

    await pass.run('audio/song.mp3', restore);
    await pass.run('audio/song.mp3', restore);
    expect(extractions, 1);
    expect(validations, 1);
    await BackupFileRestorePass().run('audio/song.mp3', restore);
    expect(extractions, 2); // A separate ZIP restore has no stale cache.
  });
  test('failed verification propagates and is not cached', () async {
    final pass = BackupFileRestorePass();
    var attempts = 0;
    Future<void> restore() async {
      if (++attempts == 1) throw StateError('hash mismatch');
    }

    await expectLater(pass.run('cover.png', restore), throwsStateError);
    await pass.run('cover.png', restore);
    expect(attempts, 2);
  });
  test('concurrent references await the same extraction', () async {
    final pass = BackupFileRestorePass();
    final gate = Completer<void>();
    var attempts = 0;
    Future<void> restore() async {
      attempts++;
      await gate.future;
    }

    final first = pass.run('video.mp4', restore);
    final second = pass.run('video.mp4', restore);
    expect(identical(first, second), isTrue);
    gate.complete();
    await Future.wait([first, second]);
    expect(attempts, 1);
  });
}

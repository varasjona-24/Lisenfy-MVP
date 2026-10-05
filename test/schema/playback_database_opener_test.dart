import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('playback-opener-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test('real schema creates staging with correct pragmas and reopens', () async {
    expect(
      await rootBundle.loadString(PlaybackDatabaseOpener.schemaAsset),
      await File(PlaybackDatabaseOpener.schemaAsset).readAsString(),
    );
    final db = await PlaybackDatabaseOpener.openStaging(
      generation: 'fresh',
      supportDirectory: directory,
      temporaryDirectory: directory,
    );
    try {
      expect(
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
            )
            .get(),
        hasLength(14),
      );
      for (final entry in {
        'foreign_keys': 1,
        'synchronous': 2,
        'busy_timeout': 5000,
        'user_version': 1,
      }.entries) {
        expect(
          (await db.customSelect('PRAGMA ${entry.key}').get())
              .single
              .data
              .values
              .single,
          entry.value,
        );
      }
      expect(
        (await db.customSelect('PRAGMA journal_mode').get())
            .single
            .data
            .values
            .single,
        'wal',
      );
    } finally {
      await db.close();
    }
    final reopened = await PlaybackDatabaseOpener.openStaging(
      generation: 'fresh',
      supportDirectory: directory,
      temporaryDirectory: directory,
    );
    await reopened.close();
  });
  test('future schema is not reset', () async {
    final staging = Directory('${directory.path}/playback/staging');
    await staging.create(recursive: true);
    final raw = sqlite3.open('${staging.path}/future.db');
    raw.execute('CREATE TABLE keep_data(value TEXT)');
    raw.execute('PRAGMA user_version=2');
    raw.close();
    await expectLater(
      PlaybackDatabaseOpener.openStaging(
        generation: 'future',
        supportDirectory: directory,
        temporaryDirectory: directory,
      ),
      throwsA(anything),
    );
    final check = sqlite3.open('${staging.path}/future.db');
    expect(check.select('PRAGMA user_version').single.values.single, 2);
    expect(
      check.select("SELECT name FROM sqlite_master WHERE name='keep_data'"),
      hasLength(1),
    );
    check.close();
  });
  test('path traversal rejected', () async {
    await expectLater(
      PlaybackDatabaseOpener.openStaging(
        generation: '../active',
        supportDirectory: directory,
        temporaryDirectory: directory,
      ),
      throwsArgumentError,
    );
  });
  test('version alone cannot validate an incomplete schema', () async {
    final staging = Directory('${directory.path}/playback/staging');
    await staging.create(recursive: true);
    final raw = sqlite3.open('${staging.path}/partial.db');
    raw.execute('PRAGMA user_version=1');
    raw.close();
    await expectLater(
      PlaybackDatabaseOpener.openStaging(
        generation: 'partial',
        supportDirectory: directory,
        temporaryDirectory: directory,
      ),
      throwsA(isA<StateError>()),
    );
  });
}

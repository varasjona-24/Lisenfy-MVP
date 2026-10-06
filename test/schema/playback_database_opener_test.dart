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
        hasLength(34),
      );
      for (final entry in {
        'foreign_keys': 1,
        'synchronous': 2,
        'busy_timeout': 5000,
        'user_version': 6,
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
    raw.execute('PRAGMA user_version=7');
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
    expect(check.select('PRAGMA user_version').single.values.single, 7);
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
  test(
    'v2 upgrade preserves existing restoration while adding catalog',
    () async {
      final staging = Directory('${directory.path}/playback/staging');
      await staging.create(recursive: true);
      final raw = sqlite3.open('${staging.path}/v2.db');
      raw.execute(
        await File(PlaybackDatabaseOpener.schemaAsset).readAsString(),
      );
      raw.execute(
        await File(
          PlaybackDatabaseOpener.restorationSchemaAsset,
        ).readAsString(),
      );
      raw.execute(
        "INSERT INTO playback_restoration VALUES ('audio',1,'{}',123)",
      );
      raw.close();
      final upgraded = await PlaybackDatabaseOpener.openStaging(
        generation: 'v2',
        supportDirectory: directory,
        temporaryDirectory: directory,
      );
      try {
        expect(
          (await upgraded.customSelect('PRAGMA user_version').getSingle())
              .data
              .values
              .single,
          6,
        );
        expect(
          (await upgraded
                  .customSelect(
                    'SELECT updated_at_utc_ms FROM playback_restoration',
                  )
                  .getSingle())
              .read<int>('updated_at_utc_ms'),
          123,
        );
        expect(
          await upgraded.customSelect('SELECT * FROM library_record').get(),
          isEmpty,
        );
      } finally {
        await upgraded.close();
      }
    },
  );
  test('v3 upgrade preserves catalog records', () async {
    final staging = Directory('${directory.path}/playback/staging');
    await staging.create(recursive: true);
    final raw = sqlite3.open('${staging.path}/v3.db');
    for (final asset in [
      PlaybackDatabaseOpener.schemaAsset,
      PlaybackDatabaseOpener.restorationSchemaAsset,
      PlaybackDatabaseOpener.catalogSchemaAsset,
    ]) {
      raw.execute(await File(asset).readAsString());
    }
    raw.execute("INSERT INTO library_record VALUES ('kept',0,'{}')");
    raw.close();
    final upgraded = await PlaybackDatabaseOpener.openStaging(
      generation: 'v3',
      supportDirectory: directory,
      temporaryDirectory: directory,
    );
    try {
      expect(
        (await upgraded
                .customSelect('SELECT id FROM library_record')
                .getSingle())
            .read<String>('id'),
        'kept',
      );
      expect(
        await upgraded.customSelect('SELECT * FROM app_domain_state').get(),
        isEmpty,
      );
    } finally {
      await upgraded.close();
    }
  });
  test('v4 upgrade installs artist relations without losing library', () async {
    final staging = Directory('${directory.path}/playback/staging');
    await staging.create(recursive: true);
    final raw = sqlite3.open('${staging.path}/v4.db');
    for (final asset in [
      PlaybackDatabaseOpener.schemaAsset,
      PlaybackDatabaseOpener.restorationSchemaAsset,
      PlaybackDatabaseOpener.catalogSchemaAsset,
      PlaybackDatabaseOpener.domainSchemaAsset,
    ]) {
      raw.execute(await File(asset).readAsString());
    }
    raw.execute("INSERT INTO library_record VALUES ('kept',0,'{}')");
    raw.close();
    final upgraded = await PlaybackDatabaseOpener.openStaging(
      generation: 'v4',
      supportDirectory: directory,
      temporaryDirectory: directory,
    );
    try {
      expect(
        (await upgraded.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        6,
      );
      expect(
        await upgraded.customSelect('SELECT * FROM library_record').get(),
        hasLength(1),
      );
      expect(
        await upgraded
            .customSelect('SELECT * FROM library_artist_credit')
            .get(),
        isEmpty,
      );
    } finally {
      await upgraded.close();
    }
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
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('Incomplete playback schema'),
        ),
      ),
    );
  });
}

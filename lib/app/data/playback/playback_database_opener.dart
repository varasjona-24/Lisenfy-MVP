import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'playback_database.dart';

/// Only staging is exposed: there is deliberately no active-generation opener.
class PlaybackDatabaseOpener {
  static const schemaAsset = 'docs/playback/schema_v1.sql';

  static Future<PlaybackDatabase> openStaging({
    required String generation,
    Directory? supportDirectory,
    Directory? temporaryDirectory,
    AssetBundle? bundle,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(generation)) {
      throw ArgumentError.value(generation, 'generation', 'Invalid generation');
    }
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    final temporary = temporaryDirectory ?? await getTemporaryDirectory();
    final directory = Directory(p.join(support.path, 'playback', 'staging'));
    await directory.create(recursive: true);
    final schema = await (bundle ?? rootBundle).loadString(schemaAsset);
    final tempPath = temporary.path;
    final executor = NativeDatabase.createInBackground(
      File(p.join(directory.path, '$generation.db')),
      setup: (database) {
        sql.sqlite3.tempDirectory = tempPath;
        final version =
            database.select('PRAGMA user_version').single.values.single as int;
        if (version != 0 && version != 1) {
          throw StateError('Unsupported playback schema version: $version');
        }
        database.execute('PRAGMA foreign_keys = ON');
        database.execute('PRAGMA busy_timeout = 5000');
        database.execute('PRAGMA journal_mode = WAL');
        database.execute('PRAGMA synchronous = FULL');
        database.execute('PRAGMA wal_autocheckpoint = 1000');
        if (version == 0) {
          if (database
              .select(
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
              )
              .isNotEmpty) {
            throw StateError('Unversioned nonempty playback database');
          }
          database.execute(schema);
        }
        final installed = database
            .select('PRAGMA user_version')
            .single
            .values
            .single;
        if (installed != 1) {
          throw StateError('Playback schema installation failed');
        }
      },
    );
    final database = PlaybackDatabase(executor);
    try {
      await database.verify();
      return database;
    } catch (_) {
      await database.close();
      rethrow;
    }
  }
}

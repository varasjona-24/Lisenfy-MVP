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
  static const restorationSchemaAsset = 'docs/playback/migration_v2.sql';
  static const catalogSchemaAsset = 'docs/playback/migration_v3.sql';
  static const domainSchemaAsset = 'docs/playback/migration_v4.sql';
  static const artistSchemaAsset = 'docs/playback/migration_v5.sql';

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
    final restorationSchema = await (bundle ?? rootBundle).loadString(
      restorationSchemaAsset,
    );
    final tempPath = temporary.path;
    final artistSchema = await (bundle ?? rootBundle).loadString(
      artistSchemaAsset,
    );
    final domainSchema = await (bundle ?? rootBundle).loadString(
      domainSchemaAsset,
    );
    final catalogSchema = await (bundle ?? rootBundle).loadString(
      catalogSchemaAsset,
    );
    final executor = NativeDatabase.createInBackground(
      File(p.join(directory.path, '$generation.db')),
      setup: (database) {
        sql.sqlite3.tempDirectory = tempPath;
        final version =
            database.select('PRAGMA user_version').single.values.single as int;
        if (version < 0 || version > 5) {
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
        if (version < 2) {
          // Verify v1 before changing it; never upgrade an incomplete database.
          for (final table in PlaybackDatabase.v1Tables) {
            if (database.select(
              'SELECT name FROM sqlite_master WHERE type=\'table\' AND name=?',
              [table],
            ).isEmpty) {
              throw StateError('Incomplete playback schema before upgrade');
            }
          }
          database.execute(restorationSchema);
        }
        if (version < 3) {
          for (final table in {
            ...PlaybackDatabase.v1Tables,
            'playback_restoration',
            'playback_resume',
            'restoration_import',
          }) {
            if (database.select(
              'SELECT name FROM sqlite_master WHERE type=\'table\' AND name=?',
              [table],
            ).isEmpty) {
              throw StateError(
                'Incomplete playback schema before catalog upgrade',
              );
            }
          }
          database.execute(catalogSchema);
        }
        if (version < 4) {
          for (final table in PlaybackDatabase.catalogTables) {
            if (database.select(
              'SELECT name FROM sqlite_master WHERE type=\'table\' AND name=?',
              [table],
            ).isEmpty) {
              throw StateError('Incomplete catalog before domain upgrade');
            }
          }
          database.execute(domainSchema);
        }
        if (version < 5) {
          for (final table in PlaybackDatabase.domainTables) {
            if (database.select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
              [table],
            ).isEmpty) {
              throw StateError('Incomplete domains before artist upgrade');
            }
          }
          database.execute(artistSchema);
        }
        final installed = database
            .select('PRAGMA user_version')
            .single
            .values
            .single;
        if (installed != 5) {
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

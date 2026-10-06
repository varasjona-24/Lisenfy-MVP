import 'package:drift/drift.dart';

/// Internal persistence handle. Not registered in GetX until cutover is tested.
/// Tables are installed from the bundled SQL, not a second Dart schema.
class PlaybackDatabase extends GeneratedDatabase {
  PlaybackDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {},
    onUpgrade: (_, from, to) async {
      throw StateError('No playback migration registered: $from -> $to');
    },
  );

  Future<void> verify() async {
    final requiredTables = {
      ...v1Tables,
      'playback_restoration',
      'playback_resume',
      'restoration_import',
      ...catalogTables,
      ...domainTables,
      ...artistRelationTables,
      'artist_name_alias',
      'artist_redirect',
    };
    final tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table'",
    ).get();
    if (!tables
        .map((row) => row.read<String>('name'))
        .toSet()
        .containsAll(requiredTables)) {
      throw StateError('Incomplete playback schema');
    }
    final integrity = await customSelect('PRAGMA quick_check').get();
    if (integrity.length != 1 || integrity.single.data.values.single != 'ok') {
      throw StateError('Playback database integrity check failed');
    }
    if ((await customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
      throw StateError('Playback database contains invalid foreign keys');
    }
  }

  static const v1Tables = {
    'media_identity',
    'media_alias',
    'media_variant',
    'metadata_snapshot',
    'applied_command',
    'playback_session',
    'playback_event',
    'playback_interval',
    'playback_aggregate',
    'migration_state',
    'migration_reject',
    'legacy_metrics',
    'feedback_event',
    'repository_state',
  };

  static const catalogTables = {
    'library_record',
    'library_variant',
    'playlist_record',
    'playlist_member',
    'artist_record',
    'catalog_file_reference',
    'catalog_import',
  };
  static const artistRelationTables = {
    'catalog_artist_identity',
    'library_credit_state',
    'library_artist_credit',
    'artist_membership',
  };
  static const domainTables = {
    'app_domain_state',
    'app_domain_record',
    'app_domain_file',
    'app_domain_import',
  };
}

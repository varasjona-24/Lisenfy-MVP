part of 'playback_repository.dart';

const durableDomainKeys = {
  'source_theme_pills': 'list',
  'source_theme_topics': 'list',
  'source_theme_topic_playlists': 'list',
  'capture_gallery_tags': 'map',
  'capture_gallery_tag_colors': 'map',
  'capture_gallery_sources': 'map',
  'capture_gallery_tag_collections': 'map',
  'capture_files_v1': 'map',
  'appBackgroundImagePaths': 'list',
  'recommendation_state_v1': 'map',
  'recommendation_mix_state_v2': 'map',
  'recommendation_ml_state_v1': 'map',
  'recommendation_feedback_v1': 'map',
  'world_mode_country_discovery_v1': 'map',
  'world_mode_station_memory_v1': 'map',
  'world_mode_country_affinity_v1': 'map',
  'world_mode_playback_events_v1': 'list',
  'instrumental_tasks_v1': 'map',
  'spatial8d_tasks_v1': 'map',
};

extension DomainPersistence on PlaybackRepository {
  Future<void> importDomains(
    String sourceId,
    String sourceHash,
    Map<String, dynamic> values,
  ) => _catalogCommand(
    () => _database.transaction(() async {
      final receipt = await _database
          .customSelect(
            'SELECT source_hash FROM app_domain_import WHERE source_id=?',
            variables: [Variable(sourceId)],
          )
          .getSingleOrNull();
      if (receipt != null) {
        if (receipt.read<String>('source_hash') != sourceHash) {
          throw StateError('Durable import source changed');
        }
        return;
      }
      if ((await _database
              .customSelect('SELECT 1 FROM app_domain_state LIMIT 1')
              .get())
          .isNotEmpty) {
        throw StateError('Durable baseline requires empty domain storage');
      }
      for (final entry in values.entries) {
        if (entry.value != null) await _replaceDomain(entry.key, entry.value);
      }
      await _database.customStatement(
        'INSERT INTO app_domain_import VALUES (?,?,?)',
        [sourceId, sourceHash, DateTime.now().millisecondsSinceEpoch],
      );
    }),
  );

  Future<void> replaceDomain(String key, dynamic value) => _catalogCommand(
    () => _database.transaction(() => _replaceDomain(key, value)),
  );

  Future<void> _replaceDomain(String key, dynamic value) async {
    final shape = durableDomainKeys[key];
    if (shape == null) throw ArgumentError.value(key, 'key');
    if (value != null &&
        ((shape == 'map' && value is! Map) ||
            (shape == 'list' && value is! List))) {
      throw FormatException('Invalid durable shape: $key');
    }
    await _database.customStatement(
      'DELETE FROM app_domain_state WHERE namespace=?',
      [key],
    );
    if (value == null) return;
    await _database.customStatement(
      'INSERT INTO app_domain_state VALUES (?,?)',
      [key, shape],
    );
    final entries = shape == 'map'
        ? (value as Map).entries.toList()
        : [
            for (var i = 0; i < (value as List).length; i++)
              MapEntry('$i', value[i]),
          ];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.key is! String) throw FormatException('Non-string durable key');
      final record = entry.value;
      final id =
          shape == 'list' &&
              key.startsWith('source_theme_') &&
              record is Map &&
              record['id'] is String
          ? record['id'] as String
          : entry.key as String;
      final parent = record is Map
          ? record['topicId'] ?? record['themeId'] ?? record['pillId']
          : null;
      await _database.customStatement(
        'INSERT INTO app_domain_record VALUES (?,?,?,?,?)',
        [key, id, i, parent is String ? parent : null, jsonEncode(record)],
      );
      Future<void> file(String slot, dynamic locator) async {
        if (locator is String && locator.isNotEmpty) {
          await _database.customStatement(
            'INSERT INTO app_domain_file VALUES (?,?,?,?)',
            [key, id, slot, locator],
          );
        }
      }

      if (key == 'appBackgroundImagePaths') await file('background', record);
      if (key == 'capture_files_v1') await file('capture', entry.key);
      if (key == 'capture_gallery_sources' || key == 'capture_gallery_tags') {
        await file('capture', entry.key);
      }
      if (record is Map) {
        for (final field in [
          'localPath',
          'thumbnailLocalPath',
          'coverLocalPath',
          'outputPath',
          'resultPath',
          'sourcePath',
          'thumbnailPath',
        ]) {
          await file(field, record[field]);
        }
      }
    }
  }

  Future<Map<String, dynamic>> readDomains() => _catalogCommand(
    () => _database.transaction(() async {
      final values = <String, dynamic>{};
      for (final state
          in await _database
              .customSelect('SELECT * FROM app_domain_state')
              .get()) {
        final key = state.read<String>('namespace');
        final rows = await _database
            .customSelect(
              'SELECT record_key,payload_json FROM app_domain_record WHERE namespace=? ORDER BY ordinal',
              variables: [Variable(key)],
            )
            .get();
        values[key] = state.read<String>('shape') == 'list'
            ? rows
                  .map((r) => jsonDecode(r.read<String>('payload_json')))
                  .toList()
            : {
                for (final r in rows)
                  r.read<String>('record_key'): jsonDecode(
                    r.read<String>('payload_json'),
                  ),
              };
      }
      return values;
    }),
  );

  Future<void> restoreDomainValues(Map<String, dynamic> values) =>
      _catalogCommand(
        () => _database.transaction(() async {
          for (final entry in values.entries) {
            await _replaceDomain(entry.key, entry.value);
          }
        }),
      );
}

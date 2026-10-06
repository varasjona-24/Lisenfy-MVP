part of 'playback_repository.dart';

/// Debug transfer/query APIs. Imports facts without manufacturing listen ranges.
extension PlaybackDebugTransfer on PlaybackRepository {
  /// Legacy ZIPs are a baseline, not additive history. Permit an empty target
  /// or an exact retry, never sum an overlapping backup into existing history.
  Future<void> validateLegacyBackupTarget(String sourceHash) =>
      _restorationTask(() async {
        final receipt = await _database
            .customSelect(
              'SELECT migration_id FROM migration_state WHERE migration_id=?',
              variables: [Variable('legacy-zip-$sourceHash')],
            )
            .getSingleOrNull();
        if (receipt != null) return;
        final row = await _database
            .customSelect(
              'SELECT (SELECT COUNT(*) FROM legacy_metrics) + '
              '(SELECT COUNT(*) FROM playback_session) AS total',
            )
            .getSingle();
        if (row.read<int>('total') != 0) {
          throw StateError('legacy_backup_requires_empty_history');
        }
      });

  Future<Map<String, Map<String, dynamic>>> queryLibraryMetrics({
    String? mode,
  }) => _restorationTask(() async {
    final rows = await _database
        .customSelect(
          '''
      SELECT m.library_id, SUM(t.plays) plays,SUM(t.skips) skips,SUM(t.completed) completed,
        SUM(t.progress_sum) progress_sum,SUM(t.samples) samples, MAX(t.last_played) last_played,MAX(t.last_completed) last_completed
      FROM (
        SELECT media_id,mode,COALESCE(play_count,0) plays,COALESCE(skip_count,0) skips,COALESCE(completed_count,0) completed,
          COALESCE(avg_progress,0)*COALESCE(play_count,0) progress_sum,COALESCE(play_count,0) samples,
          last_played_at_utc_ms last_played,last_completed_at_utc_ms last_completed FROM legacy_metrics
        UNION ALL
        SELECT media_id,mode,SUM(valid_play),SUM(skipped),SUM(completed),SUM(COALESCE(progress_ratio,0)),COUNT(progress_ratio),
          MAX(CASE WHEN valid_play=1 THEN started_at_utc_ms END),MAX(CASE WHEN completed=1 THEN ended_at_utc_ms END)
          FROM playback_session WHERE aggregate_scope IN ('independent','post_cutover') GROUP BY media_id,mode
      ) t JOIN media_identity m USING(media_id) WHERE m.library_id IS NOT NULL AND (? IS NULL OR t.mode=?) GROUP BY m.library_id
    ''',
          variables: [Variable<String>(mode), Variable<String>(mode)],
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('library_id'): {
          'playCount': row.read<int>('plays'),
          'skipCount': row.read<int>('skips'),
          'fullListenCount': row.read<int>('completed'),
          'avgListenProgress': row.read<int>('samples') == 0
              ? 0.0
              : (row.data['progress_sum'] as num).toDouble() /
                    row.read<int>('samples'),
          'lastPlayedAt': row.readNullable<int>('last_played'),
          'lastCompletedAt': row.readNullable<int>('last_completed'),
        },
    };
  });
  Future<void> importLegacyHistory({
    required List<Map<String, dynamic>> library,
    required List<Map<String, dynamic>> events,
    required String scope,
    required String sourceHash,
    required int nowUtcMs,
    String? migrationId,
  }) => _restorationTask(() async {
    final source = migrationId ?? 'debug-legacy-$scope';
    await _database.transaction(() async {
      final previous = await _database
          .customSelect(
            'SELECT source_hash FROM migration_state WHERE migration_id=?',
            variables: [Variable(source)],
          )
          .getSingleOrNull();
      if (previous != null) {
        if (previous.read<String>('source_hash') != sourceHash) {
          throw PlaybackIdempotencyConflict(source);
        }
        return;
      }
      if (migrationId?.startsWith('legacy-zip-') == true) {
        final occupied = await _database
            .customSelect(
              'SELECT (SELECT COUNT(*) FROM legacy_metrics) + '
              '(SELECT COUNT(*) FROM playback_session) AS total',
            )
            .getSingle();
        if (occupied.read<int>('total') != 0) {
          throw StateError('legacy_backup_requires_empty_history');
        }
      }
      await _database.customStatement(
        "INSERT INTO migration_state(migration_id,source_id,source_hash,hash_algorithm,canonicalization_version,target_schema_version,cutover_at_utc_ms,state) VALUES(?,?,?,'sha256',1,?,?,'staging')",
        [source, source, sourceHash, _database.schemaVersion, nowUtcMs],
      );
      const uuid = Uuid();
      const namespace = '6ba7b811-9dad-11d1-80b4-00c04fd430c8';
      String stable(String domain, Object value) =>
          uuid.v5(namespace, jsonEncode([domain, scope, value]));
      final byKey = <String, List<Map<String, dynamic>>>{};
      final identities = <String, String>{};
      Future<String> identity(String key, Map<String, dynamic>? item) async {
        final local = item?['id'] as String? ?? key;
        if (identities.containsKey(local)) return identities[local]!;
        final existing = await _database
            .customSelect(
              "SELECT media_id FROM media_alias WHERE namespace='local' AND scope=? AND value=?",
              variables: [Variable(scope), Variable(local)],
            )
            .getSingleOrNull();
        final media =
            existing?.read<String>('media_id') ?? stable('media', local);
        if (existing == null) {
          await _database.customStatement(
            'INSERT INTO media_identity(media_id,library_id,created_at_utc_ms) VALUES(?,?,?)',
            [media, item?['id'], nowUtcMs],
          );
          await _database.customStatement(
            "INSERT INTO media_alias(namespace,scope,value,media_id,provenance) VALUES('local',?,?,?,'imported')",
            [scope, local, media],
          );
        }
        identities[local] = media;
        return media;
      }

      for (final item in library) {
        final id = item['id'] as String;
        final publicId = item['publicId'] as String? ?? '';
        for (final key in {
          id,
          'i:$id',
          if (publicId.isNotEmpty) publicId,
          if (publicId.isNotEmpty) 'p:$publicId',
        }) {
          byKey.putIfAbsent(key, () => []).add(item);
        }
        final media = await identity(id, item);
        final kinds = (item['variants'] as List? ?? [])
            .whereType<Map>()
            .map((v) => v['kind'])
            .where((k) => k == 'audio' || k == 'video')
            .toSet();
        final baselineMode = kinds.length == 1 ? kinds.single : 'unknown';
        await _database.customStatement(
          "INSERT INTO legacy_metrics(baseline_id,media_id,mode,migration_id,source_record_id,play_count,skip_count,completed_count,avg_progress,last_played_at_utc_ms,last_completed_at_utc_ms,provenance) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
          [
            stable('baseline', id),
            media,
            baselineMode,
            source,
            id,
            item['playCount'] ?? 0,
            item['skipCount'] ?? 0,
            item['fullListenCount'] ?? 0,
            item['avgListenProgress'] ?? 0,
            item['lastPlayedAt'],
            item['lastCompletedAt'],
            baselineMode == 'unknown' ? 'imported' : 'inferred_exclusive_mode',
          ],
        );
      }
      for (var ordinal = 0; ordinal < events.length; ordinal++) {
        final event = events[ordinal];
        final key = event['trackKey'] as String;
        final at = event['occurredAt'] as int;
        if (key.isEmpty || at <= 0) {
          throw FormatException('Invalid legacy event at $ordinal');
        }
        final candidates = byKey[key];
        final embedded = event['mediaSnapshot'];
        final item = embedded is Map
            ? Map<String, dynamic>.from(embedded)
            : candidates?.length == 1
            ? candidates!.single
            : null;
        final media = await identity(key, item);
        final mode = event['mode'] == 'audio' || event['mode'] == 'video'
            ? event['mode'] as String
            : 'unknown';
        final variant = stable('legacy-variant', [media, mode]);
        await _database.customStatement(
          "INSERT OR IGNORE INTO media_variant(variant_id,media_id,mode,role,created_at_utc_ms) VALUES(?,?,?,'unknown',?)",
          [variant, media, mode, at],
        );
        final snapshot = stable('legacy-snapshot', [sourceHash, ordinal]);
        final title = item?['title'] as String?;
        final artist = item?['subtitle'] as String?;
        final snapshotHash = sha256
            .convert(
              utf8.encode(
                jsonEncode([
                  'snapshot',
                  2,
                  title,
                  artist,
                  null,
                  null,
                  'imported',
                ]),
              ),
            )
            .toString();
        await _database.customStatement(
          "INSERT OR IGNORE INTO metadata_snapshot(snapshot_id,content_hash,hash_algorithm,canonicalization_version,title,artist,provenance) VALUES(?,?,'sha256',2,?,?,'imported')",
          [snapshot, snapshotHash, title, artist],
        );
        final actualSnapshot =
            (await _database
                    .customSelect(
                      'SELECT snapshot_id FROM metadata_snapshot WHERE content_hash=? AND canonicalization_version=2',
                      variables: [Variable(snapshotHash)],
                    )
                    .getSingle())
                .read<String>('snapshot_id');
        final session = stable('legacy-session', [sourceHash, ordinal]);
        final command = stable('legacy-command', [sourceHash, ordinal]);
        final compactEvent = Map<String, dynamic>.from(event);
        if (embedded is Map) {
          compactEvent['mediaSnapshot'] = {
            for (final key in [
              'id',
              'publicId',
              'title',
              'subtitle',
              'source',
              'origin',
              'thumbnail',
              'thumbnailLocalPath',
              'durationSeconds',
              'variants',
            ])
              if (embedded.containsKey(key)) key: embedded[key],
          };
        }
        final payload = jsonEncode({
          'source': source,
          'ordinal': ordinal,
          'quality': 'imported',
          'legacy': compactEvent,
        });
        if (utf8.encode(payload).length > 65536) {
          throw FormatException('Legacy event payload too large at $ordinal');
        }
        final requestHash = sha256.convert(utf8.encode(payload)).toString();
        await _database.customStatement(
          "INSERT INTO applied_command(command_id,request_hash,hash_algorithm,canonicalization_version,codec_version,applied_at_utc_ms,result_json) VALUES(?,?,'sha256',1,1,?,'{}')",
          [command, requestHash, nowUtcMs],
        );
        final completed = event['completed'] == true;
        final skipped = event['skipped'] == true;
        if (completed && skipped) {
          throw FormatException('Conflicting legacy flags at $ordinal');
        }
        final ratio = ((event['progress'] as num?)?.toDouble() ?? 0);
        await _database.customStatement(
          "INSERT INTO playback_session(session_id,media_id,mode,initial_variant_id,final_variant_id,snapshot_id,started_at_utc_ms,context,status,valid_play,completed,skipped,progress_ratio,policy_version,aggregate_scope,provenance,last_sequence) VALUES(?,?,?,?,?,?,?,'unknown','legacy',1,?,?,?,1,'baseline_covered','imported',1)",
          [
            session,
            media,
            mode,
            variant,
            variant,
            actualSnapshot,
            at,
            completed ? 1 : 0,
            skipped ? 1 : 0,
            ratio,
          ],
        );
        await _database.customStatement(
          "INSERT INTO playback_event(event_id,session_id,sequence,type,occurred_at_utc_ms,event_version,codec_version,payload_version,payload_json,command_id,command_event_index) VALUES(?,?,1,'legacy_import',?,1,1,1,?,?,0)",
          [
            stable('legacy-event', [sourceHash, ordinal]),
            session,
            at,
            payload,
            command,
          ],
        );
      }
      await _database.customStatement(
        "UPDATE migration_state SET state='verified',imported_count=? WHERE migration_id=?",
        [events.length, source],
      );
      await _restorationRevision();
    });
  });

  Future<List<Map<String, dynamic>>> queryListeningEvents({
    int? startUtcMs,
    int? endUtcMs,
  }) => _restorationTask(() async {
    final rows = await _database
        .customSelect(
          '''WITH bounds AS (SELECT ? lo, ? hi)
          SELECT s.*,m.library_id,n.title,n.artist,n.artwork_ref,e.payload_json,
            (SELECT SUM(i.wall_ms*1.0 *
              (MIN(i.ended_at_utc_ms,COALESCE(hi,i.ended_at_utc_ms))-MAX(i.started_at_utc_ms,COALESCE(lo,i.started_at_utc_ms))) /
              NULLIF(i.ended_at_utc_ms-i.started_at_utc_ms,0))
             FROM playback_interval i WHERE i.session_id=s.session_id
               AND (lo IS NULL OR i.ended_at_utc_ms>lo) AND (hi IS NULL OR i.started_at_utc_ms<hi)) range_wall
          FROM playback_session s JOIN media_identity m USING(media_id) JOIN metadata_snapshot n USING(snapshot_id)
            CROSS JOIN bounds LEFT JOIN playback_event e ON e.session_id=s.session_id AND e.type='legacy_import'
          WHERE (s.valid_play=1 OR s.wall_ms>0 OR s.status='legacy') AND
            (((lo IS NULL OR s.started_at_utc_ms>=lo) AND (hi IS NULL OR s.started_at_utc_ms<hi)) OR
              (s.status!='legacy' AND EXISTS(SELECT 1 FROM playback_interval i WHERE i.session_id=s.session_id
                AND (lo IS NULL OR i.ended_at_utc_ms>lo) AND (hi IS NULL OR i.started_at_utc_ms<hi))))
          ORDER BY s.started_at_utc_ms,s.session_id''',
          variables: [Variable<int>(startUtcMs), Variable<int>(endUtcMs)],
        )
        .get();
    return rows.map((row) {
      final legacy = row.readNullable<String>('payload_json');
      if (legacy != null) {
        return Map<String, dynamic>.from(
          (jsonDecode(legacy) as Map)['legacy'] as Map,
        );
      }
      return <String, dynamic>{
        'trackKey':
            row.readNullable<String>('library_id') ??
            row.read<String>('media_id'),
        'occurredAt':
            startUtcMs != null &&
                row.read<int>('started_at_utc_ms') < startUtcMs
            ? startUtcMs
            : row.read<int>('started_at_utc_ms'),
        'countsAsPlay':
            row.read<int>('valid_play') == 1 &&
            (startUtcMs == null ||
                row.read<int>('started_at_utc_ms') >= startUtcMs),
        'progress': row.readNullable<double>('progress_ratio') ?? 0,
        'completed': row.read<int>('completed') == 1,
        'skipped': row.read<int>('skipped') == 1,
        'mode': row.read<String>('mode'),
        'sessionId': row.read<String>('session_id'),
        'playedSeconds': ((row.data['range_wall'] as num?) ?? 0) / 1000,
        'mediaSnapshot': {
          'id':
              row.readNullable<String>('library_id') ??
              row.read<String>('media_id'),
          'publicId': '',
          'title': row.readNullable<String>('title') ?? '',
          'subtitle': row.readNullable<String>('artist') ?? '',
          'source': 'local',
          'variants': [],
          'origin': 'device',
          if (row.readNullable<String>('artwork_ref')?.startsWith('local:') ==
              true)
            'thumbnailLocalPath': row.read<String>('artwork_ref').substring(6),
          if (row.readNullable<String>('artwork_ref')?.startsWith('remote:') ==
              true)
            'thumbnail': row.read<String>('artwork_ref').substring(7),
        },
      };
    }).toList();
  });

  static const transferTables = [
    'media_identity',
    'media_alias',
    'media_variant',
    'metadata_snapshot',
    'applied_command',
    'playback_session',
    'playback_event',
    'playback_interval',
    'migration_state',
    'migration_reject',
    'legacy_metrics',
    'feedback_event',
    'playback_aggregate',
    'playback_restoration',
    'playback_resume',
    'restoration_import',
  ];

  /// Complete SQL snapshot. Logical restore remains versioned independently.
  /// Enumerate installed tables so future durable tables cannot be omitted.
  Future<Map<String, dynamic>> exportCompleteDatabase() => _restorationTask(
    () => _database.transaction(() async {
      final names =
          (await _database
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toList();
      final tables = <String, dynamic>{};
      for (final name in names) {
        final quoted = name.replaceAll('"', '""');
        tables[name] =
            (await _database.customSelect('SELECT * FROM "$quoted"').get())
                .map((row) => row.data)
                .toList();
      }
      return <String, dynamic>{
        'formatVersion': 1,
        'databaseSchemaVersion': _database.schemaVersion,
        'scope': 'all_application_tables',
        'tables': tables,
      };
    }),
  );

  Future<Map<String, dynamic>> exportDebugBundle() => _restorationTask(
    () => _database.transaction(
      () async => {
        'schemaVersion': 2,
        // This envelope exports the playback subset, not the entire app DB.
        'databaseSchemaVersion': _database.schemaVersion,
        'scope': 'playback_history_and_restoration',
        'tables': {
          for (final table in transferTables)
            table: (await _database.customSelect('SELECT * FROM $table').get())
                .map((r) => r.data)
                .toList(),
        },
      },
    ),
  );

  /// Explicit complete restore replaces SQL contents in one transaction.
  Future<void> restoreCompleteDatabase(
    Map<String, dynamic> bundle,
  ) => _restorationTask(
    () => _database.transaction(() async {
      if (bundle['formatVersion'] != 1 ||
          ![
            4,
            5,
            _database.schemaVersion,
          ].contains(bundle['databaseSchemaVersion']) ||
          bundle['scope'] != 'all_application_tables' ||
          bundle['tables'] is! Map) {
        throw FormatException('Unsupported complete database backup');
      }
      final tables = Map<String, dynamic>.from(bundle['tables'] as Map);
      final upgradeRelations = bundle['databaseSchemaVersion'] == 4;
      if (upgradeRelations) {
        for (final name in PlaybackDatabase.artistRelationTables) {
          if (tables.containsKey(name)) {
            throw FormatException('Unexpected v4 relation table');
          }
          tables[name] = <dynamic>[];
        }
      }
      final upgradeIds =
          bundle['databaseSchemaVersion'] != _database.schemaVersion;
      if (upgradeIds) {
        if (tables.containsKey('artist_name_alias') ||
            tables.containsKey('artist_redirect')) {
          throw FormatException('Unexpected old identity tables');
        }
        tables['artist_name_alias'] = <dynamic>[];
        tables['artist_redirect'] = <dynamic>[];
        final mapping = <String, String>{};
        for (final raw in tables['catalog_artist_identity'] as List) {
          final row = raw as Map;
          final old = row['artist_key'] as String;
          final id = 'artist-${const Uuid().v4()}';
          mapping[old] = id;
          row['artist_key'] = id;
          (tables['artist_name_alias'] as List).add({
            'name_key': old,
            'artist_id': id,
          });
        }
        for (final raw in tables['artist_record'] as List) {
          final row = raw as Map;
          final old = row['artist_key'] as String;
          final id = mapping[old];
          if (id == null) continue;
          final metadata = jsonDecode(row['metadata_json'] as String) as Map;
          metadata['key'] = id;
          metadata['memberKeys'] = (metadata['memberKeys'] as List? ?? [])
              .map((key) => mapping[key] ?? key)
              .toList();
          row['artist_key'] = id;
          row['metadata_json'] = jsonEncode(metadata);
        }
        for (final raw in tables['library_artist_credit'] as List) {
          final row = raw as Map;
          row['artist_key'] = mapping[row['artist_key']] ?? row['artist_key'];
        }
        for (final raw in tables['artist_membership'] as List) {
          final row = raw as Map;
          row['band_key'] = mapping[row['band_key']] ?? row['band_key'];
          row['member_key'] = mapping[row['member_key']] ?? row['member_key'];
        }
        for (final raw in tables['catalog_file_reference'] as List) {
          final row = raw as Map;
          if (row['owner_kind'] == 'artist') {
            row['owner_id'] = mapping[row['owner_id']] ?? row['owner_id'];
          }
        }
      }
      final installed =
          (await _database
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      if (tables.keys.toSet().difference(installed).isNotEmpty ||
          installed.difference(tables.keys.toSet()).isNotEmpty) {
        throw FormatException('Incomplete database backup');
      }
      String quote(String name) => '"${name.replaceAll('"', '""')}"';
      final parents = <String, Set<String>>{};
      for (final table in installed) {
        final columns =
            (await _database
                    .customSelect('PRAGMA table_info(${quote(table)})')
                    .get())
                .map((row) => row.read<String>('name'))
                .toSet();
        if (tables[table] is! List) throw FormatException('Invalid table rows');
        for (final raw in tables[table] as List) {
          if (raw is! Map ||
              raw.keys.toSet().difference(columns).isNotEmpty ||
              columns.difference(raw.keys.toSet()).isNotEmpty) {
            throw FormatException('Invalid complete backup columns');
          }
        }
        parents[table] =
            (await _database
                    .customSelect('PRAGMA foreign_key_list(${quote(table)})')
                    .get())
                .map((row) => row.read<String>('table'))
                .where((name) => name != table)
                .toSet();
      }
      final order = <String>[];
      while (order.length < installed.length) {
        final ready = installed
            .where(
              (name) =>
                  !order.contains(name) && parents[name]!.every(order.contains),
            )
            .toList();
        if (ready.isEmpty) throw FormatException('Cyclic backup dependencies');
        order.addAll(ready);
      }
      for (final table in order.reversed) {
        await _database.customStatement('DELETE FROM ${quote(table)}');
      }
      for (final table in order) {
        for (final raw in tables[table] as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          await _database.customStatement(
            'INSERT INTO ${quote(table)} (${row.keys.map(quote).join(',')}) VALUES (${row.keys.map((_) => '?').join(',')})',
            row.values.toList(),
          );
        }
      }
      if (upgradeRelations) {
        final profiles =
            (await _database
                    .customSelect(
                      'SELECT metadata_json FROM artist_record ORDER BY ordinal',
                    )
                    .get())
                .map((r) => jsonDecode(r.read<String>('metadata_json')))
                .toList();
        await _replaceCatalog('artist_profiles', profiles);
        await _rebuildArtistRelations();
      }
      if ((await _database.customSelect('PRAGMA foreign_key_check').get())
          .isNotEmpty) {
        throw FormatException('Invalid restored foreign keys');
      }
    }),
  );

  /// Exact merge only. Conflicting rows roll back, never overwrite live history.
  Future<void> restoreDebugBundle(
    Map<String, dynamic> bundle,
  ) => _restorationTask(() async {
    if (bundle['schemaVersion'] != 2 || bundle['tables'] is! Map) {
      throw FormatException('Unsupported playback backup');
    }
    final tables = Map<String, dynamic>.from(bundle['tables'] as Map);
    if (tables.keys.toSet().difference(transferTables.toSet()).isNotEmpty ||
        transferTables.any((t) => tables[t] is! List)) {
      throw FormatException('Invalid playback backup tables');
    }
    final revision = await _database.transaction(() async {
      for (final table in transferTables) {
        if (table == 'playback_aggregate') continue;
        if (table == 'playback_resume') {
          // Explicit restore replaces operational positions, never journal facts.
          await _database.customStatement('DELETE FROM playback_resume');
        }
        final columns =
            (await _database.customSelect('PRAGMA table_info($table)').get())
                .map((r) => r.read<String>('name'))
                .toSet();
        for (final raw in tables[table] as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          if (row.keys.toSet().difference(columns).isNotEmpty || row.isEmpty) {
            throw FormatException('Invalid backup columns');
          }
          if (table == 'playback_event' &&
              (row['event_version'] != 1 ||
                  row['codec_version'] != 1 ||
                  row['payload_version'] != 1)) {
            throw FormatException('Unsupported playback event codec');
          }
          if (table == 'playback_restoration') {
            if (row['payload_version'] != 1) {
              throw FormatException('Unsupported restoration codec');
            }
            PlaybackRestoration.decode(
              RestorationMode.values.byName(row['mode'] as String),
              row['payload_json'] as String,
            );
            await _database.customStatement(
              'DELETE FROM playback_restoration WHERE mode=?',
              [row['mode']],
            );
          }
          if (table == 'playback_session' && row['status'] == 'open') {
            final current = await _database
                .customSelect(
                  'SELECT * FROM playback_session WHERE session_id=?',
                  variables: [Variable(row['session_id'] as String)],
                )
                .getSingleOrNull();
            if (current != null &&
                current.read<int>('last_sequence') >=
                    (row['last_sequence'] as int)) {
              const immutable = [
                'media_id',
                'mode',
                'initial_variant_id',
                'snapshot_id',
                'started_at_utc_ms',
                'context',
                'source_id',
                'initial_position_ms',
                'initial_speed',
                'aggregate_scope',
                'provenance',
                'policy_version',
              ];
              if (immutable.any((key) => current.data[key] != row[key])) {
                throw StateError('Conflicting historical session');
              }
              // The journal rows below must still match exactly. Never roll a
              // confirmed terminal back to an older open materialization.
              continue;
            }
          }
          final names = row.keys.toList();
          final existing = await _database
              .customSelect(
                'SELECT 1 FROM $table WHERE ${names.map((n) => '"$n" IS ?').join(' AND ')}',
                variables: row.values.map((v) => Variable(v)).toList(),
              )
              .get();
          if (existing.isNotEmpty) continue;
          await _database.customStatement(
            'INSERT INTO $table (${names.map((n) => '"$n"').join(',')}) VALUES(${names.map((_) => '?').join(',')})',
            row.values.toList(),
          );
        }
      }
      final affected = await _database
          .customSelect('SELECT DISTINCT media_id,mode FROM playback_session')
          .get();
      for (final row in affected) {
        await _refreshAggregate(
          row.read<String>('media_id'),
          row.read<String>('mode'),
        );
      }
      return _restorationRevision();
    });
    _revisions.add(revision);
  });
}

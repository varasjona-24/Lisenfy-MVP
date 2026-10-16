part of 'playback_repository.dart';

extension MediaReplacementWriter on PlaybackRepository {
  /// Keeps the source identity. Historical payloads and physical files are untouched.
  Future<(MediaItem, int)> replaceMediaFile(
    String sourceId,
    String targetId,
    Map<String, String> resumeChoices,
  ) => _catalogCommand(() async {
    final result = await _database.transaction(() async {
      await _database.customStatement('PRAGMA defer_foreign_keys=ON');
      if (sourceId == targetId) throw StateError('replacement_same_item');
      final rows = await _database
          .customSelect('SELECT * FROM library_record ORDER BY ordinal')
          .get();
      final library = <Map<String, dynamic>>[];
      for (final row in rows) {
        final json =
            jsonDecode(row.read<String>('metadata_json'))
                as Map<String, dynamic>;
        json['variants'] =
            (await _database
                    .customSelect(
                      'SELECT payload_json FROM library_variant WHERE item_id=? ORDER BY ordinal',
                      variables: [Variable(row.read<String>('id'))],
                    )
                    .get())
                .map((v) => jsonDecode(v.read<String>('payload_json')))
                .toList();
        library.add(json);
      }
      final sources = library.where((r) => r['id'] == sourceId).toList();
      final targets = library.where((r) => r['id'] == targetId).toList();
      if (sources.length != 1 || targets.length != 1) {
        throw StateError('replacement_missing_item');
      }
      final source = MediaItem.fromJson(sources.single);
      final target = MediaItem.fromJson(targets.single);
      final variants = [
        ...target.variants.where((v) => (v.localPath ?? '').trim().isNotEmpty),
      ];
      if (variants.isEmpty) throw StateError('replacement_missing_file');
      for (final v in source.variants) {
        if (!variants.any((other) => other.sameIdentityAs(v))) variants.add(v);
      }
      final updated = source.copyWith(
        variants: variants,
        durationSeconds: target.effectiveDurationSeconds,
      );
      final identities = await _database
          .customSelect(
            'SELECT media_id,library_id FROM media_identity WHERE library_id IN (?,?) AND retired_at_utc_ms IS NULL ORDER BY created_at_utc_ms,media_id',
            variables: [Variable(sourceId), Variable(targetId)],
          )
          .get();
      final sourceIdentities = identities
          .where((r) => r.read<String>('library_id') == sourceId)
          .toList();
      if (sourceIdentities.isEmpty) {
        throw StateError('replacement_missing_identity');
      }
      final canonical = sourceIdentities.first.read<String>('media_id');
      final ids = identities.map((r) => r.read<String>('media_id')).toList();
      for (final id in ids) {
        if ((await _database
                .customSelect(
                  "SELECT session_id FROM playback_session WHERE media_id=? AND status='open' LIMIT 1",
                  variables: [Variable(id)],
                )
                .get())
            .isNotEmpty) {
          throw StateError('replacement_active_session');
        }
      }
      final guards = await _database
          .customSelect(
            "SELECT name,sql FROM sqlite_master WHERE type='trigger' AND name IN ('session_terminal_immutable','feedback_no_update')",
          )
          .get();
      for (final guard in guards) {
        await _database.customStatement(
          'DROP TRIGGER ${guard.read<String>('name')}',
        );
      }
      for (final old in ids.where((id) => id != canonical)) {
        for (final table in [
          'media_alias',
          'media_variant',
          'playback_session',
          'playback_interval',
          'legacy_metrics',
        ]) {
          await _database.customStatement(
            'UPDATE $table SET media_id=? WHERE media_id=?',
            [canonical, old],
          );
        }
        await _database.customStatement(
          "UPDATE feedback_event SET media_id=?,target_key=? WHERE media_id=? AND target_kind='media'",
          [canonical, canonical, old],
        );
        await _database.customStatement(
          'DELETE FROM playback_aggregate WHERE media_id=?',
          [old],
        );
        await _database.customStatement(
          'UPDATE media_identity SET library_id=NULL,retired_at_utc_ms=? WHERE media_id=?',
          [DateTime.now().millisecondsSinceEpoch, old],
        );
      }
      for (final guard in guards) {
        await _database.customStatement(guard.read<String>('sql'));
      }
      final sourceKey = source.publicId.trim().isEmpty
          ? source.id
          : source.publicId.trim();
      final targetKey = target.publicId.trim().isEmpty
          ? target.id
          : target.publicId.trim();
      final targetKeys =
          {target.id, targetKey, 'i:${target.id}', 'p:$targetKey'}
            ..remove(sourceKey)
            ..remove(source.id);
      final sourceKeys = {
        sourceKey,
        source.id,
        'i:${source.id}',
        'p:$sourceKey',
      };
      String remap(String key) => targetKeys.contains(key) ? sourceKey : key;
      var playlistCount = 0;
      final playlists = <Map<String, dynamic>>[];
      for (final row
          in await _database
              .customSelect('SELECT * FROM playlist_record ORDER BY ordinal')
              .get()) {
        final json =
            jsonDecode(row.read<String>('metadata_json'))
                as Map<String, dynamic>;
        final members =
            (await _database
                    .customSelect(
                      'SELECT item_key FROM playlist_member WHERE playlist_id=? ORDER BY ordinal',
                      variables: [Variable(row.read<String>('id'))],
                    )
                    .get())
                .map((r) => r.read<String>('item_key'))
                .toList();
        if (members.any(targetKeys.contains)) playlistCount++;
        json['itemIds'] = members.map(remap).toSet().toList();
        final added = Map<String, dynamic>.from(
          json['itemAddedAt'] as Map? ?? {},
        );
        for (final key in targetKeys) {
          final date = added.remove(key);
          if (date != null) added.putIfAbsent(sourceKey, () => date);
        }
        json['itemAddedAt'] = added;
        playlists.add(json);
      }
      // Resume is operational state, independent of immutable listening evidence.
      for (final mode in ['audio', 'video']) {
        final points = await _database
            .customSelect(
              'SELECT * FROM playback_resume WHERE mode=?',
              variables: [Variable(mode)],
            )
            .get();
        QueryRow? sourcePoint, targetPoint;
        for (final point in points) {
          if (sourceKeys.contains(point.read<String>('track_key'))) {
            if (sourcePoint == null ||
                point.read<int>('position_ms') >
                    sourcePoint.read<int>('position_ms')) {
              sourcePoint = point;
            }
          }
          if (targetKeys.contains(point.read<String>('track_key'))) {
            if (targetPoint == null ||
                point.read<int>('position_ms') >
                    targetPoint.read<int>('position_ms')) {
              targetPoint = point;
            }
          }
        }
        final choice = resumeChoices[mode];
        if (sourcePoint != null && targetPoint != null && choice == null) {
          throw StateError('replacement_resume_choice_required');
        }
        if (choice != null &&
            !['source', 'target', 'restart'].contains(choice)) {
          throw ArgumentError('Invalid resume choice');
        }
        final selected = choice == 'restart'
            ? null
            : choice == 'target'
            ? targetPoint
            : sourcePoint ?? targetPoint;
        final playable = updated.variants
            .where(
              (v) =>
                  v.kind ==
                  (mode == 'audio'
                      ? MediaVariantKind.audio
                      : MediaVariantKind.video),
            )
            .toList();
        final durationMs = playable.isEmpty
            ? 0
            : (playable.first.durationSeconds ?? updated.durationSeconds ?? 0) *
                  1000;
        final selectedPosition = selected?.read<int>('position_ms') ?? 0;
        final position = durationMs > 0
            ? selectedPosition.clamp(0, durationMs).toInt()
            : selectedPosition;
        for (final key in {...sourceKeys, ...targetKeys}) {
          await _database.customStatement(
            'DELETE FROM playback_resume WHERE mode=? AND track_key=?',
            [mode, key],
          );
        }
        if (selected != null) {
          await _database.customStatement(
            'INSERT INTO playback_resume VALUES (?,?,?,?)',
            [
              mode,
              sourceKey,
              position,
              selected.readNullable<int>('trusted_watch_ms'),
            ],
          );
        }
        // Keep queue order and update only snapshots of the replaced content.
        final restoration = await _database
            .customSelect(
              'SELECT payload_json FROM playback_restoration WHERE mode=?',
              variables: [Variable(mode)],
            )
            .getSingleOrNull();
        if (restoration != null) {
          final payload =
              jsonDecode(restoration.read<String>('payload_json')) as Map;
          final snapshots = [
            ...(payload['queue'] as List? ?? []),
            if (payload['lastItem'] is Map) payload['lastItem'],
          ];
          if (snapshots.whereType<Map>().any(
            (r) => [sourceId, targetId].contains(r['id']),
          )) {
            final queue = List<dynamic>.from(payload['queue'] as List? ?? []);
            final engineVariants = List<dynamic>.from(
              payload['variants'] as List? ?? [],
            );
            final kind = mode == 'audio'
                ? MediaVariantKind.audio
                : MediaVariantKind.video;
            final available = updated.variants
                .where((v) => v.kind == kind && (v.localPath ?? '').isNotEmpty)
                .toList();
            final nextVariant = available.isEmpty
                ? null
                : available.first.toJson();
            final index = (payload['index'] as num?)?.toInt() ?? 0;
            var activeChanged = false;
            for (var i = 0; i < queue.length; i++) {
              final item = queue[i];
              if (item is Map && [sourceId, targetId].contains(item['id'])) {
                queue[i] = updated.toJson();
                if (i < engineVariants.length && nextVariant != null) {
                  engineVariants[i] = nextVariant;
                }
                if (i == index) activeChanged = true;
              }
            }
            final last = payload['lastItem'];
            if (last is Map && [sourceId, targetId].contains(last['id'])) {
              payload['lastItem'] = updated.toJson();
              if (nextVariant != null) payload['lastVariant'] = nextVariant;
              activeChanged = true;
            }
            payload['queue'] = queue;
            payload['variants'] = engineVariants;
            if (activeChanged) {
              payload['positionMs'] = position;
              payload['wasPlaying'] = false;
            }
            await _database.customStatement(
              'UPDATE playback_restoration SET payload_json=?,updated_at_utc_ms=? WHERE mode=?',
              [
                jsonEncode(payload),
                DateTime.now().millisecondsSinceEpoch,
                mode,
              ],
            );
          }
        }
      }
      // Collections keep references to the canonical song, with duplicates removed.
      for (final row
          in await _database
              .customSelect(
                "SELECT * FROM app_domain_record WHERE namespace IN ('source_theme_topics','source_theme_topic_playlists')",
              )
              .get()) {
        final json = jsonDecode(row.read<String>('payload_json'));
        if (json is Map && json['itemIds'] is List) {
          json['itemIds'] = (json['itemIds'] as List)
              .map((id) => id is String ? remap(id) : id)
              .toSet()
              .toList();
          await _database.customStatement(
            'UPDATE app_domain_record SET payload_json=? WHERE namespace=? AND record_key=?',
            [
              jsonEncode(json),
              row.read<String>('namespace'),
              row.read<String>('record_key'),
            ],
          );
        }
      }
      // Remap only documented recommendation references, never model weights.
      dynamic remapRecommendations(dynamic value) {
        if (value is List) return value.map(remapRecommendations).toList();
        if (value is! Map) return value;
        final copy = Map<String, dynamic>.from(value);
        for (final entry in copy.entries.toList()) {
          if (entry.key == 'itemId' && entry.value == targetId) {
            copy[entry.key] = sourceId;
          } else if (entry.key == 'publicId' &&
              entry.value == target.publicId) {
            copy[entry.key] = source.publicId;
          } else if (['itemKeys', 'hiddenTrackKeys'].contains(entry.key) &&
              entry.value is List) {
            copy[entry.key] = (entry.value as List)
                .map((key) => key is String ? remap(key) : key)
                .toSet()
                .toList();
          } else {
            copy[entry.key] = remapRecommendations(entry.value);
          }
        }
        return copy;
      }

      for (final row
          in await _database
              .customSelect(
                "SELECT * FROM app_domain_record WHERE namespace IN ('recommendation_state_v1','recommendation_mix_state_v2','recommendation_feedback_v1')",
              )
              .get()) {
        final payload = jsonDecode(row.read<String>('payload_json'));
        final key = row.read<String>('record_key');
        dynamic updatedPayload;
        if (key == 'hiddenTrackKeys' && payload is List) {
          updatedPayload = payload
              .map((v) => v is String ? remap(v) : v)
              .toSet()
              .toList();
        } else if (key == 'trackBias' && payload is Map) {
          final biases = Map<String, dynamic>.from(payload);
          for (final target in targetKeys) {
            final bias = biases.remove(target);
            if (bias != null) biases.putIfAbsent(sourceKey, () => bias);
          }
          updatedPayload = biases;
        } else {
          updatedPayload = remapRecommendations(payload);
        }
        await _database.customStatement(
          'UPDATE app_domain_record SET payload_json=? WHERE namespace=? AND record_key=?',
          [jsonEncode(updatedPayload), row.read<String>('namespace'), key],
        );
      }
      await _replaceCatalog('local_library_items', [
        for (final item in library)
          if (item['id'] != targetId)
            item['id'] == sourceId ? updated.toJson() : item,
      ]);
      await _replaceCatalog('playlists', playlists);
      await _rebuildArtistRelations();
      for (final mode in ['audio', 'video', 'unknown']) {
        await _refreshAggregate(canonical, mode);
      }
      await faultInjector?.call(PlaybackFaultPoint.beforeCommit);
      return (updated, playlistCount, await _restorationRevision());
    });
    _revisions.add(result.$3);
    return (result.$1, result.$2);
  });
}

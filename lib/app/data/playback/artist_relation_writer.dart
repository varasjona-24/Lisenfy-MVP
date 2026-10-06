part of 'playback_repository.dart';

extension ArtistRelationPersistence on PlaybackRepository {
  Future<Map<String, List<Map<String, dynamic>>>>
  readArtistCandidates() => _catalogCommand(
    () => _database.transaction(() async {
      final result = <String, List<Map<String, dynamic>>>{};
      for (final row
          in await _database
              .customSelect(
                'SELECT n.name_key,a.artist_key,a.display_name,p.metadata_json FROM artist_name_alias n JOIN catalog_artist_identity a ON a.artist_key=n.artist_id LEFT JOIN artist_record p ON p.artist_key=a.artist_key',
              )
              .get()) {
        final metadata = row.readNullable<String>('metadata_json');
        result.putIfAbsent(row.read<String>('name_key'), () => []).add({
          'id': row.read<String>('artist_key'),
          'name': row.read<String>('display_name'),
          'country': metadata == null
              ? null
              : (jsonDecode(metadata) as Map)['country'],
        });
      }
      return result;
    }),
  );
  Future<void> assignArtistCredits(
    String itemId,
    List<Map<String, dynamic>> choices,
  ) => _catalogCommand(
    () => _database.transaction(() async {
      final state = await _database
          .customSelect(
            'SELECT raw_credit FROM library_credit_state WHERE item_id=?',
            variables: [Variable(itemId)],
          )
          .getSingle();
      final raw = state.read<String>('raw_credit');
      final parsed = ArtistCreditParser.parse(raw);
      if (choices.length != parsed.allArtists.length) {
        throw FormatException('Incomplete artist choices');
      }
      final ids = <String>[];
      for (var i = 0; i < choices.length; i++) {
        final id = choices[i]['id'] as String?;
        if (id != null) {
          if ((await _database
                  .customSelect(
                    'SELECT artist_key FROM catalog_artist_identity WHERE artist_key=?',
                    variables: [Variable(id)],
                  )
                  .get())
              .isEmpty) {
            throw StateError('Artist no longer exists');
          }
          ids.add(id);
        } else {
          final created = 'artist-${const Uuid().v4()}';
          final name = parsed.allArtists[i];
          await _database.customStatement(
            'INSERT INTO catalog_artist_identity VALUES (?,?)',
            [created, name],
          );
          await _database.customStatement(
            'INSERT INTO artist_name_alias VALUES (?,?)',
            [ArtistCreditParser.normalizeKey(name), created],
          );
          ids.add(created);
        }
        await _database.customStatement(
          'INSERT OR IGNORE INTO artist_name_alias VALUES (?,?)',
          [ArtistCreditParser.normalizeKey(parsed.allArtists[i]), ids.last],
        );
      }
      if (ids.toSet().length != ids.length) {
        throw FormatException('Duplicate artist choices');
      }
      await _database.customStatement(
        'DELETE FROM library_artist_credit WHERE item_id=?',
        [itemId],
      );
      for (var i = 0; i < ids.length; i++) {
        await _database.customStatement(
          'INSERT INTO library_artist_credit VALUES (?,?,?,?,?)',
          [
            itemId,
            ids[i],
            i,
            i == 0 ? 'primary' : 'featured',
            'user_confirmed',
          ],
        );
      }
      await _database.customStatement(
        "UPDATE library_credit_state SET interpretation='legacy_parsed' WHERE item_id=?",
        [itemId],
      );
    }),
  );
  Future<List<String>> _artistCandidates(String name) async {
    return (await _database
            .customSelect(
              'SELECT artist_id FROM artist_name_alias WHERE name_key=?',
              variables: [Variable(ArtistCreditParser.normalizeKey(name))],
            )
            .get())
        .map((r) => r.read<String>('artist_id'))
        .toList();
  }

  Future<String> _artistIdentity(String name) async {
    final redirect = await _database
        .customSelect(
          'SELECT target_id FROM artist_redirect WHERE source_id=?',
          variables: [Variable(name)],
        )
        .getSingleOrNull();
    if (redirect != null) {
      return _artistIdentity(redirect.read<String>('target_id'));
    }
    final existing = await _database
        .customSelect(
          'SELECT artist_key FROM catalog_artist_identity WHERE artist_key=?',
          variables: [Variable(name)],
        )
        .getSingleOrNull();
    if (existing != null) return name;
    final candidates = await _artistCandidates(name);
    if (candidates.length > 1) {
      throw StateError('Ambiguous artist identity: $name');
    }
    if (candidates.isNotEmpty) return candidates.single;
    final stableId = RegExp(
      r'^artist-(?:[0-9a-f]{32}|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$',
    ).hasMatch(name);
    final id = stableId ? name : 'artist-${const Uuid().v4()}';
    await _database.customStatement(
      'INSERT INTO catalog_artist_identity VALUES (?,?)',
      [id, ArtistCreditParser.cleanName(name)],
    );
    await _database.customStatement(
      'INSERT INTO artist_name_alias VALUES (?,?)',
      [ArtistCreditParser.normalizeKey(name), id],
    );
    return id;
  }

  Future<void> rebuildArtistRelations() =>
      _catalogCommand(() => _database.transaction(_rebuildArtistRelations));
  Future<void> _rebuildArtistRelations() async {
    final previous = <String, Map<String, dynamic>>{};
    for (final state
        in await _database
            .customSelect('SELECT * FROM library_credit_state')
            .get()) {
      final id = state.read<String>('item_id');
      previous[id] = {
        'raw': state.read<String>('raw_credit'),
        'provenance':
            (await _database
                    .customSelect(
                      'SELECT provenance FROM library_artist_credit WHERE item_id=? ORDER BY ordinal',
                      variables: [Variable(id)],
                    )
                    .get())
                .map((r) => r.read<String>('provenance'))
                .toList(),
        'keys':
            (await _database
                    .customSelect(
                      'SELECT artist_key FROM library_artist_credit WHERE item_id=? ORDER BY ordinal',
                      variables: [Variable(id)],
                    )
                    .get())
                .map((r) => r.read<String>('artist_key'))
                .toList(),
      };
    }
    for (final table in [
      'library_artist_credit',
      'library_credit_state',
      'artist_membership',
    ]) {
      await _database.customStatement('DELETE FROM $table');
    }
    Future<String> identity(String name) => _artistIdentity(name);

    var profiles = await _database
        .customSelect('SELECT * FROM artist_record ORDER BY ordinal')
        .get();
    // Profiles in older catalogs may never have been materialized in v5.
    var requiresCanonicalization = false;
    for (final row in profiles) {
      if (await identity(row.read<String>('artist_key')) !=
          row.read<String>('artist_key')) {
        requiresCanonicalization = true;
      }
    }
    if (requiresCanonicalization) {
      await _replaceCatalog('artist_profiles', [
        for (final row in profiles)
          jsonDecode(row.read<String>('metadata_json')),
      ]);
      profiles = await _database
          .customSelect('SELECT * FROM artist_record ORDER BY ordinal')
          .get();
    }
    for (final row in profiles) {
      final profile = jsonDecode(row.read<String>('metadata_json')) as Map;
      await identity(row.read<String>('artist_key'));
      await _database.customStatement(
        'INSERT OR IGNORE INTO artist_name_alias VALUES (?,?)',
        [
          ArtistCreditParser.normalizeKey(
            profile['displayName'] as String? ?? '',
          ),
          row.read<String>('artist_key'),
        ],
      );
      await _database.customStatement(
        'UPDATE catalog_artist_identity SET display_name=? WHERE artist_key=?',
        [
          profile['displayName'] ?? row.read<String>('artist_key'),
          row.read<String>('artist_key'),
        ],
      );
    }
    for (final row in profiles) {
      final profile = jsonDecode(row.read<String>('metadata_json')) as Map;
      if (profile['kind'] != 'band') continue;
      final band = row.read<String>('artist_key');
      final seen = <String>{};
      for (final name in profile['memberKeys'] as List? ?? []) {
        if (name is String && (name.trim().isEmpty || name == 'unknown')) {
          continue;
        }
        final member = await identity(name as String);
        if (member == band || member == 'unknown' || !seen.add(member)) {
          continue;
        }
        await _database.customStatement(
          'INSERT INTO artist_membership VALUES (?,?,?,?)',
          [band, member, seen.length - 1, 'registered_profile'],
        );
      }
    }
    for (final row
        in await _database
            .customSelect('SELECT id,metadata_json FROM library_record')
            .get()) {
      final item = jsonDecode(row.read<String>('metadata_json')) as Map;
      final raw =
          item['artist'] as String? ?? item['subtitle'] as String? ?? '';
      final credits = ArtistCreditParser.parse(raw);
      final ambiguous =
          !credits.hasCollaborators && RegExp(r'\s[&xX]\s|,').hasMatch(raw);
      await _database
          .customStatement('INSERT INTO library_credit_state VALUES (?,?,?)', [
            row.read<String>('id'),
            raw,
            raw.trim().isEmpty
                ? 'empty'
                : ambiguous
                ? 'ambiguous'
                : 'legacy_parsed',
          ]);
      final preserved = previous[row.read<String>('id')];
      final oldKeys = preserved?['keys'] as List<String>?;
      var unresolved = false;
      for (final name in credits.allArtists) {
        if ((await _artistCandidates(name)).length > 1 &&
            !(preserved?['raw'] == raw &&
                oldKeys?.length == credits.allArtists.length)) {
          unresolved = true;
        }
      }
      if (unresolved) {
        await _database.customStatement(
          "UPDATE library_credit_state SET interpretation='ambiguous' WHERE item_id=?",
          [row.read<String>('id')],
        );
        continue;
      }
      for (var i = 0; i < credits.allArtists.length; i++) {
        final name = credits.allArtists[i];
        final preserved = previous[row.read<String>('id')];
        final oldKeys = preserved?['keys'] as List<String>?;
        final candidates = await _artistCandidates(name);
        if (candidates.length > 1 &&
            !(preserved?['raw'] == raw &&
                oldKeys != null &&
                i < oldKeys.length)) {
          await _database.customStatement(
            "UPDATE library_credit_state SET interpretation='ambiguous' WHERE item_id=?",
            [row.read<String>('id')],
          );
          continue;
        }
        final key =
            preserved?['raw'] == raw && oldKeys != null && i < oldKeys.length
            ? oldKeys[i]
            : await identity(name);
        await _database.customStatement(
          'INSERT INTO library_artist_credit VALUES (?,?,?,?,?)',
          [
            row.read<String>('id'),
            key,
            i,
            i == 0 ? 'primary' : 'featured',
            preserved?['raw'] == raw && oldKeys != null && i < oldKeys.length
                ? (preserved!['provenance'] as List<String>)[i]
                : 'legacy_credit_parser',
          ],
        );
      }
    }
  }

  Future<void> updateArtistAtomically({
    required String sourceId,
    required Map<String, dynamic> profile,
    String? mergeTargetId,
  }) => _catalogCommand(
    () => _database.transaction(() async {
      final source = await _artistIdentity(sourceId);
      final target = mergeTargetId == null
          ? source
          : await _artistIdentity(mergeTargetId);
      if (mergeTargetId != null && sourceId != source && source == target) {
        return;
      }
      if ((profile['displayName'] as String? ?? '').trim().isEmpty) {
        throw ArgumentError('Artist display name cannot be empty');
      }
      final profiles = <String, Map<String, dynamic>>{};
      for (final row
          in await _database
              .customSelect('SELECT * FROM artist_record')
              .get()) {
        profiles[row.read<String>('artist_key')] = Map<String, dynamic>.from(
          jsonDecode(row.read<String>('metadata_json')) as Map,
        );
      }
      if (!profiles.containsKey(source)) {
        final identity = await _database
            .customSelect(
              'SELECT display_name FROM catalog_artist_identity WHERE artist_key=?',
              variables: [Variable(source)],
            )
            .getSingle();
        profiles[source] = {
          'key': source,
          'displayName': identity.read<String>('display_name'),
          'kind': profile['kind'],
          'memberKeys': [],
        };
      }
      final oldName = profiles[source]!['displayName'] as String;
      final desired = Map<String, dynamic>.from(profile)..['key'] = target;
      if (target != source) {
        final targetIdentity = await _database
            .customSelect(
              'SELECT display_name FROM catalog_artist_identity WHERE artist_key=?',
              variables: [Variable(target)],
            )
            .getSingle();
        final existing =
            profiles[target] ??
            <String, dynamic>{
              'key': target,
              'displayName': targetIdentity.read<String>('display_name'),
              'kind': desired['kind'],
              'memberKeys': <String>[],
            };
        if (existing['kind'] != desired['kind']) {
          throw StateError('Cannot merge a band with a singer');
        }
        for (final entry in existing.entries) {
          if (entry.key != 'memberKeys' &&
              entry.value != null &&
              entry.value != '' &&
              entry.value != 'none') {
            desired[entry.key] = entry.value;
          }
        }
        desired['memberKeys'] = <dynamic>{
          ...(existing['memberKeys'] as List? ?? []),
          ...(profile['memberKeys'] as List? ?? []),
        }.toList();
        final credits = await _database
            .customSelect(
              'SELECT * FROM library_artist_credit WHERE artist_key=?',
              variables: [Variable(source)],
            )
            .get();
        for (final credit in credits) {
          final item = credit.read<String>('item_id');
          final collision = await _database
              .customSelect(
                'SELECT * FROM library_artist_credit WHERE item_id=? AND artist_key=?',
                variables: [Variable(item), Variable(target)],
              )
              .getSingleOrNull();
          if (collision != null) {
            if (credit.read<String>('role') == 'primary') {
              await _database.customStatement(
                "UPDATE library_artist_credit SET role='primary' WHERE item_id=? AND artist_key=?",
                [item, target],
              );
            }
            await _database.customStatement(
              'DELETE FROM library_artist_credit WHERE item_id=? AND artist_key=?',
              [item, source],
            );
          } else {
            await _database.customStatement(
              'UPDATE library_artist_credit SET artist_key=? WHERE item_id=? AND artist_key=?',
              [target, item, source],
            );
          }
        }
        await _database.customStatement(
          'INSERT OR IGNORE INTO artist_name_alias SELECT name_key,? FROM artist_name_alias WHERE artist_id=?',
          [target, source],
        );
        await _database.customStatement(
          'DELETE FROM artist_name_alias WHERE artist_id=?',
          [source],
        );
        await _database.customStatement(
          'UPDATE artist_redirect SET target_id=? WHERE target_id=?',
          [target, source],
        );
        await _database.customStatement(
          'INSERT OR REPLACE INTO artist_redirect VALUES (?,?)',
          [source, target],
        );
        profiles.remove(source);
      }
      final newName = desired['displayName'] as String;
      await _database.customStatement(
        'INSERT OR IGNORE INTO artist_name_alias VALUES (?,?)',
        [ArtistCreditParser.normalizeKey(oldName), target],
      );
      await _database.customStatement(
        'INSERT OR IGNORE INTO artist_name_alias VALUES (?,?)',
        [ArtistCreditParser.normalizeKey(newName), target],
      );
      for (final row
          in await _database
              .customSelect('SELECT id,metadata_json FROM library_record')
              .get()) {
        final id = row.read<String>('id');
        final linked = await _database
            .customSelect(
              'SELECT 1 FROM library_artist_credit WHERE item_id=? AND artist_key=?',
              variables: [Variable(id), Variable(target)],
            )
            .get();
        if (linked.isEmpty) continue;
        final item = Map<String, dynamic>.from(
          jsonDecode(row.read<String>('metadata_json')) as Map,
        );
        final raw = item['artist'] as String? ?? '';
        final next = ArtistCreditParser.replaceArtistName(
          raw,
          artistKey: oldName,
          newName: newName,
        );
        item['artist'] = next;
        await _database.customStatement(
          'UPDATE library_record SET metadata_json=? WHERE id=?',
          [jsonEncode(item), id],
        );
        await _database.customStatement(
          'UPDATE library_credit_state SET raw_credit=? WHERE item_id=?',
          [next, id],
        );
      }
      profiles[target] = desired;
      for (final entry in profiles.entries) {
        final members = (entry.value['memberKeys'] as List? ?? [])
            .map((member) => member == source ? target : member)
            .where((member) => member != entry.key)
            .toSet()
            .toList();
        entry.value['memberKeys'] = members;
      }
      await _replaceCatalog('artist_profiles', profiles.values.toList());
      await _rebuildArtistRelations();
      await faultInjector?.call(PlaybackFaultPoint.beforeCommit);
    }),
  );

  Future<Map<String, ArtistCredits>> readArtistCredits() => _catalogCommand(
    () => _database.transaction(() async {
      final result = <String, ArtistCredits>{};
      for (final state
          in await _database
              .customSelect('SELECT * FROM library_credit_state')
              .get()) {
        final id = state.read<String>('item_id');
        final rows = await _database
            .customSelect(
              'SELECT c.role,c.artist_key,a.display_name FROM library_artist_credit c JOIN catalog_artist_identity a USING(artist_key) WHERE c.item_id=? ORDER BY c.ordinal',
              variables: [Variable(id)],
            )
            .get();
        result[id] = ArtistCredits(
          rawArtist: state.read<String>('raw_credit'),
          artistKeys: rows.map((r) => r.read<String>('artist_key')).toList(),
          primaryArtist: rows.isEmpty
              ? ''
              : rows.first.read<String>('display_name'),
          collaborators: rows
              .skip(1)
              .map((r) => r.read<String>('display_name'))
              .toList(),
        );
      }
      return result;
    }),
  );
}

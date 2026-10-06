part of 'playback_repository.dart';

extension ArtistRelationPersistence on PlaybackRepository {
  Future<void> rebuildArtistRelations() =>
      _catalogCommand(() => _database.transaction(_rebuildArtistRelations));
  Future<void> _rebuildArtistRelations() async {
    for (final table in [
      'library_artist_credit',
      'library_credit_state',
      'artist_membership',
    ]) {
      await _database.customStatement('DELETE FROM $table');
    }
    Future<String> identity(String name) async {
      final key = ArtistCreditParser.normalizeKey(name);
      await _database.customStatement(
        'INSERT INTO catalog_artist_identity VALUES (?,?) ON CONFLICT(artist_key) DO NOTHING',
        [key, ArtistCreditParser.cleanName(name)],
      );
      return key;
    }

    final profiles = await _database
        .customSelect('SELECT * FROM artist_record ORDER BY ordinal')
        .get();
    for (final row in profiles) {
      final profile = jsonDecode(row.read<String>('metadata_json')) as Map;
      await identity(row.read<String>('artist_key'));
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
      for (var i = 0; i < credits.allArtists.length; i++) {
        final name = credits.allArtists[i];
        final key = await identity(name);
        await _database.customStatement(
          'INSERT INTO library_artist_credit VALUES (?,?,?,?,?)',
          [
            row.read<String>('id'),
            key,
            i,
            i == 0 ? 'primary' : 'featured',
            'legacy_credit_parser',
          ],
        );
      }
    }
  }

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
              'SELECT c.role,a.display_name FROM library_artist_credit c JOIN catalog_artist_identity a USING(artist_key) WHERE c.item_id=? ORDER BY c.ordinal',
              variables: [Variable(id)],
            )
            .get();
        result[id] = ArtistCredits(
          rawArtist: state.read<String>('raw_credit'),
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

part of 'playback_repository.dart';

const catalogKeys = ['local_library_items', 'playlists', 'artist_profiles'];

extension CatalogPersistence on PlaybackRepository {
  Future<T> _catalogCommand<T>(Future<T> Function() action) {
    if (_closing) return Future.error(StateError('Repository is closing'));
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<void> importCatalog({
    required String sourceId,
    required String sourceHash,
    required Map<String, List<dynamic>> data,
  }) {
    return _catalogCommand(
      () => _database.transaction(() async {
        final receipt = await _database
            .customSelect(
              'SELECT source_hash FROM catalog_import WHERE source_id=?',
              variables: [Variable(sourceId)],
            )
            .getSingleOrNull();
        if (receipt != null) {
          if (receipt.read<String>('source_hash') != sourceHash) {
            throw StateError('Catalog import source changed');
          }
          return;
        }
        for (final table in [
          'library_record',
          'playlist_record',
          'artist_record',
        ]) {
          if ((await _database
                  .customSelect('SELECT 1 FROM $table LIMIT 1')
                  .get())
              .isNotEmpty) {
            throw StateError(
              'Catalog baseline import requires an empty catalog',
            );
          }
        }
        for (final key in catalogKeys) {
          await _replaceCatalog(key, data[key] ?? []);
        }
        await _database.customStatement(
          'INSERT INTO catalog_import VALUES (?,?,?)',
          [sourceId, sourceHash, DateTime.now().millisecondsSinceEpoch],
        );
      }),
    );
  }

  Future<void> replaceCatalog(String key, List<dynamic> data) =>
      _catalogCommand(
        () => _database.transaction(() => _replaceCatalog(key, data)),
      );

  Future<void> _replaceCatalog(String key, List<dynamic> data) async {
    final (table, owner, idField) = switch (key) {
      'local_library_items' => ('library_record', 'library', 'id'),
      'playlists' => ('playlist_record', 'playlist', 'id'),
      'artist_profiles' => ('artist_record', 'artist', 'key'),
      _ => throw ArgumentError.value(key, 'key'),
    };
    await _database.customStatement('DELETE FROM $table');
    await _database.customStatement(
      'DELETE FROM catalog_file_reference WHERE owner_kind=?',
      [owner],
    );
    Future<void> file(
      String id,
      String slot,
      dynamic value,
      String kind,
    ) async {
      if (value == null || value == '') return;
      if (value is! String) throw FormatException('Invalid file locator');
      await _database.customStatement(
        'INSERT INTO catalog_file_reference VALUES (?,?,?,?,?)',
        [owner, id, slot, kind, value],
      );
    }

    for (var ordinal = 0; ordinal < data.length; ordinal++) {
      final raw = data[ordinal];
      if (raw is! Map) throw FormatException('Invalid catalog row');
      final json = Map<String, dynamic>.from(raw);
      final id = json[idField];
      if (id is! String || id.isEmpty) {
        throw FormatException('Missing catalog identity');
      }
      final variants = key == 'local_library_items'
          ? json.remove('variants')
          : null;
      final members = key == 'playlists' ? json.remove('itemIds') : null;
      await _database.customStatement('INSERT INTO $table VALUES (?,?,?)', [
        id,
        ordinal,
        jsonEncode(json),
      ]);
      await file(
        id,
        'thumbnailLocalPath',
        json['thumbnailLocalPath'],
        'local_path',
      );
      await file(id, 'thumbnail', json['thumbnail'], 'http_url');
      await file(id, 'coverLocalPath', json['coverLocalPath'], 'local_path');
      if (variants != null && variants is! List) {
        throw FormatException('Invalid variants');
      }
      final variantList = variants as List? ?? [];
      for (var i = 0; i < variantList.length; i++) {
        final variant = Map<String, dynamic>.from(variantList[i] as Map);
        await _database.customStatement(
          'INSERT INTO library_variant VALUES (?,?,?,?,?)',
          [id, i, variant['kind'], variant['format'], jsonEncode(variant)],
        );
        await file(id, 'variant:$i', variant['localPath'], 'local_path');
      }
      if (members != null && members is! List) {
        throw FormatException('Invalid playlist members');
      }
      final memberList = members as List? ?? [];
      for (var i = 0; i < memberList.length; i++) {
        if (memberList[i] is! String) {
          throw FormatException('Invalid playlist member');
        }
        await _database.customStatement(
          'INSERT INTO playlist_member VALUES (?,?,?)',
          [id, i, memberList[i]],
        );
      }
    }
  }

  Future<Map<String, List<dynamic>>> readCatalog() => _catalogCommand(
    () => _database.transaction(() async {
      final result = <String, List<dynamic>>{};
      for (final key in catalogKeys) {
        final (table, idColumn) = switch (key) {
          'local_library_items' => ('library_record', 'id'),
          'playlists' => ('playlist_record', 'id'),
          _ => ('artist_record', 'artist_key'),
        };
        final list = <dynamic>[];
        final rows = await _database
            .customSelect('SELECT * FROM $table ORDER BY ordinal')
            .get();
        for (final row in rows) {
          final json =
              jsonDecode(row.read<String>('metadata_json'))
                  as Map<String, dynamic>;
          final id = row.read<String>(idColumn);
          if (key == 'local_library_items') {
            json['variants'] =
                (await _database
                        .customSelect(
                          'SELECT payload_json FROM library_variant WHERE item_id=? ORDER BY ordinal',
                          variables: [Variable(id)],
                        )
                        .get())
                    .map((v) => jsonDecode(v.read<String>('payload_json')))
                    .toList();
          } else if (key == 'playlists') {
            json['itemIds'] =
                (await _database
                        .customSelect(
                          'SELECT item_key FROM playlist_member WHERE playlist_id=? ORDER BY ordinal',
                          variables: [Variable(id)],
                        )
                        .get())
                    .map((v) => v.read<String>('item_key'))
                    .toList();
          }
          list.add(json);
        }
        result[key] = list;
      }
      return result;
    }),
  );
}

import 'package:get_storage/get_storage.dart';

import '../domain/playlist.dart';
import '../../../app/data/local/catalog_storage.dart';

class PlaylistStore {
  PlaylistStore(GetStorage box) : _box = catalogStorage(box);

  final GetStorage _box;
  static const _key = 'playlists';
  static const maxTemporaryPlaylistsPerDay = 3;

  Future<List<Playlist>> readAll() async {
    final all = _readRawPlaylists();
    final active = all.where((playlist) => !playlist.isExpired).toList();
    if (active.length != all.length) {
      await _box.write(_key, active.map((e) => e.toJson()).toList());
    }
    return active;
  }

  List<Playlist> readAllSync() {
    return _readRawPlaylists()
        .where((playlist) => !playlist.isExpired)
        .toList();
  }

  List<Playlist> _readRawPlaylists() {
    final raw = _box.read<List>(_key) ?? <dynamic>[];
    return raw
        .whereType<Map>()
        .map((m) => Playlist.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<Playlist?> createTemporary({
    required String name,
    required List<String> itemIds,
    String? fingerprint,
    String? coverLocalPath,
    Duration lifetime = const Duration(days: 3),
  }) async {
    final ids = itemIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return null;

    final nowDate = DateTime.now();
    if (await hasReachedDailyTemporaryLimit(nowDate)) return null;

    final now = nowDate.millisecondsSinceEpoch;
    final playlist = Playlist(
      id: 'temporary_${nowDate.microsecondsSinceEpoch}',
      name: name,
      itemIds: ids.toList(growable: false),
      createdAt: now,
      updatedAt: now,
      expiresAt: now + lifetime.inMilliseconds,
      fingerprint: fingerprint?.trim(),
      coverLocalPath: coverLocalPath?.trim().isEmpty == true
          ? null
          : coverLocalPath?.trim(),
    );
    await upsert(playlist);
    return playlist;
  }

  Future<Playlist?> createQueuePlaylist({
    required String name,
    required List<String> itemIds,
    String? fingerprint,
  }) async {
    final trimmedName = name.trim();
    final ids = itemIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (trimmedName.isEmpty || ids.isEmpty) return null;

    final nowDate = DateTime.now();
    final now = nowDate.millisecondsSinceEpoch;
    final playlist = Playlist(
      id: 'pl_${nowDate.microsecondsSinceEpoch}',
      name: trimmedName,
      itemIds: ids.toList(growable: false),
      createdAt: now,
      updatedAt: now,
      fingerprint: fingerprint?.trim(),
    );
    await upsert(playlist);
    return playlist;
  }

  Future<bool> hasReachedDailyTemporaryLimit([DateTime? now]) async {
    final day = now ?? DateTime.now();
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final playlists = await readAll();
    final count = playlists.where((playlist) {
      if (!playlist.isTemporary) return false;
      final createdAt = DateTime.fromMillisecondsSinceEpoch(playlist.createdAt);
      return !createdAt.isBefore(start) && createdAt.isBefore(end);
    }).length;
    return count >= maxTemporaryPlaylistsPerDay;
  }

  Future<void> upsert(Playlist playlist) async {
    final list = await readAll();
    final idx = list.indexWhere((e) => e.id == playlist.id);
    if (idx == -1) {
      list.insert(0, playlist);
    } else {
      list[idx] = playlist;
    }
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }

  Future<void> upsertAll(List<Playlist> playlists) async {
    if (playlists.isEmpty) return;

    final existing = await readAll();
    final incomingIds = playlists.map((e) => e.id).toSet();
    final merged = <Playlist>[
      ...playlists.reversed,
      ...existing.where((e) => !incomingIds.contains(e.id)),
    ];

    await _box.write(_key, merged.map((e) => e.toJson()).toList());
  }

  Future<void> remove(String id) async {
    final list = await readAll();
    list.removeWhere((e) => e.id == id);
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }
}

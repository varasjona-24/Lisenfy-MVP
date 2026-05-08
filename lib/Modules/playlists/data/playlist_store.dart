import 'package:get_storage/get_storage.dart';

import '../domain/playlist.dart';

class PlaylistStore {
  PlaylistStore(this._box);

  final GetStorage _box;
  static const _key = 'playlists';

  Future<List<Playlist>> readAll() async {
    return readAllSync();
  }

  List<Playlist> readAllSync() {
    final raw = _box.read<List>(_key) ?? <dynamic>[];
    return raw
        .whereType<Map>()
        .map((m) => Playlist.fromJson(Map<String, dynamic>.from(m)))
        .toList();
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

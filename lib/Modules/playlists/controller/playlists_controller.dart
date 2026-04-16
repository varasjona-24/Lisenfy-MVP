import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../data/playlist_store.dart';
import '../domain/playlist.dart';

class SmartPlaylist {
  SmartPlaylist({
    required this.id,
    required this.title,
    required this.items,
    required this.colors,
    required this.icon,
  });

  final String id;
  final String title;
  final List<MediaItem> items;
  final List<Color> colors;
  final IconData icon;
}

class PlaylistsController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final PlaylistStore _store = Get.find<PlaylistStore>();

  final RxBool isLoading = false.obs;
  final RxBool detailGridView = false.obs;
  final RxList<Playlist> playlists = <Playlist>[].obs;
  final RxList<SmartPlaylist> smartPlaylists = <SmartPlaylist>[].obs;

  final RxList<MediaItem> _library = <MediaItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final items = await _repo.getLibrary();
      _library.assignAll(items);

      final stored = await _store.readAll();
      playlists.assignAll(stored);

      _buildSmartPlaylists();
    } finally {
      isLoading.value = false;
    }
  }

  List<MediaItem> get libraryAudio => _library.where(_hasAudioVariant).toList();

  String _keyForItem(MediaItem item) {
    final pid = item.publicId.trim();
    return pid.isNotEmpty ? pid : item.id.trim();
  }

  bool _hasAudioVariant(MediaItem item) {
    return item.variants.any((v) => v.kind == MediaVariantKind.audio);
  }

  List<MediaItem> resolvePlaylistItems(Playlist playlist) {
    final ids = playlist.itemIds.toSet();
    if (ids.isEmpty) return <MediaItem>[];

    final result = <MediaItem>[];
    for (final item in _library) {
      final key = _keyForItem(item);
      if (ids.contains(key) && _hasAudioVariant(item)) {
        result.add(item);
      }
    }
    return result;
  }

  SmartPlaylist? getSmartById(String id) {
    for (final p in smartPlaylists) {
      if (p.id == id) return p;
    }
    return null;
  }

  Playlist? getPlaylistById(String id) {
    for (final p in playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> createPlaylist(String name, {String? coverLocalPath}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'pl_${now}_${Random().nextInt(9999)}';
    final playlist = Playlist(
      id: id,
      name: trimmed,
      itemIds: const [],
      createdAt: now,
      updatedAt: now,
      coverLocalPath: coverLocalPath?.trim().isEmpty == true
          ? null
          : coverLocalPath,
    );
    await _store.upsert(playlist);
    await load();
  }

  Future<void> renamePlaylist(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final current = getPlaylistById(id);
    if (current == null) return;
    final updated = current.copyWith(
      name: trimmed,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _store.upsert(updated);
    await load();
  }

  Future<void> updateCover(
    String id, {
    String? coverUrl,
    String? coverLocalPath,
    bool? coverCleared,
  }) async {
    final current = getPlaylistById(id);
    if (current == null) return;
    final updated = current.copyWith(
      coverUrl: coverUrl?.trim().isEmpty == true ? null : coverUrl,
      coverLocalPath: coverLocalPath?.trim().isEmpty == true
          ? null
          : coverLocalPath,
      coverCleared: coverCleared ?? current.coverCleared,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _store.upsert(updated);
    await load();
  }

  Future<void> deletePlaylist(String id) async {
    await _store.remove(id);
    await load();
  }

  Future<void> addItemsToPlaylist(String id, List<MediaItem> items) async {
    final current = getPlaylistById(id);
    if (current == null || items.isEmpty) return;
    final ids = current.itemIds.toSet();
    for (final item in items) {
      ids.add(_keyForItem(item));
    }
    final updated = current.copyWith(
      itemIds: ids.toList(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _store.upsert(updated);
    await load();
  }

  Future<void> removeItemFromPlaylist(String id, MediaItem item) async {
    final current = getPlaylistById(id);
    if (current == null) return;
    final key = _keyForItem(item);
    final updated = current.copyWith(
      itemIds: current.itemIds.where((e) => e != key).toList(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _store.upsert(updated);
    await load();
  }

  void _buildSmartPlaylists() {
    final items = libraryAudio;

    final favorites = items.where((e) => e.isFavorite).toList();

    final recent = items.where((e) => (e.lastPlayedAt ?? 0) > 0).toList()
      ..sort((a, b) => (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0));

    final mostPlayed = items.where((e) => e.playCount > 0).toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));

    final latest = items.where((e) => e.isOfflineStored).toList()
      ..sort(
        (a, b) =>
            _latestVariantCreatedAt(b).compareTo(_latestVariantCreatedAt(a)),
      );

    smartPlaylists.assignAll([
      SmartPlaylist(
        id: 'smart_favorites',
        title: 'Mis favoritos',
        items: favorites,
        colors: const [Color(0xFFB32D5D), Color(0xFFE35D8A)],
        icon: Icons.favorite_rounded,
      ),
      SmartPlaylist(
        id: 'smart_latest',
        title: 'Últimos agregados',
        items: latest,
        colors: const [Color(0xFF0E6E7F), Color(0xFF20B6C9)],
        icon: Icons.cloud_download_rounded,
      ),
      SmartPlaylist(
        id: 'smart_recent',
        title: 'Reproducciones recientes',
        items: recent,
        colors: const [Color(0xFF3E4C9A), Color(0xFF6E7BD6)],
        icon: Icons.history_rounded,
      ),
      SmartPlaylist(
        id: 'smart_most',
        title: 'Más reproducido',
        items: mostPlayed,
        colors: const [Color(0xFFB3552E), Color(0xFFE18B5C)],
        icon: Icons.local_fire_department_rounded,
      ),
    ]);
  }

  int _latestVariantCreatedAt(MediaItem item) {
    var maxTs = 0;
    for (final v in item.variants) {
      if (v.localPath?.trim().isNotEmpty != true) continue;
      if (v.createdAt > maxTs) maxTs = v.createdAt;
    }
    return maxTs;
  }

  void toggleDetailGridView() {
    detailGridView.value = !detailGridView.value;
  }
}

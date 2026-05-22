import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../../app/services/local_media_metadata_service.dart';
import '../../sources/domain/source_origin.dart';
import '../domain/source_theme.dart';
import '../domain/source_theme_pill.dart';
import '../data/source_theme_pill_store.dart';
import '../domain/source_theme_topic.dart';
import '../data/source_theme_topic_store.dart';
import '../domain/source_theme_topic_playlist.dart';
import '../data/source_theme_topic_playlist_store.dart';

class SourcesController extends GetxController {
  // ============================
  // 🔌 DEPENDENCIAS
  // ============================
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final MediaRepository _repo = Get.find<MediaRepository>();
  final SourceThemePillStore _pillStore = Get.find<SourceThemePillStore>();
  final SourceThemeTopicStore _topicStore = Get.find<SourceThemeTopicStore>();
  final SourceThemeTopicPlaylistStore _topicPlaylistStore =
      Get.find<SourceThemeTopicPlaylistStore>();
  final LocalMediaMetadataService _metadata =
      Get.find<LocalMediaMetadataService>();

  // ============================
  // 🧠 ESTADO
  // ============================
  /// Archivos escogidos pero todavía NO importados a la librería interna
  final RxList<MediaItem> localFiles = <MediaItem>[].obs;

  final RxBool importing = false.obs;

  final RxList<SourceThemePill> pills = <SourceThemePill>[].obs;
  final RxList<SourceThemeTopic> topics = <SourceThemeTopic>[].obs;
  final RxList<SourceThemeTopicPlaylist> topicPlaylists =
      <SourceThemeTopicPlaylist>[].obs;

  // ============================
  // 🧭 HELPERS
  // ============================
  String keyForItem(MediaItem item) {
    final pid = item.publicId.trim();
    return pid.isNotEmpty ? pid : item.id.trim();
  }

  // ============================
  // 📚 LIBRERIA (FILTROS)
  // ============================
  Future<List<MediaItem>> loadLibraryItems({
    bool onlyOffline = false,
    SourceOrigin? origin,
    List<SourceOrigin>? origins,
    MediaVariantKind? forceKind,
    MediaVariantKind? modeKind,
  }) async {
    final all = await _repo.getLibrary();
    Iterable<MediaItem> items = all;

    if (onlyOffline) {
      items = items.where((e) => e.isOfflineStored);
    }

    if (origin != null) {
      items = items.where((e) => e.origin == origin);
    }

    if (origins != null && origins.isNotEmpty) {
      final set = origins.toSet();
      items = items.where((e) => set.contains(e.origin));
    }

    if (forceKind != null) {
      items = items.where((e) => e.variants.any((v) => v.kind == forceKind));
    } else if (modeKind != null) {
      items = items.where((e) => e.variants.any((v) => v.kind == modeKind));
    }

    final list = await _backfillVideoDurations(items.toList());
    list.sort(
      (a, b) =>
          (b.variants.first.createdAt).compareTo(a.variants.first.createdAt),
    );
    return list;
  }

  // ============================
  // 🧩 TEMATICAS: ITEMS Y CANDIDATOS
  // ============================
  Future<List<MediaItem>> loadTopicItems({
    required SourceTheme theme,
    required SourceThemeTopic topic,
    List<SourceOrigin>? origins,
  }) async {
    final all = await _repo.getLibrary();

    Iterable<MediaItem> items = all;
    if (theme.forceKind != null) {
      final kind = theme.forceKind!;
      items = items.where((e) => e.variants.any((v) => v.kind == kind));
    }

    final idSet = topic.itemIds.toSet();
    return _backfillVideoDurations(
      items.where((e) => idSet.contains(keyForItem(e))).toList(),
    );
  }

  Future<List<MediaItem>> loadPlaylistItems({
    required SourceTheme theme,
    required SourceThemeTopicPlaylist playlist,
    List<SourceOrigin>? origins,
  }) async {
    final all = await _repo.getLibrary();

    Iterable<MediaItem> items = all;
    if (theme.forceKind != null) {
      final kind = theme.forceKind!;
      items = items.where((e) => e.variants.any((v) => v.kind == kind));
    }

    final idSet = playlist.itemIds.toSet();
    return _backfillVideoDurations(
      items.where((e) => idSet.contains(keyForItem(e))).toList(),
    );
  }

  Future<List<MediaItem>> loadCandidateItems({
    required SourceTheme theme,
    List<SourceOrigin>? origins,
  }) async {
    final all = await _repo.getLibrary();
    Iterable<MediaItem> items = all;
    if (theme.forceKind != null) {
      final kind = theme.forceKind!;
      items = items.where((e) => e.variants.any((v) => v.kind == kind));
    }

    final list = await _backfillVideoDurations(items.toList());
    list.sort(
      (a, b) =>
          (b.variants.first.createdAt).compareTo(a.variants.first.createdAt),
    );
    return list;
  }

  Future<List<MediaItem>> _backfillVideoDurations(List<MediaItem> input) async {
    final output = <MediaItem>[];
    for (final item in input) {
      if (!item.hasVideoLocal || (item.effectiveDurationSeconds ?? 0) > 0) {
        output.add(item);
        continue;
      }

      final video = item.localVideoVariant;
      final path = video?.playablePath?.trim();
      if (video == null || path == null || path.isEmpty) {
        output.add(item);
        continue;
      }

      final metadata = await _metadata.readMediaMetadata(path);
      final seconds = metadata?.durationSeconds;
      if (seconds == null || seconds <= 0) {
        output.add(item);
        continue;
      }

      final variants = item.variants
          .map((variant) {
            if (!variant.sameIdentityAs(video)) return variant;
            return MediaVariant(
              kind: variant.kind,
              format: variant.format,
              fileName: variant.fileName,
              localPath: variant.localPath,
              createdAt: variant.createdAt,
              size: variant.size,
              durationSeconds: seconds,
              role: variant.role,
            );
          })
          .toList(growable: false);

      final updated = item.copyWith(
        variants: variants,
        durationSeconds: item.durationSeconds ?? seconds,
      );
      await _store.upsert(updated);
      output.add(updated);
    }
    return output;
  }

  // ============================
  // 📥 IMPORTS DESDE DISPOSITIVO
  // ============================
  Future<void> pickLocalFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'mp3',
        'm4a',
        'wav',
        'flac',
        'aac',
        'ogg',
        'mp4',
        'mov',
        'mkv',
        'webm',
      ],
    );

    if (res == null) return;

    final picked = res.files.where((f) => f.path != null).toList();

    for (final pf in picked) {
      final filePath = pf.path!;
      final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();

      final isVideo = const ['mp4', 'mkv', 'mov', 'webm'].contains(ext);
      final kind = isVideo ? MediaVariantKind.video : MediaVariantKind.audio;

      final id = await _buildStableId(filePath);

      final variant = MediaVariant(
        kind: kind,
        format: ext,
        fileName: p.basename(filePath), // ✅ SOLO nombre
        localPath: filePath, // ✅ path real (picker)
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final item = MediaItem(
        id: id,
        publicId: id,
        title: pf.name,
        subtitle: '',
        source: MediaSource.local,
        origin: SourceOrigin.device, // ✅ clave
        thumbnail: null,
        variants: [variant],
        durationSeconds: null,
      );

      if (localFiles.any((e) => e.id == item.id)) continue;
      localFiles.add(item);
    }
  }

  /// ✅ Importa (copia) a storage interno y lo guarda en LocalLibraryStore
  Future<MediaItem?> importToAppStorage(MediaItem item) async {
    try {
      importing.value = true;

      final v = item.variants.first;

      final sourcePath = v.localPath ?? v.fileName; // fallback
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        throw Exception('File not found: $sourcePath');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(appDir.path, 'media'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final ext = v.format.toLowerCase();
      final destPath = p.join(mediaDir.path, '${item.id}.$ext');
      final destFile = File(destPath);

      if (!await destFile.exists()) {
        await sourceFile.copy(destPath);
      }

      final importedVariant = MediaVariant(
        kind: v.kind,
        format: v.format,
        fileName: p.basename(destPath), // ✅ nombre
        localPath: destPath, // ✅ path interno
        createdAt: v.createdAt,
        size: await destFile.length(),
        durationSeconds: v.durationSeconds,
      );

      final importedItem = MediaItem(
        id: item.id,
        publicId: item.publicId,
        title: item.title,
        subtitle: item.subtitle,
        source: MediaSource.local,
        origin: item.origin, // ✅ NO CAMBIAR (queda device)
        thumbnail: item.thumbnail,
        variants: [importedVariant],
        durationSeconds: item.durationSeconds,
      );

      // ✅ AQUÍ ESTÁ LA CLAVE: persistir en la librería local
      await _store.upsert(importedItem);

      return importedItem;
    } catch (e) {
      print('Import failed: $e');
      return null;
    } finally {
      importing.value = false;
    }
  }

  void clearLocal() => localFiles.clear();

  // ============================
  // ⬇️ DESCARGAS (BACKEND)
  // ============================
  Future<bool> requestAndFetchMedia({
    required String mediaId,
    String? url,
    required String kind,
    required String format,
    String? quality,
    void Function(int received, int total)? onProgress,
  }) async {
    return _repo.requestAndFetchMedia(
      mediaId: mediaId,
      url: url,
      kind: kind,
      format: format,
      quality: quality,
      onProgress: onProgress,
    );
  }

  // ============================
  // 🧹 CACHE / ALMACENAMIENTO
  // ============================
  /// 🗑️ Limpia el caché de descargas y archivos temporales
  Future<void> clearCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(appDir.path, 'media'));

      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
        await mediaDir.create(recursive: true);
      }

      print('✅ Caché limpiado correctamente');
    } catch (e) {
      print('❌ Error al limpiar caché: $e');
    }
  }

  /// 📊 Obtiene el tamaño total del almacenamiento usado
  Future<String> getStorageUsage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(appDir.path, 'media'));

      if (!await mediaDir.exists()) return '0 MB';

      int totalSize = 0;
      final files = mediaDir.listSync(recursive: true);

      for (var file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      final mb = totalSize / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB';
    } catch (e) {
      print('Error getting storage usage: $e');
      return '0 MB';
    }
  }

  // ============================
  // 🧰 HELPERS INTERNOS
  // ============================

  Future<String> _buildStableId(String filePath) async {
    try {
      final f = File(filePath);
      final stat = await f.stat();

      final payload = [
        filePath,
        stat.size.toString(),
        stat.modified.millisecondsSinceEpoch.toString(),
      ].join('|');

      return _sha1(payload);
    } catch (_) {
      return _sha1(filePath);
    }
  }

  String _sha1(String input) {
    final bytes = utf8.encode(input);
    return sha1.convert(bytes).toString();
  }

  @override
  void onInit() {
    super.onInit();
    _loadPills();
    _loadTopics();
    _loadTopicPlaylists();
  }

  // ============================
  // 🔄 REFRESCO GENERAL
  // ============================
  Future<void> refreshAll() async {
    await Future.wait([_loadPills(), _loadTopics(), _loadTopicPlaylists()]);
  }

  // ============================
  // 🎛️ CATÁLOGO DE TEMATICAS
  // ============================
  List<SourceTheme> get themes => [
    SourceTheme(
      id: 'movies',
      title: 'Películas y series',
      subtitle: 'Descargas y catálogos de video',
      icon: Icons.local_movies_rounded,
      colors: const [Color(0xFF2C2F7A), Color(0xFF5D6BE0)],
      defaultOrigins: [
        SourceOrigin.youtube,
        SourceOrigin.vimeo,
        SourceOrigin.mega,
        SourceOrigin.vk,
      ],
      forceKind: MediaVariantKind.video,
    ),
    SourceTheme(
      id: 'tutorials',
      title: 'Tutoriales',
      subtitle: 'Guías, cursos y prácticas',
      icon: Icons.handyman_rounded,
      colors: const [Color(0xFF1E4D6B), Color(0xFF3E8BC9)],
      defaultOrigins: [
        SourceOrigin.youtube,
        SourceOrigin.vimeo,
        SourceOrigin.reddit,
      ],
      forceKind: MediaVariantKind.video,
    ),
    SourceTheme(
      id: 'podcasts',
      title: 'Podcasts y vlogs',
      subtitle: 'Charlas y contenido hablado',
      icon: Icons.mic_rounded,
      colors: const [Color(0xFF5B2C2C), Color(0xFFD36A6A)],
      defaultOrigins: [
        SourceOrigin.youtube,
        SourceOrigin.instagram,
        SourceOrigin.facebook,
        SourceOrigin.telegram,
      ],
      forceKind: MediaVariantKind.video,
    ),
    SourceTheme(
      id: 'social',
      title: 'Redes sociales',
      subtitle: 'Contenido social y trending',
      icon: Icons.people_alt_rounded,
      colors: const [Color(0xFF3A2F57), Color(0xFF8C6FD9)],
      defaultOrigins: [
        SourceOrigin.instagram,
        SourceOrigin.facebook,
        SourceOrigin.x,
        SourceOrigin.reddit,
        SourceOrigin.threads,
        SourceOrigin.snapchat,
        SourceOrigin.telegram,
        SourceOrigin.pinterest,
        SourceOrigin.vk,
        SourceOrigin.amino,
      ],
      forceKind: MediaVariantKind.video,
    ),
    SourceTheme(
      id: 'education',
      title: 'Contenido educativo',
      subtitle: 'Clases y material formativo',
      icon: Icons.school_rounded,
      colors: const [Color(0xFF1F4A3D), Color(0xFF4FB286)],
      defaultOrigins: [
        SourceOrigin.youtube,
        SourceOrigin.vimeo,
        SourceOrigin.blogger,
      ],
      forceKind: MediaVariantKind.video,
    ),
    SourceTheme(
      id: 'files',
      title: 'Archivos personales',
      subtitle: 'Imports desde tu dispositivo',
      icon: Icons.folder_rounded,
      colors: const [Color(0xFF3F2A1A), Color(0xFFB07A4E)],
      defaultOrigins: [SourceOrigin.device],
      forceKind: MediaVariantKind.video,
    ),
  ];

  // ============================
  // 🧩 CONSULTAS RAPIDAS
  // ============================
  List<SourceThemePill> pillsForTheme(String themeId) {
    return pills.where((p) => p.themeId == themeId).toList();
  }

  List<SourceThemeTopic> topicsForTheme(String themeId) {
    return topics.where((t) => t.themeId == themeId).toList();
  }

  List<SourceThemeTopicPlaylist> playlistsForTopic(
    String topicId, {
    String? parentId,
  }) {
    return topicPlaylists
        .where((p) => p.topicId == topicId && p.parentId == parentId)
        .toList();
  }

  // ============================
  // 🗂️ TEMATICAS (TOPICS)
  // ============================
  Future<void> addTopic({
    required String themeId,
    required String title,
    String? coverUrl,
    String? coverLocalPath,
    int? colorValue,
  }) async {
    if (topicsForTheme(themeId).length >= 10) return;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'stt_${themeId}_$now';
    final topic = SourceThemeTopic(
      id: id,
      themeId: themeId,
      title: trimmed,
      createdAt: now,
      itemIds: const [],
      playlistIds: const [],
      coverUrl: coverUrl?.trim().isEmpty == true ? null : coverUrl,
      coverLocalPath: coverLocalPath?.trim().isEmpty == true
          ? null
          : coverLocalPath,
      colorValue: colorValue,
    );
    await _topicStore.upsert(topic);
    await _loadTopics();
  }

  Future<void> deleteTopic(SourceThemeTopic topic) async {
    await _topicStore.remove(topic.id);
    await _loadTopics();
  }

  Future<void> updateTopic(SourceThemeTopic topic) async {
    await _topicStore.upsert(topic);
    await _loadTopics();
  }

  // ============================
  // 📚 LISTAS (PLAYLISTS)
  // ============================
  Future<bool> addTopicPlaylist({
    required String topicId,
    required String name,
    required List<MediaItem> items,
    String? parentId,
    int depth = 1,
    String? coverUrl,
    String? coverLocalPath,
    int? colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (depth > 10) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'stpl_${topicId}_$now';
    final itemIds = items.map(keyForItem).toList();
    final playlist = SourceThemeTopicPlaylist(
      id: id,
      topicId: topicId,
      name: trimmed,
      itemIds: itemIds,
      createdAt: now,
      parentId: parentId,
      depth: depth,
      coverUrl: coverUrl?.trim().isEmpty == true ? null : coverUrl,
      coverLocalPath: coverLocalPath?.trim().isEmpty == true
          ? null
          : coverLocalPath,
      colorValue: colorValue,
    );
    await _topicPlaylistStore.upsert(playlist);
    await _loadTopicPlaylists();
    return true;
  }

  Future<void> deleteTopicPlaylist(SourceThemeTopicPlaylist playlist) async {
    await _topicPlaylistStore.remove(playlist.id);
    await _loadTopicPlaylists();
  }

  Future<void> updateTopicPlaylist(SourceThemeTopicPlaylist playlist) async {
    await _topicPlaylistStore.upsert(playlist);
    await _loadTopicPlaylists();
  }

  Future<void> addItemsToTopic(
    SourceThemeTopic topic,
    List<MediaItem> items,
  ) async {
    if (items.isEmpty) return;
    final ids = topic.itemIds.toSet();
    for (final item in items) {
      ids.add(keyForItem(item));
    }
    final updated = topic.copyWith(itemIds: ids.toList());
    await _topicStore.upsert(updated);
    await _loadTopics();
  }

  Future<void> removeItemFromTopic(
    SourceThemeTopic topic,
    MediaItem item,
  ) async {
    final key = keyForItem(item);
    final updated = topic.copyWith(
      itemIds: topic.itemIds.where((e) => e != key).toList(),
    );
    await _topicStore.upsert(updated);
    await _loadTopics();
  }

  Future<void> addPlaylistsToTopic(
    SourceThemeTopic topic,
    List<String> playlistIds,
  ) async {
    if (playlistIds.isEmpty) return;
    final ids = topic.playlistIds.toSet()..addAll(playlistIds);
    final updated = topic.copyWith(playlistIds: ids.toList());
    await _topicStore.upsert(updated);
    await _loadTopics();
  }

  Future<void> removePlaylistFromTopic(
    SourceThemeTopic topic,
    String playlistId,
  ) async {
    final updated = topic.copyWith(
      playlistIds: topic.playlistIds.where((e) => e != playlistId).toList(),
    );
    await _topicStore.upsert(updated);
    await _loadTopics();
  }

  // ============================
  // 🧷 PILLS (FILTROS RAPIDOS)
  // ============================
  Future<void> addPill({
    required String themeId,
    required String title,
    required List<SourceOrigin> origins,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'stp_${themeId}_$now';
    final pill = SourceThemePill(
      id: id,
      themeId: themeId,
      title: trimmed,
      origins: origins,
      createdAt: now,
    );
    await _pillStore.upsert(pill);
    await _loadPills();
  }

  Future<void> deletePill(SourceThemePill pill) async {
    await _pillStore.remove(pill.id);
    await _loadPills();
  }

  // ============================
  // 🔄 CARGA DE STORES
  // ============================
  Future<void> _loadPills() async {
    final list = await _pillStore.readAll();
    pills.assignAll(list);
  }

  Future<void> _loadTopics() async {
    final list = await _topicStore.readAll();
    topics.assignAll(list);
  }

  Future<void> _loadTopicPlaylists() async {
    final list = await _topicPlaylistStore.readAll();
    topicPlaylists.assignAll(list);
  }
}

// ============================
// 🎧 HELPERS DE REPRODUCCION
// ============================
extension SourcesControllerPlayable on SourcesController {
  /// Devuelve un URL reproducible.
  /// - Local: file:///...
  /// - Remoto: si fileName ya es URL, lo devuelve tal cual (fallback)
  String resolvePlayableUrl(MediaItem item) {
    if (item.variants.isEmpty) return '';

    final v = item.variants.first;

    final lp = (v.localPath ?? '').trim();
    if (lp.isNotEmpty) {
      return Uri.file(lp).toString(); // ✅ LINK CORRECTO
    }

    // Fallback: si en otros casos fileName trae un URL remoto completo.
    return (v.fileName).trim();
  }
}

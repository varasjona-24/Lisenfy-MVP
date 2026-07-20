import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/media_item.dart';
import '../local/local_library_store.dart';
import '../network/backend_api_error.dart';
import '../network/dio_client.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/Modules/sources/domain/detect_source_origin.dart';

class ImportedPlaylistResult {
  const ImportedPlaylistResult({
    required this.playlistId,
    required this.name,
    required this.itemIds,
    required this.total,
    required this.imported,
    required this.failed,
    this.coverUrl,
  });

  final String playlistId;
  final String name;
  final List<String> itemIds;
  final int total;
  final int imported;
  final int failed;
  final String? coverUrl;
}

class PlaylistPreviewEntry {
  const PlaylistPreviewEntry({
    required this.url,
    required this.title,
    required this.index,
    required this.isAvailable,
    this.artist,
    this.durationMs,
    this.thumbnail,
    this.availabilityReason,
  });

  final String url;
  final String title;
  final int index;
  final String? artist;
  final int? durationMs;
  final String? thumbnail;
  final bool isAvailable;
  final String? availabilityReason;

  factory PlaylistPreviewEntry.fromMap(Map<String, dynamic> map) {
    final durationMs = (map['durationMs'] as num?)?.toInt();
    final duration = map['duration'];
    final resolvedDurationMs =
        durationMs ??
        (duration is num
            ? (duration > 10000 ? duration.round() : (duration * 1000).round())
            : null);
    return PlaylistPreviewEntry(
      url: (map['url'] as String?)?.trim() ?? '',
      title: (map['title'] as String?)?.trim() ?? '',
      artist: (map['artist'] as String?)?.trim(),
      durationMs: resolvedDurationMs,
      thumbnail: (map['thumbnail'] as String?)?.trim(),
      index: (map['index'] as num?)?.toInt() ?? 0,
      isAvailable: map['isAvailable'] != false,
      availabilityReason: (map['availabilityReason'] as String?)?.trim(),
    );
  }
}

class PlaylistPreview {
  const PlaylistPreview({
    required this.name,
    required this.total,
    required this.entries,
    this.thumbnail,
  });

  final String name;
  final int total;
  final List<PlaylistPreviewEntry> entries;
  final String? thumbnail;

  factory PlaylistPreview.fromMap(Map<String, dynamic> map) {
    final rawEntries = (map['entries'] as List?) ?? const [];
    final entries = rawEntries
        .whereType<Map>()
        .map(
          (raw) => PlaylistPreviewEntry.fromMap(Map<String, dynamic>.from(raw)),
        )
        .where((entry) => entry.url.isNotEmpty)
        .toList(growable: false);
    return PlaylistPreview(
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Playlist',
      total: (map['total'] as num?)?.toInt() ?? entries.length,
      thumbnail: (map['thumbnail'] as String?)?.trim(),
      entries: entries,
    );
  }
}

class MediaRepository {
  // ============================
  // 🔌 DEPENDENCIAS
  // ============================
  final DioClient _client = Get.find<DioClient>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();

  // ============================
  // 📚 LIBRERÍA (LOCAL-FIRST)
  // ============================
  Future<List<MediaItem>> getLibrary({
    String? query,
    String? order,
    String? source,
  }) async {
    // 1) siempre algo local
    final localItems = await _store.readAll();
    final normalizedItems = <MediaItem>[];
    final itemsToUpdate = <MediaItem>[];

    for (final item in localItems) {
      if (item.origin == SourceOrigin.generic) {
        final inferred = _inferOriginFromItem(item);
        if (inferred != SourceOrigin.generic) {
          final updated = item.copyWith(origin: inferred);
          normalizedItems.add(updated);
          itemsToUpdate.add(updated);
          continue;
        }
      }
      normalizedItems.add(item);
    }

    if (itemsToUpdate.isNotEmpty) {
      for (final item in itemsToUpdate) {
        await _store.upsert(item);
      }
    }

    // 2) filtros opcionales
    Iterable<MediaItem> result = normalizedItems;

    if (source != null && source.trim().isNotEmpty) {
      final s = source.toLowerCase().trim();
      result = result.where(
        (e) =>
            (s == 'local' && e.source == MediaSource.local) ||
            (s == 'youtube' && e.source == MediaSource.youtube),
      );
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      result = result.where(
        (e) =>
            e.title.toLowerCase().contains(q) ||
            e.subtitle.toLowerCase().contains(q),
      );
    }

    // 3) orden (si luego lo usas)
    // TODO: aplicar "order" si lo necesitas (por fecha, título, etc.)

    return result.toList();
  }

  // ============================
  // ⬇️ DESCARGA DESDE BACKEND + GUARDADO LOCAL
  // ============================
  /// Flujo:
  /// 1) POST /media/download (backend prepara)
  /// 2) GET  /media/file/:id/:kind/:format (app baja a disco)
  /// 3) (B) GET portada (thumbnail) y guardarla offline
  /// 4) Upsert en librería local con variant.localPath
  Future<bool> requestAndFetchMedia({
    String? mediaId,
    String? url,
    required String kind, // 'audio' | 'video'
    required String format, // 'mp3' | 'm4a' | 'mp4'...
    String? quality, // 'low' | 'medium' | 'high'
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      // ----------------------------
      // ✅ VALIDACIÓN INPUT
      // ----------------------------
      if ((mediaId == null || mediaId.trim().isEmpty) &&
          (url == null || url.trim().isEmpty)) {
        print('Download error: mediaId or url is required');
        return false;
      }

      final normalizedKind = kind.toLowerCase().trim();
      final normalizedFormat = format.toLowerCase().trim();

      // ----------------------------
      // 1) PEDIR AL BACKEND QUE PREPARE LA VARIANTE
      // ----------------------------
      final resolvedId = await _requestBackendDownload(
        mediaId: mediaId,
        url: url,
        kind: normalizedKind,
        format: normalizedFormat,
        quality: quality,
      );

      if (resolvedId.isEmpty) return false;

      // ----------------------------
      // 2) DESCARGAR ARCHIVO A DISCO (SIN CARGARLO EN RAM)
      // ----------------------------
      final destPath = await _buildDestPath(
        resolvedId: resolvedId,
        kind: normalizedKind,
        format: normalizedFormat,
      );

      final ok = await _downloadWithRetry(
        path: '/media/file/$resolvedId/$normalizedKind/$normalizedFormat',
        savePath: destPath,
        onProgress: onProgress,
      );

      if (!ok) return false;

      // asegurar que existe y no está vacío
      final f = File(destPath);
      if (!await f.exists()) {
        print('Download error: file not found at $destPath');
        return false;
      }
      final fileSize = await f.length();
      if (fileSize <= 0) {
        print('Download error: file is empty at $destPath');
        return false;
      }

      // ----------------------------
      // 3) CREAR VARIANT LOCAL
      // ----------------------------
      final variant = MediaVariant(
        kind: normalizedKind == 'video'
            ? MediaVariantKind.video
            : MediaVariantKind.audio,
        format: normalizedFormat,
        fileName: p.basename(destPath),
        localPath: destPath,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        size: fileSize,
      );

      // ----------------------------
      // 4) (B) RESOLVER METADATA + PORTADA OFFLINE (SI HAY URL)
      // ----------------------------
      MediaItem? resolved;
      String? thumbnailLocalPath;

      final u = url?.trim();
      if (u != null && u.isNotEmpty) {
        resolved = await _fetchResolvedInfo(u);

        final thumb = resolved?.thumbnail?.trim();
        if (thumb != null && thumb.isNotEmpty) {
          thumbnailLocalPath = await _downloadThumbnailToDisk(
            resolvedId: resolvedId,
            thumbnailUrl: thumb,
          );
        }
      }

      // ----------------------------
      // 5) UPSERT EN LIBRERÍA LOCAL (EVITAR DUPLICADOS)
      // ----------------------------
      final source = _detectSource(url);
      await _upsertItemWithVariant(
        resolvedId: resolvedId,
        url: url,
        source: source,
        variant: variant,
        resolved: resolved,
        thumbnailLocalPath: thumbnailLocalPath,
      );

      return true;
    } on BackendApiException {
      rethrow;
    } catch (e) {
      print('Download failed: $e');
      return false;
    }
  }

  Future<ImportedPlaylistResult?> importPlaylistFromUrl({
    required String url,
    required String kind,
    required String format,
    String? quality,
    int maxItems = 50,
    List<String>? selectedUrls,
    void Function(int current, int total, String title)? onItemProgress,
    void Function(int received, int total)? onFileProgress,
  }) async {
    try {
      final normalizedUrl = url.trim();
      if (normalizedUrl.isEmpty) return null;

      final normalizedKind = kind.toLowerCase().trim();
      final normalizedFormat = format.toLowerCase().trim();
      final resp = await _client.post(
        '/media/playlist/import',
        data: {
          'url': normalizedUrl,
          'kind': normalizedKind,
          'format': normalizedFormat,
          if (quality != null && quality.trim().isNotEmpty)
            'quality': quality.trim(),
          'maxItems': maxItems,
          if (selectedUrls != null && selectedUrls.isNotEmpty)
            'selectedUrls': selectedUrls,
        },
        options: dio.Options(
          receiveTimeout: const Duration(minutes: 45),
          sendTimeout: const Duration(minutes: 2),
        ),
      );

      final data = resp.data;
      if (data is! Map) return null;

      final playlistRaw = data['playlist'];
      final playlist = playlistRaw is Map
          ? Map<String, dynamic>.from(playlistRaw)
          : <String, dynamic>{};
      final playlistId = (playlist['id'] as String?)?.trim() ?? '';
      final name =
          (data['name'] as String?)?.trim() ??
          (playlist['name'] as String?)?.trim() ??
          'Playlist';
      final coverUrl = (data['thumbnail'] as String?)?.trim();
      final itemsRaw = (data['items'] as List?) ?? const [];
      final total = (data['total'] as num?)?.toInt() ?? itemsRaw.length;
      final failed = (data['failed'] as num?)?.toInt() ?? 0;
      final itemIds = <String>[];

      for (var i = 0; i < itemsRaw.length; i++) {
        final raw = itemsRaw[i];
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final mediaId = (item['mediaId'] as String?)?.trim() ?? '';
        if (mediaId.isEmpty) continue;

        final title = (item['title'] as String?)?.trim() ?? mediaId;
        onItemProgress?.call(i + 1, itemsRaw.length, title);

        final destPath = await _buildDestPath(
          resolvedId: mediaId,
          kind: normalizedKind,
          format: normalizedFormat,
        );
        final ok = await _downloadWithRetry(
          path: '/media/file/$mediaId/$normalizedKind/$normalizedFormat',
          savePath: destPath,
          onProgress: onFileProgress,
        );
        if (!ok) continue;

        final file = File(destPath);
        if (!await file.exists()) continue;
        final fileSize = await file.length();
        if (fileSize <= 0) continue;

        final thumbnail = (item['thumbnail'] as String?)?.trim();
        final thumbnailLocalPath = thumbnail != null && thumbnail.isNotEmpty
            ? await _downloadThumbnailToDisk(
                resolvedId: mediaId,
                thumbnailUrl: thumbnail,
              )
            : null;

        final variant = MediaVariant(
          kind: normalizedKind == 'video'
              ? MediaVariantKind.video
              : MediaVariantKind.audio,
          format: normalizedFormat,
          fileName: p.basename(destPath),
          localPath: destPath,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          size: fileSize,
        );

        final resolved = MediaItem(
          id: mediaId,
          publicId: mediaId,
          title: title,
          subtitle: (item['artist'] as String?)?.trim() ?? '',
          source: MediaSource.youtube,
          origin: SourceOrigin.youtube,
          thumbnail: thumbnail,
          thumbnailLocalPath: null,
          durationSeconds: MediaItem.normalizeDurationSeconds(item['duration']),
          variants: const [],
        );

        final saved = await _upsertItemWithVariant(
          resolvedId: mediaId,
          url: (item['url'] as String?)?.trim(),
          source: MediaSource.youtube,
          variant: variant,
          resolved: resolved,
          thumbnailLocalPath: thumbnailLocalPath,
        );
        itemIds.add(
          saved.publicId.trim().isNotEmpty ? saved.publicId : saved.id,
        );
      }

      return ImportedPlaylistResult(
        playlistId: playlistId.isNotEmpty
            ? playlistId
            : 'pl_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        itemIds: itemIds,
        total: total,
        imported: itemIds.length,
        failed: failed + (itemsRaw.length - itemIds.length),
        coverUrl: coverUrl?.isEmpty == true ? null : coverUrl,
      );
    } on BackendApiException {
      rethrow;
    } catch (e) {
      if (e is dio.DioException) {
        throw BackendApiException.fromDio(
          e,
          fallbackMessage: tr('imports.playlist_failed'),
        );
      }
      return null;
    }
  }

  Future<PlaylistPreview?> resolvePlaylistFromUrl({
    required String url,
    int maxItems = 100,
  }) async {
    try {
      final normalizedUrl = url.trim();
      if (normalizedUrl.isEmpty) return null;

      final resp = await _client.get(
        '/media/playlist/resolve',
        queryParameters: {'url': normalizedUrl, 'maxItems': maxItems},
        options: dio.Options(
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      final data = resp.data;
      if (data is! Map) return null;
      return PlaylistPreview.fromMap(Map<String, dynamic>.from(data));
    } on BackendApiException {
      rethrow;
    } catch (e) {
      if (e is dio.DioException) {
        throw BackendApiException.fromDio(
          e,
          fallbackMessage: tr('imports.playlist_failed'),
        );
      }
      return null;
    }
  }

  // ============================
  // 🧩 HELPERS (BACKEND)
  // ============================
  Future<String> _requestBackendDownload({
    required String? mediaId,
    required String? url,
    required String kind,
    required String format,
    String? quality,
  }) async {
    try {
      final resp = await _client.post(
        '/media/download',
        data: {
          if (mediaId != null && mediaId.trim().isNotEmpty)
            'mediaId': mediaId.trim(),
          if (url != null && url.trim().isNotEmpty) 'url': url.trim(),
          'kind': kind,
          'format': format,
          if (quality != null && quality.trim().isNotEmpty)
            'quality': quality.trim(),
        },
        options: dio.Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 2),
        ),
      );

      // resolvedId = prefer backend response, then client mediaId, then fallback
      String resolvedId = '';

      final data = resp.data;
      if (data is Map) {
        final v = data['mediaId'];
        if (v is String && v.trim().isNotEmpty) {
          resolvedId = v.trim();
        }
      }

      if (resolvedId.isEmpty) {
        resolvedId = (mediaId ?? '').trim();
      }

      if (resolvedId.isEmpty) {
        // fallback si el backend no devolvió nada útil
        resolvedId = 'dl-${DateTime.now().millisecondsSinceEpoch}';
      }

      return resolvedId;
    } catch (e) {
      if (e is dio.DioException) {
        print('DIO ERROR: ${e.type}');
        print('URL: ${e.requestOptions.uri}');
        print('STATUS: ${e.response?.statusCode}');
        print('DATA: ${e.response?.data}');
        final msg = e.response?.data is Map
            ? (e.response?.data['error']?.toString() ?? '')
            : (e.response?.data?.toString() ?? '');
        _maybeNotifyCookiesIssue(msg);
        _maybeNotifyDrmIssue(msg);
      } else {
        print('Error: $e');
      }
      if (e is dio.DioException) {
        throw BackendApiException.fromDio(
          e,
          fallbackMessage: 'No se pudo preparar la descarga.',
        );
      }
      return '';
    }
  }

  void _maybeNotifyCookiesIssue(String message) {
    final m = message.toLowerCase();
    if (!m.contains('cookie') &&
        !m.contains('not a bot') &&
        !m.contains('sign in')) {
      return;
    }

    Get.snackbar(
      'YouTube',
      'Cookies expiradas. Actualiza en Ajustes > Datos y descargas.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _maybeNotifyDrmIssue(String message) {
    final m = message.toLowerCase();
    if (!m.contains('drm')) return;

    Get.snackbar(
      'Contenido protegido',
      'Este contenido usa DRM y no se puede descargar.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<MediaItem?> _fetchResolvedInfo(String url) async {
    try {
      final resp = await _client.get(
        '/media/resolve-info',
        queryParameters: {'url': url},
      );

      final data = resp.data;

      // Caso común: el endpoint devuelve directo el objeto
      if (data is Map) {
        return MediaItem.fromJson(Map<String, dynamic>.from(data));
      }

      return null;
    } catch (e) {
      print('resolve-info failed: $e');
      return null;
    }
  }

  // ============================
  // 🧩 HELPERS (DESCARGA A DISCO)
  // ============================
  Future<String> _buildDestPath({
    required String resolvedId,
    required String kind,
    required String format,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(p.join(appDir.path, 'downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    // Si quieres nombres distintos por kind:
    // final fileName = '$resolvedId-$kind.$format';
    final fileName = '$resolvedId.$format';
    return p.join(downloadsDir.path, fileName);
  }

  Future<bool> _downloadWithRetry({
    required String path,
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    int attempts = 0;
    const maxAttempts = 4;
    const initialDelay = Duration(seconds: 1);

    while (true) {
      try {
        // Requiere que tengas _client.download(...) en DioClient
        await _client.download(path, savePath, onProgress: onProgress);
        return true;
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) {
          if (e is dio.DioException) {
            print('Download failed after $maxAttempts attempts: ${e.type}');
            print('URL: ${e.requestOptions.uri}');
            print('STATUS: ${e.response?.statusCode}');
            print('DATA: ${e.response?.data}');
          } else {
            print('Download failed after $maxAttempts attempts: $e');
          }
          if (e is dio.DioException) {
            throw BackendApiException.fromDio(
              e,
              fallbackMessage: 'No se pudo descargar el archivo remoto.',
            );
          }
          return false;
        }

        // backoff: 1s, 2s, 4s, 8s
        final delay = initialDelay * (1 << (attempts - 1));
        print(
          'Download attempt $attempts failed, retrying in ${delay.inSeconds}s',
        );
        await Future.delayed(delay);
      }
    }
  }

  // ============================
  // 🧩 HELPERS (THUMBNAIL EXTERNO)
  // ============================
  Future<String?> cacheThumbnailForItem({
    required String itemId,
    required String thumbnailUrl,
  }) {
    return _downloadThumbnailToDisk(
      resolvedId: itemId,
      thumbnailUrl: thumbnailUrl,
    );
  }

  // ============================
  // 🧩 HELPERS (THUMBNAIL OFFLINE)
  // ============================
  Future<String?> _downloadThumbnailToDisk({
    required String resolvedId,
    required String thumbnailUrl,
  }) async {
    try {
      final u = thumbnailUrl.trim();
      if (u.isEmpty) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'downloads', 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      // ✅ bajar bytes con headers (Google Images suele exigirlos)
      final resp = await _client.dio.get<List<int>>(
        u,
        options: dio.Options(
          responseType: dio.ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
            'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
          },
        ),
      );

      final bytesList = resp.data;
      if (bytesList == null || bytesList.isEmpty) return null;

      final bytes = Uint8List.fromList(bytesList);

      // ✅ Detectar extensión REAL por magic-bytes
      final ext = _detectImageExt(bytes);
      if (ext == null) {
        // No parece imagen (HTML/JSON/etc)
        return null;
      }

      final coverPath = p.join(coversDir.path, '$resolvedId.$ext');

      final f = File(coverPath);
      await f.writeAsBytes(bytes, flush: true);

      return coverPath;
    } catch (e) {
      if (_isExpectedThumbnailConnectionMiss(e)) {
        return null;
      }
      print('thumbnail download failed: $e');
      return null;
    }
  }

  bool _isExpectedThumbnailConnectionMiss(Object error) {
    if (error is! dio.DioException) return false;
    if (error.type != dio.DioExceptionType.connectionError) return false;
    final uri = error.requestOptions.uri;
    final host = uri.host.toLowerCase();
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host.startsWith('172.') ||
        host.startsWith('192.168.') ||
        host.startsWith('10.');
  }

  /// Retorna extensión real según magic bytes (sin punto)
  String? _detectImageExt(Uint8List b) {
    if (b.length < 12) return null;

    // JPEG: FF D8 FF
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'jpg';

    // PNG: 89 50 4E 47
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return 'png';
    }

    // WEBP: "RIFF....WEBP"
    final riff = String.fromCharCodes(b.sublist(0, 4));
    final webp = String.fromCharCodes(b.sublist(8, 12));
    if (riff == 'RIFF' && webp == 'WEBP') return 'webp';

    // GIF: "GIF8"
    final gif = String.fromCharCodes(b.sublist(0, 4));
    if (gif == 'GIF8') return 'gif';

    // AVIF: "....ftypavif" o "....ftypavis"
    // (ISO BMFF) revisa caja ftyp
    final ftyp = String.fromCharCodes(b.sublist(4, 8));
    if (ftyp == 'ftyp') {
      final brand = String.fromCharCodes(b.sublist(8, 12));
      if (brand == 'avif' || brand == 'avis') return 'avif';
    }

    return null;
  }

  // ============================
  // 🧩 HELPERS (LIBRERÍA / UPSERT)
  // ============================
  MediaSource _detectSource(String? url) {
    if (url == null || url.trim().isEmpty) return MediaSource.local;

    final u = url.toLowerCase();
    if (u.contains('youtube') || u.contains('youtu.be')) {
      return MediaSource.youtube;
    }

    return MediaSource.local;
  }

  SourceOrigin _detectOrigin(String? url) {
    if (url == null || url.trim().isEmpty) return SourceOrigin.generic;
    return detectSourceOriginFromUrl(url);
  }

  SourceOrigin _inferOriginFromItem(MediaItem item) {
    final candidates = <String?>[item.thumbnail, item.subtitle];
    for (final candidate in candidates) {
      final s = candidate?.trim() ?? '';
      if (s.isEmpty || !_looksLikeUrl(s)) continue;
      final detected = detectSourceOriginFromUrl(s);
      if (detected != SourceOrigin.generic) return detected;
    }
    return SourceOrigin.generic;
  }

  bool _looksLikeUrl(String value) {
    final s = value.toLowerCase();
    return s.contains('http://') ||
        s.contains('https://') ||
        s.contains('www.') ||
        s.contains('.com') ||
        s.contains('.net') ||
        s.contains('.org');
  }

  Future<MediaItem> _upsertItemWithVariant({
    required String resolvedId,
    required String? url,
    required MediaSource source,
    required MediaVariant variant,

    MediaItem? resolved, // ✅ nuevo
    String? thumbnailLocalPath, // ✅ nuevo
  }) async {
    // Buscar si ya existe un item por publicId
    final all = await _store.readAll();
    final existingIndex = all.indexWhere(
      (e) => e.publicId.trim() == resolvedId.trim(),
    );

    if (existingIndex >= 0) {
      final existing = all[existingIndex];

      // merge variants: reemplaza si existe misma kind+format, si no añade
      final merged = [...existing.variants];
      final i = merged.indexWhere((v) => v.sameSlotAs(variant));

      if (i >= 0) {
        merged[i] = variant;
      } else {
        merged.add(variant);
      }

      // Si le falta metadata y tenemos url, intentamos resolver info (fallback)
      MediaItem? resolvedFallback;
      final u = url?.trim();
      if (resolved == null &&
          u != null &&
          u.isNotEmpty &&
          (existing.thumbnail == null ||
              existing.thumbnail!.trim().isEmpty ||
              existing.title.trim().isEmpty ||
              existing.subtitle.trim().isEmpty ||
              existing.durationSeconds == null)) {
        resolvedFallback = await _fetchResolvedInfo(u);
      }

      final r = resolved ?? resolvedFallback;

      final detectedOrigin = _detectOrigin(url);
      final resolvedOrigin =
          (r?.origin != null && r!.origin != SourceOrigin.generic)
          ? r.origin
          : detectedOrigin;
      final finalOrigin = existing.origin != SourceOrigin.generic
          ? existing.origin
          : resolvedOrigin;

      final updated = existing.copyWith(
        // NO toco title/subtitle si ya existen, solo si están vacíos
        title: (existing.title.trim().isEmpty)
            ? (r?.title ?? resolvedId)
            : existing.title,
        subtitle: (existing.subtitle.trim().isEmpty)
            ? (r?.subtitle ?? (u ?? 'Descarga'))
            : existing.subtitle,
        thumbnail:
            (existing.thumbnail == null || existing.thumbnail!.trim().isEmpty)
            ? r?.thumbnail
            : existing.thumbnail,
        thumbnailLocalPath:
            (existing.thumbnailLocalPath == null ||
                existing.thumbnailLocalPath!.trim().isEmpty)
            ? thumbnailLocalPath
            : existing.thumbnailLocalPath,
        durationSeconds: (existing.durationSeconds == null)
            ? r?.durationSeconds
            : existing.durationSeconds,
        origin: finalOrigin,
        source: existing.source, // respeta el original
        variants: merged,
        publicId: resolvedId, // asegurar consistencia
      );

      await _store.upsert(updated);
      return updated;
    }

    // Si no existe, intentar crear desde resolve-info para tener portada/título
    MediaItem? resolvedFallback;
    final u = url?.trim();
    if (resolved == null && u != null && u.isNotEmpty) {
      resolvedFallback = await _fetchResolvedInfo(u);
    }

    final detectedOrigin = _detectOrigin(url);
    final resolvedForOrigin = resolved ?? resolvedFallback;
    final resolvedOrigin =
        (resolvedForOrigin?.origin != null &&
            resolvedForOrigin!.origin != SourceOrigin.generic)
        ? resolvedForOrigin.origin
        : detectedOrigin;

    final base =
        resolved ??
        resolvedFallback ??
        MediaItem(
          id: '$resolvedId-${DateTime.now().millisecondsSinceEpoch}',
          publicId: resolvedId,
          title: resolvedId, // luego lo reemplazas por title real si lo tienes
          subtitle: u ?? 'Descarga local',
          source: source,
          origin: resolvedOrigin,
          thumbnail: null,
          thumbnailLocalPath: null,
          durationSeconds: null,
          variants: const [],
        );

    final item = base.copyWith(
      publicId: resolvedId,
      source: source,
      thumbnailLocalPath: thumbnailLocalPath ?? base.thumbnailLocalPath,
      variants: [
        ...((base.variants).where((v) => !v.sameSlotAs(variant))),
        variant,
      ],
    );

    await _store.upsert(item);
    return item;
  }
}

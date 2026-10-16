import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/media_item.dart';
import '../local/local_library_store.dart';
import '../network/dio_client.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/Modules/sources/domain/detect_source_origin.dart';

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
}

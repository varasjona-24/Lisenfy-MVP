import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:get_storage/get_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/network/dio_client.dart';
import '../models/media_item.dart';

enum KaraokeSeparationJobStatus {
  queued,
  running,
  completed,
  failed,
  canceled,
  unknown,
}

class KaraokeSeparationProgress {
  const KaraokeSeparationProgress({
    required this.status,
    required this.progress,
    required this.message,
    required this.jobId,
  });

  final KaraokeSeparationJobStatus status;
  final double progress;
  final String message;
  final String jobId;
}

class KaraokeSeparationResult {
  const KaraokeSeparationResult({
    required this.jobId,
    required this.instrumentalLocalPath,
    this.instrumentalUrl,
    this.model,
    this.completedAtMs,
  });

  final String jobId;
  final String instrumentalLocalPath;
  final String? instrumentalUrl;
  final String? model;
  final int? completedAtMs;
}

class KaraokeSeparationAgent {
  KaraokeSeparationAgent({
    required DioClient client,
    required GetStorage storage,
  }) : _client = client,
       _storage = storage;

  final DioClient _client;
  final GetStorage _storage;

  static const String _cacheKey = 'karaoke_separation_cache_v1';

  Future<KaraokeSeparationResult?> getCachedForItem(MediaItem item) async {
    final key = _itemStableKey(item);
    if (key.isEmpty) return null;

    final rawMap = _readCacheMap();
    final raw = rawMap[key];
    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw);
    final localPath = (map['instrumentalLocalPath'] as String?)?.trim() ?? '';
    if (localPath.isEmpty) return null;
    final file = File(localPath);
    if (!file.existsSync()) {
      rawMap.remove(key);
      await _writeCacheMap(rawMap);
      return null;
    }

    final expectedSourceSize = (map['sourceSize'] as num?)?.toInt();
    final currentSourceSize = await _safeFileSize(item.bestLocalPath);
    if (expectedSourceSize != null &&
        currentSourceSize != null &&
        expectedSourceSize != currentSourceSize) {
      rawMap.remove(key);
      await _writeCacheMap(rawMap);
      return null;
    }

    return KaraokeSeparationResult(
      jobId: (map['jobId'] as String?)?.trim() ?? '',
      instrumentalLocalPath: localPath,
      instrumentalUrl: (map['instrumentalUrl'] as String?)?.trim(),
      model: (map['model'] as String?)?.trim(),
      completedAtMs: (map['completedAtMs'] as num?)?.toInt(),
    );
  }

  Future<KaraokeSeparationResult> requestForItem({
    required MediaItem item,
    required String sourcePath,
    Duration timeout = const Duration(minutes: 3),
    void Function(KaraokeSeparationProgress progress)? onProgress,
  }) async {
    final stableKey = _itemStableKey(item);
    if (stableKey.isEmpty) {
      throw Exception('No se pudo construir clave estable para separación IA.');
    }

    final cached = await getCachedForItem(item);
    if (cached != null) {
      onProgress?.call(
        const KaraokeSeparationProgress(
          status: KaraokeSeparationJobStatus.completed,
          progress: 1.0,
          message: 'Instrumental IA en caché',
          jobId: '',
        ),
      );
      return cached;
    }

    final sourcePathNormalized = sourcePath.replaceFirst('file://', '').trim();
    if (sourcePathNormalized.isEmpty) {
      throw Exception('Se requiere ruta local de audio para separación IA.');
    }

    onProgress?.call(
      const KaraokeSeparationProgress(
        status: KaraokeSeparationJobStatus.queued,
        progress: 0.0,
        message: 'Encolando separación IA...',
        jobId: '',
      ),
    );

    final createResp = await _createJob(item: item);
    final jobId = createResp.jobId;
    var statusPayload = createResp.initialStatus;

    if (jobId.isEmpty && statusPayload == null) {
      throw Exception('El backend no devolvió jobId de separación.');
    }

    final startAt = DateTime.now();
    while (true) {
      if (statusPayload == null) {
        if (DateTime.now().difference(startAt) > timeout) {
          throw Exception('Tiempo de espera agotado en separación IA.');
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        statusPayload = await _fetchJobStatus(jobId);
      }

      final parsed = _parseStatus(statusPayload, fallbackJobId: jobId);
      onProgress?.call(parsed.progress);

      if (parsed.progress.status == KaraokeSeparationJobStatus.completed) {
        final instrumentalUrl = parsed.instrumentalUrl?.trim() ?? '';
        if (instrumentalUrl.isEmpty) {
          throw Exception('Job completado sin URL de instrumental.');
        }
        final downloadedPath = await _downloadInstrumental(
          stableKey: stableKey,
          sourcePath: sourcePathNormalized,
          instrumentalUrl: instrumentalUrl,
        );

        final result = KaraokeSeparationResult(
          jobId: parsed.progress.jobId,
          instrumentalLocalPath: downloadedPath,
          instrumentalUrl: instrumentalUrl,
          model: parsed.model,
          completedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        await _cacheResult(
          key: stableKey,
          sourcePath: sourcePathNormalized,
          result: result,
        );
        return result;
      }

      if (parsed.progress.status == KaraokeSeparationJobStatus.failed ||
          parsed.progress.status == KaraokeSeparationJobStatus.canceled) {
        final msg = parsed.progress.message.trim().isEmpty
            ? 'El backend reportó fallo de separación IA.'
            : parsed.progress.message;
        throw Exception(msg);
      }

      if (DateTime.now().difference(startAt) > timeout) {
        throw Exception('Tiempo de espera agotado en separación IA.');
      }

      await Future<void>.delayed(const Duration(seconds: 2));
      statusPayload = await _fetchJobStatus(parsed.progress.jobId);
    }
  }

  Future<void> clearCache() async {
    await _storage.write(_cacheKey, <String, dynamic>{});
  }

  Future<_CreateJobResponse> _createJob({required MediaItem item}) async {
    try {
      final payload = <String, dynamic>{
        'mediaId': item.fileId,
        'title': item.title,
        'artist': item.displaySubtitle,
        'source': 'listenfy',
      };

      final res = await _client.post('/karaoke/jobs', data: payload);
      final body = _asMap(res.data);
      if (body == null) {
        return const _CreateJobResponse(jobId: '', initialStatus: null);
      }

      final topJobId = _stringOf(body['jobId']);
      if (topJobId.isNotEmpty) {
        return _CreateJobResponse(jobId: topJobId, initialStatus: null);
      }

      final nestedJob = _asMap(body['job']);
      final nestedId = _stringOf(nestedJob?['id']);
      if (nestedId.isNotEmpty) {
        return _CreateJobResponse(jobId: nestedId, initialStatus: nestedJob);
      }

      final topStatus = _stringOf(body['status']);
      if (topStatus.isNotEmpty) {
        return _CreateJobResponse(jobId: '', initialStatus: body);
      }

      return const _CreateJobResponse(jobId: '', initialStatus: null);
    } on dio.DioException catch (e) {
      final status = e.response?.statusCode ?? -1;
      throw Exception(
        'No se pudo crear job IA (${status == -1 ? 'sin respuesta' : 'HTTP $status'}).',
      );
    }
  }

  Future<Map<String, dynamic>?> _fetchJobStatus(String jobId) async {
    final id = jobId.trim();
    if (id.isEmpty) return null;
    try {
      final res = await _client.get('/karaoke/jobs/$id');
      return _asMap(res.data);
    } catch (_) {
      return null;
    }
  }

  _ParsedStatus _parseStatus(
    Map<String, dynamic>? payload, {
    required String fallbackJobId,
  }) {
    final body = payload ?? const <String, dynamic>{};
    final nested = _asMap(body['job']) ?? body;
    final result = _asMap(nested['result']) ?? _asMap(body['result']);

    final jobId = _stringOf(
      nested['id'],
    ).ifEmpty(_stringOf(body['jobId'])).ifEmpty(fallbackJobId);
    final statusRaw = _stringOf(
      nested['status'],
    ).ifEmpty(_stringOf(body['status']));
    final status = _parseStatusEnum(statusRaw);
    final progress = _parseProgressNumber(
      nested['progress'] ?? body['progress'],
    );
    final message = _stringOf(
      nested['message'],
    ).ifEmpty(_stringOf(body['message']));
    final instrumentalUrl = _stringOf(
      result?['instrumentalUrl'] ??
          result?['instrumental_url'] ??
          nested['instrumentalUrl'] ??
          body['instrumentalUrl'],
    );
    final model = _stringOf(
      result?['model'] ?? nested['model'] ?? body['model'],
    );

    final fallbackMsg = switch (status) {
      KaraokeSeparationJobStatus.queued => 'Job en cola',
      KaraokeSeparationJobStatus.running => 'Separando voces e instrumental...',
      KaraokeSeparationJobStatus.completed => 'Separación completada',
      KaraokeSeparationJobStatus.failed => 'Separación fallida',
      KaraokeSeparationJobStatus.canceled => 'Separación cancelada',
      KaraokeSeparationJobStatus.unknown => 'Procesando...',
    };

    return _ParsedStatus(
      progress: KaraokeSeparationProgress(
        status: status,
        progress: progress,
        message: message.isEmpty ? fallbackMsg : message,
        jobId: jobId,
      ),
      instrumentalUrl: instrumentalUrl.isEmpty ? null : instrumentalUrl,
      model: model.isEmpty ? null : model,
    );
  }

  KaraokeSeparationJobStatus _parseStatusEnum(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return KaraokeSeparationJobStatus.unknown;
    if (value == 'queued' || value == 'pending') {
      return KaraokeSeparationJobStatus.queued;
    }
    if (value == 'running' ||
        value == 'processing' ||
        value == 'started' ||
        value == 'working') {
      return KaraokeSeparationJobStatus.running;
    }
    if (value == 'completed' || value == 'done' || value == 'success') {
      return KaraokeSeparationJobStatus.completed;
    }
    if (value == 'failed' || value == 'error') {
      return KaraokeSeparationJobStatus.failed;
    }
    if (value == 'canceled' || value == 'cancelled') {
      return KaraokeSeparationJobStatus.canceled;
    }
    return KaraokeSeparationJobStatus.unknown;
  }

  double _parseProgressNumber(dynamic raw) {
    if (raw is num) {
      final v = raw.toDouble();
      return v > 1.0 ? (v / 100.0).clamp(0.0, 1.0) : v.clamp(0.0, 1.0);
    }
    if (raw is String) {
      final n = double.tryParse(raw.trim());
      if (n == null) return 0.0;
      return n > 1.0 ? (n / 100.0).clamp(0.0, 1.0) : n.clamp(0.0, 1.0);
    }
    return 0.0;
  }

  Future<String> _downloadInstrumental({
    required String stableKey,
    required String sourcePath,
    required String instrumentalUrl,
  }) async {
    final dir = await _instrumentalCacheDir();
    final sourceFile = File(sourcePath);
    final sourceName = sourceFile.uri.pathSegments.isEmpty
        ? stableKey
        : sourceFile.uri.pathSegments.last;
    final base = sourceName.contains('.')
        ? sourceName.substring(0, sourceName.lastIndexOf('.'))
        : sourceName;
    final extension = _extensionFromUrl(instrumentalUrl).ifEmpty('wav');
    final outputPath = p.join(
      dir.path,
      '${_safeName(base)}_ai_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );

    final options = dio.Options(
      responseType: dio.ResponseType.bytes,
      followRedirects: true,
      receiveTimeout: const Duration(minutes: 3),
      sendTimeout: const Duration(seconds: 30),
    );

    if (instrumentalUrl.startsWith('http://') ||
        instrumentalUrl.startsWith('https://')) {
      await _client.dio.download(instrumentalUrl, outputPath, options: options);
    } else {
      await _client.download(instrumentalUrl, outputPath, options: options);
    }

    final file = File(outputPath);
    if (!file.existsSync() || file.lengthSync() <= 0) {
      throw Exception('No se pudo descargar instrumental IA.');
    }
    return outputPath;
  }

  Future<void> _cacheResult({
    required String key,
    required String sourcePath,
    required KaraokeSeparationResult result,
  }) async {
    final map = _readCacheMap();
    map[key] = <String, dynamic>{
      'jobId': result.jobId,
      'instrumentalLocalPath': result.instrumentalLocalPath,
      'instrumentalUrl': result.instrumentalUrl,
      'model': result.model,
      'completedAtMs': result.completedAtMs,
      'sourceSize': await _safeFileSize(sourcePath),
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    };
    await _writeCacheMap(map);
  }

  String _itemStableKey(MediaItem item) {
    final publicId = item.publicId.trim();
    if (publicId.isNotEmpty) return publicId;
    return item.id.trim();
  }

  Map<String, dynamic> _readCacheMap() {
    final raw = _storage.read(_cacheKey);
    if (raw is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(raw);
  }

  Future<void> _writeCacheMap(Map<String, dynamic> map) async {
    await _storage.write(_cacheKey, map);
  }

  Future<int?> _safeFileSize(String? path) async {
    final clean = path?.replaceFirst('file://', '').trim() ?? '';
    if (clean.isEmpty) return null;
    final file = File(clean);
    if (!file.existsSync()) return null;
    try {
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _instrumentalCacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'downloads', 'karaoke_ai'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _safeName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '').trim();
    if (cleaned.isEmpty) return 'track';
    return cleaned.replaceAll(RegExp(r'\s+'), '_');
  }

  String _extensionFromUrl(String raw) {
    final clean = raw.split('?').first;
    final dot = clean.lastIndexOf('.');
    if (dot < 0 || dot >= clean.length - 1) return '';
    final ext = clean.substring(dot + 1).trim().toLowerCase();
    if (ext.length > 6) return '';
    return ext.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  String _stringOf(dynamic raw) => raw?.toString().trim() ?? '';
}

class _CreateJobResponse {
  const _CreateJobResponse({required this.jobId, required this.initialStatus});
  final String jobId;
  final Map<String, dynamic>? initialStatus;
}

class _ParsedStatus {
  const _ParsedStatus({
    required this.progress,
    required this.instrumentalUrl,
    required this.model,
  });
  final KaraokeSeparationProgress progress;
  final String? instrumentalUrl;
  final String? model;
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

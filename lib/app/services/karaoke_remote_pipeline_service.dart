import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/network/dio_client.dart';
import '../models/media_item.dart';

enum KaraokeRemoteSessionStatus {
  separating,
  readyToRecord,
  completed,
  failed,
  canceled,
  unknown,
}

enum KaraokeRemoteVariantMode { instrumental, spatial8d }

class KaraokeRemoteSession {
  const KaraokeRemoteSession({
    required this.id,
    required this.mode,
    required this.status,
    required this.progress,
    required this.message,
    this.instrumentalUrl,
    this.spatial8dUrl,
    this.separatorModel,
    this.error,
  });

  final String id;
  final KaraokeRemoteVariantMode mode;
  final KaraokeRemoteSessionStatus status;
  final double progress;
  final String message;
  final String? instrumentalUrl;
  final String? spatial8dUrl;
  final String? separatorModel;
  final String? error;

  bool get isReadyToRecord =>
      status == KaraokeRemoteSessionStatus.readyToRecord;
  bool get isSeparationCompleted =>
      status == KaraokeRemoteSessionStatus.completed;
  bool get isFailed => status == KaraokeRemoteSessionStatus.failed;

  String? urlFor(KaraokeRemoteVariantMode mode) {
    return switch (mode) {
      KaraokeRemoteVariantMode.instrumental => instrumentalUrl,
      KaraokeRemoteVariantMode.spatial8d => spatial8dUrl,
    };
  }
}

class KaraokeRemoteProgress {
  const KaraokeRemoteProgress({
    required this.progress,
    required this.message,
    required this.status,
  });

  final double progress;
  final String message;
  final KaraokeRemoteSessionStatus status;
}

class KaraokeRemotePipelineService {
  KaraokeRemotePipelineService({required DioClient client}) : _client = client;

  final DioClient _client;

  Future<bool> isBackendReachable({
    Duration connectTimeout = const Duration(seconds: 4),
    Duration receiveTimeout = const Duration(seconds: 4),
  }) async {
    try {
      final response = await _client.get(
        '/karaoke/health',
        options: dio.Options(
          sendTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
        ),
      );
      final body = _asMap(response.data);
      if (body == null) return false;
      return body['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<KaraokeRemoteSession> createSessionFromSource({
    required MediaItem item,
    required String sourcePath,
    KaraokeRemoteVariantMode mode = KaraokeRemoteVariantMode.instrumental,
  }) async {
    final normalized = sourcePath.replaceFirst('file://', '').trim();
    if (normalized.isEmpty) {
      throw Exception('No hay archivo fuente local para crear sesión remota.');
    }

    final file = File(normalized);
    if (!file.existsSync()) {
      throw Exception('No se encontró audio local en: $normalized');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('El audio fuente está vacío.');
    }

    final query = <String, String>{
      'mediaId': item.fileId,
      'title': item.title,
      'artist': item.displaySubtitle,
      'source': 'listenfy_front',
      'filename': p.basename(normalized),
      'mode': _modeQueryValue(mode),
    };

    try {
      final response = await _client.post(
        '/karaoke/sessions?${_queryString(query)}',
        data: bytes,
        options: dio.Options(
          contentType: 'application/octet-stream',
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      final body = _asMap(response.data);
      final sessionMap = _asMap(body?['session']) ?? body;
      final session = _parseSession(sessionMap);
      if (session == null || session.id.trim().isEmpty) {
        throw Exception('El backend no devolvió una sesión remota válida.');
      }
      return session;
    } on dio.DioException catch (e) {
      throw Exception(_friendlyDioError(e, action: 'crear sesión'));
    }
  }

  Future<KaraokeRemoteSession> getSession(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) {
      throw Exception('sessionId inválido');
    }

    try {
      final response = await _client.get(
        '/karaoke/sessions/$id',
        options: dio.Options(
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );
      final body = _asMap(response.data);
      final sessionMap = _asMap(body?['session']) ?? body;
      final session = _parseSession(sessionMap);
      if (session == null) {
        throw Exception('Respuesta inválida al consultar sesión.');
      }
      return session;
    } on dio.DioException catch (e) {
      throw Exception(_friendlyDioError(e, action: 'consultar sesión'));
    }
  }

  Future<KaraokeRemoteSession> waitUntilReady({
    required String sessionId,
    KaraokeRemoteVariantMode mode = KaraokeRemoteVariantMode.instrumental,
    Duration timeout = const Duration(minutes: 18),
    Duration pollEvery = const Duration(seconds: 2),
    void Function(KaraokeRemoteProgress progress)? onProgress,
  }) async {
    final start = DateTime.now();
    var transientFailures = 0;
    String? lastTransientError;
    while (true) {
      if (DateTime.now().difference(start) > timeout) {
        throw Exception(
          lastTransientError != null
              ? 'Timeout esperando ${_modeLabel(mode)} en backend. Último error: $lastTransientError'
              : 'Timeout esperando ${_modeLabel(mode)} en backend.',
        );
      }

      KaraokeRemoteSession current;
      try {
        current = await getSession(sessionId);
        transientFailures = 0;
        lastTransientError = null;
      } catch (error) {
        final message = _normalizeExceptionMessage(error);
        if (!_isRetryableSessionPollError(message)) {
          throw Exception(message);
        }

        transientFailures += 1;
        lastTransientError = message;
        if (transientFailures >= 12) {
          throw Exception(
            'No se pudo consultar sesión tras varios reintentos: $message',
          );
        }

        onProgress?.call(
          KaraokeRemoteProgress(
            progress: 0.2,
            message:
                'Backend ocupado consultando sesión, reintentando ($transientFailures/12)...',
            status: KaraokeRemoteSessionStatus.separating,
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 3));
        continue;
      }

      onProgress?.call(
        KaraokeRemoteProgress(
          progress: current.progress,
          message: current.message,
          status: current.status,
        ),
      );

      if (current.isReadyToRecord || current.isSeparationCompleted) {
        return current;
      }
      if (current.isFailed ||
          current.status == KaraokeRemoteSessionStatus.canceled) {
        final reason = current.error?.trim();
        throw Exception(
          reason != null && reason.isNotEmpty
              ? reason
              : 'El procesamiento de ${_modeLabel(mode)} falló en backend.',
        );
      }

      await Future<void>.delayed(pollEvery);
    }
  }

  Future<String> downloadInstrumentalToLocal({
    required KaraokeRemoteSession session,
    required MediaItem item,
  }) async {
    return downloadVariantToLocal(
      session: session,
      item: item,
      mode: KaraokeRemoteVariantMode.instrumental,
    );
  }

  Future<String> downloadSpatial8dToLocal({
    required KaraokeRemoteSession session,
    required MediaItem item,
  }) async {
    return downloadVariantToLocal(
      session: session,
      item: item,
      mode: KaraokeRemoteVariantMode.spatial8d,
    );
  }

  Future<String> downloadVariantToLocal({
    required KaraokeRemoteSession session,
    required MediaItem item,
    required KaraokeRemoteVariantMode mode,
  }) async {
    final url = session.urlFor(mode)?.trim() ?? '';
    if (url.isEmpty) {
      throw Exception(
        mode == KaraokeRemoteVariantMode.instrumental
            ? 'La sesión no tiene URL de instrumental.'
            : 'La sesión no tiene URL de audio 8D.',
      );
    }

    final dir = await _ensureCacheDir();
    final suffix = mode == KaraokeRemoteVariantMode.instrumental
        ? 'inst'
        : '8d';
    final outputPath = p.join(
      dir.path,
      '${_safeName(item.title)}_${session.id}_$suffix.wav',
    );

    final action = mode == KaraokeRemoteVariantMode.instrumental
        ? 'descargar instrumental'
        : 'descargar audio 8D';

    await _downloadWithRetry(
      url: url,
      outputPath: outputPath,
      action: action,
      maxAttempts: 4,
      retryDelay: const Duration(seconds: 2),
    );
    final file = File(outputPath);
    if (!file.existsSync() || file.lengthSync() <= 0) {
      throw Exception(
        mode == KaraokeRemoteVariantMode.instrumental
            ? 'No se pudo descargar instrumental remoto.'
            : 'No se pudo descargar audio 8D remoto.',
      );
    }
    return outputPath;
  }

  Future<void> _download(String url, String outputPath) async {
    final normalizedUrl = _normalizeAssetUrl(url);
    final options = dio.Options(
      responseType: dio.ResponseType.bytes,
      followRedirects: true,
      receiveTimeout: const Duration(minutes: 4),
      sendTimeout: const Duration(minutes: 1),
    );
    if (normalizedUrl.startsWith('http://') ||
        normalizedUrl.startsWith('https://')) {
      await _client.dio.download(normalizedUrl, outputPath, options: options);
      return;
    }
    await _client.download(normalizedUrl, outputPath, options: options);
  }

  Future<void> _downloadWithRetry({
    required String url,
    required String outputPath,
    required String action,
    int maxAttempts = 1,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    dio.DioException? lastDioError;
    Object? lastOtherError;

    for (int attempt = 1; attempt <= maxAttempts; attempt += 1) {
      try {
        await _download(url, outputPath);
        return;
      } on dio.DioException catch (e) {
        lastDioError = e;
        final status = e.response?.statusCode;
        final shouldRetry404 = status == 404 && attempt < maxAttempts;
        if (shouldRetry404) {
          await Future<void>.delayed(retryDelay);
          continue;
        }
        throw Exception(_friendlyDioError(e, action: action));
      } catch (e) {
        lastOtherError = e;
        break;
      }
    }

    if (lastDioError != null) {
      throw Exception(_friendlyDioError(lastDioError, action: action));
    }
    if (lastOtherError != null) {
      throw Exception('No se pudo $action: ${lastOtherError.toString()}');
    }
    throw Exception('No se pudo $action.');
  }

  Future<Directory> _ensureCacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'downloads', 'karaoke_remote'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  KaraokeRemoteSession? _parseSession(Map<String, dynamic>? map) {
    if (map == null) return null;
    final resultMap = _asMap(map['result']);
    final id = _stringOf(map['id']).trim();
    if (id.isEmpty) return null;
    final mode = _parseMode(_stringOf(resultMap?['mode'] ?? map['mode']));

    final statusRaw = _stringOf(map['status']);
    final status = _parseStatus(statusRaw);
    final progress = _parseProgress(map['progress']);
    final message = _stringOf(
      map['message'],
    ).ifEmpty(_defaultStatusMessage(status, mode));

    return KaraokeRemoteSession(
      id: id,
      mode: mode,
      status: status,
      progress: progress,
      message: message,
      separatorModel: _stringOf(map['separatorModel']),
      error: _stringOf(map['error']),
      instrumentalUrl: _stringOf(
        resultMap?['instrumentalUrl'] ?? map['instrumentalUrl'],
      ).ifEmptyNull(),
      spatial8dUrl: _stringOf(
        resultMap?['spatial8dUrl'] ?? map['spatial8dUrl'],
      ).ifEmptyNull(),
    );
  }

  KaraokeRemoteVariantMode _parseMode(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'spatial8d' || value == '8d' || value == 'spatial') {
      return KaraokeRemoteVariantMode.spatial8d;
    }
    return KaraokeRemoteVariantMode.instrumental;
  }

  KaraokeRemoteSessionStatus _parseStatus(String raw) {
    final value = raw.trim().toLowerCase();
    return switch (value) {
      'separating' => KaraokeRemoteSessionStatus.separating,
      'ready_to_record' => KaraokeRemoteSessionStatus.readyToRecord,
      'completed' => KaraokeRemoteSessionStatus.completed,
      'failed' => KaraokeRemoteSessionStatus.failed,
      'canceled' || 'cancelled' => KaraokeRemoteSessionStatus.canceled,
      _ => KaraokeRemoteSessionStatus.unknown,
    };
  }

  double _parseProgress(dynamic raw) {
    if (raw is num) {
      final value = raw.toDouble();
      return value > 1.0
          ? (value / 100.0).clamp(0.0, 1.0)
          : value.clamp(0.0, 1.0);
    }
    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      if (parsed == null) return 0.0;
      return parsed > 1.0
          ? (parsed / 100.0).clamp(0.0, 1.0)
          : parsed.clamp(0.0, 1.0);
    }
    return 0.0;
  }

  String _safeName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '').trim();
    if (cleaned.isEmpty) return 'track';
    return cleaned.replaceAll(RegExp(r'\s+'), '_');
  }

  String _queryString(Map<String, String> params) {
    return params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }

  String _modeQueryValue(KaraokeRemoteVariantMode mode) {
    return mode == KaraokeRemoteVariantMode.instrumental
        ? 'instrumental'
        : 'spatial8d';
  }

  String _modeLabel(KaraokeRemoteVariantMode mode) {
    return mode == KaraokeRemoteVariantMode.instrumental
        ? 'separación de instrumental'
        : 'procesamiento 8D';
  }

  String _defaultStatusMessage(
    KaraokeRemoteSessionStatus status,
    KaraokeRemoteVariantMode mode,
  ) {
    final noun = mode == KaraokeRemoteVariantMode.instrumental
        ? 'instrumental'
        : 'audio 8D';
    return switch (status) {
      KaraokeRemoteSessionStatus.separating => tr(
        'karaoke_remote.status.separating',
        args: [noun],
      ),
      KaraokeRemoteSessionStatus.readyToRecord => tr(
        'karaoke_remote.status.ready',
        args: [noun],
      ),
      KaraokeRemoteSessionStatus.completed => tr(
        'karaoke_remote.status.completed',
        args: [noun],
      ),
      KaraokeRemoteSessionStatus.failed => tr('karaoke_remote.status.failed'),
      KaraokeRemoteSessionStatus.canceled => tr(
        'karaoke_remote.status.canceled',
      ),
      KaraokeRemoteSessionStatus.unknown => tr('karaoke_remote.status.unknown'),
    };
  }

  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  String _stringOf(dynamic raw) => raw?.toString().trim() ?? '';

  String _normalizeAssetUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/api/v1/')) {
      return value.replaceFirst('/api/v1', '');
    }
    if (value.startsWith('api/v1/')) {
      return '/${value.substring('api/v1'.length)}';
    }
    return value;
  }

  String _friendlyDioError(dio.DioException error, {required String action}) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String? backendMsg;
    if (data is Map) {
      backendMsg = _stringOf(data['error']);
    }

    if (error.type == dio.DioExceptionType.connectionTimeout) {
      return 'No se pudo conectar a tiempo con el backend al $action. Reintenta: la primera ejecución de Demucs puede tardar más.';
    }
    if (error.type == dio.DioExceptionType.receiveTimeout) {
      return 'El backend tardó demasiado al $action. Reintenta en unos segundos.';
    }
    if (error.type == dio.DioExceptionType.sendTimeout) {
      return 'Se agotó el tiempo al enviar datos para $action.';
    }

    if (status == 404) {
      if (action == 'crear sesión') {
        return 'Backend sin endpoint remoto (404). Actualiza el backend con /karaoke/sessions.';
      }
      if (action == 'consultar sesión') {
        return 'Sesión remota no encontrada (404). El backend pudo reiniciarse o la sesión expiró.';
      }
      if (action == 'descargar instrumental') {
        return 'El backend aún no expone el instrumental (404). Reintenta en unos segundos.';
      }
      if (action == 'descargar audio 8D') {
        return 'El backend aún no expone el audio 8D (404). Reintenta en unos segundos.';
      }
      return 'Recurso remoto no encontrado (404).';
    }

    if (status != null) {
      final reason = backendMsg?.isNotEmpty == true
          ? backendMsg!
          : 'HTTP $status';
      return 'Error de backend al $action: $reason';
    }

    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return 'No se pudo $action: $message';
    }
    return 'No se pudo $action por un error de red.';
  }

  bool _isRetryableSessionPollError(String message) {
    final text = message.toLowerCase();
    if (text.contains('404') ||
        text.contains('no encontrada') ||
        text.contains('expiró') ||
        text.contains('inválido')) {
      return false;
    }

    if (text.contains('tardó demasiado') ||
        text.contains('timeout') ||
        text.contains('conectar') ||
        text.contains('error de red') ||
        text.contains('http 5')) {
      return true;
    }

    return true;
  }

  String _normalizeExceptionMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception:')) {
      return raw.substring('Exception:'.length).trim();
    }
    return raw;
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
  String? ifEmptyNull() => isEmpty ? null : this;
}

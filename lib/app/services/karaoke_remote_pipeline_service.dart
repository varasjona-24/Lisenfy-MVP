import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/network/dio_client.dart';
import '../models/media_item.dart';

enum KaraokeRemoteSessionStatus {
  separating,
  readyToRecord,
  mixing,
  completed,
  failed,
  canceled,
  unknown,
}

class KaraokeRemoteSession {
  const KaraokeRemoteSession({
    required this.id,
    required this.status,
    required this.progress,
    required this.message,
    this.instrumentalUrl,
    this.mixUrl,
    this.separatorModel,
    this.error,
  });

  final String id;
  final KaraokeRemoteSessionStatus status;
  final double progress;
  final String message;
  final String? instrumentalUrl;
  final String? mixUrl;
  final String? separatorModel;
  final String? error;

  bool get isReadyToRecord =>
      status == KaraokeRemoteSessionStatus.readyToRecord;
  bool get isMixed => status == KaraokeRemoteSessionStatus.completed;
  bool get isFailed => status == KaraokeRemoteSessionStatus.failed;
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
        throw Exception('El backend no devolvió sesión de karaoke válida.');
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
              ? 'Timeout esperando separación de instrumental en backend. Último error: $lastTransientError'
              : 'Timeout esperando separación de instrumental en backend.',
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

      if (current.isReadyToRecord || current.isMixed) {
        return current;
      }
      if (current.isFailed ||
          current.status == KaraokeRemoteSessionStatus.canceled) {
        final reason = current.error?.trim();
        throw Exception(
          reason != null && reason.isNotEmpty
              ? reason
              : 'La separación de instrumental falló en backend.',
        );
      }

      await Future<void>.delayed(pollEvery);
    }
  }

  Future<String> downloadInstrumentalToLocal({
    required KaraokeRemoteSession session,
    required MediaItem item,
  }) async {
    final url = session.instrumentalUrl?.trim() ?? '';
    if (url.isEmpty) {
      throw Exception('La sesión no tiene URL de instrumental.');
    }

    final dir = await _ensureCacheDir();
    final outputPath = p.join(
      dir.path,
      '${_safeName(item.title)}_${session.id}_inst.wav',
    );

    await _downloadWithRetry(
      url: url,
      outputPath: outputPath,
      action: 'descargar instrumental',
      maxAttempts: 4,
      retryDelay: const Duration(seconds: 2),
    );
    final file = File(outputPath);
    if (!file.existsSync() || file.lengthSync() <= 0) {
      throw Exception('No se pudo descargar instrumental remoto.');
    }
    return outputPath;
  }

  Future<KaraokeRemoteSession> uploadVoiceAndMix({
    required String sessionId,
    required String voicePath,
    required double voiceGain,
    required double instrumentalGain,
  }) async {
    final id = sessionId.trim();
    if (id.isEmpty) throw Exception('sessionId inválido.');

    final normalized = voicePath.replaceFirst('file://', '').trim();
    if (normalized.isEmpty) {
      throw Exception('No hay archivo de voz para subir al backend.');
    }
    final file = File(normalized);
    if (!file.existsSync()) {
      throw Exception('No se encontró grabación de voz: $normalized');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('La grabación de voz está vacía.');
    }

    final query = <String, String>{
      'filename': p.basename(normalized),
      'voiceGain': voiceGain.clamp(0.0, 2.5).toStringAsFixed(3),
      'instrumentalGain': instrumentalGain.clamp(0.0, 2.5).toStringAsFixed(3),
    };

    try {
      final response = await _client.post(
        '/karaoke/sessions/$id/voice?${_queryString(query)}',
        data: bytes,
        options: dio.Options(
          contentType: 'application/octet-stream',
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 4),
        ),
      );

      final body = _asMap(response.data);
      final sessionMap = _asMap(body?['session']) ?? body;
      final session = _parseSession(sessionMap);
      if (session == null) {
        throw Exception('Respuesta inválida al subir voz para mezcla.');
      }
      return session;
    } on dio.DioException catch (e) {
      throw Exception(_friendlyDioError(e, action: 'subir voz'));
    }
  }

  Future<KaraokeRemoteSession> waitUntilMixed({
    required String sessionId,
    Duration timeout = const Duration(minutes: 5),
    Duration pollEvery = const Duration(seconds: 2),
    void Function(KaraokeRemoteProgress progress)? onProgress,
  }) async {
    final start = DateTime.now();
    while (true) {
      if (DateTime.now().difference(start) > timeout) {
        throw Exception('Timeout esperando mezcla final de karaoke.');
      }

      final current = await getSession(sessionId);
      onProgress?.call(
        KaraokeRemoteProgress(
          progress: current.progress,
          message: current.message,
          status: current.status,
        ),
      );

      if (current.isMixed) return current;
      if (current.isFailed ||
          current.status == KaraokeRemoteSessionStatus.canceled) {
        final reason = current.error?.trim();
        throw Exception(
          reason != null && reason.isNotEmpty
              ? reason
              : 'La mezcla final falló en backend.',
        );
      }

      await Future<void>.delayed(pollEvery);
    }
  }

  Future<String> downloadMixToLocal({
    required KaraokeRemoteSession session,
    required MediaItem item,
  }) async {
    final url = session.mixUrl?.trim() ?? '';
    if (url.isEmpty) {
      throw Exception('La sesión aún no tiene mezcla final.');
    }

    final dir = await _ensureCacheDir();
    final outputPath = p.join(
      dir.path,
      '${_safeName(item.title)}_${session.id}_mix.wav',
    );

    await _downloadWithRetry(
      url: url,
      outputPath: outputPath,
      action: 'descargar mezcla final',
      maxAttempts: 3,
      retryDelay: const Duration(seconds: 2),
    );
    final file = File(outputPath);
    if (!file.existsSync() || file.lengthSync() <= 0) {
      throw Exception('No se pudo descargar la mezcla final.');
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

    final statusRaw = _stringOf(map['status']);
    final status = _parseStatus(statusRaw);
    final progress = _parseProgress(map['progress']);
    final message = _stringOf(map['message']).ifEmpty(switch (status) {
      KaraokeRemoteSessionStatus.separating =>
        'Separando instrumental en backend...',
      KaraokeRemoteSessionStatus.readyToRecord =>
        'Instrumental listo para grabar.',
      KaraokeRemoteSessionStatus.mixing =>
        'Mezclando voz con instrumental en backend...',
      KaraokeRemoteSessionStatus.completed => 'Mezcla final completada.',
      KaraokeRemoteSessionStatus.failed => 'Proceso fallido en backend.',
      KaraokeRemoteSessionStatus.canceled => 'Proceso cancelado.',
      KaraokeRemoteSessionStatus.unknown => 'Procesando...',
    });

    return KaraokeRemoteSession(
      id: id,
      status: status,
      progress: progress,
      message: message,
      separatorModel: _stringOf(map['separatorModel']),
      error: _stringOf(map['error']),
      instrumentalUrl: _stringOf(
        resultMap?['instrumentalUrl'] ?? map['instrumentalUrl'],
      ).ifEmptyNull(),
      mixUrl: _stringOf(resultMap?['mixUrl'] ?? map['mixUrl']).ifEmptyNull(),
    );
  }

  KaraokeRemoteSessionStatus _parseStatus(String raw) {
    final value = raw.trim().toLowerCase();
    return switch (value) {
      'separating' => KaraokeRemoteSessionStatus.separating,
      'ready_to_record' => KaraokeRemoteSessionStatus.readyToRecord,
      'mixing' => KaraokeRemoteSessionStatus.mixing,
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
        return 'Backend sin endpoint de karaoke remoto (404). Actualiza el backend con /karaoke/sessions.';
      }
      if (action == 'consultar sesión') {
        return 'Sesión remota no encontrada (404). El backend pudo reiniciarse o la sesión expiró.';
      }
      if (action == 'subir voz') {
        return 'No se pudo subir voz: sesión remota no encontrada (404).';
      }
      if (action == 'descargar instrumental') {
        return 'El backend aún no expone el instrumental (404). Reintenta en unos segundos.';
      }
      if (action == 'descargar mezcla final') {
        return 'El backend aún no expone la mezcla final (404). Reintenta cuando termine el proceso.';
      }
      return 'Recurso de karaoke no encontrado (404).';
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

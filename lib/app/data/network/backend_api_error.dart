import 'package:dio/dio.dart' as dio;
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;

class BackendApiException implements Exception {
  const BackendApiException({
    required this.message,
    this.code,
    this.retryable = false,
    this.retryAfterSeconds,
    this.statusCode,
    this.details,
  });

  final String message;
  final String? code;
  final bool retryable;
  final int? retryAfterSeconds;
  final int? statusCode;
  final Map<String, dynamic>? details;

  String get normalizedCode => code?.trim().toUpperCase() ?? '';

  factory BackendApiException.fromDio(
    dio.DioException error, {
    required String fallbackMessage,
  }) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final parsed = _parseBody(data);
    final retryAfter = _parseRetryAfter(
      error.response?.headers.value('retry-after'),
    );

    if (parsed != null) {
      return BackendApiException(
        message: parsed.message.isNotEmpty ? parsed.message : fallbackMessage,
        code: parsed.code,
        retryable: parsed.retryable,
        retryAfterSeconds: parsed.retryAfterSeconds ?? retryAfter,
        statusCode: statusCode,
        details: parsed.details,
      );
    }

    return BackendApiException(
      message: fallbackMessage,
      retryable: _isRetryableStatus(statusCode),
      retryAfterSeconds: retryAfter,
      statusCode: statusCode,
    );
  }

  @override
  String toString() => message;

  String localizedTitle({String fallback = 'Listenfy'}) {
    final value = _localizedValue('backend_errors.titles.$normalizedCode');
    return value ?? fallback;
  }

  String localizedMessage({
    bool includeRetryHint = true,
    String? fallbackMessage,
  }) {
    final fallback = (fallbackMessage?.trim().isNotEmpty == true)
        ? fallbackMessage!.trim()
        : message.trim();
    final translated =
        _localizedValue('backend_errors.messages.$normalizedCode') ??
        (fallback.isNotEmpty ? fallback : tr('imports.failed'));

    if (!includeRetryHint || !retryable || retryAfterSeconds == null) {
      return translated;
    }

    final retryText = tr(
      'backend_errors.retry_in',
      args: [retryAfterSeconds.toString()],
    );
    return '$translated $retryText';
  }

  static _ParsedBackendError? _parseBody(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final nested = map['error'] is Map
        ? Map<String, dynamic>.from(map['error'] as Map)
        : null;
    final source = nested ?? map;

    final code = _stringOf(source['code']).ifEmptyNull();
    final userMessage = _stringOf(
      source['userMessage'],
    ).ifEmpty(_stringOf(source['error']));
    final message = userMessage.ifEmpty(_stringOf(source['message']));
    final retryable = source['retryable'] == true;
    final retryAfterSeconds = _intOf(source['retryAfterSeconds']);
    final detailsRaw = source['details'];

    if (code == null && message.isEmpty) return null;

    return _ParsedBackendError(
      code: code,
      message: message,
      retryable: retryable,
      retryAfterSeconds: retryAfterSeconds,
      details: detailsRaw is Map ? Map<String, dynamic>.from(detailsRaw) : null,
    );
  }

  static int? _parseRetryAfter(String? raw) {
    if (raw == null) return null;
    return int.tryParse(raw.trim());
  }

  static bool _isRetryableStatus(int? statusCode) {
    if (statusCode == null) return false;
    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  static String _stringOf(dynamic raw) => raw?.toString().trim() ?? '';

  static int? _intOf(dynamic raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  static String? _localizedValue(String key) {
    if (key.endsWith('.')) return null;
    final value = tr(key).trim();
    if (value.isEmpty || value == key) return null;
    return value;
  }
}

class _ParsedBackendError {
  const _ParsedBackendError({
    required this.message,
    this.code,
    this.retryable = false,
    this.retryAfterSeconds,
    this.details,
  });

  final String message;
  final String? code;
  final bool retryable;
  final int? retryAfterSeconds;
  final Map<String, dynamic>? details;
}

extension _BackendApiStringX on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
  String? ifEmptyNull() => isEmpty ? null : this;
}

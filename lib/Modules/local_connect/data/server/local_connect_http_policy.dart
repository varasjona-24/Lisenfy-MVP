import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ConnectHttpException implements Exception {
  const ConnectHttpException(this.statusCode, this.code);
  final int statusCode;
  final String code;
}

/// Shared input limits for the LAN server. Browser origins are compared exactly
/// against the address advertised by the server, never against an arbitrary Host.
class LocalConnectHttpPolicy {
  static const maxBodyBytes = 8192;

  static bool allowsRequest({
    required Uri server,
    required String? host,
    required String? origin,
    String? fetchSite,
  }) {
    if (host != server.authority) return false;
    if (origin != null && origin != server.origin) return false;
    return fetchSite == null ||
        fetchSite == 'same-origin' ||
        fetchSite == 'none';
  }

  static Future<Map<String, dynamic>> readJson(HttpRequest request) async {
    if (request.headers.contentType?.mimeType != 'application/json') {
      throw const ConnectHttpException(415, 'json_required');
    }
    if (request.contentLength > maxBodyBytes) {
      throw const ConnectHttpException(413, 'body_too_large');
    }
    final bytes = <int>[];
    final reader = StreamIterator<List<int>>(request);
    final deadline = Stopwatch()..start();
    try {
      while (await reader.moveNext().timeout(
        const Duration(seconds: 5) - deadline.elapsed,
      )) {
        if (bytes.length + reader.current.length > maxBodyBytes) {
          throw const ConnectHttpException(413, 'body_too_large');
        }
        bytes.addAll(reader.current);
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } on TimeoutException {
      throw const ConnectHttpException(408, 'body_timeout');
    } on FormatException {
      throw const ConnectHttpException(400, 'invalid_json');
    } finally {
      await reader.cancel();
    }
  }

  /// Only HTTP(S) destinations may be used for remote artwork/media.
  static bool isRemoteUrl(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }
}

class ConnectByteRange {
  const ConnectByteRange(this.start, this.end);
  final int start;
  final int end;
  int get length => end - start + 1;

  static ConnectByteRange parse(String header, int size) {
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (match == null || size <= 0) {
      throw const ConnectHttpException(416, 'invalid_range');
    }
    final first = match[1]!;
    final last = match[2]!;
    if (first.isEmpty) {
      final suffix = int.tryParse(last);
      if (suffix == null || suffix <= 0) {
        throw const ConnectHttpException(416, 'invalid_range');
      }
      return ConnectByteRange((size - suffix).clamp(0, size - 1), size - 1);
    }
    final start = int.tryParse(first);
    final end = last.isEmpty ? size - 1 : int.tryParse(last);
    if (start == null || end == null || start >= size || end < start) {
      throw const ConnectHttpException(416, 'invalid_range');
    }
    return ConnectByteRange(start, end.clamp(start, size - 1));
  }
}

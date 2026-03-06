import 'dart:convert';

import 'package:dio/dio.dart';

class LyricsTranslationResult {
  final String translated;
  final String? romanized;

  const LyricsTranslationResult({required this.translated, this.romanized});
}

class LyricsService {
  static const List<String> _libreEndpoints = <String>[
    'https://translate.astian.org/translate',
    'https://libretranslate.de/translate',
    'https://translate.argosopentech.com/translate',
  ];

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 12),
      responseType: ResponseType.plain,
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (code) => (code ?? 500) < 500,
      headers: const {'User-Agent': 'Listenfy/1.0'},
    ),
  );

  /// Fetch lyrics from a given URL (e.g., a Google search result page).
  /// Returns plain text with basic HTML cleanup.
  static Future<String?> fetchLyricsFromUrl(String url) async {
    final source = url.trim();
    if (source.isEmpty) return null;
    final uri = Uri.tryParse(source);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }

    try {
      final response = await _dio.get<String>(source);
      final body = response.data ?? '';
      if (response.statusCode != 200 || body.trim().isEmpty) return null;

      final cleaned = _cleanupHtmlToText(body);
      if (cleaned.isEmpty) return null;
      return cleaned;
    } catch (_) {
      return null;
    }
  }

  static String _cleanupHtmlToText(String html) {
    var text = html;
    text = text.replaceAll(
      RegExp(
        r'<(script|style|noscript)[^>]*>[\s\S]*?<\/\1>',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<\/p\s*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final compact = lines.join('\n').trim();
    if (compact.length <= 20) return '';

    // Prevent returning full pages; keep a realistic lyrics-sized payload.
    const maxLen = 12000;
    if (compact.length > maxLen) {
      return compact.substring(0, maxLen);
    }
    return compact;
  }

  /// Translate given lyrics to target language using LibreTranslate public API.
  /// Returns translated text or null on failure.
  static Future<String?> translateLyrics(
    String lyrics,
    String targetLang, {
    String? sourceLang,
  }) async {
    final result = await translateLyricsDetailed(
      lyrics,
      targetLang,
      sourceLang: sourceLang,
    );
    return result?.translated;
  }

  static Future<LyricsTranslationResult?> translateLyricsDetailed(
    String lyrics,
    String targetLang, {
    String? sourceLang,
  }) async {
    final text = lyrics.trim();
    final target = targetLang.trim().toLowerCase();
    final source = (sourceLang ?? 'auto').trim().toLowerCase();
    if (text.isEmpty || target.isEmpty) return null;
    if (source == target) {
      return LyricsTranslationResult(translated: text);
    }

    final chunks = _chunkTextForTranslation(text, maxChunkChars: 1400);
    if (chunks.isEmpty) return null;

    final out = <String>[];
    for (final chunk in chunks) {
      final translated = await _translateChunkWithFallback(
        chunk,
        targetLang: target,
        sourceLang: source,
      );
      if (translated == null || translated.trim().isEmpty) return null;
      out.add(translated.trim());
    }

    final joined = out.join('\n\n').trim();
    if (joined.isEmpty) return null;

    String? romanized;
    if (target == 'ja' || target == 'ko') {
      romanized = await romanizeText(joined, sourceLang: target);
    }

    return LyricsTranslationResult(translated: joined, romanized: romanized);
  }

  static Future<String?> _translateChunkWithFallback(
    String text, {
    required String targetLang,
    required String sourceLang,
  }) async {
    for (final endpoint in _libreEndpoints) {
      final translated = await _translateViaLibre(
        endpoint: endpoint,
        text: text,
        targetLang: targetLang,
        sourceLang: sourceLang,
      );
      if (translated != null && translated.trim().isNotEmpty) {
        return translated.trim();
      }
    }

    final google = await _translateViaGoogleGtx(
      text: text,
      targetLang: targetLang,
      sourceLang: sourceLang,
    );
    if (google != null && google.trim().isNotEmpty) return google.trim();

    return null;
  }

  static Future<String?> _translateViaLibre({
    required String endpoint,
    required String text,
    required String targetLang,
    required String sourceLang,
  }) async {
    final payload = <String, dynamic>{
      'q': text,
      'source': sourceLang,
      'target': targetLang,
      'format': 'text',
    };

    try {
      final jsonResp = await _dio.post<dynamic>(
        endpoint,
        data: payload,
        options: Options(
          responseType: ResponseType.json,
          contentType: Headers.jsonContentType,
        ),
      );
      final fromJson = _extractTranslatedText(jsonResp.data);
      if (fromJson != null && fromJson.trim().isNotEmpty) {
        return fromJson.trim();
      }
    } catch (_) {}

    try {
      final formResp = await _dio.post<dynamic>(
        endpoint,
        data: payload,
        options: Options(
          responseType: ResponseType.json,
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      final fromForm = _extractTranslatedText(formResp.data);
      if (fromForm != null && fromForm.trim().isNotEmpty) {
        return fromForm.trim();
      }
    } catch (_) {}

    return null;
  }

  static Future<String?> _translateViaGoogleGtx({
    required String text,
    required String targetLang,
    required String sourceLang,
  }) async {
    final sl = sourceLang == 'auto' ? 'auto' : sourceLang;
    final uri = Uri.parse('https://translate.googleapis.com/translate_a/single')
        .replace(
          queryParameters: <String, String>{
            'client': 'gtx',
            'sl': sl,
            'tl': targetLang,
            'dt': 't',
            'q': text,
          },
        );

    try {
      final resp = await _dio.get<dynamic>(
        uri.toString(),
        options: Options(responseType: ResponseType.json),
      );
      final payload = resp.data;
      final list = payload is String ? jsonDecode(payload) : payload;
      if (list is! List || list.isEmpty || list.first is! List) return null;

      final translatedParts = <String>[];
      for (final segment in list.first as List) {
        if (segment is List && segment.isNotEmpty && segment.first is String) {
          translatedParts.add(segment.first as String);
        }
      }
      final joined = _stitchTranslatedSegments(translatedParts).trim();
      return joined.isEmpty ? null : joined;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> romanizeText(
    String text, {
    required String sourceLang,
  }) async {
    final src = sourceLang.trim().toLowerCase();
    if (text.trim().isEmpty) return null;
    if (src != 'ja' && src != 'ko') return null;

    final chunks = _chunkTextForTranslation(text, maxChunkChars: 1200);
    if (chunks.isEmpty) return null;

    final out = <String>[];
    for (final chunk in chunks) {
      final romanized = await _romanizeChunkViaGoogle(
        text: chunk,
        sourceLang: src,
      );
      if (romanized == null || romanized.trim().isEmpty) {
        return null;
      }
      out.add(romanized.trim());
    }

    final joined = out.join('\n\n').trim();
    return joined.isEmpty ? null : joined;
  }

  static Future<String?> _romanizeChunkViaGoogle({
    required String text,
    required String sourceLang,
  }) async {
    final uri = Uri.parse('https://translate.googleapis.com/translate_a/single')
        .replace(
          queryParameters: <String, String>{
            'client': 'gtx',
            'sl': sourceLang,
            'tl': sourceLang,
            'dt': 'rm',
            'q': text,
          },
        );

    try {
      final resp = await _dio.get<dynamic>(
        uri.toString(),
        options: Options(responseType: ResponseType.json),
      );
      final payload = resp.data;
      final list = payload is String ? jsonDecode(payload) : payload;
      if (list is! List || list.isEmpty || list.first is! List) return null;

      final romanizedParts = <String>[];
      for (final segment in list.first as List) {
        if (segment is! List || segment.isEmpty) continue;

        for (var i = segment.length - 1; i >= 0; i--) {
          final value = segment[i];
          if (value is String && _looksRomanized(value)) {
            romanizedParts.add(value);
            break;
          }
        }
      }

      if (romanizedParts.isEmpty) return null;
      final joined = _stitchTranslatedSegments(romanizedParts).trim();
      return joined.isEmpty ? null : joined;
    } catch (_) {
      return null;
    }
  }

  static String _stitchTranslatedSegments(List<String> parts) {
    if (parts.isEmpty) return '';

    final out = StringBuffer();
    int? prevLastCodeUnit;

    for (final raw in parts) {
      final part = raw;
      if (part.isEmpty) continue;

      if (out.isNotEmpty) {
        final firstCode = _firstNonWhitespaceCodeUnit(part);
        if (_needsSpaceBetween(prevLastCodeUnit, firstCode)) {
          out.write(' ');
        }
      }

      out.write(part);
      prevLastCodeUnit = _lastNonWhitespaceCodeUnit(part) ?? prevLastCodeUnit;
    }

    return out.toString();
  }

  static int? _firstNonWhitespaceCodeUnit(String value) {
    for (var i = 0; i < value.length; i++) {
      final cu = value.codeUnitAt(i);
      if (!_isWhitespace(cu)) return cu;
    }
    return null;
  }

  static int? _lastNonWhitespaceCodeUnit(String value) {
    for (var i = value.length - 1; i >= 0; i--) {
      final cu = value.codeUnitAt(i);
      if (!_isWhitespace(cu)) return cu;
    }
    return null;
  }

  static bool _needsSpaceBetween(int? left, int? right) {
    if (left == null || right == null) return false;
    if (_isPunctuation(left) || _isPunctuation(right)) return false;
    return _isWordLike(left) && _isWordLike(right);
  }

  static bool _isWhitespace(int cu) =>
      cu == 0x20 || cu == 0x09 || cu == 0x0A || cu == 0x0D;

  static bool _isPunctuation(int cu) {
    const punct = <int>{
      0x2E, // .
      0x2C, // ,
      0x3A, // :
      0x3B, // ;
      0x21, // !
      0x3F, // ?
      0x29, // )
      0x28, // (
      0x5D, // ]
      0x5B, // [
      0x7D, // }
      0x7B, // {
      0x2D, // -
      0x22, // "
      0x27, // '
      0x2F, // /
      0x5C, // \
    };
    return punct.contains(cu);
  }

  static bool _isWordLike(int cu) {
    // ASCII digits/letters + latin extended ranges used commonly in ES/PT/FR/IT/DE
    if ((cu >= 0x30 && cu <= 0x39) || // 0-9
        (cu >= 0x41 && cu <= 0x5A) || // A-Z
        (cu >= 0x61 && cu <= 0x7A) || // a-z
        (cu >= 0x00C0 && cu <= 0x024F)) {
      return true;
    }
    return false;
  }

  static bool _looksRomanized(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (!RegExp(r'[A-Za-z]').hasMatch(v)) return false;
    if (RegExp(r'[\u3040-\u30FF\u3400-\u9FFF\uAC00-\uD7AF]').hasMatch(v)) {
      return false;
    }
    return true;
  }

  static String? _extractTranslatedText(dynamic payload) {
    final data = payload is String ? _tryDecodeJson(payload) : payload;
    if (data is Map) {
      final translated = data['translatedText'];
      if (translated is String && translated.trim().isNotEmpty) {
        return translated.trim();
      }
    }
    return null;
  }

  static dynamic _tryDecodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static List<String> _chunkTextForTranslation(
    String text, {
    int maxChunkChars = 1400,
  }) {
    final src = text.replaceAll('\r\n', '\n').trim();
    if (src.isEmpty) return const <String>[];
    if (src.length <= maxChunkChars) return <String>[src];

    final chunks = <String>[];
    var start = 0;

    while (start < src.length) {
      var end = (start + maxChunkChars).clamp(0, src.length);
      if (end >= src.length) {
        final tail = src.substring(start).trim();
        if (tail.isNotEmpty) chunks.add(tail);
        break;
      }

      var split = src.lastIndexOf('\n\n', end);
      if (split <= start) split = src.lastIndexOf('\n', end);
      if (split <= start) split = src.lastIndexOf(' ', end);
      if (split <= start) split = end;

      final piece = src.substring(start, split).trim();
      if (piece.isNotEmpty) chunks.add(piece);
      start = split;

      while (start < src.length) {
        final code = src.codeUnitAt(start);
        final isWhitespace = code == 0x20 || code == 0x0A || code == 0x09;
        if (!isWhitespace) break;
        start += 1;
      }
    }

    return chunks;
  }
}

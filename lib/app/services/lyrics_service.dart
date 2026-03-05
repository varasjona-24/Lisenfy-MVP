import 'package:dio/dio.dart';

class LyricsService {
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
    final text = lyrics.trim();
    final target = targetLang.trim().toLowerCase();
    final source = (sourceLang ?? 'auto').trim().toLowerCase();
    if (text.isEmpty || target.isEmpty) return null;

    const apiUrl = 'https://translate.astian.org/translate';
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        apiUrl,
        data: <String, dynamic>{
          'q': text,
          'source': source,
          'target': target,
          'format': 'text',
        },
        options: Options(responseType: ResponseType.json),
      );

      if (response.statusCode != 200) return null;
      final data = response.data;
      if (data == null) return null;
      final translated = data['translatedText'];
      if (translated is! String) return null;
      final out = translated.trim();
      return out.isEmpty ? null : out;
    } catch (_) {}
    return null;
  }
}

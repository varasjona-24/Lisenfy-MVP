import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

typedef DownloadCommand =
    Future<String> Function(
      String executable,
      List<String> arguments,
      void Function(String line)? onLine,
    );

class DesktopDownloadException implements Exception {
  const DesktopDownloadException(this.message, {this.diagnostic});
  final String message;
  final String? diagnostic;
  @override
  String toString() => message;
}

/// Native extraction/conversion only. Persistence remains in MediaRepository.
class DesktopDownloadEngine {
  DesktopDownloadEngine({
    required this.ytDlp,
    required this.ffmpeg,
    required this.runtime,
    this.runtimeName = 'deno',
    this.cookies,
    DownloadCommand? command,
    bool Function()? cancelled,
  }) : _command =
           command ??
           ((executable, arguments, onLine) =>
               runCommand(executable, arguments, onLine, cancelled: cancelled));

  final String ytDlp, ffmpeg, runtime, runtimeName;
  final String? cookies;
  final DownloadCommand _command;

  static bool get supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static Future<DesktopDownloadEngine> discover({
    String? applicationExecutable,
    Map<String, String>? environment,
    bool Function()? cancelled,
  }) async {
    final env = environment ?? Platform.environment;
    final executablePath = applicationExecutable ?? Platform.resolvedExecutable;
    final macBundle =
        Platform.isMacOS && executablePath.contains('.app/Contents/MacOS/');
    Future<String?> find(String name, String variable) async {
      final configured = env[variable];
      final executableDir = p.dirname(executablePath);
      final filename = Platform.isWindows ? '$name.exe' : name;
      final candidates = [
        if (configured != null && configured.isNotEmpty) configured,
        p.join(executableDir, 'download-tools', filename),
        p.join(executableDir, 'download-tools', 'bin', filename),
        if (name == 'yt-dlp')
          p.join(
            executableDir,
            '..',
            'Resources',
            'download-tools',
            'yt-dlp',
            'yt-dlp_macos',
          ),
        p.join(
          executableDir,
          '..',
          'Resources',
          'download-tools',
          'bin',
          filename,
        ),
        p.normalize(
          p.join(executableDir, '..', 'Resources', 'download-tools', filename),
        ),
        if (Platform.isMacOS && !macBundle) ...[
          '/opt/homebrew/bin/$name',
          '/usr/local/bin/$name',
        ],
        for (final dir in (macBundle ? '' : env['PATH'] ?? '').split(
          Platform.isWindows ? ';' : ':',
        ))
          if (dir.isNotEmpty) p.join(dir, filename),
      ];
      for (final candidate in candidates) {
        final normalized = p.normalize(candidate);
        if (await File(normalized).exists()) return normalized;
      }
      return null;
    }

    final yt = await find('yt-dlp', 'LISTENFY_YTDLP_PATH');
    final ff = await find('ffmpeg', 'LISTENFY_FFMPEG_PATH');
    final deno = await find('deno', 'LISTENFY_DENO_PATH');
    final node = deno == null ? await find('node', 'LISTENFY_NODE_PATH') : null;
    if (yt == null || ff == null || (deno == null && node == null)) {
      throw const DesktopDownloadException(
        'Faltan herramientas de descarga local: yt-dlp, FFmpeg y Deno o Node. Consulta docs/desktop_downloads.md.',
      );
    }
    return DesktopDownloadEngine(
      cancelled: cancelled,
      ytDlp: yt,
      ffmpeg: ff,
      runtime: deno ?? node!,
      runtimeName: deno == null ? 'node' : 'deno',
      cookies: env['LISTENFY_YTDLP_COOKIES'],
    );
  }

  static String validateUrl(String input) {
    // Clipboard text can carry bidi/isolation markers which are invisible in
    // the input field but prevent Uri from recognizing the scheme.
    final cleaned = input.replaceAll(
      RegExp(
        r'^[\s\u200B-\u200F\u202A-\u202E\u2060-\u2069\uFEFF]+|[\s\u200B-\u200F\u202A-\u202E\u2060-\u2069\uFEFF]+$',
      ),
      '',
    );
    final uri = Uri.tryParse(cleaned);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw DesktopDownloadException(
        'Introduce una URL HTTP o HTTPS válida.',
        diagnostic:
            'URL validation: length=${input.length}, scheme=${uri?.scheme}, hostPresent=${uri?.host.isNotEmpty}, nonAscii=${input.runes.where((r) => r > 127).map((r) => r.toRadixString(16)).take(12).join(',')}',
      );
    }
    return uri.toString();
  }

  List<String> get _base => [
    '--ignore-config',
    '--no-update',
    '--no-color',
    '--socket-timeout',
    '30',
    '--js-runtimes',
    '$runtimeName:$runtime',
    if (cookies?.isNotEmpty == true) ...['--cookies', cookies!],
  ];

  Future<Map<String, dynamic>> resolve(
    String url, {
    bool playlist = false,
    int limit = 100,
  }) async {
    final output = await _command(ytDlp, [
      ..._base,
      '--skip-download',
      '--dump-single-json',
      if (playlist) ...[
        '--flat-playlist',
        '--yes-playlist',
        '--playlist-end',
        '${limit.clamp(1, 500)}',
      ] else
        '--no-playlist',
      '--',
      validateUrl(url),
    ], null);
    Object? decoded;
    try {
      decoded = jsonDecode(output);
    } on FormatException {
      throw const DesktopDownloadException(
        'La fuente devolvió metadatos incompletos. Intenta nuevamente.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const DesktopDownloadException(
        'La fuente no devolvió metadatos válidos.',
      );
    }
    return decoded;
  }

  static String stableId(Map<String, dynamic> info, String url) => sha256
      .convert(
        utf8.encode(
          '${info['extractor_key'] ?? info['extractor'] ?? 'url'}:${info['id'] ?? validateUrl(url)}',
        ),
      )
      .toString();

  List<String> downloadArguments(
    String url,
    String output, {
    required String kind,
    required String format,
    String? quality,
    int? maxBytes,
  }) {
    if (!['audio', 'video'].contains(kind) ||
        (kind == 'audio'
            ? !['mp3', 'm4a'].contains(format)
            : format != 'mp4')) {
      throw const DesktopDownloadException(
        'Formato de descarga no compatible.',
      );
    }
    final q = quality ?? 'high';
    if (!['low', 'medium', 'high'].contains(q)) {
      throw const DesktopDownloadException('Calidad de descarga no válida.');
    }
    final height = {'low': 360, 'medium': 720, 'high': 1080}[q]!;
    return [
      ..._base,
      '--ffmpeg-location',
      ffmpeg,
      '--no-playlist',
      if (maxBytes != null) ...['--max-filesize', '$maxBytes'],
      '--newline',
      '--progress',
      '--progress-template',
      'download:LISTENFY_PROGRESS:%(progress.downloaded_bytes)s:%(progress.total_bytes,progress.total_bytes_estimate)s',
      if (kind == 'audio') ...[
        '-x',
        '--audio-format',
        format,
        '--audio-quality',
        {'low': '5', 'medium': '3', 'high': '0'}[q]!,
        '--postprocessor-args',
        'ffmpeg:-b:a ${{'low': '128k', 'medium': '192k', 'high': '320k'}[q]}',
      ] else ...[
        '-f',
        'bestvideo[ext=mp4][vcodec^=avc1][height<=$height][dynamic_range=SDR]+bestaudio[ext=m4a]/best[ext=mp4][vcodec^=avc1][height<=$height][dynamic_range=SDR]/bestvideo[ext=mp4][vcodec^=avc1][height<=$height]+bestaudio[ext=m4a]/best[ext=mp4][vcodec^=avc1][height<=$height]/best[ext=mp4][vcodec^=?avc1][height<=?$height]',
        '--merge-output-format',
        'mp4',
        '--postprocessor-args',
        'Merger+ffmpeg:-movflags +faststart',
      ],
      '-o',
      output,
      '--',
      validateUrl(url),
    ];
  }

  Future<void> download(
    String url,
    String destination, {
    required String kind,
    required String format,
    String? quality,
    int? maxBytes,
    void Function(int, int)? onProgress,
  }) async {
    final staging = await Directory(
      p.dirname(destination),
    ).createTemp('.listenfy-download-');
    try {
      final output = p.join(staging.path, 'media.$format');
      await _command(
        ytDlp,
        downloadArguments(
          url,
          output,
          kind: kind,
          format: format,
          quality: quality,
          maxBytes: maxBytes,
        ),
        (line) {
          final match = RegExp(
            r'LISTENFY_PROGRESS:(\d+):(\d+)',
          ).firstMatch(line);
          if (match != null) {
            onProgress?.call(int.parse(match[1]!), int.parse(match[2]!));
          }
        },
      );
      final file = File(output);
      if (!await file.exists() || await file.length() == 0) {
        throw const DesktopDownloadException(
          'La descarga local no generó un archivo válido.',
        );
      }
      await file.rename(destination);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  static Future<String> runCommand(
    String executable,
    List<String> arguments,
    void Function(String)? onLine, {
    bool Function()? cancelled,
  }) async {
    if (cancelled?.call() == true) {
      throw const DesktopDownloadException('Descarga cancelada.');
    }
    final Process process;
    try {
      final macBundle =
          Platform.isMacOS &&
          Platform.resolvedExecutable.contains('.app/Contents/MacOS/');
      process = await Process.start(
        executable,
        arguments,
        runInShell: false,
        environment: macBundle
            ? {
                'DENO_V8_FLAGS': '--jitless',
                'DENO_DIR': p.join(Directory.systemTemp.path, 'listenfy-deno'),
              }
            : null,
      );
    } on ProcessException catch (error) {
      throw DesktopDownloadException(
        'No se pudo iniciar la herramienta de descarga local. Revisa su instalación y los permisos de macOS.',
        diagnostic:
            'Process.start: executable=$executable, code=${error.errorCode}, message=${error.message}',
      );
    }
    final cancellation = cancelled == null
        ? null
        : Timer.periodic(const Duration(milliseconds: 250), (_) {
            if (cancelled()) process.kill();
          });
    final stdout = StringBuffer();
    final errors = <String>[];
    final out = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          stdout.writeln(line);
          onLine?.call(line);
        });
    final err = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          if (errors.length >= 30) errors.removeAt(0);
          errors.add(line);
          onLine?.call(line);
        });
    try {
      final code = await process.exitCode.timeout(
        arguments.contains('--progress')
            ? const Duration(minutes: 30)
            : arguments.contains('--skip-download')
            ? const Duration(minutes: 2)
            : const Duration(seconds: 15),
        onTimeout: () {
          process.kill();
          throw const DesktopDownloadException(
            'La descarga local superó el tiempo máximo.',
          );
        },
      );
      await out;
      await err;
      if (code != 0) {
        throw DesktopDownloadException(
          'No se pudo completar la descarga local (código $code). ${errors.join('\n')}',
        );
      }
      return stdout.toString();
    } finally {
      cancellation?.cancel();
      process.kill();
    }
  }
}

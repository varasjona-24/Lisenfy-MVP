import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Shared by Windows and macOS; does not require yt-dlp or a JS runtime.
class DesktopMediaTools {
  const DesktopMediaTools();

  static bool get supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static String localPath(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    return uri?.scheme == 'file' ? uri!.toFilePath() : trimmed;
  }

  Future<String> find(String tool) async {
    final executableDir = p.dirname(Platform.resolvedExecutable);
    final filename = Platform.isWindows ? '$tool.exe' : tool;
    final configured =
        Platform.environment['LISTENFY_${tool.toUpperCase()}_PATH'];
    final bundledMac =
        Platform.isMacOS &&
        Platform.resolvedExecutable.contains('.app/Contents/MacOS/');
    final candidates = <String>[
      if (configured != null && configured.isNotEmpty) configured,
      p.join(executableDir, 'download-tools', filename),
      p.join(executableDir, 'download-tools', 'bin', filename),
      p.join(
        executableDir,
        '..',
        'Resources',
        'download-tools',
        'bin',
        filename,
      ),
      p.join(executableDir, '..', 'Resources', 'download-tools', filename),
      if (Platform.isMacOS && !bundledMac) ...[
        '/opt/homebrew/bin/$tool',
        '/usr/local/bin/$tool',
      ],
      if (!bundledMac)
        for (final dir in (Platform.environment['PATH'] ?? '').split(
          Platform.isWindows ? ';' : ':',
        ))
          if (dir.isNotEmpty) p.join(dir, filename),
    ];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return p.normalize(candidate);
    }
    throw StateError('No se encontró $tool en las herramientas de escritorio.');
  }

  Future<ProcessResult> run(String tool, List<String> arguments) async {
    final process = await Process.start(await find(tool), arguments);
    final output = process.stdout.fold<List<int>>(
      [],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    final errors = process.stderr.transform(utf8.decoder).join();
    try {
      final code = await process.exitCode.timeout(const Duration(seconds: 30));
      final result = ProcessResult(
        process.pid,
        code,
        await output,
        await errors,
      );
      if (code != 0) throw StateError('$tool: ${result.stderr}');
      return result;
    } finally {
      process.kill();
    }
  }

  Future<Map<String, dynamic>> probe(String path) async {
    final result = await run('ffprobe', [
      '-v',
      'error',
      '-show_format',
      '-show_streams',
      '-of',
      'json',
      '-i',
      localPath(path),
    ]);
    return jsonDecode(utf8.decode(result.stdout as List<int>))
        as Map<String, dynamic>;
  }

  Future<Uint8List?> picture(String path, {required int streamIndex}) async {
    final result = await run('ffmpeg', [
      '-nostdin',
      '-v',
      'error',
      '-i',
      localPath(path),
      '-map',
      '0:$streamIndex',
      '-frames:v',
      '1',
      '-vf',
      "scale='min(1200,iw)':-2",
      '-f',
      'image2pipe',
      '-c:v',
      'mjpeg',
      'pipe:1',
    ]);
    final bytes = result.stdout as List<int>;
    return bytes.isEmpty ? null : Uint8List.fromList(bytes);
  }

  Future<Uint8List?> frame({
    required String source,
    required int positionMs,
    required int maxWidth,
    required int quality,
  }) async {
    final result = await run('ffmpeg', [
      '-nostdin',
      '-v',
      'error',
      '-ss',
      '${positionMs.clamp(0, 1 << 53) / 1000}',
      '-i',
      localPath(source),
      '-frames:v',
      '1',
      '-vf',
      "scale='min(${maxWidth.clamp(16, 3840)},iw)':-2",
      '-q:v',
      '${(31 - quality.clamp(1, 100) * 29 / 100).round()}',
      '-f',
      'image2pipe',
      '-c:v',
      'mjpeg',
      'pipe:1',
    ]);
    final bytes = result.stdout as List<int>;
    return bytes.isEmpty ? null : Uint8List.fromList(bytes);
  }
}

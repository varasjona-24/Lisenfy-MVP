import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:listenfy/app/data/downloads/desktop_download_engine.dart';

/// Run with: flutter run -d macos -t tool/probe_desktop_download_app.dart
/// Runs inside the actual app sandbox and removes every generated file.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Comprobando herramientas locales…')),
      ),
    ),
  );
  final directory = await Directory.systemTemp.createTemp(
    'listenfy-sandbox-probe-',
  );
  HttpServer? server;
  var failed = false;
  try {
    final engine = await DesktopDownloadEngine.discover();
    debugPrint('SANDBOX_PROBE yt-dlp=${engine.ytDlp}');
    debugPrint(
      'SANDBOX_PROBE version=${(await DesktopDownloadEngine.runCommand(engine.ytDlp, ['--version'], null)).trim()}',
    );
    final fixture = p.join(directory.path, 'fixture.mp4');
    await DesktopDownloadEngine.runCommand(engine.ffmpeg, [
      '-y',
      '-f',
      'lavfi',
      '-i',
      'color=c=blue:s=160x120:d=1',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=1',
      '-c:v',
      'libx264',
      '-c:a',
      'aac',
      '-shortest',
      fixture,
    ], null);
    final bytes = await File(fixture).readAsBytes();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType('video', 'mp4');
      request.response.contentLength = bytes.length;
      if (request.method != 'HEAD') request.response.add(bytes);
      await request.response.close();
    });
    final url = 'http://127.0.0.1:${server.port}/fixture.mp4';
    await engine.resolve(url);
    final output = p.join(directory.path, 'result.mp3');
    await engine.download(
      url,
      output,
      kind: 'audio',
      format: 'mp3',
      quality: 'low',
    );
    debugPrint('SANDBOX_PROBE audio=${await File(output).length()}');
    final runtimeVersion = await DesktopDownloadEngine.runCommand(
      engine.runtime,
      ['--version'],
      null,
    );
    debugPrint('SANDBOX_PROBE runtime=${runtimeVersion.split('\n').first}');
    final eval = await DesktopDownloadEngine.runCommand(engine.runtime, [
      'eval',
      'console.log(42)',
    ], null);
    if (eval.trim() != '42') {
      throw StateError('JavaScript runtime probe failed');
    }
    debugPrint('SANDBOX_PROBE JAVASCRIPT SUCCESS');
    const youtubeUrl = String.fromEnvironment('LISTENFY_PROBE_URL');
    if (youtubeUrl.isNotEmpty) {
      final info = await engine.resolve(youtubeUrl);
      debugPrint('SANDBOX_PROBE YouTube metadata resolved');
      await engine.download(
        youtubeUrl,
        p.join(directory.path, 'youtube.mp4'),
        kind: 'video',
        format: 'mp4',
        quality: 'low',
      );
      debugPrint('SANDBOX_PROBE YOUTUBE VIDEO SUCCESS: ${info['id']}');
    }
    debugPrint('SANDBOX_PROBE SUCCESS');
  } catch (error, stack) {
    failed = true;
    debugPrint('SANDBOX_PROBE FAILED: $error');
    if (error is DesktopDownloadException) debugPrint(error.diagnostic);
    debugPrintStack(stackTrace: stack);
  } finally {
    await server?.close(force: true);
    await directory.delete(recursive: true);
    // A separate entrypoint: never quits the regular Listenfy application.
    exit(failed ? 1 : 0);
  }
}

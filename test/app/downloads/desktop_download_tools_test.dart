import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:listenfy/app/data/downloads/desktop_download_engine.dart';

void main() {
  test(
    'real yt-dlp and FFmpeg download and convert a local HTTP fixture without backend',
    () async {
      final engine = await DesktopDownloadEngine.discover();
      final dir = await Directory.systemTemp.createTemp('listenfy-real-tools-');
      addTearDown(() => dir.delete(recursive: true));
      final fixture = File(p.join(dir.path, 'fixture.mp4'));
      final generated = await Process.run(engine.ffmpeg, [
        '-y',
        '-f',
        'lavfi',
        '-i',
        'color=c=blue:s=160x120:d=2',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=2',
        '-c:v',
        'libx264',
        '-c:a',
        'aac',
        '-shortest',
        fixture.path,
      ]);
      expect(generated.exitCode, 0, reason: generated.stderr.toString());
      final bytes = await fixture.readAsBytes();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType('video', 'mp4');
        request.response.contentLength = bytes.length;
        if (request.method != 'HEAD') request.response.add(bytes);
        await request.response.close();
      });
      final url = 'http://127.0.0.1:${server.port}/fixture.mp4';
      final info = await engine.resolve(url);
      expect(info['id'], isNotNull);
      final output = p.join(dir.path, 'result.mp3');
      await engine.download(
        url,
        output,
        kind: 'audio',
        format: 'mp3',
        quality: 'low',
      );
      expect(await File(output).length(), greaterThan(1000));
      final videoOutput = p.join(dir.path, 'result.mp4');
      await engine.download(
        url,
        videoOutput,
        kind: 'video',
        format: 'mp4',
        quality: 'low',
      );
      expect(await File(videoOutput).length(), greaterThan(1000));
      expect(
        await dir.list().where((entry) => entry is Directory).isEmpty,
        isTrue,
      );
    },
    skip: !const bool.fromEnvironment('RUN_DESKTOP_DOWNLOAD_TOOLS'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

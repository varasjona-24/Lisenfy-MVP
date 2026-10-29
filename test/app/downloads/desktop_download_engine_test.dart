import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:listenfy/app/data/downloads/desktop_download_engine.dart';

DesktopDownloadEngine engine(DownloadCommand command) => DesktopDownloadEngine(
  ytDlp: '/tools/yt-dlp',
  ffmpeg: '/tools/ffmpeg',
  runtime: '/tools/deno',
  command: command,
);

void main() {
  test('validates URLs and keeps URL as a single argument after separator', () {
    final service = engine((_, _, _) async => '');
    expect(
      () => service.downloadArguments(
        'file:///etc/passwd',
        'out.mp3',
        kind: 'audio',
        format: 'mp3',
      ),
      throwsA(isA<DesktopDownloadException>()),
    );
    expect(
      () => service.downloadArguments(
        'https://example.com/a',
        'out.exe',
        kind: 'audio',
        format: 'exe',
      ),
      throwsA(isA<DesktopDownloadException>()),
    );
    const url = 'https://example.com/watch?v=1&x=hello%20world';
    final args = service.downloadArguments(
      url,
      'a path/output.mp3',
      kind: 'audio',
      format: 'mp3',
      quality: 'medium',
    );
    expect(args.last, url);
    expect(args[args.length - 2], '--');
    expect(args, contains('ffmpeg:-b:a 192k'));
    expect(args, contains('a path/output.mp3'));
  });
  test('accepts the reported YouTube URL with clipboard isolation marks', () {
    const url = 'https://youtu.be/O8BLUzAxNmQ?si=ycHtUXHwV7UQu5Jv';
    expect(DesktopDownloadEngine.validateUrl(url), url);
    expect(DesktopDownloadEngine.validateUrl('\u2068$url\u2069'), url);
    expect(DesktopDownloadEngine.validateUrl(' \u200e$url\u200f '), url);
    expect(
      () => DesktopDownloadEngine.validateUrl('not a url'),
      throwsA(isA<DesktopDownloadException>()),
    );
  });
  test(
    'process launch failures are readable and retain diagnostic codes',
    () async {
      await expectLater(
        DesktopDownloadEngine.runCommand(
          '/nonexistent/listenfy-tool',
          const [],
          null,
        ),
        throwsA(
          isA<DesktopDownloadException>().having(
            (e) => e.diagnostic,
            'diagnostic',
            contains('Process.start'),
          ),
        ),
      );
    },
  );
  test('discovers bundled tools without depending on Homebrew', () async {
    final dir = await Directory.systemTemp.createTemp('listenfy-bundle-test-');
    addTearDown(() => dir.delete(recursive: true));
    final contents = p.join(dir.path, 'Listenfy.app', 'Contents');
    final tools = p.join(contents, 'Resources', 'download-tools');
    for (final path in ['yt-dlp/yt-dlp_macos', 'bin/ffmpeg', 'bin/deno']) {
      final file = File(p.join(tools, path));
      await file.parent.create(recursive: true);
      await file.writeAsString('fixture');
    }
    final discovered = await DesktopDownloadEngine.discover(
      applicationExecutable: p.join(contents, 'MacOS', 'Listenfy'),
      environment: const {'PATH': '/usr/local/bin'},
    );
    expect(
      discovered.ytDlp,
      contains('Resources/download-tools/yt-dlp/yt-dlp_macos'),
    );
    expect(discovered.ffmpeg, contains('Resources/download-tools/bin/ffmpeg'));
    if (Platform.isMacOS) {
      await File(discovered.ytDlp).delete();
      await expectLater(
        DesktopDownloadEngine.discover(
          applicationExecutable: p.join(contents, 'MacOS', 'Listenfy'),
          environment: const {'PATH': '/usr/local/bin'},
        ),
        throwsA(isA<DesktopDownloadException>()),
      );
    }
  });
  test('video keeps compatible codecs, quality and merge behavior', () {
    final args = engine((_, _, _) async => '').downloadArguments(
      'https://example.com/a',
      'out.mp4',
      kind: 'video',
      format: 'mp4',
      quality: 'low',
    );
    expect(args[args.indexOf('-f') + 1], contains('height<=360'));
    expect(args[args.indexOf('-f') + 1], contains('vcodec^=avc1'));
    expect(args, contains('--merge-output-format'));
  });
  test('rejects invalid metadata with a download error', () async {
    final service = engine((_, _, _) async => 'invalid json');
    await expectLater(
      service.resolve('https://example.com/a'),
      throwsA(isA<DesktopDownloadException>()),
    );
  });
  test('does not publish missing output and cleans staging', () async {
    final dir = await Directory.systemTemp.createTemp('listenfy-empty-');
    addTearDown(() => dir.delete(recursive: true));
    await expectLater(
      engine((_, _, _) async => '').download(
        'https://example.com/a',
        p.join(dir.path, 'out.mp3'),
        kind: 'audio',
        format: 'mp3',
      ),
      throwsA(isA<DesktopDownloadException>()),
    );
    expect(await dir.list().isEmpty, isTrue);
  });
  test('stable identity ignores changed titles and source URL aliases', () {
    expect(
      DesktopDownloadEngine.stableId({
        'id': 'abc',
        'extractor': 'youtube',
        'title': 'Old',
      }, 'https://youtu.be/abc'),
      DesktopDownloadEngine.stableId({
        'id': 'abc',
        'extractor': 'youtube',
        'title': 'New',
      }, 'https://youtube.com/watch?v=abc'),
    );
  });
  test('resolves metadata and limits playlist extraction', () async {
    final service = engine((_, args, _) async {
      expect(args, contains('--flat-playlist'));
      expect(args[args.indexOf('--playlist-end') + 1], '50');
      return '{"id":"list","entries":[]}';
    });
    expect(
      (await service.resolve(
        'https://example.com/list',
        playlist: true,
        limit: 50,
      ))['id'],
      'list',
    );
  });
  test(
    'publishes completed file, reports progress and removes staging',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'listenfy-download-test-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final progress = <int>[];
      final service = engine((_, args, onLine) async {
        await File(args[args.indexOf('-o') + 1]).writeAsBytes([1, 2, 3]);
        onLine?.call('LISTENFY_PROGRESS:3:3');
        return '';
      });
      final destination = p.join(dir.path, 'song.mp3');
      await service.download(
        'https://example.com/a',
        destination,
        kind: 'audio',
        format: 'mp3',
        onProgress: (r, t) => progress.addAll([r, t]),
      );
      expect(await File(destination).readAsBytes(), [1, 2, 3]);
      expect(progress, [3, 3]);
      expect(await dir.list().length, 1);
    },
  );
  test(
    'failed download cleans partials without replacing existing media',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'listenfy-download-fail-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final destination = File(p.join(dir.path, 'song.mp3'));
      await destination.writeAsBytes([9]);
      final service = engine((_, args, _) async {
        await File(args[args.indexOf('-o') + 1]).writeAsBytes([1]);
        throw const DesktopDownloadException('download failed');
      });
      await expectLater(
        service.download(
          'https://example.com/a',
          destination.path,
          kind: 'audio',
          format: 'mp3',
        ),
        throwsA(isA<DesktopDownloadException>()),
      );
      expect(await destination.readAsBytes(), [9]);
      expect(await dir.list().length, 1);
    },
  );
}

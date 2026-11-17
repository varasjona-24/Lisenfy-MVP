import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/services/desktop_media_tools.dart';
import 'package:listenfy/app/services/local_media_metadata_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test('decodes file URIs with spaces without changing remote sources', () {
    final path = p.join(Directory.systemTemp.path, 'cover with spaces.mp3');
    expect(DesktopMediaTools.localPath(Uri.file(path).toString()), path);
    expect(
      DesktopMediaTools.localPath('https://example.com/video.mp4'),
      'https://example.com/video.mp4',
    );
  });

  test(
    'real tools extract tags, embedded cover and original frame aspect ratio',
    () async {
      const tools = DesktopMediaTools();
      final dir = await Directory.systemTemp.createTemp('listenfy-media-');
      addTearDown(() => dir.delete(recursive: true));
      final cover = p.join(dir.path, 'cover.jpg');
      final audio = p.join(dir.path, 'tagged audio.mp3');
      final video = p.join(dir.path, 'portrait.mp4');
      await tools.run('ffmpeg', [
        '-nostdin',
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=c=red:s=160x160',
        '-frames:v',
        '1',
        cover,
      ]);
      await tools.run('ffmpeg', [
        '-nostdin',
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=2',
        '-i',
        cover,
        '-map',
        '0:a',
        '-map',
        '1:v',
        '-c:a',
        'libmp3lame',
        '-c:v',
        'copy',
        '-id3v2_version',
        '3',
        '-disposition:v',
        'attached_pic',
        '-metadata',
        'title=Prueba canción',
        '-metadata',
        'artist=Artista',
        '-metadata',
        'album=Álbum',
        audio,
      ]);
      final metadata = await LocalMediaMetadataService().readMediaMetadata(
        Uri.file(audio).toString(),
      );
      expect(metadata, isNotNull);
      expect(metadata!.title, 'Prueba canción');
      expect(metadata.artist, 'Artista');
      expect(metadata.album, 'Álbum');
      expect(metadata.durationSeconds, 2);
      expect(metadata.pictureBytes, isNotEmpty);
      await tools.run('ffmpeg', [
        '-nostdin',
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=c=blue:s=120x200:d=2',
        '-c:v',
        'mpeg4',
        video,
      ]);
      final bytes = await tools.frame(
        source: video,
        positionMs: 500,
        maxWidth: 60,
        quality: 90,
      );
      expect(bytes, isNotEmpty);
      final image = File(p.join(dir.path, 'frame.jpg'));
      await image.writeAsBytes(bytes!);
      final info = await tools.probe(image.path);
      final stream = (info['streams'] as List).first as Map;
      expect(stream['width'], 60);
      expect(stream['height'], 100);
      // Corrupt input must fail rather than returning a successful empty probe.
      final corrupt = File(p.join(dir.path, 'broken.mp3'));
      await corrupt.writeAsString(jsonEncode({'not': 'audio'}));
      expect(
        await LocalMediaMetadataService().readMediaMetadata(corrupt.path),
        isNull,
      );
    },
    skip: !const bool.fromEnvironment('RUN_DESKTOP_MEDIA_TOOLS'),
  );
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/models/audio_cleanup.dart';
import 'package:listenfy/app/services/audio_cleanup_service.dart';
import 'package:listenfy/app/services/desktop_audio_cleanup.dart';
import 'package:listenfy/app/services/desktop_media_tools.dart';
import 'package:path/path.dart' as p;

AudioSilenceSegment _range(int start, int end) => AudioSilenceSegment(
  startMs: start,
  endMs: end,
  durationMs: end - start,
  meanDb: -120,
);

Future<File> _wave(
  String path,
  List<(int, int)> parts, {
  int channels = 2,
}) async {
  const rate = 8000;
  final frames = parts.fold<int>(
    0,
    (sum, part) => sum + part.$1 * rate ~/ 1000,
  );
  final data = ByteData(44 + frames * channels * 2);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  data.setUint32(4, data.lengthInBytes - 8, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * channels * 2, Endian.little);
  data.setUint16(32, channels * 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, frames * channels * 2, Endian.little);
  var cursor = 44;
  for (final part in parts) {
    for (var frame = 0; frame < part.$1 * rate ~/ 1000; frame++) {
      for (var channel = 0; channel < channels; channel++) {
        data.setInt16(
          cursor,
          frame % 16 < 8 ? part.$2 : -part.$2,
          Endian.little,
        );
        cursor += 2;
      }
    }
  }
  return File(path).writeAsBytes(data.buffer.asUint8List());
}

void main() {
  group(
    'real desktop silence cleanup',
    () {
      late Directory dir;
      late File source;
      late DesktopAudioCleanup engine;
      late AudioCleanupService service;
      setUp(() async {
        dir = await Directory.systemTemp.createTemp('listenfy-cleanup-test-');
        source = await _wave(p.join(dir.path, 'song with spaces.wav'), [
          (1000, 0),
          (1000, 5000),
          (1000, 0),
          (1000, 5000),
          (1000, 0),
        ]);
        engine = DesktopAudioCleanup(
          outputDirectory: () async => Directory(p.join(dir.path, 'results')),
        );
        service = AudioCleanupService(desktop: engine);
      });
      tearDown(() => dir.delete(recursive: true));

      test(
        'detects leading, internal and trailing silence with measured RMS',
        () async {
          final result = await service.analyzeSilences(
            localPath: source.uri.toString(),
            minSilenceMs: 500,
          );
          expect(result, isNotNull);
          expect(result!.durationMs, 5000);
          expect(result.channels, 2);
          expect(result.sampleRate, 8000);
          expect(result.segments.map((s) => (s.startMs, s.endMs)), [
            (0, 1000),
            (2000, 3000),
            (4000, 5000),
          ]);
          expect(result.segments.every((s) => s.meanDb == -120), isTrue);
          final quiet = await _wave(p.join(dir.path, 'quiet.wav'), [
            (1000, 100),
          ]);
          final measured = await service.analyzeSilences(
            localPath: quiet.path,
            minSilenceMs: 500,
          );
          expect(measured!.segments.single.meanDb, closeTo(-50.31, .05));
        },
      );

      test('ignores short pauses and keeps audible audio', () async {
        final short = await _wave(p.join(dir.path, 'short.wav'), [
          (1000, 5000),
          (200, 0),
          (1000, 5000),
        ], channels: 1);
        final result = await service.analyzeSilences(
          localPath: short.path,
          minSilenceMs: 500,
        );
        expect(result!.segments, isEmpty);
        expect(result.channels, 1);
      });

      test(
        'removes only selected ranges, preserves source and fades stereo joins',
        () async {
          final original = await source.readAsBytes();
          final result = await service.renderCleanedAudio(
            localPath: source.path,
            removeSegments: [_range(2000, 3000)],
          );
          expect(result, isNotNull);
          expect(result!.outputPath, isNot(source.path));
          expect(p.extension(result.outputPath), '.m4a');
          expect(
            await File(result.outputPath).length(),
            lessThan(original.length),
          );
          expect(result.originalDurationMs, 5000);
          expect(result.cleanedDurationMs, 4000);
          expect(result.removedDurationMs, 1000);
          expect(result.removedSegmentsCount, 1);
          expect(await source.readAsBytes(), original);
          const tools = DesktopMediaTools();
          final probe = await tools.probe(result.outputPath);
          expect((probe['streams'] as List).first['channels'], 2);
          expect((probe['streams'] as List).first['codec_name'], 'aac');
          expect((probe['streams'] as List).first['sample_rate'], '8000');
          final analysis = await service.analyzeSilences(
            localPath: result.outputPath,
            minSilenceMs: 500,
          );
          expect(
            analysis!.segments.length,
            2,
          ); // Unselected edge silences remain.
          final raw = p.join(dir.path, 'check.pcm');
          await tools.run('ffmpeg', [
            '-nostdin',
            '-v',
            'error',
            '-i',
            result.outputPath,
            '-f',
            's16le',
            '-c:a',
            'pcm_s16le',
            raw,
          ]);
          final samples = ByteData.sublistView(await File(raw).readAsBytes());
          expect(
            samples.getInt16(16000 * 4, Endian.little).abs(),
            lessThan(1200),
          );
          expect(
            samples.getInt16(16000 * 4 + 2, Endian.little).abs(),
            lessThan(1200),
          );
          expect(
            samples.getInt16(15999 * 4, Endian.little).abs(),
            lessThan(1200),
          );
        },
      );

      test(
        'external tool timeout stops the process before returning',
        () async {
          await expectLater(
            const DesktopMediaTools().run('ffmpeg', [
              '-nostdin',
              '-v',
              'error',
              '-re',
              '-f',
              'lavfi',
              '-i',
              'anullsrc=r=8000:cl=mono',
              '-t',
              '10',
              '-f',
              'null',
              '-',
            ], timeout: const Duration(milliseconds: 100)),
            throwsA(isA<TimeoutException>()),
          );
        },
      );

      test(
        'normalizes overlap and bounds and rejects removing all audio',
        () async {
          final result = await engine.render(
            path: source.path,
            fadeMs: 0,
            segments: [
              _range(400, 1000),
              _range(-100, 500),
              _range(4500, 10000),
            ],
          );
          expect(result.cleanedDurationMs, 3500);
          expect(result.removedSegmentsCount, 2);
          await expectLater(
            engine.render(
              path: source.path,
              fadeMs: 20,
              segments: [_range(0, 5000)],
            ),
            throwsFormatException,
          );
          await expectLater(
            engine.render(
              path: source.path,
              fadeMs: 20,
              segments: [_range(6000, 7000)],
            ),
            throwsFormatException,
          );
          expect(await Directory(p.join(dir.path, 'results')).list().length, 1);
          expect(await source.exists(), isTrue);
        },
      );
    },
    skip: !const bool.fromEnvironment('RUN_DESKTOP_MEDIA_TOOLS'),
  );
}

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_cleanup.dart';
import 'desktop_media_tools.dart';

/// Decodes through FFmpeg and processes bounded PCM chunks in a worker isolate.
class DesktopAudioCleanup {
  DesktopAudioCleanup({Future<Directory> Function()? outputDirectory})
    : _outputDirectory = outputDirectory ?? _defaultDirectory;

  final Future<Directory> Function() _outputDirectory;
  static const _tools = DesktopMediaTools();

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join(
      (await getApplicationDocumentsDirectory()).path,
      'downloads',
      'cleaned_audio',
    ),
  );

  Future<({int rate, int channels, int frames})> _decode(
    String source,
    String output,
  ) async {
    final path = DesktopMediaTools.localPath(source);
    if (!await File(path).exists()) {
      throw const FileSystemException('Audio local no encontrado.');
    }
    final metadata = await _tools.probe(path);
    final streams = (metadata['streams'] as List? ?? []).whereType<Map>();
    final audio = streams
        .where((stream) => stream['codec_type'] == 'audio')
        .firstOrNull;
    final rate = int.tryParse('${audio?['sample_rate']}') ?? 0;
    final channels = (audio?['channels'] as num?)?.toInt() ?? 0;
    if (rate <= 0 || channels <= 0) {
      throw const FormatException('No hay una pista de audio válida.');
    }
    await _tools.run('ffmpeg', [
      '-nostdin',
      '-v',
      'error',
      '-i',
      path,
      '-map',
      '0:a:0',
      '-vn',
      '-ar',
      '$rate',
      '-ac',
      '$channels',
      '-c:a',
      'pcm_s16le',
      '-f',
      's16le',
      output,
    ], timeout: const Duration(minutes: 15));
    final frames = await File(output).length() ~/ (channels * 2);
    if (frames <= 0) throw const FormatException('Audio vacío.');
    return (rate: rate, channels: channels, frames: frames);
  }

  Future<AudioSilenceAnalysis> analyze({
    required String path,
    required int minSilenceMs,
    required int windowMs,
    required double thresholdDb,
  }) async {
    if (!thresholdDb.isFinite) {
      throw ArgumentError.value(thresholdDb, 'thresholdDb');
    }
    final temp = await Directory.systemTemp.createTemp('listenfy-silence-');
    try {
      final raw = p.join(temp.path, 'source.pcm');
      final pcm = await _decode(path, raw);
      return await Isolate.run(
        () => _analyzePcm(
          raw,
          pcm.rate,
          pcm.channels,
          pcm.frames,
          math.max(500, minSilenceMs),
          windowMs.clamp(10, 1000),
          thresholdDb,
        ),
      );
    } finally {
      await temp.delete(recursive: true);
    }
  }

  Future<AudioCleanupRenderResult> render({
    required String path,
    required List<AudioSilenceSegment> segments,
    required int fadeMs,
  }) async {
    final temp = await Directory.systemTemp.createTemp('listenfy-cleanup-');
    File? output;
    var completed = false;
    try {
      final raw = p.join(temp.path, 'source.pcm');
      final pcm = await _decode(path, raw);
      final remove = _normalizeRanges(segments, pcm.rate, pcm.frames);
      if (remove.isEmpty) {
        throw const FormatException('No hay intervalos válidos para recortar.');
      }
      final keep = <(int, int)>[];
      var cursor = 0;
      for (final range in remove) {
        if (range.$1 > cursor) keep.add((cursor, range.$1));
        cursor = range.$2;
      }
      if (cursor < pcm.frames) keep.add((cursor, pcm.frames));
      if (keep.isEmpty) {
        throw const FormatException('No se puede eliminar todo el audio.');
      }
      final cleaned = p.join(temp.path, 'cleaned.pcm');
      final fadeFrames = fadeMs.clamp(0, 80) * pcm.rate ~/ 1000;
      await Isolate.run(
        () => _copyKeptPcm(raw, cleaned, keep, pcm.channels, fadeFrames),
      );
      final directory = await _outputDirectory();
      await directory.create(recursive: true);
      output = File(p.join(directory.path, 'clean_${const Uuid().v4()}.m4a'));
      await _tools.run('ffmpeg', [
        '-nostdin',
        '-v',
        'error',
        '-f',
        's16le',
        '-ar',
        '${pcm.rate}',
        '-ac',
        '${pcm.channels}',
        '-i',
        cleaned,
        '-c:a',
        'aac',
        '-ar',
        '${pcm.rate}',
        '-b:a',
        '256k',
        '-movflags',
        '+faststart',
        output.path,
      ], timeout: const Duration(minutes: 15));
      final cleanedFrames = await File(cleaned).length() ~/ (pcm.channels * 2);
      final originalMs = pcm.frames * 1000 ~/ pcm.rate;
      final cleanedMs = cleanedFrames * 1000 ~/ pcm.rate;
      if (await output.length() <= 44) {
        throw const FormatException('No se generó audio válido.');
      }
      final verified = await _tools.probe(output.path);
      final audio = (verified['streams'] as List)
          .whereType<Map>()
          .where((stream) => stream['codec_type'] == 'audio')
          .firstOrNull;
      final duration = double.tryParse(
        '${(verified['format'] as Map?)?['duration']}',
      );
      final tolerance = math.max(100.0, 2048 * 1000 / pcm.rate);
      if (audio?['codec_name'] != 'aac' ||
          audio?['channels'] != pcm.channels ||
          '${audio?['sample_rate']}' != '${pcm.rate}' ||
          duration == null ||
          !duration.isFinite ||
          (duration * 1000 - cleanedMs).abs() > tolerance) {
        throw const FormatException(
          'La versión limpia no superó la validación.',
        );
      }
      await _tools.run('ffmpeg', [
        '-nostdin',
        '-v',
        'error',
        '-xerror',
        '-i',
        output.path,
        '-map',
        '0:a:0',
        '-f',
        'null',
        '-',
      ], timeout: const Duration(minutes: 15));
      completed = true;
      return AudioCleanupRenderResult(
        outputPath: output.path,
        originalDurationMs: originalMs,
        cleanedDurationMs: cleanedMs,
        removedDurationMs: originalMs - cleanedMs,
        sampleRate: pcm.rate,
        channels: pcm.channels,
        removedSegmentsCount: remove.length,
      );
    } finally {
      if (!completed && output != null && await output.exists()) {
        await output.delete();
      }
      await temp.delete(recursive: true);
    }
  }
}

AudioSilenceAnalysis _analyzePcm(
  String path,
  int rate,
  int channels,
  int frames,
  int minSilenceMs,
  int windowMs,
  double thresholdDb,
) {
  final file = File(path).openSync();
  final windowFrames = math.max(1, windowMs * rate ~/ 1000);
  final found = <AudioSilenceSegment>[];
  int? silenceStart;
  var dbSum = 0.0;
  var windows = 0;
  void finish(int frame) {
    if (silenceStart == null) return;
    final start = silenceStart! * 1000 ~/ rate;
    final end = frame * 1000 ~/ rate;
    if (end - start >= minSilenceMs) {
      found.add(
        AudioSilenceSegment(
          startMs: start,
          endMs: end,
          durationMs: end - start,
          meanDb: dbSum / windows,
        ),
      );
    }
    silenceStart = null;
    dbSum = 0;
    windows = 0;
  }

  try {
    for (var frame = 0; frame < frames; frame += windowFrames) {
      final bytes = file.readSync(
        math.min(windowFrames, frames - frame) * channels * 2,
      );
      final data = ByteData.sublistView(bytes);
      var sum = 0.0;
      for (var offset = 0; offset < data.lengthInBytes; offset += 2) {
        final sample = data.getInt16(offset, Endian.little) / 32768;
        sum += sample * sample;
      }
      final rms = math.sqrt(sum / (bytes.length / 2));
      final db = rms <= 1e-9
          ? -120.0
          : math.max(-120.0, 20 * math.log(rms) / math.ln10);
      if (db <= thresholdDb) {
        silenceStart ??= frame;
        dbSum += db;
        windows++;
      } else {
        finish(frame);
      }
    }
    finish(frames);
  } finally {
    file.closeSync();
  }
  final merged = <AudioSilenceSegment>[];
  for (final next in found) {
    if (merged.isNotEmpty &&
        next.startMs - merged.last.endMs <= math.max(20, windowMs * 2)) {
      final last = merged.removeLast();
      merged.add(
        AudioSilenceSegment(
          startMs: last.startMs,
          endMs: next.endMs,
          durationMs: next.endMs - last.startMs,
          meanDb:
              (last.meanDb * last.durationMs + next.meanDb * next.durationMs) /
              (last.durationMs + next.durationMs),
        ),
      );
    } else {
      merged.add(next);
    }
  }
  return AudioSilenceAnalysis(
    durationMs: frames * 1000 ~/ rate,
    sampleRate: rate,
    channels: channels,
    segments: merged,
  );
}

List<(int, int)> _normalizeRanges(
  List<AudioSilenceSegment> segments,
  int rate,
  int frames,
) {
  final ranges =
      segments
          .map(
            (segment) => (
              (segment.startMs * rate ~/ 1000).clamp(0, frames),
              (segment.endMs * rate ~/ 1000).clamp(0, frames),
            ),
          )
          .where((range) => range.$2 > range.$1)
          .toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[];
  for (final next in ranges) {
    if (merged.isNotEmpty && next.$1 <= merged.last.$2) {
      final previous = merged.removeLast();
      merged.add((previous.$1, math.max(previous.$2, next.$2)));
    } else {
      merged.add(next);
    }
  }
  return merged;
}

void _copyKeptPcm(
  String source,
  String target,
  List<(int, int)> keep,
  int channels,
  int fadeFrames,
) {
  final input = File(source).openSync();
  final output = File(target).openSync(mode: FileMode.write);
  final frameBytes = channels * 2;
  try {
    for (var index = 0; index < keep.length; index++) {
      final range = keep[index];
      final length = range.$2 - range.$1;
      final fade = math.min(fadeFrames, length ~/ 2);
      input.setPositionSync(range.$1 * frameBytes);
      for (var position = 0; position < length;) {
        final count = math.min(16384, length - position);
        final bytes = input.readSync(count * frameBytes);
        if (bytes.length != count * frameBytes) {
          throw const FormatException('Audio incompleto.');
        }
        if (fade > 0) {
          final data = ByteData.sublistView(bytes);
          for (var frame = 0; frame < count; frame++) {
            final relative = position + frame;
            final gainIn = index > 0 ? math.min(1.0, relative / fade) : 1.0;
            final gainOut = index < keep.length - 1
                ? math.min(1.0, (length - 1 - relative) / fade)
                : 1.0;
            final gain = math.min(gainIn, gainOut);
            if (gain == 1) continue;
            for (var channel = 0; channel < channels; channel++) {
              final offset = (frame * channels + channel) * 2;
              data.setInt16(
                offset,
                (data.getInt16(offset, Endian.little) * gain).round(),
                Endian.little,
              );
            }
          }
        }
        output.writeFromSync(bytes);
        position += count;
      }
    }
  } finally {
    input.closeSync();
    output.closeSync();
  }
}

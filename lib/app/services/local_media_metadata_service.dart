import 'package:flutter/services.dart';
import 'package:get/get.dart';

class LocalAudioMetadata {
  const LocalAudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.durationSeconds,
    this.pictureBytes,
  });

  final String? title;
  final String? artist;
  final String? album;
  final int? durationSeconds;
  final Uint8List? pictureBytes;
}

class LocalMediaMetadataService extends GetxService {
  static const MethodChannel _channel = MethodChannel(
    'listenfy/media_metadata',
  );

  Future<LocalAudioMetadata?> readAudioMetadata(String path) async {
    return readMediaMetadata(path);
  }

  Future<LocalAudioMetadata?> readMediaMetadata(String path) async {
    final clean = path.replaceFirst('file://', '').trim();
    if (clean.isEmpty) return null;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'extractAudioMetadata',
        {'path': clean},
      );
      if (result == null) return null;

      final title = _asCleanString(result['title']);
      final artist = _asCleanString(result['artist']);
      final album = _asCleanString(result['album']);
      final durationMs = _asInt(result['durationMs']);
      final pictureBytes = _asBytes(result['picture']);

      return LocalAudioMetadata(
        title: title,
        artist: artist,
        album: album,
        durationSeconds: durationMs != null && durationMs > 0
            ? durationMs ~/ 1000
            : null,
        pictureBytes: pictureBytes,
      );
    } catch (_) {
      return null;
    }
  }

  String? _asCleanString(dynamic raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower == '<unknown>' || lower == 'unknown' || lower == 'null') {
      return null;
    }
    return value;
  }

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  Uint8List? _asBytes(dynamic raw) {
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    if (raw is List) {
      final out = <int>[];
      for (final v in raw) {
        if (v is int) {
          out.add(v);
        } else if (v is num) {
          out.add(v.toInt());
        } else {
          return null;
        }
      }
      return Uint8List.fromList(out);
    }
    return null;
  }
}

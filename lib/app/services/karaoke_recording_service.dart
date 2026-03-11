import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class KaraokeSessionStart {
  const KaraokeSessionStart({
    required this.sourcePath,
    required this.instrumentalPath,
    required this.voicePath,
    required this.sampleRate,
    required this.channels,
    required this.estimatedDurationMs,
    required this.startedAtMs,
  });

  final String sourcePath;
  final String instrumentalPath;
  final String voicePath;
  final int sampleRate;
  final int channels;
  final int estimatedDurationMs;
  final int startedAtMs;

  factory KaraokeSessionStart.fromJson(Map<String, dynamic> json) {
    return KaraokeSessionStart(
      sourcePath: json['sourcePath']?.toString() ?? '',
      instrumentalPath: json['instrumentalPath']?.toString() ?? '',
      voicePath: json['voicePath']?.toString() ?? '',
      sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 0,
      channels: (json['channels'] as num?)?.toInt() ?? 0,
      estimatedDurationMs: (json['estimatedDurationMs'] as num?)?.toInt() ?? 0,
      startedAtMs: (json['startedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class KaraokeSessionStopResult {
  const KaraokeSessionStopResult({
    required this.sourcePath,
    required this.instrumentalPath,
    required this.voicePath,
    required this.mixedPath,
    required this.recordedMs,
    required this.durationMs,
    required this.sampleRate,
    required this.channels,
  });

  final String sourcePath;
  final String instrumentalPath;
  final String voicePath;
  final String? mixedPath;
  final int recordedMs;
  final int durationMs;
  final int sampleRate;
  final int channels;

  factory KaraokeSessionStopResult.fromJson(Map<String, dynamic> json) {
    final mixedRaw = json['mixedPath']?.toString().trim();
    return KaraokeSessionStopResult(
      sourcePath: json['sourcePath']?.toString() ?? '',
      instrumentalPath: json['instrumentalPath']?.toString() ?? '',
      voicePath: json['voicePath']?.toString() ?? '',
      mixedPath: (mixedRaw == null || mixedRaw.isEmpty) ? null : mixedRaw,
      recordedMs: (json['recordedMs'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 0,
      channels: (json['channels'] as num?)?.toInt() ?? 0,
    );
  }
}

class KaraokeRecordingService {
  static const MethodChannel _channel = MethodChannel(
    'listenfy/karaoke_recorder',
  );

  Future<bool> isRecording() async {
    if (!Platform.isAndroid) return false;
    try {
      final raw = await _channel.invokeMethod<bool>('isRecording');
      return raw ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<KaraokeSessionStart?> startSession({
    required String sourcePath,
    double instrumentalGain = 1.0,
    String? instrumentalPath,
  }) async {
    if (!Platform.isAndroid) return null;
    final normalizedPath = sourcePath.replaceFirst('file://', '').trim();
    if (normalizedPath.isEmpty) return null;

    final granted = await _ensureMicrophonePermission();
    if (!granted) {
      throw Exception('Permiso de micrófono requerido para grabar karaoke.');
    }

    try {
      final raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('startSession', {
            'sourcePath': normalizedPath,
            'instrumentalGain': instrumentalGain.clamp(0.1, 1.8),
            if (instrumentalPath != null && instrumentalPath.trim().isNotEmpty)
              'instrumentalPath': instrumentalPath.trim(),
          });
      if (raw == null) return null;
      return KaraokeSessionStart.fromJson(Map<String, dynamic>.from(raw));
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'No se pudo iniciar sesión karaoke.');
    } catch (e) {
      debugPrint('karaoke start error: $e');
      throw Exception('No se pudo iniciar sesión karaoke.');
    }
  }

  Future<KaraokeSessionStopResult?> stopSession({
    bool exportMixed = true,
    double voiceGain = 1.0,
    double instrumentalGain = 0.8,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('stopSession', {
            'exportMixed': exportMixed,
            'voiceGain': voiceGain.clamp(0.0, 2.0),
            'instrumentalGain': instrumentalGain.clamp(0.0, 2.0),
          });
      if (raw == null) return null;
      return KaraokeSessionStopResult.fromJson(Map<String, dynamic>.from(raw));
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'No se pudo detener sesión karaoke.');
    } catch (e) {
      debugPrint('karaoke stop error: $e');
      throw Exception('No se pudo detener sesión karaoke.');
    }
  }

  Future<bool> cancelSession() async {
    if (!Platform.isAndroid) return false;
    try {
      final raw = await _channel.invokeMethod<bool>('cancelSession');
      return raw ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'No se pudo cancelar sesión karaoke.');
    } catch (e) {
      debugPrint('karaoke cancel error: $e');
      return false;
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final requested = await Permission.microphone.request();
    return requested.isGranted;
  }
}

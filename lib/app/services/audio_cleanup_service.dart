import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/audio_cleanup.dart';
import 'desktop_audio_cleanup.dart';
import 'desktop_media_tools.dart';

class AudioCleanupService {
  AudioCleanupService({DesktopAudioCleanup? desktop})
    : _desktop = desktop ?? DesktopAudioCleanup();

  final DesktopAudioCleanup _desktop;
  static const MethodChannel _channel = MethodChannel('listenfy/audio_cleanup');

  Future<AudioSilenceAnalysis?> analyzeSilences({
    required String localPath,
    int minSilenceMs = 4000,
    int windowMs = 50,
    double thresholdDb = -35,
  }) async {
    final path = localPath.trim();
    if (path.isEmpty) return null;

    try {
      if (DesktopMediaTools.supported) {
        return await _desktop.analyze(
          path: path,
          minSilenceMs: minSilenceMs,
          windowMs: windowMs,
          thresholdDb: thresholdDb,
        );
      }
      final raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('analyzeSilences', {
            'path': path,
            'minSilenceMs': minSilenceMs,
            'windowMs': windowMs,
            'thresholdDb': thresholdDb,
          });
      if (raw == null) return null;
      return AudioSilenceAnalysis.fromJson(Map<String, dynamic>.from(raw));
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'No se pudo analizar silencios.');
    } catch (e) {
      debugPrint('audio cleanup analyze error: $e');
      throw Exception('No se pudo analizar silencios.');
    }
  }

  Future<AudioCleanupRenderResult?> renderCleanedAudio({
    required String localPath,
    required List<AudioSilenceSegment> removeSegments,
    int fadeMs = 20,
  }) async {
    final path = localPath.trim();
    if (path.isEmpty || removeSegments.isEmpty) return null;

    try {
      if (DesktopMediaTools.supported) {
        return await _desktop.render(
          path: path,
          segments: removeSegments,
          fadeMs: fadeMs,
        );
      }
      final raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('renderCleanedAudio', {
            'path': path,
            'fadeMs': fadeMs,
            'removeRanges': removeSegments.map((e) => e.toJson()).toList(),
          });
      if (raw == null) return null;
      return AudioCleanupRenderResult.fromJson(Map<String, dynamic>.from(raw));
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'No se pudo aplicar limpieza.');
    } catch (e) {
      debugPrint('audio cleanup render error: $e');
      throw Exception('No se pudo aplicar limpieza.');
    }
  }
}

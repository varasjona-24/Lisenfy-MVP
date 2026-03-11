import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../models/media_item.dart';
import 'karaoke_recording_service.dart';
import 'karaoke_remote_pipeline_service.dart';

enum KaraokeFlowStage {
  idle,
  recording,
  uploadingVoice,
  waitingMix,
  downloadingMix,
  savingMix,
  completed,
  canceled,
  failed,
}

class KaraokeFlowSnapshot {
  const KaraokeFlowSnapshot({
    required this.stage,
    required this.message,
    required this.sessionId,
    required this.item,
    this.mixPath,
    this.error,
  });

  final KaraokeFlowStage stage;
  final String message;
  final String sessionId;
  final MediaItem item;
  final String? mixPath;
  final String? error;

  bool get isTerminal =>
      stage == KaraokeFlowStage.completed ||
      stage == KaraokeFlowStage.canceled ||
      stage == KaraokeFlowStage.failed;
}

class KaraokeFlowCoordinatorService extends GetxService {
  KaraokeFlowCoordinatorService({
    required KaraokeRecordingService recordingService,
    required KaraokeRemotePipelineService remoteService,
  }) : _recordingService = recordingService,
       _remoteService = remoteService;

  final KaraokeRecordingService _recordingService;
  final KaraokeRemotePipelineService _remoteService;

  final Rxn<KaraokeFlowSnapshot> activeFlow = Rxn<KaraokeFlowSnapshot>();

  Timer? _autoStopTimer;
  int _token = 0;

  bool get hasActiveFlow => activeFlow.value != null;

  Future<void> startAutoFlow({
    required MediaItem item,
    required String sessionId,
    required int estimatedDurationMs,
    required double voiceGain,
    required double instrumentalGain,
  }) async {
    await cancelCurrent(notify: false);
    _token += 1;
    final localToken = _token;

    activeFlow.value = KaraokeFlowSnapshot(
      stage: KaraokeFlowStage.recording,
      message: 'Grabando voz...',
      sessionId: sessionId,
      item: item,
    );

    final fallbackMs = 3 * 60 * 1000;
    final safeDurationMs = estimatedDurationMs <= 0
        ? fallbackMs
        : estimatedDurationMs + 700;

    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(Duration(milliseconds: safeDurationMs), () {
      unawaited(
        _finishAndMix(
          token: localToken,
          sessionId: sessionId,
          item: item,
          voiceGain: voiceGain,
          instrumentalGain: instrumentalGain,
        ),
      );
    });
  }

  Future<void> cancelCurrent({bool notify = true}) async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _token += 1;

    final running = activeFlow.value;
    if (running == null) return;

    try {
      await _recordingService.cancelSession();
    } catch (_) {}

    activeFlow.value = KaraokeFlowSnapshot(
      stage: KaraokeFlowStage.canceled,
      message: 'Proceso de karaoke cancelado.',
      sessionId: running.sessionId,
      item: running.item,
    );

    if (notify) {
      Get.snackbar(
        'Karaoke',
        'Proceso cancelado.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _finishAndMix({
    required int token,
    required String sessionId,
    required MediaItem item,
    required double voiceGain,
    required double instrumentalGain,
  }) async {
    if (token != _token) return;

    try {
      activeFlow.value = KaraokeFlowSnapshot(
        stage: KaraokeFlowStage.uploadingVoice,
        message: 'Subiendo voz al backend...',
        sessionId: sessionId,
        item: item,
      );

      final stopped = await _recordingService.stopSession(
        exportMixed: false,
        voiceGain: voiceGain,
        instrumentalGain: instrumentalGain,
      );

      if (token != _token) return;
      if (stopped == null || stopped.voicePath.trim().isEmpty) {
        throw Exception('No se pudo obtener la grabación de voz.');
      }

      activeFlow.value = KaraokeFlowSnapshot(
        stage: KaraokeFlowStage.waitingMix,
        message: 'Mezclando en backend...',
        sessionId: sessionId,
        item: item,
      );

      var mixedSession = await _remoteService.uploadVoiceAndMix(
        sessionId: sessionId,
        voicePath: stopped.voicePath,
        voiceGain: voiceGain,
        instrumentalGain: instrumentalGain,
      );

      if (token != _token) return;

      if (!mixedSession.isMixed) {
        mixedSession = await _remoteService.waitUntilMixed(
          sessionId: sessionId,
          onProgress: (progress) {
            if (token != _token) return;
            activeFlow.value = KaraokeFlowSnapshot(
              stage: KaraokeFlowStage.waitingMix,
              message: progress.message,
              sessionId: sessionId,
              item: item,
            );
          },
        );
      }

      if (token != _token) return;
      activeFlow.value = KaraokeFlowSnapshot(
        stage: KaraokeFlowStage.downloadingMix,
        message: 'Descargando mezcla final...',
        sessionId: sessionId,
        item: item,
      );

      final downloadedMixPath = await _remoteService.downloadMixToLocal(
        session: mixedSession,
        item: item,
      );

      if (token != _token) return;
      activeFlow.value = KaraokeFlowSnapshot(
        stage: KaraokeFlowStage.savingMix,
        message: 'Selecciona carpeta para guardar la mezcla final...',
        sessionId: sessionId,
        item: item,
      );

      final saveResult = await _saveMixToUserChosenFolder(
        item: item,
        localMixPath: downloadedMixPath,
      );
      if (token != _token) return;

      activeFlow.value = KaraokeFlowSnapshot(
        stage: KaraokeFlowStage.completed,
        message: saveResult.savedToUserFolder
            ? 'Mezcla final guardada en tu carpeta seleccionada.'
            : 'Mezcla final lista (guardada localmente).',
        sessionId: sessionId,
        item: item,
        mixPath: saveResult.path,
      );

      Get.snackbar(
        'Karaoke',
        saveResult.savedToUserFolder
            ? 'Mezcla final guardada en archivos.'
            : 'No seleccionaste carpeta. Se guardó localmente.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      if (token != _token) return;
      activeFlow.value = KaraokeFlowSnapshot(
        stage: KaraokeFlowStage.failed,
        message: 'Falló el proceso de mezcla remota.',
        sessionId: sessionId,
        item: item,
        error: e.toString().replaceFirst('Exception: ', ''),
      );

      Get.snackbar(
        'Karaoke',
        'Falló el proceso remoto: ${e.toString().replaceFirst('Exception: ', '')}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<_MixSaveResult> _saveMixToUserChosenFolder({
    required MediaItem item,
    required String localMixPath,
  }) async {
    final normalizedLocal = localMixPath.replaceFirst('file://', '').trim();
    final source = File(normalizedLocal);
    if (!source.existsSync()) {
      return _MixSaveResult(path: localMixPath, savedToUserFolder: false);
    }

    String? pickedDirPath;
    try {
      pickedDirPath = await FilePicker.platform.getDirectoryPath();
    } catch (_) {
      pickedDirPath = null;
    }

    if (pickedDirPath == null || pickedDirPath.trim().isEmpty) {
      return _MixSaveResult(path: localMixPath, savedToUserFolder: false);
    }

    try {
      final dir = Directory(pickedDirPath);
      await dir.create(recursive: true);

      final ext = p.extension(normalizedLocal).trim().isNotEmpty
          ? p.extension(normalizedLocal)
          : '.wav';
      final now = DateTime.now();
      final stamp =
          '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final baseName = 'listenfy_karaoke_${_safeName(item.title)}_$stamp';
      var outPath = p.join(dir.path, '$baseName$ext');
      var attempt = 1;
      while (await File(outPath).exists()) {
        outPath = p.join(dir.path, '${baseName}_$attempt$ext');
        attempt += 1;
      }

      final copied = await source.copy(outPath);
      return _MixSaveResult(path: copied.path, savedToUserFolder: true);
    } catch (_) {
      return _MixSaveResult(path: localMixPath, savedToUserFolder: false);
    }
  }

  String _safeName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '').trim();
    if (cleaned.isEmpty) return 'track';
    return cleaned.replaceAll(RegExp(r'\s+'), '_');
  }
}

class _MixSaveResult {
  const _MixSaveResult({required this.path, required this.savedToUserFolder});

  final String path;
  final bool savedToUserFolder;
}

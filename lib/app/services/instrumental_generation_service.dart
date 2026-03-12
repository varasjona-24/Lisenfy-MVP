import 'dart:io';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path/path.dart' as p;

import '../../Modules/player/audio/controller/audio_player_controller.dart';
import '../data/local/local_library_store.dart';
import '../models/media_item.dart';
import 'karaoke_remote_pipeline_service.dart';

enum InstrumentalTaskStage {
  preparing,
  uploading,
  separating,
  downloading,
  saving,
  completed,
  failed,
}

class InstrumentalTaskSnapshot {
  const InstrumentalTaskSnapshot({
    required this.itemKey,
    required this.stage,
    required this.progress,
    required this.message,
    required this.updatedAt,
    this.sessionId,
    this.sourcePath,
    this.separatorModel,
    this.error,
    this.itemJson,
  });

  final String itemKey;
  final InstrumentalTaskStage stage;
  final double progress;
  final String message;
  final int updatedAt;
  final String? sessionId;
  final String? sourcePath;
  final String? separatorModel;
  final String? error;
  final Map<String, dynamic>? itemJson;

  bool get isTerminal =>
      stage == InstrumentalTaskStage.completed ||
      stage == InstrumentalTaskStage.failed;

  Map<String, dynamic> toJson() {
    return {
      'itemKey': itemKey,
      'stage': stage.name,
      'progress': progress,
      'message': message,
      'updatedAt': updatedAt,
      if (sessionId != null && sessionId!.isNotEmpty) 'sessionId': sessionId,
      if (sourcePath != null && sourcePath!.isNotEmpty)
        'sourcePath': sourcePath,
      if (separatorModel != null && separatorModel!.isNotEmpty)
        'separatorModel': separatorModel,
      if (error != null && error!.isNotEmpty) 'error': error,
      if (itemJson != null) 'itemJson': itemJson,
    };
  }

  factory InstrumentalTaskSnapshot.fromJson(Map<String, dynamic> json) {
    final stageRaw = (json['stage'] as String?)?.trim() ?? '';
    final stage = InstrumentalTaskStage.values.firstWhere(
      (e) => e.name == stageRaw,
      orElse: () => InstrumentalTaskStage.failed,
    );
    final itemJsonRaw = json['itemJson'];
    return InstrumentalTaskSnapshot(
      itemKey: (json['itemKey'] as String?)?.trim() ?? '',
      stage: stage,
      progress: ((json['progress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
      message: (json['message'] as String?)?.trim() ?? '',
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      sessionId: (json['sessionId'] as String?)?.trim(),
      sourcePath: (json['sourcePath'] as String?)?.trim(),
      separatorModel: (json['separatorModel'] as String?)?.trim(),
      error: (json['error'] as String?)?.trim(),
      itemJson: itemJsonRaw is Map
          ? Map<String, dynamic>.from(itemJsonRaw)
          : null,
    );
  }

  InstrumentalTaskSnapshot copyWith({
    InstrumentalTaskStage? stage,
    double? progress,
    String? message,
    int? updatedAt,
    String? sessionId,
    String? sourcePath,
    String? separatorModel,
    String? error,
    Map<String, dynamic>? itemJson,
  }) {
    return InstrumentalTaskSnapshot(
      itemKey: itemKey,
      stage: stage ?? this.stage,
      progress: (progress ?? this.progress).clamp(0.0, 1.0),
      message: message ?? this.message,
      updatedAt: updatedAt ?? this.updatedAt,
      sessionId: sessionId ?? this.sessionId,
      sourcePath: sourcePath ?? this.sourcePath,
      separatorModel: separatorModel ?? this.separatorModel,
      error: error,
      itemJson: itemJson ?? this.itemJson,
    );
  }
}

class InstrumentalGenerationService extends GetxService {
  static const String _storageKey = 'instrumental_tasks_v1';

  final GetStorage _storage = Get.find<GetStorage>();
  final LocalLibraryStore _library = Get.find<LocalLibraryStore>();
  final KaraokeRemotePipelineService _remote =
      Get.find<KaraokeRemotePipelineService>();

  final RxMap<String, InstrumentalTaskSnapshot> tasks =
      <String, InstrumentalTaskSnapshot>{}.obs;

  final Map<String, Future<MediaItem?>> _running =
      <String, Future<MediaItem?>>{};

  @override
  void onInit() {
    super.onInit();
    _restoreSnapshots();
    _resumePendingSnapshots();
  }

  String keyForItem(MediaItem item) {
    final publicId = item.publicId.trim();
    if (publicId.isNotEmpty) return 'public:$publicId';
    final id = item.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    return 'title:${item.title.trim().toLowerCase()}';
  }

  InstrumentalTaskSnapshot? stateFor(MediaItem item) => tasks[keyForItem(item)];

  bool isRunningFor(MediaItem item) {
    final snapshot = stateFor(item);
    return snapshot != null && !snapshot.isTerminal;
  }

  Future<MediaItem?> generateForItem({
    required MediaItem item,
    required String sourcePath,
    bool forceRegenerate = false,
  }) {
    final normalizedSource = sourcePath.replaceFirst('file://', '').trim();
    if (normalizedSource.isEmpty) {
      return Future<MediaItem?>.value(null);
    }

    final key = keyForItem(item);
    final already = _running[key];
    if (already != null) return already;

    final snapshot = tasks[key];
    final resumableSessionId =
        (!forceRegenerate &&
            snapshot != null &&
            !snapshot.isTerminal &&
            (snapshot.sessionId?.trim().isNotEmpty ?? false))
        ? snapshot.sessionId!.trim()
        : null;

    final future = _runTask(
      itemKey: key,
      seedItem: item,
      sourcePath: normalizedSource,
      resumeSessionId: resumableSessionId,
    );
    _running[key] = future;
    future.whenComplete(() {
      _running.remove(key);
    });
    return future;
  }

  Future<void> _resumePendingSnapshots() async {
    final pending = tasks.values
        .where(
          (s) => !s.isTerminal && (s.sessionId?.trim().isNotEmpty ?? false),
        )
        .toList(growable: false);
    for (final snapshot in pending) {
      if (_running.containsKey(snapshot.itemKey)) continue;
      final item = await _resolveItem(snapshot);
      if (item == null) {
        _updateSnapshot(
          snapshot.itemKey,
          snapshot.copyWith(
            stage: InstrumentalTaskStage.failed,
            message: 'No se encontró canción local para reanudar proceso.',
            error: 'No se encontró canción local para reanudar proceso.',
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        continue;
      }
      final sourcePath = snapshot.sourcePath?.trim();
      if (sourcePath == null || sourcePath.isEmpty) continue;

      final future = _runTask(
        itemKey: snapshot.itemKey,
        seedItem: item,
        sourcePath: sourcePath,
        resumeSessionId: snapshot.sessionId?.trim(),
      );
      _running[snapshot.itemKey] = future;
      future.whenComplete(() {
        _running.remove(snapshot.itemKey);
      });
    }
  }

  Future<MediaItem?> _runTask({
    required String itemKey,
    required MediaItem seedItem,
    required String sourcePath,
    String? resumeSessionId,
  }) async {
    var currentItem = await _latestItem(seedItem) ?? seedItem;
    var sessionId = resumeSessionId?.trim();
    var separatorModel = '';

    _updateSnapshot(
      itemKey,
      InstrumentalTaskSnapshot(
        itemKey: itemKey,
        stage: InstrumentalTaskStage.preparing,
        progress: 0.03,
        message: 'Validando conexión con backend...',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        sessionId: sessionId,
        sourcePath: sourcePath,
        itemJson: currentItem.toJson(),
      ),
    );

    try {
      final reachable = await _remote.isBackendReachable();
      if (!reachable) {
        throw Exception(
          'Sin conexión al servidor. El modo instrumental requiere internet.',
        );
      }

      _patch(
        itemKey,
        stage: InstrumentalTaskStage.uploading,
        progress: 0.08,
        message: 'Subiendo audio fuente al servidor...',
      );

      KaraokeRemoteSession initialSession;
      if (sessionId != null && sessionId.isNotEmpty) {
        try {
          initialSession = await _remote.getSession(sessionId);
        } catch (error) {
          if (!_isMissingRemoteSession(error)) rethrow;

          _patch(
            itemKey,
            stage: InstrumentalTaskStage.uploading,
            progress: 0.1,
            message:
                'La sesión remota expiró. Creando una nueva automáticamente...',
            sessionId: null,
          );

          initialSession = await _remote.createSessionFromSource(
            item: currentItem,
            sourcePath: sourcePath,
          );
          sessionId = initialSession.id;
        }
      } else {
        initialSession = await _remote.createSessionFromSource(
          item: currentItem,
          sourcePath: sourcePath,
        );
        sessionId = initialSession.id;
      }

      _patch(
        itemKey,
        stage: InstrumentalTaskStage.separating,
        progress: 0.14,
        message: 'Separando voces e instrumental en backend...',
        sessionId: sessionId,
      );

      final currentSessionId = sessionId;
      if (currentSessionId.isEmpty) {
        throw Exception('No se pudo obtener un id de sesión remoto.');
      }

      final ready =
          (initialSession.isReadyToRecord ||
              initialSession.isSeparationCompleted)
          ? initialSession
          : await _remote.waitUntilReady(
              sessionId: currentSessionId,
              onProgress: (progress) {
                _patch(
                  itemKey,
                  stage: InstrumentalTaskStage.separating,
                  progress: (0.14 + progress.progress * 0.72).clamp(0.14, 0.9),
                  message: progress.message,
                  sessionId: sessionId,
                );
              },
            );

      separatorModel = ready.separatorModel?.trim() ?? '';
      _patch(
        itemKey,
        stage: InstrumentalTaskStage.downloading,
        progress: 0.92,
        message: 'Descargando instrumental...',
        separatorModel: separatorModel,
        sessionId: sessionId,
      );

      final downloadedPath = await _remote.downloadInstrumentalToLocal(
        session: ready,
        item: currentItem,
      );

      _patch(
        itemKey,
        stage: InstrumentalTaskStage.saving,
        progress: 0.96,
        message: 'Guardando variante instrumental...',
        separatorModel: separatorModel,
        sessionId: sessionId,
      );

      currentItem = await _latestItem(currentItem) ?? currentItem;
      final sourceVariant = _resolveSourceVariant(currentItem, sourcePath);
      final variant = await _buildInstrumentalVariant(
        downloadedPath: downloadedPath,
        sourceVariant: sourceVariant,
        item: currentItem,
      );
      final updated = _mergeInstrumentalVariant(currentItem, variant);
      await _library.upsert(updated);

      if (Get.isRegistered<AudioPlayerController>()) {
        Get.find<AudioPlayerController>().updateQueueItem(updated);
      }

      _updateSnapshot(
        itemKey,
        InstrumentalTaskSnapshot(
          itemKey: itemKey,
          stage: InstrumentalTaskStage.completed,
          progress: 1.0,
          message: 'Instrumental guardado correctamente.',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          sessionId: sessionId,
          sourcePath: sourcePath,
          separatorModel: separatorModel,
          itemJson: updated.toJson(),
        ),
      );

      return updated;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      _updateSnapshot(
        itemKey,
        InstrumentalTaskSnapshot(
          itemKey: itemKey,
          stage: InstrumentalTaskStage.failed,
          progress: 1.0,
          message: message,
          error: message,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          sessionId: sessionId,
          sourcePath: sourcePath,
          separatorModel: separatorModel.isEmpty ? null : separatorModel,
          itemJson: currentItem.toJson(),
        ),
      );
      return null;
    }
  }

  Future<MediaItem?> _latestItem(MediaItem item) async {
    final all = await _library.readAll();
    for (final it in all) {
      if (_sameItem(it, item)) return it;
    }
    return null;
  }

  Future<MediaItem?> _resolveItem(InstrumentalTaskSnapshot snapshot) async {
    final itemJson = snapshot.itemJson;
    if (itemJson != null) {
      try {
        final item = MediaItem.fromJson(itemJson);
        final latest = await _latestItem(item);
        return latest ?? item;
      } catch (_) {}
    }

    final all = await _library.readAll();
    for (final it in all) {
      if (keyForItem(it) == snapshot.itemKey) return it;
    }
    return null;
  }

  MediaVariant _resolveSourceVariant(MediaItem item, String sourcePath) {
    for (final v in item.variants) {
      if (v.kind != MediaVariantKind.audio || !v.isValid) continue;
      if (v.isInstrumental) continue;
      final local = v.localPath?.replaceFirst('file://', '').trim() ?? '';
      if (local.isNotEmpty && local == sourcePath) return v;
    }
    for (final v in item.variants) {
      if (v.kind == MediaVariantKind.audio && !v.isInstrumental && v.isValid) {
        return v;
      }
    }
    return MediaVariant(
      kind: MediaVariantKind.audio,
      format: 'wav',
      fileName: p.basename(sourcePath),
      localPath: sourcePath,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      durationSeconds: item.durationSeconds,
      role: 'main',
    );
  }

  Future<MediaVariant> _buildInstrumentalVariant({
    required String downloadedPath,
    required MediaVariant sourceVariant,
    required MediaItem item,
  }) async {
    final normalized = downloadedPath.replaceFirst('file://', '').trim();
    final file = File(normalized);
    final length = file.existsSync() ? await file.length() : null;
    final ext = p
        .extension(normalized)
        .replaceFirst('.', '')
        .trim()
        .toLowerCase();
    final format = ext.isEmpty
        ? (sourceVariant.format.trim().isEmpty
              ? 'wav'
              : sourceVariant.format.trim())
        : ext;

    return MediaVariant(
      kind: MediaVariantKind.audio,
      format: format,
      fileName: p.basename(normalized),
      localPath: normalized,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      size: length,
      durationSeconds: sourceVariant.durationSeconds ?? item.durationSeconds,
      role: 'instrumental',
    );
  }

  MediaItem _mergeInstrumentalVariant(
    MediaItem item,
    MediaVariant instrumental,
  ) {
    final preserved = item.variants
        .where((v) {
          if (v.kind != MediaVariantKind.audio) return true;
          return !v.isInstrumental;
        })
        .toList(growable: true);
    preserved.add(instrumental);
    return item.copyWith(variants: preserved);
  }

  void _patch(
    String itemKey, {
    InstrumentalTaskStage? stage,
    double? progress,
    String? message,
    String? sessionId,
    String? separatorModel,
  }) {
    final current = tasks[itemKey];
    if (current == null) return;
    _updateSnapshot(
      itemKey,
      current.copyWith(
        stage: stage,
        progress: progress,
        message: message,
        sessionId: sessionId,
        separatorModel: separatorModel,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _updateSnapshot(String itemKey, InstrumentalTaskSnapshot snapshot) {
    tasks[itemKey] = snapshot;
    _persistSnapshots();
  }

  void _restoreSnapshots() {
    final raw = _storage.read(_storageKey);
    if (raw is! Map) return;
    final restored = <String, InstrumentalTaskSnapshot>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is! Map) continue;
      try {
        final parsed = InstrumentalTaskSnapshot.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (parsed.itemKey.isEmpty) continue;
        restored[key] = parsed;
      } catch (_) {}
    }
    tasks.assignAll(restored);
  }

  void _persistSnapshots() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final keep = <String, InstrumentalTaskSnapshot>{};
    for (final entry in tasks.entries) {
      final snapshot = entry.value;
      if (snapshot.isTerminal &&
          now - snapshot.updatedAt > 24 * 60 * 60 * 1000) {
        continue;
      }
      keep[entry.key] = snapshot;
    }
    if (keep.length != tasks.length) {
      tasks
        ..clear()
        ..addAll(keep);
    }
    final encoded = <String, dynamic>{};
    for (final entry in keep.entries) {
      encoded[entry.key] = entry.value.toJson();
    }
    _storage.write(_storageKey, encoded);
  }

  bool _sameItem(MediaItem a, MediaItem b) {
    if (a.id == b.id) return true;
    final ap = a.publicId.trim();
    final bp = b.publicId.trim();
    return ap.isNotEmpty && bp.isNotEmpty && ap == bp;
  }

  bool _isMissingRemoteSession(Object error) {
    final raw = error.toString().replaceFirst('Exception:', '').trim();
    final text = raw.toLowerCase();
    if (text.contains('sesión remota no encontrada')) return true;
    if (text.contains('sesion remota no encontrada')) return true;
    return text.contains('404') &&
        (text.contains('sesión') ||
            text.contains('sesion') ||
            text.contains('session'));
  }
}

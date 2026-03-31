import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/core/presentation/getx_state_controller.dart';
import '../../../app/core/presentation/view_status.dart';
import '../../../app/data/local/local_library_store.dart';
import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/services/local_media_metadata_service.dart';
import '../domain/usecases/load_download_items_usecase.dart';
import '../service/download_task_service.dart';
import '../state/downloads_state.dart';

import '../../sources/domain/source_origin.dart';

class DownloadsController extends GetxStateController<DownloadsState> {
  DownloadsController({
    required LoadDownloadItemsUseCase loadDownloadItemsUseCase,
  }) : _loadDownloadItemsUseCase = loadDownloadItemsUseCase,
       super(DownloadsState.initial());

  // ============================
  // 🔌 DEPENDENCIAS
  // ============================
  final LoadDownloadItemsUseCase _loadDownloadItemsUseCase;
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final DownloadTaskService _downloadTask = Get.find<DownloadTaskService>();
  final LocalMediaMetadataService _metadata =
      Get.find<LocalMediaMetadataService>();

  // ============================
  // 🧭 ESTADO UI
  // ============================
  final RxBool customTabOpening = false.obs;
  RxBool get isDownloading => _downloadTask.isDownloading;
  RxDouble get downloadProgress => _downloadTask.downloadProgress;
  RxString get downloadStatus => _downloadTask.downloadStatus;

  bool get isLoading => state.value.status.isLoading;
  List<MediaItem> get downloads => state.value.items;

  // 📁 Archivos locales para importar
  final RxList<MediaItem> localFilesForImport = <MediaItem>[].obs;
  final RxBool importing = false.obs;
  final RxString sharedUrl = ''.obs;
  final RxBool shareDialogOpen = false.obs;
  final RxBool sharedArgConsumed = false.obs;
  final RxBool localImportArgConsumed = false.obs;
  final RxBool localImportDialogOpen = false.obs;
  final RxBool openLocalImportRequested = false.obs;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  bool _processingSharedFiles = false;

  static const Set<String> _audioExts = <String>{
    'mp3',
    'm4a',
    'wav',
    'flac',
    'aac',
    'ogg',
    'opus',
  };

  static const Set<String> _videoExts = <String>{'mp4', 'mov', 'mkv', 'webm'};

  // ============================
  // 🔁 LIFECYCLE
  // ============================
  @override
  void onInit() {
    super.onInit();
    load();
    _listenSharedLinks();
  }

  @override
  void onClose() {
    _shareSub?.cancel();
    super.onClose();
  }

  // ============================
  // 🔗 SHARE INTENT
  // ============================
  Future<void> _listenSharedLinks() async {
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) {
        unawaited(_handleIncomingSharedMedia(initial));
      }
      _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen((
        value,
      ) {
        if (value.isNotEmpty) {
          unawaited(_handleIncomingSharedMedia(value));
        }
      });
    } catch (e) {
      debugPrint('Share intent error: $e');
    }
  }

  Future<void> _handleIncomingSharedMedia(List<SharedMediaFile> files) async {
    if (files.isEmpty || _processingSharedFiles) return;
    _processingSharedFiles = true;
    var importedCount = 0;
    var skippedCount = 0;

    try {
      final incomingMetadata = await _readIncomingListenfyMetadata(files);

      for (final shared in files) {
        final raw = shared.path.trim();
        if (raw.isEmpty) {
          skippedCount += 1;
          continue;
        }

        if (_isLikelyWebUrl(raw)) {
          _setSharedUrl(raw);
          continue;
        }

        if (_isListenfyMetadataFilePath(raw)) {
          continue;
        }

        final candidate = await _buildCandidateFromPath(
          raw,
          displayName: p.basename(raw),
        );
        if (candidate == null) {
          skippedCount += 1;
          continue;
        }

        final metadata = _matchIncomingMetadata(
          mediaPath: raw,
          mediaItem: candidate,
          metadataPool: incomingMetadata,
        );
        final enrichedCandidate = await _applyIncomingMetadata(
          candidate,
          metadata,
        );

        final imported = await importLocalFileToApp(enrichedCandidate);
        if (imported != null) {
          importedCount += 1;
        } else {
          skippedCount += 1;
        }
      }

      if (importedCount > 0) {
        await load();
        _openDownloadsFromShare();
        Get.snackbar(
          'Importación completada',
          importedCount == 1
              ? 'Se importó 1 archivo compartido.'
              : 'Se importaron $importedCount archivos compartidos.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else if (skippedCount > 0) {
        Get.snackbar(
          'Importación',
          'No se pudo importar el archivo compartido. Verifica formato y permisos.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      _processingSharedFiles = false;
    }
  }

  void _setSharedUrl(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return;
    if (!_isLikelyWebUrl(v)) return;
    sharedUrl.value = v;
    _openImportsFromShare(v);
  }

  void _openImportsFromShare(String url) {
    if (Get.currentRoute == AppRoutes.downloads) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.currentRoute != AppRoutes.downloads) {
        Get.toNamed(AppRoutes.downloads, arguments: {'sharedUrl': url});
      }
    });
  }

  void _openDownloadsFromShare() {
    if (Get.currentRoute == AppRoutes.downloads) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.currentRoute != AppRoutes.downloads) {
        Get.toNamed(AppRoutes.downloads);
      }
    });
  }

  void requestOpenLocalImport() {
    openLocalImportRequested.value = true;
  }

  // ============================
  // 🌐 CUSTOM TAB
  // ============================
  String normalizeImportUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'https://m.youtube.com';
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    return 'https://$t';
  }

  Future<void> openCustomTab(BuildContext context, String rawUrl) async {
    if (customTabOpening.value) return;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final url = normalizeImportUrl(rawUrl);
    final uri = Uri.tryParse(url);
    if (uri == null) {
      Get.snackbar('URL inválida', 'No pude interpretar: $url');
      return;
    }

    customTabOpening.value = true;
    try {
      await launchUrl(
        uri,
        prefersDeepLink: false,
        customTabsOptions: CustomTabsOptions(
          browser: const CustomTabsBrowserConfiguration(
            prefersDefaultBrowser: true,
            fallbackCustomTabs: <String>[
              'com.brave.browser',
              'com.microsoft.emmx',
              'com.sec.android.app.sbrowser',
              'com.opera.browser',
            ],
          ),
          colorSchemes: CustomTabsColorSchemes.defaults(
            toolbarColor: cs.surface,
          ),
          showTitle: true,
          urlBarHidingEnabled: true,
          shareState: CustomTabsShareState.on,
          instantAppsEnabled: false,
          closeButton: CustomTabsCloseButton(
            icon: CustomTabsCloseButtonIcons.back,
          ),
          animations: CustomTabsSystemAnimations.slideIn(),
        ),
        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: cs.surface,
          preferredControlTintColor: cs.onSurface,
          barCollapsingEnabled: true,
          dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        ),
      );
    } catch (e) {
      debugPrint('CustomTab launch error: $e');
      Get.snackbar(
        'No se pudo abrir',
        'No hay navegador compatible (Custom Tabs) disponible o está deshabilitado.',
      );
    } finally {
      customTabOpening.value = false;
    }
  }

  // ============================
  // 📥 CARGA DE DESCARGAS
  // ============================
  Future<void> load() async {
    emit(state.value.copyWith(status: ViewStatus.loading, clearError: true));

    try {
      final list = await _loadDownloadItemsUseCase();
      emit(
        state.value.copyWith(
          status: ViewStatus.success,
          items: list,
          clearError: true,
        ),
      );
    } catch (e) {
      debugPrint('Error loading downloads: $e');
      emit(
        state.value.copyWith(
          status: ViewStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // Alias
  Future<void> loadDownloads() => load();

  // ============================
  // ▶️ REPRODUCIR
  // ============================
  void play(MediaItem item) {
    final queue = List<MediaItem>.from(state.value.items);
    final idx = queue.indexWhere((e) => e.id == item.id);

    Get.toNamed(
      AppRoutes.audioPlayer,
      arguments: {'queue': queue, 'index': idx < 0 ? 0 : idx},
    );
  }

  // ============================
  // 🗑️ ELIMINAR
  // ============================
  // ============================
  // 🧾 DESCRIPCIONES UI
  // ============================
  String getQualityDescription(String quality) {
    switch (quality) {
      case 'low':
        return 'Baja: 128 kbps (audio) / 360p (video) - Menor consumo de datos';
      case 'medium':
        return 'Media: 192 kbps (audio) / 720p (video) - Balance calidad/datos';
      case 'high':
        return 'Alta: 320 kbps (audio) / 1080p (video) - Máxima calidad';
      default:
        return 'Alta: 320 kbps (audio) / 1080p (video) - Máxima calidad';
    }
  }

  String getDataUsageDescription(String usage) {
    switch (usage) {
      case 'wifi_only':
        return 'Solo descargas en redes Wi-Fi';
      case 'all':
        return 'Descargas en Wi-Fi y conexiones móviles';
      default:
        return 'Descargas en Wi-Fi y conexiones móviles';
    }
  }

  // ============================
  // ⬇️ DESCARGAR DESDE URL
  // ============================
  Future<void> downloadFromUrl({
    String? mediaId,
    required String url,
    required String kind,
    String? quality,
  }) async {
    final ok = await _downloadTask.downloadFromUrl(
      mediaId: mediaId,
      url: url,
      kind: kind,
      quality: quality,
    );
    if (ok && !isClosed) {
      await load();
    }
  }

  // ============================
  // 📁 DESCARGAR DESDE DISPOSITIVO
  // ============================
  Future<void> pickLocalFilesForImport() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'mp3',
        'm4a',
        'wav',
        'flac',
        'aac',
        'ogg',
        'mp4',
        'mov',
        'mkv',
        'webm',
      ],
    );

    if (res == null) return;

    final picked = res.files.where((f) => f.path != null).toList();

    for (final pf in picked) {
      final filePath = pf.path!;
      final item = await _buildCandidateFromPath(
        filePath,
        displayName: pf.name,
      );
      if (item == null) continue;

      if (localFilesForImport.any((e) => e.id == item.id)) continue;
      localFilesForImport.add(item);
    }
  }

  /// 📥 Importar archivo local a la app
  Future<MediaItem?> importLocalFileToApp(MediaItem item) async {
    try {
      importing.value = true;

      final v = item.variants.first;
      final sourcePath = v.localPath ?? v.fileName;
      final normalizedSource = sourcePath.replaceFirst('file://', '').trim();
      if (normalizedSource.startsWith('content://')) {
        throw Exception(
          'No se puede leer URI content:// directo. Comparte el archivo desde "Archivos" para importarlo.',
        );
      }
      final sourceFile = File(normalizedSource);

      if (!await sourceFile.exists()) {
        throw Exception('File not found: $sourcePath');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(appDir.path, 'media'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final ext = v.format.toLowerCase();
      final destPath = p.join(mediaDir.path, '${item.id}.$ext');
      final destFile = File(destPath);

      if (!await destFile.exists()) {
        await sourceFile.copy(destPath);
      }

      final importedVariant = MediaVariant(
        kind: v.kind,
        format: v.format,
        fileName: p.basename(destPath),
        localPath: destPath,
        createdAt: v.createdAt,
        size: await destFile.length(),
        durationSeconds:
            v.durationSeconds ??
            (v.kind == MediaVariantKind.audio
                ? await _probeDurationSeconds(destPath)
                : null),
      );

      final importedItem = MediaItem(
        id: item.id,
        publicId: item.publicId,
        title: item.title,
        subtitle: item.subtitle,
        country: item.country,
        source: MediaSource.local,
        origin: item.origin,
        thumbnail: item.thumbnail,
        thumbnailLocalPath: item.thumbnailLocalPath,
        variants: [importedVariant],
        durationSeconds:
            item.durationSeconds ?? importedVariant.durationSeconds,
        lyrics: item.lyrics,
        lyricsLanguage: item.lyricsLanguage,
        translations: item.translations,
        timedLyrics: item.timedLyrics,
      );

      await _store.upsert(importedItem);
      await load();

      return importedItem;
    } catch (e) {
      debugPrint('Import failed: $e');
      return null;
    } finally {
      importing.value = false;
    }
  }

  /// 🧹 Limpiar lista local
  void clearLocalFilesForImport() => localFilesForImport.clear();

  // ============================
  // 🔧 HELPERS
  // ============================

  Future<String> _buildStableId(String filePath) async {
    try {
      final f = File(filePath);
      final stat = await f.stat();

      final payload = [
        filePath,
        stat.size.toString(),
        stat.modified.millisecondsSinceEpoch.toString(),
      ].join('|');

      return _sha1(payload);
    } catch (_) {
      return _sha1(filePath);
    }
  }

  String _sha1(String input) {
    final bytes = utf8.encode(input);
    return sha1.convert(bytes).toString();
  }

  Future<int?> _probeDurationSeconds(String filePath) async {
    final player = AudioPlayer();
    try {
      await player.setFilePath(filePath);
      final d = player.duration;
      if (d == null || d <= Duration.zero) return null;
      return d.inSeconds;
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
  }

  bool _isLikelyWebUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
  }

  bool _isListenfyMetadataFilePath(String rawPath) {
    final cleanPath = rawPath.replaceFirst('file://', '').trim().toLowerCase();
    if (cleanPath.isEmpty) return false;
    return cleanPath.endsWith('.listenfy.json');
  }

  Future<List<_IncomingShareMetadata>> _readIncomingListenfyMetadata(
    List<SharedMediaFile> files,
  ) async {
    final result = <_IncomingShareMetadata>[];

    for (final shared in files) {
      final raw = shared.path.trim();
      if (raw.isEmpty || _isLikelyWebUrl(raw)) continue;
      if (!_isListenfyMetadataFilePath(raw)) continue;

      final cleanPath = raw.replaceFirst('file://', '').trim();
      if (cleanPath.isEmpty || cleanPath.startsWith('content://')) continue;

      try {
        final file = File(cleanPath);
        if (!await file.exists()) continue;
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map) continue;

        final metadata = _IncomingShareMetadata.fromJson(
          json: Map<String, dynamic>.from(decoded),
          sidecarPath: cleanPath,
        );
        if (metadata != null) {
          result.add(metadata);
        }
      } catch (e) {
        debugPrint('Invalid listenfy sidecar ignored: $e');
      }
    }

    return result;
  }

  _IncomingShareMetadata? _matchIncomingMetadata({
    required String mediaPath,
    required MediaItem mediaItem,
    required List<_IncomingShareMetadata> metadataPool,
  }) {
    if (metadataPool.isEmpty) return null;

    final cleanPath = mediaPath.replaceFirst('file://', '').trim();
    final incomingFileName = p.basename(cleanPath).toLowerCase();
    final incomingBaseName = p
        .basenameWithoutExtension(cleanPath)
        .toLowerCase();
    final incomingSize = mediaItem.variants.firstOrNull?.size;

    for (final metadata in metadataPool) {
      if (metadata.audioFileNameLower == null) continue;
      if (metadata.audioFileNameLower == incomingFileName) {
        final expectedSize = metadata.audioSizeBytes;
        if (expectedSize == null || expectedSize == incomingSize) {
          return metadata;
        }
      }
    }

    for (final metadata in metadataPool) {
      if (metadata.sidecarBaseNameLower == incomingBaseName) {
        return metadata;
      }
    }

    if (metadataPool.length == 1) return metadataPool.first;
    return null;
  }

  Future<MediaItem> _applyIncomingMetadata(
    MediaItem candidate,
    _IncomingShareMetadata? metadata,
  ) async {
    if (metadata == null) return candidate;

    MediaItem? sharedItem;
    if (metadata.mediaItemJson != null) {
      try {
        sharedItem = MediaItem.fromJson(metadata.mediaItemJson!);
      } catch (e) {
        debugPrint('Invalid shared media metadata payload: $e');
      }
    }

    Uint8List? coverBytes;
    final encodedCover = metadata.coverBase64;
    if (encodedCover != null && encodedCover.isNotEmpty) {
      try {
        coverBytes = base64Decode(encodedCover);
      } catch (e) {
        debugPrint('Invalid cover base64 in shared metadata: $e');
      }
    }
    final sharedCoverPath = await _saveEmbeddedCover(
      itemId: candidate.id,
      pictureBytes: coverBytes,
    );

    final sharedTitle = _cleanMetaField(sharedItem?.title);
    final sharedArtist = _cleanMetaField(sharedItem?.subtitle);

    return candidate.copyWith(
      title: sharedTitle ?? candidate.title,
      subtitle: sharedArtist ?? candidate.subtitle,
      country: sharedItem?.country ?? candidate.country,
      durationSeconds:
          sharedItem?.durationSeconds ??
          metadata.durationSeconds ??
          candidate.durationSeconds,
      lyrics: sharedItem?.lyrics ?? candidate.lyrics,
      lyricsLanguage: sharedItem?.lyricsLanguage ?? candidate.lyricsLanguage,
      translations: sharedItem?.translations ?? candidate.translations,
      timedLyrics: sharedItem?.timedLyrics ?? candidate.timedLyrics,
      thumbnail: sharedItem?.thumbnail ?? candidate.thumbnail,
      thumbnailLocalPath:
          sharedCoverPath ??
          sharedItem?.thumbnailLocalPath ??
          candidate.thumbnailLocalPath,
    );
  }

  MediaVariantKind? _kindFromExtension(String ext) {
    if (_audioExts.contains(ext)) return MediaVariantKind.audio;
    if (_videoExts.contains(ext)) return MediaVariantKind.video;
    return null;
  }

  Future<MediaItem?> _buildCandidateFromPath(
    String rawPath, {
    String? displayName,
  }) async {
    final cleanPath = rawPath.replaceFirst('file://', '').trim();
    if (cleanPath.isEmpty || cleanPath.startsWith('content://')) return null;

    final file = File(cleanPath);
    if (!await file.exists()) return null;

    final ext = p.extension(cleanPath).replaceFirst('.', '').toLowerCase();
    final kind = _kindFromExtension(ext);
    if (kind == null) return null;

    final id = await _buildStableId(cleanPath);
    final metadata = kind == MediaVariantKind.audio
        ? await _metadata.readAudioMetadata(cleanPath)
        : null;
    final durationSeconds =
        metadata?.durationSeconds ??
        (kind == MediaVariantKind.audio
            ? await _probeDurationSeconds(cleanPath)
            : null);
    final fileName = p.basename(cleanPath);
    final prettyFileName = (displayName ?? fileName).trim();
    final fallbackTitle = p
        .basenameWithoutExtension(
          prettyFileName.isNotEmpty ? prettyFileName : fileName,
        )
        .replaceAll('_', ' ')
        .trim();
    final title = _cleanMetaField(metadata?.title) ?? fallbackTitle;
    final artist = _cleanMetaField(metadata?.artist) ?? '';
    final coverPath = await _saveEmbeddedCover(
      itemId: id,
      pictureBytes: metadata?.pictureBytes,
    );

    final variant = MediaVariant(
      kind: kind,
      format: ext,
      fileName: fileName,
      localPath: cleanPath,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      size: await file.length(),
      durationSeconds: durationSeconds,
    );

    return MediaItem(
      id: id,
      publicId: id,
      title: title.isNotEmpty ? title : fileName,
      subtitle: artist,
      source: MediaSource.local,
      origin: SourceOrigin.device,
      thumbnail: null,
      thumbnailLocalPath: coverPath,
      variants: [variant],
      durationSeconds: durationSeconds,
    );
  }

  String? _cleanMetaField(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower == '<unknown>' || lower == 'unknown' || lower == 'null') {
      return null;
    }
    return value;
  }

  Future<String?> _saveEmbeddedCover({
    required String itemId,
    required Uint8List? pictureBytes,
  }) async {
    if (pictureBytes == null || pictureBytes.isEmpty) return null;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'media', 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final ext = _guessImageExt(pictureBytes);
      final coverFile = File(p.join(coversDir.path, '${itemId}_cover.$ext'));
      await coverFile.writeAsBytes(pictureBytes, flush: true);
      return coverFile.path;
    } catch (_) {
      return null;
    }
  }

  String _guessImageExt(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    return 'jpg';
  }
}

class _IncomingShareMetadata {
  final String? audioFileNameLower;
  final int? audioSizeBytes;
  final int? durationSeconds;
  final String? coverBase64;
  final Map<String, dynamic>? mediaItemJson;
  final String sidecarBaseNameLower;

  const _IncomingShareMetadata({
    required this.audioFileNameLower,
    required this.audioSizeBytes,
    required this.durationSeconds,
    required this.coverBase64,
    required this.mediaItemJson,
    required this.sidecarBaseNameLower,
  });

  static _IncomingShareMetadata? fromJson({
    required Map<String, dynamic> json,
    required String sidecarPath,
  }) {
    final schema = (json['schema'] as String?)?.trim().toLowerCase() ?? '';
    if (schema != 'listenfy.media.share.v1') return null;

    final audioFileName = (json['audioFileName'] as String?)?.trim();
    final sizeRaw = json['audioSizeBytes'];
    final durationRaw = json['durationSeconds'];
    final coverBase64 = (json['coverBase64'] as String?)?.trim();

    final mediaItemRaw = json['mediaItem'];
    final mediaItemJson = mediaItemRaw is Map
        ? Map<String, dynamic>.from(mediaItemRaw)
        : null;

    final sidecarFile = p.basename(sidecarPath).toLowerCase();
    final sidecarBase = sidecarFile.endsWith('.listenfy.json')
        ? sidecarFile.substring(0, sidecarFile.length - '.listenfy.json'.length)
        : p.basenameWithoutExtension(sidecarFile);

    return _IncomingShareMetadata(
      audioFileNameLower: audioFileName?.toLowerCase(),
      audioSizeBytes: sizeRaw is num ? sizeRaw.toInt() : null,
      durationSeconds: durationRaw is num ? durationRaw.toInt() : null,
      coverBase64: (coverBase64 == null || coverBase64.isEmpty)
          ? null
          : coverBase64,
      mediaItemJson: mediaItemJson,
      sidecarBaseNameLower: sidecarBase,
    );
  }
}

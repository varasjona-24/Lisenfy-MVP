import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../../Modules/player/audio/controller/audio_player_controller.dart';
import '../../../data/local/local_library_store.dart';
import '../../../models/media_item.dart';
import '../../../services/audio_service.dart';
import '../../../services/karaoke_remote_pipeline_service.dart';

void openPlayerInstrumentalSheet(MediaItem item, {double heightFactor = 0.68}) {
  if (Get.isBottomSheetOpen ?? false) return;

  Get.bottomSheet<void>(
    FractionallySizedBox(
      heightFactor: heightFactor,
      child: PlayerInstrumentalSheet(item: item),
    ),
    isScrollControlled: true,
    useRootNavigator: true,
    ignoreSafeArea: false,
    isDismissible: true,
    enableDrag: true,
  );
}

class PlayerInstrumentalSheet extends StatefulWidget {
  const PlayerInstrumentalSheet({super.key, required this.item});

  final MediaItem item;

  @override
  State<PlayerInstrumentalSheet> createState() =>
      _PlayerInstrumentalSheetState();
}

class _PlayerInstrumentalSheetState extends State<PlayerInstrumentalSheet> {
  final LocalLibraryStore _library = Get.find<LocalLibraryStore>();
  final AudioPlayerController _player = Get.find<AudioPlayerController>();
  final AudioService _audio = Get.find<AudioService>();
  final KaraokeRemotePipelineService _remote =
      Get.find<KaraokeRemotePipelineService>();

  late MediaItem _item;
  bool _busy = false;
  double _progress = 0;
  String _message = 'Listo.';
  String? _error;
  String? _separatorModel;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _refreshFromStore();
  }

  MediaVariant? get _normalLocal =>
      _player.resolveNormalAudioVariant(_item, localOnly: true);

  MediaVariant? get _instrumentalLocal =>
      _player.resolveInstrumentalAudioVariant(_item, localOnly: true);

  bool _sameItem(MediaItem a, MediaItem b) {
    if (a.id == b.id) return true;
    final ap = a.publicId.trim();
    final bp = b.publicId.trim();
    return ap.isNotEmpty && bp.isNotEmpty && ap == bp;
  }

  Future<void> _refreshFromStore() async {
    final all = await _library.readAll();
    MediaItem? latest;
    for (final item in all) {
      if (_sameItem(item, _item)) {
        latest = item;
        break;
      }
    }
    if (!mounted || latest == null) return;
    setState(() {
      _item = latest!;
    });
  }

  Future<void> _switchToNormal() async {
    final variant = _normalLocal;
    if (variant == null) {
      setState(() {
        _error = 'No hay versión normal local para reproducir.';
      });
      return;
    }
    await _player.playItemWithVariant(item: _item, variant: variant);
    if (!mounted) return;
    setState(() {
      _error = null;
      _message = 'Reproduciendo versión normal.';
    });
  }

  Future<void> _switchToInstrumental() async {
    final variant = _instrumentalLocal;
    if (variant == null) {
      await _generateInstrumental();
      return;
    }
    await _player.playItemWithVariant(item: _item, variant: variant);
    if (!mounted) return;
    setState(() {
      _error = null;
      _message = 'Reproduciendo versión instrumental.';
    });
  }

  Future<void> _generateInstrumental() async {
    if (_busy) return;
    final sourceVariant = _normalLocal;
    final sourcePath = sourceVariant?.localPath?.trim() ?? '';
    if (sourcePath.isEmpty) {
      setState(() {
        _error =
            'Esta función requiere la versión normal de audio descargada localmente.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _progress = 0.03;
      _separatorModel = null;
      _message = 'Validando conexión con backend...';
    });

    try {
      final reachable = await _remote.isBackendReachable();
      if (!reachable) {
        throw Exception(
          'Sin conexión al servidor. El modo instrumental requiere internet.',
        );
      }

      if (!mounted) return;
      setState(() {
        _progress = 0.08;
        _message = 'Subiendo audio fuente al servidor...';
      });

      final created = await _remote.createSessionFromSource(
        item: _item,
        sourcePath: sourcePath,
      );

      if (!mounted) return;
      setState(() {
        _progress = 0.14;
        _message = 'Separando voces e instrumental en backend...';
      });

      final ready = await _remote.waitUntilReady(
        sessionId: created.id,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = (0.14 + progress.progress * 0.72).clamp(0.14, 0.9);
            _message = progress.message;
          });
        },
      );

      final downloadedPath = await _remote.downloadInstrumentalToLocal(
        session: ready,
        item: _item,
      );

      final variant = await _buildInstrumentalVariant(
        downloadedPath: downloadedPath,
        sourceVariant: sourceVariant!,
      );
      final updated = _mergeInstrumentalVariant(_item, variant);
      await _library.upsert(updated);

      _player.updateQueueItem(updated);

      if (!mounted) return;
      setState(() {
        _item = updated;
        _progress = 1.0;
        _separatorModel = ready.separatorModel;
        _message = 'Instrumental guardado y asociado a la canción.';
      });

      await _switchToInstrumental();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<MediaVariant> _buildInstrumentalVariant({
    required String downloadedPath,
    required MediaVariant sourceVariant,
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
      durationSeconds: sourceVariant.durationSeconds ?? _item.durationSeconds,
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

  bool _isCurrentTrackInstrumental() {
    final currentItem = _audio.currentItem.value;
    final currentVariant = _audio.currentVariant.value;
    if (currentItem == null || currentVariant == null) return false;
    if (!_sameItem(currentItem, _item)) return false;
    return currentVariant.isInstrumental;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normal = _normalLocal;
    final instrumental = _instrumentalLocal;

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modo instrumental',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (_busy || _progress > 0) ? _progress.clamp(0.0, 1.0) : 0,
              minHeight: 6,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 8),
            Text(
              _message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_separatorModel != null &&
                _separatorModel!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Motor: $_separatorModel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: [
                  Obx(() {
                    final playingInstrumental = _isCurrentTrackInstrumental();
                    return Text(
                      playingInstrumental
                          ? 'Reproduciendo: instrumental'
                          : 'Reproduciendo: normal',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: playingInstrumental
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy || normal == null
                            ? null
                            : _switchToNormal,
                        icon: const Icon(Icons.music_note_rounded),
                        label: const Text('Versión normal'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _busy
                            ? null
                            : (instrumental != null
                                  ? _switchToInstrumental
                                  : _generateInstrumental),
                        icon: const Icon(Icons.graphic_eq_rounded),
                        label: Text(
                          instrumental != null
                              ? 'Versión instrumental'
                              : 'Descargar instrumental',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || normal == null
                            ? null
                            : _generateInstrumental,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Regenerar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (normal != null)
                    Text(
                      'Normal: ${normal.localPath ?? '-'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (instrumental != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Instrumental: ${instrumental.localPath ?? '-'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

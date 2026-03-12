import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../Modules/player/audio/controller/audio_player_controller.dart';
import '../../../data/local/local_library_store.dart';
import '../../../models/media_item.dart';
import '../../../services/audio_service.dart';
import '../../../services/instrumental_generation_service.dart';

void openPlayerInstrumentalSheet(MediaItem item) {
  if (Get.isBottomSheetOpen ?? false) return;

  Get.bottomSheet<void>(
    PlayerInstrumentalSheet(item: item),
    isScrollControlled: false,
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
  final InstrumentalGenerationService _generation =
      Get.find<InstrumentalGenerationService>();

  late MediaItem _item;
  bool _switching = false;
  String _localMessage = 'Listo.';
  String? _manualError;
  Worker? _taskWorker;
  int _lastSyncedCompletedAt = 0;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _refreshFromStore();
    _taskWorker = ever(_generation.tasks, (_) {
      final snapshot = _generation.stateFor(_item);
      if (snapshot == null) return;
      if (snapshot.stage == InstrumentalTaskStage.completed &&
          snapshot.updatedAt != _lastSyncedCompletedAt) {
        _lastSyncedCompletedAt = snapshot.updatedAt;
        _refreshFromStore();
      }
    });
  }

  @override
  void dispose() {
    _taskWorker?.dispose();
    super.dispose();
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

  bool _isCurrentTrackInstrumental() {
    final currentItem = _audio.currentItem.value;
    final currentVariant = _audio.currentVariant.value;
    if (currentItem == null || currentVariant == null) return false;
    if (!_sameItem(currentItem, _item)) return false;
    return currentVariant.isInstrumental;
  }

  Future<void> _switchToNormal() async {
    final variant = _normalLocal;
    if (variant == null) {
      setState(() {
        _manualError = 'No hay versión normal local para reproducir.';
      });
      return;
    }
    await _player.playItemWithVariant(item: _item, variant: variant);
    if (!mounted) return;
    setState(() {
      _manualError = null;
      _localMessage = 'Modo normal activo.';
    });
  }

  Future<void> _switchToInstrumental() async {
    final variant = _instrumentalLocal;
    if (variant == null) {
      setState(() {
        _manualError = 'Aún no tienes instrumental descargado.';
      });
      return;
    }
    await _player.playItemWithVariant(item: _item, variant: variant);
    if (!mounted) return;
    setState(() {
      _manualError = null;
      _localMessage = 'Modo instrumental activo.';
    });
  }

  Future<void> _setInstrumentalMode(bool enabled) async {
    if (_switching || _generation.isRunningFor(_item)) return;
    setState(() {
      _switching = true;
      _manualError = null;
    });

    try {
      if (enabled) {
        if (_instrumentalLocal == null) {
          await _generateInstrumental(autoSwitch: true, forceRegenerate: false);
          return;
        }
        await _switchToInstrumental();
        return;
      }
      await _switchToNormal();
    } finally {
      if (mounted) {
        setState(() {
          _switching = false;
        });
      }
    }
  }

  Future<void> _generateInstrumental({
    required bool autoSwitch,
    required bool forceRegenerate,
  }) async {
    if (_generation.isRunningFor(_item)) return;

    final sourcePath =
        _normalLocal?.localPath?.replaceFirst('file://', '').trim() ?? '';
    if (sourcePath.isEmpty) {
      setState(() {
        _manualError =
            'Esta función requiere la versión normal de audio descargada localmente.';
      });
      return;
    }

    setState(() {
      _manualError = null;
      _localMessage = forceRegenerate
          ? 'Regenerando instrumental...'
          : 'Iniciando descarga instrumental...';
    });

    final updated = await _generation.generateForItem(
      item: _item,
      sourcePath: sourcePath,
      forceRegenerate: forceRegenerate,
    );

    await _refreshFromStore();
    if (!mounted) return;

    if (updated != null) {
      setState(() {
        _item = updated;
      });
    }

    if (autoSwitch && _instrumentalLocal != null) {
      await _switchToInstrumental();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Obx(() {
        final snapshot = _generation.stateFor(_item);
        final running = snapshot != null && !snapshot.isTerminal;
        final hasInstrumental = _instrumentalLocal != null;
        final message = snapshot?.message ?? _localMessage;
        final progress = snapshot != null ? snapshot.progress : 0.0;
        final separatorModel = snapshot?.separatorModel;
        final isInstrumental = _isCurrentTrackInstrumental();
        final taskError = snapshot?.stage == InstrumentalTaskStage.failed
            ? (snapshot?.error?.trim().isNotEmpty ?? false)
                  ? snapshot!.error!.trim()
                  : snapshot?.message
            : null;
        final shownError = _manualError ?? taskError;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                value: (running || progress > 0)
                    ? progress.clamp(0.0, 1.0)
                    : 0.0,
                minHeight: 6,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (separatorModel != null &&
                  separatorModel.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Motor: $separatorModel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (hasInstrumental) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _InstrumentalModePill(
                          active: !isInstrumental,
                          icon: Icons.record_voice_over_rounded,
                          label: 'Voz',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Switch.adaptive(
                        value: isInstrumental,
                        onChanged: (_switching || running)
                            ? null
                            : (value) {
                                _setInstrumentalMode(value);
                              },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InstrumentalModePill(
                          active: isInstrumental,
                          icon: Icons.music_note_rounded,
                          label: 'Instrumental',
                        ),
                      ),
                    ],
                  ),
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: (_switching || running)
                        ? null
                        : () => _generateInstrumental(
                            autoSwitch: false,
                            forceRegenerate: true,
                          ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Regenerar instrumental'),
                  ),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: (_switching || running)
                      ? null
                      : () => _generateInstrumental(
                          autoSwitch: false,
                          forceRegenerate: false,
                        ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Descargar instrumental'),
                ),
              ],
              const SizedBox(height: 10),
              if (shownError != null && shownError.trim().isNotEmpty) ...[
                Text(
                  shownError,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _InstrumentalModePill extends StatelessWidget {
  const _InstrumentalModePill({
    required this.active,
    required this.icon,
    required this.label,
  });

  final bool active;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? scheme.primary.withValues(alpha: 0.16)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: active ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

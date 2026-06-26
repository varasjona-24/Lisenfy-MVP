import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../Modules/player/audio/controller/audio_player_controller.dart';
import '../../../data/local/local_library_store.dart';
import '../../../models/media_item.dart';
import '../../../services/audio_service.dart';
import '../../../services/instrumental_generation_service.dart';
import '../../../services/spatial8d_generation_service.dart';

enum _AudioModeSheetKind { instrumental, spatial8d }

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
  final Spatial8dGenerationService _spatial8d =
      Get.find<Spatial8dGenerationService>();

  late MediaItem _item;
  bool _switching = false;
  _AudioModeSheetKind _sheetKind = _AudioModeSheetKind.instrumental;

  String _instrumentalMessage = 'Listo.';
  String _spatialMessage = 'Listo.';
  String? _instrumentalManualError;
  String? _spatialManualError;

  Worker? _instrumentalWorker;
  Worker? _spatialWorker;
  int _lastInstrumentalCompletedAt = 0;
  int _lastSpatialCompletedAt = 0;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _refreshFromStore();

    _instrumentalWorker = ever(_generation.tasks, (_) {
      final snapshot = _generation.stateFor(_item);
      if (snapshot == null) return;
      if (snapshot.stage == InstrumentalTaskStage.completed &&
          snapshot.updatedAt != _lastInstrumentalCompletedAt) {
        _lastInstrumentalCompletedAt = snapshot.updatedAt;
        _refreshFromStore();
      }
    });

    _spatialWorker = ever(_spatial8d.tasks, (_) {
      final snapshot = _spatial8d.stateFor(_item);
      if (snapshot == null) return;
      if (snapshot.stage == Spatial8dTaskStage.completed &&
          snapshot.updatedAt != _lastSpatialCompletedAt) {
        _lastSpatialCompletedAt = snapshot.updatedAt;
        _refreshFromStore();
      }
    });
  }

  @override
  void dispose() {
    _instrumentalWorker?.dispose();
    _spatialWorker?.dispose();
    super.dispose();
  }

  bool get _isAnyTaskRunning =>
      _generation.isRunningFor(_item) || _spatial8d.isRunningFor(_item);

  MediaVariant? get _normalLocal =>
      _player.resolveNormalAudioVariant(_item, localOnly: true);

  MediaVariant? get _instrumentalLocal =>
      _player.resolveInstrumentalAudioVariant(_item, localOnly: true);

  MediaVariant? get _spatial8dLocal =>
      _player.resolveSpatial8dAudioVariant(_item, localOnly: true);

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

  bool _isCurrentTrackSpatial8d() {
    final currentItem = _audio.currentItem.value;
    final currentVariant = _audio.currentVariant.value;
    if (currentItem == null || currentVariant == null) return false;
    if (!_sameItem(currentItem, _item)) return false;
    return currentVariant.isSpatial8d;
  }

  Future<void> _switchToNormal() async {
    final variant = _normalLocal;
    if (variant == null) {
      setState(() {
        _instrumentalManualError =
            'No hay versión normal local para reproducir.';
        _spatialManualError = _instrumentalManualError;
      });
      return;
    }
    await _player.playItemWithVariant(item: _item, variant: variant);
    if (!mounted) return;
    setState(() {
      _instrumentalManualError = null;
      _spatialManualError = null;
      _instrumentalMessage = 'Modo normal activo.';
      _spatialMessage = 'Modo normal activo.';
    });
  }

  Future<void> _switchToInstrumental() async {
    final variant = _instrumentalLocal;
    if (variant == null) {
      setState(() {
        _instrumentalManualError = 'Aún no tienes instrumental descargado.';
      });
      return;
    }
    await _player.playItemWithVariant(item: _item, variant: variant);
    if (!mounted) return;
    setState(() {
      _instrumentalManualError = null;
      _instrumentalMessage = 'Modo instrumental activo.';
    });
  }

  Future<void> _switchToSpatial8d() async {
    final variant = _spatial8dLocal;
    if (variant == null) {
      setState(() {
        _spatialManualError = 'Aún no tienes audio 8D descargado.';
      });
      return;
    }
    await _player.playItemWithVariant(item: _item, variant: variant);
    if (!mounted) return;
    setState(() {
      _spatialManualError = null;
      _spatialMessage = 'Modo 8D activo.';
    });
  }

  Future<void> _setInstrumentalMode(bool enabled) async {
    if (_switching || _isAnyTaskRunning) return;
    setState(() {
      _switching = true;
      _instrumentalManualError = null;
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

  Future<void> _setSpatial8dMode(bool enabled) async {
    if (_switching || _isAnyTaskRunning) return;
    setState(() {
      _switching = true;
      _spatialManualError = null;
    });

    try {
      if (enabled) {
        if (_spatial8dLocal == null) {
          await _generateSpatial8d(autoSwitch: true, forceRegenerate: false);
          return;
        }
        await _switchToSpatial8d();
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
        _instrumentalManualError =
            'Esta función requiere la versión normal de audio descargada localmente.';
      });
      return;
    }

    setState(() {
      _instrumentalManualError = null;
      _instrumentalMessage = forceRegenerate
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

  Future<void> _generateSpatial8d({
    required bool autoSwitch,
    required bool forceRegenerate,
  }) async {
    if (_spatial8d.isRunningFor(_item)) return;

    final sourcePath =
        _normalLocal?.localPath?.replaceFirst('file://', '').trim() ?? '';
    if (sourcePath.isEmpty) {
      setState(() {
        _spatialManualError =
            'Esta función requiere la versión normal de audio descargada localmente.';
      });
      return;
    }

    setState(() {
      _spatialManualError = null;
      _spatialMessage = forceRegenerate
          ? 'Regenerando audio 8D...'
          : 'Iniciando descarga de audio 8D...';
    });

    final updated = await _spatial8d.generateForItem(
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

    if (autoSwitch && _spatial8dLocal != null) {
      await _switchToSpatial8d();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Obx(() {
        final activeInstrumental =
            _sheetKind == _AudioModeSheetKind.instrumental;

        final instrumentalSnapshot = _generation.stateFor(_item);
        final instrumentalRunning =
            instrumentalSnapshot != null && !instrumentalSnapshot.isTerminal;
        final instrumentalProgress = instrumentalSnapshot?.progress ?? 0.0;
        final instrumentalMessage =
            instrumentalSnapshot?.message ?? _instrumentalMessage;
        final instrumentalError =
            instrumentalSnapshot?.stage == InstrumentalTaskStage.failed
            ? (instrumentalSnapshot?.error?.trim().isNotEmpty ?? false)
                  ? instrumentalSnapshot!.error!.trim()
                  : instrumentalSnapshot?.message
            : null;

        final spatialSnapshot = _spatial8d.stateFor(_item);
        final spatialRunning =
            spatialSnapshot != null && !spatialSnapshot.isTerminal;
        final spatialProgress = spatialSnapshot?.progress ?? 0.0;
        final spatialMessage = spatialSnapshot?.message ?? _spatialMessage;
        final spatialError = spatialSnapshot?.stage == Spatial8dTaskStage.failed
            ? (spatialSnapshot?.error?.trim().isNotEmpty ?? false)
                  ? spatialSnapshot!.error!.trim()
                  : spatialSnapshot?.message
            : null;

        final running = activeInstrumental
            ? instrumentalRunning
            : spatialRunning;
        final progress = activeInstrumental
            ? instrumentalProgress
            : spatialProgress;
        final message = activeInstrumental
            ? instrumentalMessage
            : spatialMessage;
        final separatorModel = activeInstrumental
            ? instrumentalSnapshot?.separatorModel
            : spatialSnapshot?.separatorModel;
        final shownError = activeInstrumental
            ? (_instrumentalManualError ?? instrumentalError)
            : (_spatialManualError ?? spatialError);

        final hasInstrumental = _instrumentalLocal != null;
        final hasSpatial8d = _spatial8dLocal != null;
        final isInstrumental = _isCurrentTrackInstrumental();
        final isSpatial8d = _isCurrentTrackSpatial8d();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    activeInstrumental
                        ? Icons.music_note_rounded
                        : Icons.surround_sound_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeInstrumental ? 'Modo instrumental' : 'Modo 8D',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (running || _isAnyTaskRunning)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _ModeSelector(
                kind: _sheetKind,
                onChanged: (kind) {
                  setState(() {
                    _sheetKind = kind;
                  });
                },
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
              const SizedBox(height: 10),
              if (shownError != null && shownError.trim().isNotEmpty) ...[
                Text(
                  shownError,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              const SizedBox(height: 10),
              if (activeInstrumental)
                _buildInstrumentalControls(
                  theme: theme,
                  hasInstrumental: hasInstrumental,
                  isInstrumental: isInstrumental,
                  running: running,
                )
              else
                _buildSpatialControls(
                  theme: theme,
                  hasSpatial8d: hasSpatial8d,
                  isSpatial8d: isSpatial8d,
                  running: running,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInstrumentalControls({
    required ThemeData theme,
    required bool hasInstrumental,
    required bool isInstrumental,
    required bool running,
  }) {
    if (!hasInstrumental) {
      return FilledButton.icon(
        onPressed: (_switching || running || _isAnyTaskRunning)
            ? null
            : () => _generateInstrumental(
                autoSwitch: false,
                forceRegenerate: false,
              ),
        icon: const Icon(Icons.download_rounded),
        label: Text(tr('player.download_instrumental')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                child: _AudioModePill(
                  active: !isInstrumental,
                  icon: Icons.record_voice_over_rounded,
                  label: tr('player.quick.normal'),
                ),
              ),
              const SizedBox(width: 10),
              Switch.adaptive(
                value: isInstrumental,
                onChanged: (_switching || running || _isAnyTaskRunning)
                    ? null
                    : _setInstrumentalMode,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AudioModePill(
                  active: isInstrumental,
                  icon: Icons.music_note_rounded,
                  label: tr('player.quick.instrumental'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: (_switching || running || _isAnyTaskRunning)
                ? null
                : () => _generateInstrumental(
                    autoSwitch: false,
                    forceRegenerate: true,
                  ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(tr('player.regenerate_instrumental')),
          ),
        ),
      ],
    );
  }

  Widget _buildSpatialControls({
    required ThemeData theme,
    required bool hasSpatial8d,
    required bool isSpatial8d,
    required bool running,
  }) {
    if (!hasSpatial8d) {
      return FilledButton.icon(
        onPressed: (_switching || running || _isAnyTaskRunning)
            ? null
            : () =>
                  _generateSpatial8d(autoSwitch: false, forceRegenerate: false),
        icon: const Icon(Icons.download_rounded),
        label: Text(tr('player.download_spatial8d')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                child: _AudioModePill(
                  active: !isSpatial8d,
                  icon: Icons.music_note_rounded,
                  label: tr('player.quick.normal'),
                ),
              ),
              const SizedBox(width: 10),
              Switch.adaptive(
                value: isSpatial8d,
                onChanged: (_switching || running || _isAnyTaskRunning)
                    ? null
                    : _setSpatial8dMode,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AudioModePill(
                  active: isSpatial8d,
                  icon: Icons.surround_sound_rounded,
                  label: '8D',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: (_switching || running || _isAnyTaskRunning)
                ? null
                : () => _generateSpatial8d(
                    autoSwitch: false,
                    forceRegenerate: true,
                  ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(tr('player.regenerate_spatial8d')),
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.kind, required this.onChanged});

  final _AudioModeSheetKind kind;
  final ValueChanged<_AudioModeSheetKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeSelectorChip(
              selected: kind == _AudioModeSheetKind.instrumental,
              icon: Icons.music_note_rounded,
              label: tr('player.quick.instrumental'),
              onTap: () => onChanged(_AudioModeSheetKind.instrumental),
            ),
          ),
          Expanded(
            child: _ModeSelectorChip(
              selected: kind == _AudioModeSheetKind.spatial8d,
              icon: Icons.surround_sound_rounded,
              label: '8D',
              onTap: () => onChanged(_AudioModeSheetKind.spatial8d),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelectorChip extends StatelessWidget {
  const _ModeSelectorChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioModePill extends StatelessWidget {
  const _AudioModePill({
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

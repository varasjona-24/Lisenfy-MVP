import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/audio_player_controller.dart';
import '../../../../app/routes/app_routes.dart';
import '../widgets/cover_art.dart';
import '../widgets/playback_controls.dart';
import '../widgets/progress_bar.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../../app/ui/widgets/player/player_instrumental_sheet.dart';
import '../../../../app/ui/widgets/player/player_lyrics_sheet.dart';
import '../../../../app/services/spatial_audio_service.dart';

void openPlayerVisualStyleSheet({
  required CoverStyle currentStyle,
  required List<CoverStyle> options,
  required ValueChanged<CoverStyle> onSelected,
}) {
  if (Get.isBottomSheetOpen ?? false) return;

  Get.bottomSheet<void>(
    _PlayerVisualStyleSheet(
      currentStyle: currentStyle,
      options: options,
      onSelected: onSelected,
    ),
    isScrollControlled: false,
    useRootNavigator: true,
    ignoreSafeArea: false,
    isDismissible: true,
    enableDrag: true,
  );
}

class AudioPlayerPage extends StatefulWidget {
  const AudioPlayerPage({super.key});

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  late final AudioPlayerController controller;

  IconData _coverStyleIcon(CoverStyle style) {
    return switch (style) {
      CoverStyle.square => Icons.crop_square_rounded,
      CoverStyle.vinyl => Icons.album_rounded,
      CoverStyle.wave => Icons.graphic_eq_rounded,
      CoverStyle.miniSpectrum => Icons.equalizer_rounded,
    };
  }

  String _coverStyleLabel(CoverStyle style) {
    return switch (style) {
      CoverStyle.square => 'normal',
      CoverStyle.vinyl => 'disco',
      CoverStyle.wave => 'ondas',
      CoverStyle.miniSpectrum => 'mini espectro',
    };
  }

  @override
  void initState() {
    super.initState();
    controller = Get.find<AudioPlayerController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.applyRouteArgs(Get.arguments);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        child: SafeArea(
          child: Obx(() {
            final queue = controller.queue;
            final idx = controller.currentIndex.value;
            final coverStyle = controller.normalizeCoverStyle(
              controller.coverStyle.value,
            );
            final item = (queue.isNotEmpty && idx >= 0 && idx < queue.length)
                ? queue[idx]
                : null;
            final currentItem = controller.audioService.currentItem.value;
            final currentVariant = controller.audioService.currentVariant.value;
            final sameCurrentItem =
                currentItem != null &&
                (currentItem.id == item?.id ||
                    (currentItem.publicId.trim().isNotEmpty &&
                        currentItem.publicId.trim() == item?.publicId.trim()));
            final isInstrumentalMode =
                sameCurrentItem && (currentVariant?.isInstrumental ?? false);
            final isSpatial8dMode =
                sameCurrentItem && (currentVariant?.isSpatial8d ?? false);

            if (item == null) {
              return const Center(child: Text('No hay nada reproduciéndose'));
            }

            return Column(
              children: [
                // ───────────────── Top Bar ─────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: Get.back,
                      ),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ver cola',
                        icon: const Icon(Icons.playlist_play),
                        onPressed: () => Get.toNamed(AppRoutes.audioQueue),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ───────────────── Cover ─────────────────
                CoverArt(controller: controller, item: item),

                const SizedBox(height: 24),

                // ───────────────── Info ─────────────────
                Text(
                  item.title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(item.subtitle, style: theme.textTheme.bodyMedium),

                const SizedBox(height: 24),

                // ───────────────── Progress ─────────────────
                const ProgressBar(),
                const SizedBox(height: 10),

                // ───────────────── Quick actions (balanced row) ─────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _PlayerQuickActionTile(
                                icon: _coverStyleIcon(coverStyle),
                                label: 'Visual',
                                value: _coverStyleLabel(coverStyle),
                                onTap: () => openPlayerVisualStyleSheet(
                                  currentStyle: coverStyle,
                                  options:
                                      AudioPlayerController.availableCoverStyles,
                                  onSelected: controller.setCoverStyle,
                                ),
                              ),
                            ),
                            _ActionDivider(color: theme.colorScheme.outline),
                            Expanded(
                              child: _PlayerQuickActionTile(
                                icon: Icons.lyrics_rounded,
                                label: 'Letras',
                                value: null,
                                onTap: () => openPlayerLyricsSheet(
                                  item,
                                  heightFactor: 0.72,
                                ),
                              ),
                            ),
                            _ActionDivider(color: theme.colorScheme.outline),
                            Expanded(
                              child: _PlayerQuickActionTile(
                                icon: Icons.graphic_eq_rounded,
                                label: 'Modo',
                                value: isInstrumentalMode
                                    ? 'Instrumental'
                                    : isSpatial8dMode
                                    ? '8D'
                                    : 'Normal',
                                onTap: () => openPlayerInstrumentalSheet(item),
                              ),
                            ),
                          ],
                        ),
                        Divider(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.16,
                          ),
                          height: 1,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Obx(() {
                                final stereoOn =
                                    controller.spatialMode.value ==
                                    SpatialAudioMode.virtualizer;
                                final lockedByBinaural =
                                    controller.isSpatialModeLocked;
                                final effectiveOn = stereoOn || lockedByBinaural;
                                return _PlayerQuickActionTile(
                                  icon: Icons.surround_sound_rounded,
                                  label: 'Estéreo',
                                  value: effectiveOn ? 'On' : 'Off',
                                  active: effectiveOn,
                                  onTap: lockedByBinaural
                                      ? null
                                      : () => controller.setSpatialMode(
                                          stereoOn
                                              ? SpatialAudioMode.off
                                              : SpatialAudioMode.virtualizer,
                                        ),
                                );
                              }),
                            ),
                            _ActionDivider(color: theme.colorScheme.outline),
                            Expanded(
                              child: Obx(() {
                                final repeatMode = controller.repeatMode.value;
                                final repeatActive =
                                    repeatMode != RepeatMode.off;
                                final repeatOne = repeatMode == RepeatMode.once;
                                return _PlayerQuickActionTile(
                                  icon: repeatOne
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  label: 'Repetir',
                                  value: repeatOne
                                      ? 'Solo esta'
                                      : repeatActive
                                      ? 'Una vez'
                                      : 'Off',
                                  active: repeatActive,
                                  onTap: controller.cycleRepeatMode,
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 12),

                // ───────────────── Controls ─────────────────
                const PlaybackControls(),

                const Spacer(),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _PlayerVisualStyleSheet extends StatelessWidget {
  const _PlayerVisualStyleSheet({
    required this.currentStyle,
    required this.options,
    required this.onSelected,
  });

  final CoverStyle currentStyle;
  final List<CoverStyle> options;
  final ValueChanged<CoverStyle> onSelected;

  IconData _iconFor(CoverStyle style) {
    return switch (style) {
      CoverStyle.square => Icons.crop_square_rounded,
      CoverStyle.vinyl => Icons.album_rounded,
      CoverStyle.wave => Icons.graphic_eq_rounded,
      CoverStyle.miniSpectrum => Icons.equalizer_rounded,
    };
  }

  String _labelFor(CoverStyle style) {
    return switch (style) {
      CoverStyle.square => 'normal',
      CoverStyle.vinyl => 'disco',
      CoverStyle.wave => 'ondas',
      CoverStyle.miniSpectrum => 'mini espectro',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visualizador',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: options
                    .map((style) {
                      final selected = style == currentStyle;
                      return ChoiceChip(
                        selected: selected,
                        showCheckmark: false,
                        avatar: Icon(
                          _iconFor(style),
                          size: 16,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        label: Text(
                          _labelFor(style),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: selected ? scheme.primary : scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        selectedColor: scheme.primary.withValues(alpha: 0.12),
                        backgroundColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        side: BorderSide(
                          color: selected
                              ? scheme.primary.withValues(alpha: 0.4)
                              : scheme.outline.withValues(alpha: 0.2),
                        ),
                        onSelected: (_) {
                          onSelected(style);
                          Get.back<void>();
                        },
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 50,
      color: color.withValues(alpha: 0.16),
    );
  }
}

class _PlayerQuickActionTile extends StatelessWidget {
  const _PlayerQuickActionTile({
    required this.icon,
    required this.label,
    this.value,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: active ? scheme.primary : scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          if ((value ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              value!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: active ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

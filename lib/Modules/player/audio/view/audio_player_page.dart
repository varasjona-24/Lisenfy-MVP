import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart' hide RepeatMode;
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
  double _verticalDragDistance = 0;

  IconData _coverStyleIcon(CoverStyle style) {
    return switch (style) {
      CoverStyle.square => Icons.photo_rounded,
      CoverStyle.vinyl => Icons.album_rounded,
      CoverStyle.landscape => Icons.landscape_rounded,
      CoverStyle.wave => Icons.graphic_eq_rounded,
      CoverStyle.miniSpectrum => Icons.equalizer_rounded,
    };
  }

  String _coverStyleLabel(CoverStyle style) {
    return switch (style) {
      CoverStyle.square => 'normal',
      CoverStyle.vinyl => 'disco',
      CoverStyle.landscape => 'paisaje',
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
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (_) => _verticalDragDistance = 0,
          onVerticalDragUpdate: (details) {
            _verticalDragDistance += details.primaryDelta ?? 0;
          },
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (_verticalDragDistance > 96 || velocity > 720) {
              Get.back();
            }
            _verticalDragDistance = 0;
          },
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
              final currentVariant =
                  controller.audioService.currentVariant.value;
              final sameCurrentItem =
                  currentItem != null &&
                  (currentItem.id == item?.id ||
                      (currentItem.publicId.trim().isNotEmpty &&
                          currentItem.publicId.trim() ==
                              item?.publicId.trim()));
              final isInstrumentalMode =
                  sameCurrentItem && (currentVariant?.isInstrumental ?? false);
              final isSpatial8dMode =
                  sameCurrentItem && (currentVariant?.isSpatial8d ?? false);

              if (item == null) {
                return const Center(child: Text('No hay nada reproduciéndose'));
              }

              if (coverStyle == CoverStyle.landscape) {
                return _LandscapePlayerView(
                  controller: controller,
                  item: item,
                  isInstrumentalMode: isInstrumentalMode,
                  isSpatial8dMode: isSpatial8dMode,
                  currentStyle: coverStyle,
                  coverStyleIcon: _coverStyleIcon,
                  coverStyleLabel: _coverStyleLabel,
                );
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
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
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
                                    options: AudioPlayerController
                                        .availableCoverStyles,
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
                                  onTap: () =>
                                      openPlayerInstrumentalSheet(item),
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
                                  final effectiveOn =
                                      stereoOn || lockedByBinaural;
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
                                  final repeatMode =
                                      controller.repeatMode.value;
                                  final repeatActive =
                                      repeatMode != RepeatMode.off;
                                  final repeatOne =
                                      repeatMode == RepeatMode.once;
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
      ),
    );
  }
}

class _LandscapePlayerView extends StatelessWidget {
  const _LandscapePlayerView({
    required this.controller,
    required this.item,
    required this.isInstrumentalMode,
    required this.isSpatial8dMode,
    required this.currentStyle,
    required this.coverStyleIcon,
    required this.coverStyleLabel,
  });

  final AudioPlayerController controller;
  final dynamic item;
  final bool isInstrumentalMode;
  final bool isSpatial8dMode;
  final CoverStyle currentStyle;
  final IconData Function(CoverStyle style) coverStyleIcon;
  final String Function(CoverStyle style) coverStyleLabel;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final landscapeTheme = baseTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFFFFF),
        onPrimary: Color(0xFF141414),
        surface: Color(0xFF101010),
        onSurface: Color(0xFFFFFFFF),
        surfaceContainerHighest: Color(0x33FFFFFF),
        onSurfaceVariant: Color(0xD9FFFFFF),
        outline: Color(0x66FFFFFF),
      ),
      textTheme: baseTheme.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );

    return Theme(
      data: landscapeTheme,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ArtworkImage(
            source: item.effectiveThumbnail ?? '',
            fit: BoxFit.cover,
          ),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
            child: ColoredBox(
              color: Colors.black,
              child: Transform.scale(
                scale: 1.12,
                child: _ArtworkImage(
                  source: item.effectiveThumbnail ?? '',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.48),
                  Colors.black.withValues(alpha: 0.72),
                  Colors.black.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: Colors.white,
                      onPressed: Get.back,
                    ),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: landscapeTheme.textTheme.titleSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ver cola',
                      icon: const Icon(Icons.playlist_play),
                      color: Colors.white,
                      onPressed: () => Get.toNamed(AppRoutes.audioQueue),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = MediaQuery.sizeOf(context).width;
                  final coverSize = width.clamp(250.0, 330.0);
                  return Container(
                    width: coverSize,
                    height: coverSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.42),
                          blurRadius: 36,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _ArtworkImage(
                      source: item.effectiveThumbnail ?? '',
                      fit: BoxFit.cover,
                      fallbackSize: 88,
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: landscapeTheme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: landscapeTheme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const ProgressBar(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _LandscapeActionButton(
                        icon: coverStyleIcon(currentStyle),
                        label: coverStyleLabel(currentStyle),
                        onTap: () => openPlayerVisualStyleSheet(
                          currentStyle: currentStyle,
                          options: AudioPlayerController.availableCoverStyles,
                          onSelected: controller.setCoverStyle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LandscapeActionButton(
                        icon: Icons.lyrics_rounded,
                        label: 'letras',
                        onTap: () =>
                            openPlayerLyricsSheet(item, heightFactor: 0.72),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LandscapeActionButton(
                        icon: Icons.graphic_eq_rounded,
                        label: isInstrumentalMode
                            ? 'instrumental'
                            : isSpatial8dMode
                            ? '8D'
                            : 'normal',
                        onTap: () => openPlayerInstrumentalSheet(item),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const PlaybackControls(),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

class _LandscapeActionButton extends StatelessWidget {
  const _LandscapeActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({
    required this.source,
    required this.fit,
    this.fallbackSize = 72,
  });

  final String source;
  final BoxFit fit;
  final double fallbackSize;

  @override
  Widget build(BuildContext context) {
    final clean = source.trim();
    if (clean.isEmpty) return _fallback(context);

    if (clean.startsWith('/')) {
      return Image.file(
        File(clean),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _fallback(context),
      );
    }

    return Image.network(
      clean,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        size: fallbackSize,
        color: Colors.white.withValues(alpha: 0.76),
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
      CoverStyle.square => Icons.photo_rounded,
      CoverStyle.vinyl => Icons.album_rounded,
      CoverStyle.landscape => Icons.landscape_rounded,
      CoverStyle.wave => Icons.graphic_eq_rounded,
      CoverStyle.miniSpectrum => Icons.equalizer_rounded,
    };
  }

  String _labelFor(CoverStyle style) {
    return switch (style) {
      CoverStyle.square => 'normal',
      CoverStyle.vinyl => 'disco',
      CoverStyle.landscape => 'paisaje',
      CoverStyle.wave => 'ondas',
      CoverStyle.miniSpectrum => 'mini espectro',
    };
  }

  String _descriptionFor(CoverStyle style) {
    return switch (style) {
      CoverStyle.square => 'Vista clásica centrada en la carátula.',
      CoverStyle.vinyl => 'Vista de disco con presencia visual.',
      CoverStyle.landscape => 'Portada grande con fondo inmersivo.',
      CoverStyle.wave => 'Forma de onda amplia y estable.',
      CoverStyle.miniSpectrum => 'Espectro circular más dinámico.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final screenSize = MediaQuery.sizeOf(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenSize.height * 0.78),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outline.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Visualizador',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Elige cómo quieres ver la portada y la animación del reproductor.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 680 ? 2 : 1;
                      return GridView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: columns == 1 ? 3.2 : 1.3,
                        ),
                        itemBuilder: (context, index) {
                          final style = options[index];
                          final selected = style == currentStyle;

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              onSelected(style);
                              Get.back<void>();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? scheme.primary.withValues(alpha: 0.14)
                                    : scheme.surfaceContainerHighest.withValues(
                                        alpha: 0.42,
                                      ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? scheme.primary.withValues(alpha: 0.65)
                                      : scheme.outline.withValues(alpha: 0.18),
                                  width: selected ? 1.4 : 1,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: scheme.primary.withValues(
                                            alpha: 0.12,
                                          ),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? scheme.primary.withValues(
                                                  alpha: 0.16,
                                                )
                                              : scheme.surface.withValues(
                                                  alpha: 0.72,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          _iconFor(style),
                                          color: selected
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (selected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheme.primary.withValues(
                                              alpha: 0.16,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            'Activo',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: scheme.primary,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    _labelFor(style),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _descriptionFor(style),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
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

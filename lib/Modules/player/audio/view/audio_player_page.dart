import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/audio_player_controller.dart';
import '../../../../app/routes/app_routes.dart';
import '../widgets/cover_art.dart';
import '../widgets/playback_controls.dart';
import '../widgets/progress_bar.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../../app/services/spatial_audio_service.dart';

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
            final coverStyle = controller.coverStyle.value;
            final item = (queue.isNotEmpty && idx >= 0 && idx < queue.length)
                ? queue[idx]
                : null;

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
                      PopupMenuButton<CoverStyle>(
                        tooltip:
                            'Visualizador: ${_coverStyleLabel(coverStyle)}',
                        icon: Icon(_coverStyleIcon(coverStyle)),
                        onSelected: controller.setCoverStyle,
                        itemBuilder: (context) {
                          return CoverStyle.values
                              .map((style) {
                                final selected = style == coverStyle;
                                return PopupMenuItem<CoverStyle>(
                                  value: style,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _coverStyleIcon(style),
                                        size: 18,
                                        color: selected
                                            ? theme.colorScheme.primary
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _coverStyleLabel(style),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: selected
                                              ? theme.textTheme.bodyMedium
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    )
                                              : theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                              .toList(growable: false);
                        },
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
                const SizedBox(height: 8),

                // ───────────────── Audio mode + Repeat ─────────────────
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Obx(() {
                          final enabled =
                              controller.spatialMode.value ==
                              SpatialAudioMode.virtualizer;
                          return IconButton(
                            tooltip: 'Envolvente',
                            icon: Icon(
                              Icons.surround_sound,
                              color: enabled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.55,
                                    ),
                            ),
                            onPressed: () => controller.setSpatialMode(
                              enabled
                                  ? SpatialAudioMode.off
                                  : SpatialAudioMode.virtualizer,
                            ),
                          );
                        }),
                        const SizedBox(width: 18),
                        Obx(() {
                          final active =
                              controller.repeatMode.value == RepeatMode.once;
                          return IconButton(
                            tooltip: 'Repetir una vez',
                            icon: Icon(
                              Icons.repeat_one,
                              color: active
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.55,
                                    ),
                            ),
                            onPressed: controller.toggleRepeatOnce,
                          );
                        }),
                        Obx(() {
                          final active =
                              controller.repeatMode.value == RepeatMode.loop;
                          return IconButton(
                            tooltip: 'Bucle infinito',
                            icon: Icon(
                              Icons.repeat,
                              color: active
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.55,
                                    ),
                            ),
                            onPressed: controller.toggleRepeatLoop,
                          );
                        }),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

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

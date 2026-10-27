import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/media_item.dart';
import '../../../routes/app_routes.dart';
import '../../../services/audio_service.dart';
import '../../../controllers/navigation_controller.dart';
import 'player_lyrics_sheet.dart';
import '../motion/app_motion.dart';
import '../navigation/app_bottom_nav.dart';
import '../../../../Modules/player/audio/controller/audio_player_controller.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = Get.find<AudioService>();
    final nav = Get.find<NavigationController>();

    return Obx(() {
      final route = nav.currentRoute.value;
      if (nav.isEditing.value ||
          nav.isVideoContext.value ||
          nav.isOverlayOpen.value ||
          nav.isModalOpen.value ||
          route == AppRoutes.entry ||
          route == AppRoutes.audioPlayer ||
          route == AppRoutes.audioQueue ||
          route == AppRoutes.videoPlayer ||
          route == AppRoutes.videoQueue) {
        return const SizedBox.shrink();
      }

      final AudioPlayerController? audioCtrl =
          Get.isRegistered<AudioPlayerController>()
          ? Get.find<AudioPlayerController>()
          : null;

      final audioItem = audio.currentItem.value;
      if (audioItem == null) {
        return const SizedBox.shrink();
      }

      final audioActive =
          !audio.miniPlayerDismissed.value &&
          (audio.state.value != PlaybackState.stopped || audio.keepLastItem);

      // El mini player es exclusivo de audio.
      // El video se pausa al salir del reproductor, no necesita mini player.
      if (!audioActive) {
        return const AppMotionSwap(child: SizedBox.shrink());
      }

      final isPlaying = audio.isPlaying.value;
      final canPrev = audioCtrl != null && audioCtrl.currentIndex.value > 0;
      final canNext =
          audioCtrl != null &&
          audioCtrl.currentIndex.value < audioCtrl.queue.length - 1;

      return AppMotionSwap(
        child: AppMotionEntrance(
          child: _MiniBar(
            item: audioItem,
            isVideo: false,
            isPlaying: isPlaying,
            canPrev: canPrev,
            canNext: canNext,
            onToggle: () async => audio.toggle(),
            onPrev: canPrev ? () async => audioCtrl.previous() : null,
            onNext: canNext ? () async => audioCtrl.next() : null,
            onClose: () async {
              audio.persistCurrentTrackResumePositionNow();
              await audio.stopAndHidePreservingSession();
            },
            onOpen: () => Get.toNamed(AppRoutes.audioPlayer),
            onLyrics: () => openPlayerLyricsSheet(audioItem),
          ),
        ),
      );
    });
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.item,
    required this.isVideo,
    required this.isPlaying,
    required this.canPrev,
    required this.canNext,
    required this.onToggle,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
    required this.onOpen,
    required this.onLyrics,
  });

  final MediaItem item;
  final bool isVideo;
  final bool isPlaying;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onToggle;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final VoidCallback onLyrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final thumb = item.effectiveThumbnail;
    final desktop = AppBottomNav.desktopSidebarEnabled;
    final wide = desktop && MediaQuery.sizeOf(context).width >= 920;
    Widget controlButton({
      required IconData icon,
      required VoidCallback? onPressed,
    }) {
      return SizedBox(
        width: desktop ? 48 : 34,
        height: desktop ? 48 : 34,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          iconSize: desktop ? 28 : 21,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      );
    }

    final bg = desktop
        ? scheme.surface
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.18),
            scheme.surface,
          );

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: desktop ? 0 : 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(desktop ? 0 : 18),
          onTap: onOpen,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(desktop ? 0 : 18),
              border: desktop
                  ? null
                  : Border.all(color: scheme.primary.withValues(alpha: 0.18)),
              boxShadow: desktop
                  ? null
                  : [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: SizedBox(
              height: desktop ? 112 : 64,
              child: Row(
                children: [
                  SizedBox(width: desktop ? 18 : 10),
                  AppMotionSwap(
                    child: KeyedSubtree(
                      key: ValueKey(thumb),
                      child: _Thumb(
                        thumb: thumb,
                        isVideo: isVideo,
                        size: desktop ? 80 : 46,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppMotionSwap(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.title,
                            key: ValueKey(item.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                (desktop
                                        ? theme.textTheme.titleMedium
                                        : theme.textTheme.titleSmall)
                                    ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.displaySubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              (desktop
                                      ? theme.textTheme.bodyMedium
                                      : theme.textTheme.bodySmall)
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  controlButton(
                    icon: Icons.skip_previous_rounded,
                    onPressed: canPrev ? onPrev : null,
                  ),
                  const SizedBox(width: 2),
                  Material(
                    color: desktop ? scheme.primary : Colors.transparent,
                    shape: const CircleBorder(),
                    child: IconTheme(
                      data: IconThemeData(
                        color: desktop ? scheme.onPrimary : scheme.onSurface,
                      ),
                      child: controlButton(
                        icon: isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        onPressed: onToggle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  controlButton(
                    icon: Icons.skip_next_rounded,
                    onPressed: canNext ? onNext : null,
                  ),
                  if (wide) const Spacer(),
                  const SizedBox(width: 2),
                  controlButton(
                    icon: Icons.lyrics_rounded,
                    onPressed: onLyrics,
                  ),
                  const SizedBox(width: 2),
                  controlButton(icon: Icons.close_rounded, onPressed: onClose),
                  SizedBox(width: desktop ? 18 : 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.thumb, required this.isVideo, this.size = 46});

  final String? thumb;
  final bool isVideo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary.withValues(alpha: 0.12);

    if (thumb != null && thumb!.isNotEmpty) {
      final provider = thumb!.startsWith('http')
          ? NetworkImage(thumb!)
          : FileImage(File(thumb!)) as ImageProvider;
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: provider,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
        color: scheme.primary,
      ),
    );
  }
}

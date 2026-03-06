import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/media_item.dart';
import '../../../routes/app_routes.dart';
import '../../../services/audio_service.dart';
import '../../../services/video_service.dart';
import '../../../controllers/navigation_controller.dart';
import 'player_lyrics_sheet.dart';
import '../../../../Modules/player/audio/controller/audio_player_controller.dart';
import '../../../../Modules/player/Video/controller/video_player_controller.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = Get.find<AudioService>();
    final video = Get.find<VideoService>();
    final nav = Get.find<NavigationController>();

    return Obx(() {
      final route = nav.currentRoute.value;
      if (nav.isEditing.value ||
          nav.isOverlayOpen.value ||
          (Get.isBottomSheetOpen ?? false) ||
          (Get.isDialogOpen ?? false) ||
          route == AppRoutes.entry ||
          route == AppRoutes.audioPlayer ||
          route == AppRoutes.videoPlayer) {
        return const SizedBox.shrink();
      }

      final audioCtrl = Get.isRegistered<AudioPlayerController>()
          ? Get.find<AudioPlayerController>()
          : null;
      final videoCtrl = Get.isRegistered<VideoPlayerController>()
          ? Get.find<VideoPlayerController>()
          : null;

      final audioItem = audio.currentItem.value;
      final videoItem = video.currentItem.value;
      final audioActive =
          audioItem != null &&
          (audio.state.value != PlaybackState.stopped || audio.keepLastItem);
      final videoActive =
          videoItem != null &&
          (video.state.value != VideoPlaybackState.stopped ||
              video.keepLastItem);

      if (!audioActive && !videoActive) {
        return const SizedBox.shrink();
      }

      final isVideo = videoActive && !audioActive;
      final item = isVideo ? videoItem : audioItem;
      if (item == null) {
        return const SizedBox.shrink();
      }
      final isPlaying = isVideo ? video.isPlaying.value : audio.isPlaying.value;

      final canPrev = isVideo
          ? (videoCtrl != null && videoCtrl.currentIndex.value > 0)
          : (audioCtrl != null && audioCtrl.currentIndex.value > 0);
      final canNext = isVideo
          ? (videoCtrl != null &&
                videoCtrl.currentIndex.value < videoCtrl.queue.length - 1)
          : (audioCtrl != null &&
                audioCtrl.currentIndex.value < audioCtrl.queue.length - 1);

      return _MiniBar(
        item: item,
        isVideo: isVideo,
        isPlaying: isPlaying,
        canPrev: canPrev,
        canNext: canNext,
        onToggle: () async {
          if (isVideo) {
            await video.toggle();
          } else {
            await audio.toggle();
          }
        },
        onPrev: canPrev
            ? () async {
                if (isVideo) {
                  await videoCtrl?.previous();
                } else {
                  await audioCtrl?.previous();
                }
              }
            : null,
        onNext: canNext
            ? () async {
                if (isVideo) {
                  await videoCtrl?.next();
                } else {
                  await audioCtrl?.next();
                }
              }
            : null,
        onClose: () async {
          if (isVideo) {
            await video.stop();
            video.clearLastItem();
            VideoPlayerController.clearPersistedQueueSnapshot();
          } else {
            await audio.stop();
            audio.clearLastItem();
          }
        },
        onOpen: () {
          final route = isVideo ? AppRoutes.videoPlayer : AppRoutes.audioPlayer;
          Get.toNamed(route);
        },
        onLyrics: () => openPlayerLyricsSheet(item),
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
    Widget controlButton({
      required IconData icon,
      required VoidCallback? onPressed,
    }) {
      return SizedBox(
        width: 34,
        height: 34,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          iconSize: 21,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      );
    }

    final bg = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.18),
      scheme.surface,
    );

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  _Thumb(thumb: thumb, isVideo: isVideo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.displaySubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  controlButton(
                    icon: Icons.skip_previous_rounded,
                    onPressed: canPrev ? onPrev : null,
                  ),
                  const SizedBox(width: 2),
                  controlButton(
                    icon: isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onPressed: onToggle,
                  ),
                  const SizedBox(width: 2),
                  controlButton(
                    icon: Icons.skip_next_rounded,
                    onPressed: canNext ? onNext : null,
                  ),
                  const SizedBox(width: 2),
                  controlButton(
                    icon: Icons.lyrics_rounded,
                    onPressed: onLyrics,
                  ),
                  const SizedBox(width: 2),
                  controlButton(icon: Icons.close_rounded, onPressed: onClose),
                  const SizedBox(width: 4),
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
  const _Thumb({required this.thumb, required this.isVideo});

  final String? thumb;
  final bool isVideo;

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
        child: Image(image: provider, width: 46, height: 46, fit: BoxFit.cover),
      );
    }

    return Container(
      width: 46,
      height: 46,
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

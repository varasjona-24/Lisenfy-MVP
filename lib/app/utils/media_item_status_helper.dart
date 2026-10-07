import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../data/local/local_library_store.dart';
import '../models/media_item.dart';
import '../data/playback/playback_state_storage.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import '../../Modules/settings/controller/playback_settings_controller.dart';

enum VideoProgressStatus { pendiente, enProgreso, viendo, completado }

VideoProgressStatus resolveVideoProgress({
  required bool seen,
  required bool started,
  required bool resumable,
}) {
  if (seen) return VideoProgressStatus.completado;
  if (resumable) return VideoProgressStatus.viendo;
  return started
      ? VideoProgressStatus.enProgreso
      : VideoProgressStatus.pendiente;
}

extension MediaItemStatusX on MediaItem {
  static const int shortVideoMaxSeconds = 150;
  static const int seenLabelMaxSeconds = 13 * 60;

  bool get isShortVideoForResume {
    final seconds = localVideoVariant?.durationSeconds ?? durationSeconds;
    return seconds != null && seconds > 0 && seconds < shortVideoMaxSeconds;
  }

  bool get usesSeenLabel {
    final seconds = localVideoVariant?.durationSeconds ?? durationSeconds;
    return seconds != null &&
        seconds >= shortVideoMaxSeconds &&
        seconds <= seenLabelMaxSeconds;
  }

  VideoProgressStatus get videoStatus {
    if (!Get.isRegistered<PlaybackStateStorage>()) {
      return VideoProgressStatus.pendiente;
    }
    final storage = Get.find<PlaybackStateStorage>();
    final metrics = storage.videoMetrics[id];
    final positions = storage.read<Map>('video_resume_positions') ?? {};
    final key = publicId.trim().isNotEmpty ? publicId : id;
    final position = positions[key];
    return resolveVideoProgress(
      seen: (metrics?['fullListenCount'] as num? ?? 0) > 0,
      started:
          (metrics?['playCount'] as num? ?? 0) > 0 ||
          (metrics?['avgListenProgress'] as num? ?? 0) > 0,
      resumable: !isShortVideoForResume && position is num && position > 0,
    );
  }
}

class VideoStatusBadge extends StatelessWidget {
  const VideoStatusBadge({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final isVideo = item.hasVideoLocal || item.localVideoVariant != null;
    if (!isVideo || item.isShortVideoForResume) return const SizedBox.shrink();

    if (Get.isRegistered<PlaybackSettingsController>()) {
      final playback = Get.find<PlaybackSettingsController>();
      return Obx(
        () => _buildBadge(
          context,
          hidden:
              playback.hideVideoStatusLabels.value ||
              (playback.hideShortVideoStatusLabels.value && item.usesSeenLabel),
        ),
      );
    }

    final storage = GetStorage();
    final hidden =
        storage.read(PlaybackSettingsController.hideVideoStatusLabelsKey) ==
            true ||
        (storage.read(
                  PlaybackSettingsController.hideShortVideoStatusLabelsKey,
                ) ==
                true &&
            item.usesSeenLabel);

    return Get.isRegistered<PlaybackStateStorage>()
        ? Obx(() => _buildBadge(context, hidden: hidden))
        : _buildBadge(context, hidden: hidden);
  }

  Widget _buildBadge(BuildContext context, {required bool hidden}) {
    if (hidden) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = item.videoStatus;

    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case VideoProgressStatus.completado:
        bg = scheme.primary;
        fg = scheme.onPrimary;
        label = tr('video_progress.seen');
        icon = Icons.check_circle_rounded;
        break;
      case VideoProgressStatus.viendo:
        bg = Colors.black.withValues(alpha: 0.75);
        fg = scheme.primary;
        label = tr('video_progress.resume');
        icon = Icons.play_circle_fill_rounded;
        break;
      case VideoProgressStatus.pendiente:
        bg = Colors.black.withValues(alpha: 0.65);
        fg = Colors.white70;
        label = tr('video_progress.pending');
        icon = Icons.hourglass_empty_rounded;
        break;
      case VideoProgressStatus.enProgreso:
        bg = Colors.black.withValues(alpha: 0.65);
        fg = Colors.white70;
        label = tr('video_progress.in_progress');
        icon = Icons.timelapse_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: status == VideoProgressStatus.viendo
            ? Border.all(color: scheme.primary.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class VideoFavoriteBadge extends StatelessWidget {
  const VideoFavoriteBadge({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    if (!item.isFavorite) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.favorite_rounded, size: 10, color: scheme.primary),
    );
  }
}

class VideoBadgesOverlay extends StatelessWidget {
  const VideoBadgesOverlay({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final isVideo = item.hasVideoLocal || item.localVideoVariant != null;
    if (!isVideo) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VideoStatusBadge(item: item),
        if (item.isFavorite) ...[
          const SizedBox(width: 4),
          VideoFavoriteBadge(item: item),
        ],
      ],
    );
  }
}

class CollectionProgressHelper {
  static (int completed, int total) getProgress(List<String> itemIds) {
    if (itemIds.isEmpty) return (0, 0);

    if (!Get.isRegistered<LocalLibraryStore>()) {
      return (0, itemIds.length);
    }

    final store = Get.find<LocalLibraryStore>();
    final allItems = store.readAllSync();

    final map = <String, MediaItem>{};
    for (final item in allItems) {
      map[item.id.trim()] = item;
      if (item.publicId.trim().isNotEmpty) map[item.publicId.trim()] = item;
    }

    int completed = 0;
    int total = itemIds.toSet().length;

    final counted = <String>{};
    for (final id in itemIds.toSet()) {
      final item = map[id.trim()];
      if (item != null) {
        if (!counted.add(item.id)) {
          total--;
          continue;
        }
        if (item.videoStatus == VideoProgressStatus.completado) {
          completed++;
        }
      }
    }

    return (completed, total);
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../models/media_item.dart';
import '../data/local/local_library_store.dart';

enum VideoProgressStatus {
  pendiente,
  viendo,
  completado,
  abandonado,
}

extension MediaItemStatusX on MediaItem {
  VideoProgressStatus get videoStatus {
    final pct = avgListenProgress * 100;
    if (pct >= 90) {
      return VideoProgressStatus.completado;
    }

    final box = GetStorage();
    final key = publicId.trim().isNotEmpty ? publicId.trim() : id.trim();
    final videoMap = box.read<Map>('video_resume_positions');
    final audioMap = box.read<Map>('audio_resume_positions');
    final videoMs = videoMap?[key] as int? ?? 0;
    final audioMs = audioMap?[key] as int? ?? 0;
    final posMs = videoMs > 0 ? videoMs : audioMs;

    if (pct == 0 || posMs == 0) {
      return VideoProgressStatus.pendiente;
    }

    return VideoProgressStatus.viendo;
  }
}

class VideoStatusBadge extends StatelessWidget {
  const VideoStatusBadge({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final isVideo = item.hasVideoLocal || item.localVideoVariant != null;
    if (!isVideo) return const SizedBox.shrink();

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
        label = 'Completado';
        icon = Icons.check_circle_rounded;
        break;
      case VideoProgressStatus.viendo:
        bg = Colors.black.withValues(alpha: 0.75);
        fg = scheme.primary;
        label = 'Viendo';
        icon = Icons.play_circle_fill_rounded;
        break;
      case VideoProgressStatus.pendiente:
        bg = Colors.black.withValues(alpha: 0.65);
        fg = Colors.white70;
        label = 'Pendiente';
        icon = Icons.hourglass_empty_rounded;
        break;
      case VideoProgressStatus.abandonado:
        bg = Colors.black.withValues(alpha: 0.65);
        fg = Colors.redAccent;
        label = 'Abandonado';
        icon = Icons.block_rounded;
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
      child: Icon(
        Icons.favorite_rounded,
        size: 10,
        color: scheme.primary,
      ),
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
      final key = item.publicId.trim().isNotEmpty ? item.publicId.trim() : item.id.trim();
      map[key] = item;
    }

    int completed = 0;
    int total = itemIds.length;

    for (final id in itemIds) {
      final item = map[id.trim()];
      if (item != null) {
        final pct = item.avgListenProgress * 100;
        if (pct >= 90) {
          completed++;
        }
      }
    }

    return (completed, total);
  }
}

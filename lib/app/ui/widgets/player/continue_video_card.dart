import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';
import '../../../services/video_service.dart';

/// Opens the existing video session without supplying a replacement queue.
class ContinueVideoCard extends StatelessWidget {
  const ContinueVideoCard({super.key, this.header, this.horizontalPadding = 0});
  final Widget? header;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<VideoService>()) return const SizedBox.shrink();
    return Obx(() {
      final item = Get.find<VideoService>().currentItem.value;
      if (item == null) return const SizedBox.shrink();
      final scheme = Theme.of(context).colorScheme;
      final typography = Theme.of(context).textTheme;
      final local = item.thumbnailLocalPath?.trim();
      final remote = item.thumbnail?.trim();
      final ImageProvider? cover = local != null && local.isNotEmpty
          ? FileImage(File(local))
          : remote != null && remote.isNotEmpty
          ? NetworkImage(remote)
          : null;
      final fallback = ColoredBox(
        color: scheme.primaryContainer,
        child: Center(
          child: Icon(Icons.movie_outlined, color: scheme.onPrimaryContainer),
        ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 10)],
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Material(
              color: scheme.surfaceContainer.withValues(alpha: 0.78),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Get.toNamed(AppRoutes.videoPlayer),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 112,
                          height: 63,
                          child: cover == null
                              ? fallback
                              : Image(
                                  image: cover,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) => fallback,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: typography.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (item.displaySubtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.displaySubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';
import '../../../services/video_service.dart';

/// Opens the existing video session without supplying a replacement queue.
class ContinueVideoCard extends StatelessWidget {
  const ContinueVideoCard({super.key});

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

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Material(
          color: scheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
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
                      width: 96,
                      height: 64,
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
                          tr('home.actions.resume_video'),
                          style: typography.labelLarge?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: typography.titleSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.play_circle_fill_rounded, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import 'media_thumb.dart';

// ============================
// 🎵 TILE DE ITEM DE HISTORIAL
// ============================
class MediaHistoryItemTile extends StatelessWidget {
  const MediaHistoryItemTile({
    super.key,
    required this.item,
    required this.time,
    required this.onTap,
    required this.onLongPress,
    this.fallbackIcon = Icons.music_note_rounded,
  });

  final MediaItem item;
  final String time;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            MediaThumb(
              path: item.thumbnailLocalPath,
              url: item.thumbnail,
              fallbackIcon: fallbackIcon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

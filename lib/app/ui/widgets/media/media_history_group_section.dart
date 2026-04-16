import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import 'media_history_item_tile.dart';
import 'media_item_grid.dart';

// ============================
// 🗂️ SECCIÓN AGRUPADA DE HISTORIAL
// ============================
class MediaHistoryGroupSection extends StatelessWidget {
  const MediaHistoryGroupSection({
    super.key,
    required this.label,
    required this.items,
    required this.onTap,
    required this.onLongPress,
    required this.timeBuilder,
    this.fallbackIcon = Icons.music_note_rounded,
    this.gridMode = false,
  });

  final String label;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onTap;
  final ValueChanged<MediaItem> onLongPress;
  final String Function(MediaItem item) timeBuilder;
  final IconData fallbackIcon;
  final bool gridMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 6),
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
        if (gridMode)
          MediaItemGrid(
            items: items,
            onTap: (item, index) => onTap(item),
            onLongPress: (item, index) => onLongPress(item),
            footerBuilder: (item, index) => timeBuilder(item),
            fallbackIcon: fallbackIcon,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.78,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          )
        else
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MediaHistoryItemTile(
                item: item,
                time: timeBuilder(item),
                onTap: () => onTap(item),
                onLongPress: () => onLongPress(item),
                fallbackIcon: fallbackIcon,
              ),
            );
          }),
        const SizedBox(height: 14),
      ],
    );
  }
}

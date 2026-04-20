import 'package:flutter/material.dart';
import '../../../models/history_group.dart';
import '../../../models/media_item.dart';
import '../../themes/app_grid_theme.dart';
import 'media_history_item_tile.dart';
import 'media_item_grid.dart';

// ============================
// 🗂️ SECCIÓN AGRUPADA DE HISTORIAL RECURSIVA
// ============================
class MediaHistoryGroupSection extends StatelessWidget {
  const MediaHistoryGroupSection({
    super.key,
    required this.group,
    required this.expandedSections,
    required this.onTap,
    required this.onLongPress,
    required this.timeBuilder,
    required this.onToggle,
    this.fallbackIcon = Icons.music_note_rounded,
    this.gridMode = false,
    this.level = 0,
  });

  final HistoryGroup group;
  final Set<String> expandedSections;
  final ValueChanged<MediaItem> onTap;
  final ValueChanged<MediaItem> onLongPress;
  final String Function(MediaItem item) timeBuilder;
  final ValueChanged<String> onToggle;
  final IconData fallbackIcon;
  final bool gridMode;
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isExpanded = expandedSections.contains(group.id);
    final isRoot = level == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onToggle(group.id),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.only(
              top: isRoot ? 6 : 4,
              bottom: isRoot ? 10 : 6,
              left: 0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: !isExpanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // Render Nested Groups
                      if (group.hasSubGroups)
                        ...group.subGroups!.map((sub) => MediaHistoryGroupSection(
                              group: sub,
                              expandedSections: expandedSections,
                              onTap: onTap,
                              onLongPress: onLongPress,
                              timeBuilder: timeBuilder,
                              onToggle: onToggle,
                              fallbackIcon: fallbackIcon,
                              gridMode: gridMode,
                              level: level + 1,
                            )),

                      // Render Leaf Items
                      if (group.isLeaf)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: gridMode
                              ? MediaItemGrid(
                                  items: group.items!,
                                  onTap: (item, index) => onTap(item),
                                  onLongPress: (item, index) => onLongPress(item),
                                  footerBuilder: (item, index) => timeBuilder(item),
                                  fallbackIcon: fallbackIcon,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: AppGridTheme.childAspectRatio,
                                  crossAxisSpacing: AppGridTheme.spacing,
                                  mainAxisSpacing: AppGridTheme.spacing,
                                )
                              : Column(
                                  children: group.items!.map((MediaItem item) {
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
                                }).toList()),
                        ),
                    ],
                  ),
                ),
        ),
        if (isRoot) const SizedBox(height: 14),
        if (level == 1) const SizedBox(height: 16),
      ],
    );
  }
}

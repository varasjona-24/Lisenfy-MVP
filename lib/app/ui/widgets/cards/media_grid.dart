import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../themes/app_grid_theme.dart';
import '../../themes/app_spacing.dart';
import 'media_card.dart';

class MediaGrid extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item)? onItemTap;

  const MediaGrid({super.key, required this.items, this.onItemTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = AppGridTheme.getCrossAxisCount(constraints.maxWidth);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: GridView.builder(
            key: ValueKey(crossAxisCount),
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: AppGridTheme.spacing,
              mainAxisSpacing: AppGridTheme.spacing,
              childAspectRatio: AppGridTheme.childAspectRatio,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return MediaCard(
                item: item,
                onTap: onItemTap != null ? () => onItemTap!(item) : () {},
              );
            },
          ),
        );
      },
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/media_item.dart';

typedef MediaGridItemCallback = void Function(MediaItem item, int index);
typedef MediaGridTextBuilder = String? Function(MediaItem item, int index);
typedef MediaGridBoolBuilder = bool Function(MediaItem item, int index);

int mediaGridCrossAxisCount(double width) {
  if (width >= 1180) return 5;
  if (width >= 900) return 4;
  return 3;
}

class MediaItemGrid extends StatelessWidget {
  const MediaItemGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.onLongPress,
    this.onMore,
    this.hintBuilder,
    this.footerBuilder,
    this.selectedBuilder,
    this.selectableBuilder,
    this.selectionMode = false,
    this.onSelectionTap,
    this.fallbackIcon = Icons.music_note_rounded,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.shrinkWrap = false,
    this.childAspectRatio = 0.70,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
  });

  final List<MediaItem> items;
  final MediaGridItemCallback onTap;
  final MediaGridItemCallback? onLongPress;
  final MediaGridItemCallback? onMore;
  final MediaGridTextBuilder? hintBuilder;
  final MediaGridTextBuilder? footerBuilder;
  final MediaGridBoolBuilder? selectedBuilder;
  final MediaGridBoolBuilder? selectableBuilder;
  final bool selectionMode;
  final MediaGridItemCallback? onSelectionTap;
  final IconData fallbackIcon;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: mediaGridCrossAxisCount(constraints.maxWidth),
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            return _buildTile(index);
          },
        );
      },
    );
  }

  Widget _buildTile(int index) {
    final item = items[index];
    return MediaGridTile(
      item: item,
      hintText: hintBuilder?.call(item, index),
      footerText: footerBuilder?.call(item, index),
      selected: selectedBuilder?.call(item, index) ?? false,
      selectable: selectableBuilder?.call(item, index) ?? true,
      selectionMode: selectionMode,
      fallbackIcon: fallbackIcon,
      onTap: () => selectionMode
          ? (onSelectionTap ?? onTap).call(item, index)
          : onTap(item, index),
      onLongPress: onLongPress == null ? null : () => onLongPress!(item, index),
      onMore: onMore == null ? null : () => onMore!(item, index),
    );
  }
}

class MediaItemSliverGrid extends StatelessWidget {
  const MediaItemSliverGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.onLongPress,
    this.onMore,
    this.hintBuilder,
    this.footerBuilder,
    this.selectedBuilder,
    this.selectableBuilder,
    this.selectionMode = false,
    this.onSelectionTap,
    this.fallbackIcon = Icons.music_note_rounded,
    this.padding = EdgeInsets.zero,
    this.childAspectRatio = 0.70,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
  });

  final List<MediaItem> items;
  final MediaGridItemCallback onTap;
  final MediaGridItemCallback? onLongPress;
  final MediaGridItemCallback? onMore;
  final MediaGridTextBuilder? hintBuilder;
  final MediaGridTextBuilder? footerBuilder;
  final MediaGridBoolBuilder? selectedBuilder;
  final MediaGridBoolBuilder? selectableBuilder;
  final bool selectionMode;
  final MediaGridItemCallback? onSelectionTap;
  final IconData fallbackIcon;
  final EdgeInsetsGeometry padding;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        return SliverPadding(
          padding: padding,
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildTile(index),
              childCount: items.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mediaGridCrossAxisCount(
                constraints.crossAxisExtent,
              ),
              crossAxisSpacing: crossAxisSpacing,
              mainAxisSpacing: mainAxisSpacing,
              childAspectRatio: childAspectRatio,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTile(int index) {
    final item = items[index];
    return MediaGridTile(
      item: item,
      hintText: hintBuilder?.call(item, index),
      footerText: footerBuilder?.call(item, index),
      selected: selectedBuilder?.call(item, index) ?? false,
      selectable: selectableBuilder?.call(item, index) ?? true,
      selectionMode: selectionMode,
      fallbackIcon: fallbackIcon,
      onTap: () => selectionMode
          ? (onSelectionTap ?? onTap).call(item, index)
          : onTap(item, index),
      onLongPress: onLongPress == null ? null : () => onLongPress!(item, index),
      onMore: onMore == null ? null : () => onMore!(item, index),
    );
  }
}

class MediaGridTile extends StatelessWidget {
  const MediaGridTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.onMore,
    this.hintText,
    this.footerText,
    this.selected = false,
    this.selectable = true,
    this.selectionMode = false,
    this.fallbackIcon = Icons.music_note_rounded,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;
  final String? hintText;
  final String? footerText;
  final bool selected;
  final bool selectable;
  final bool selectionMode;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hint = hintText?.trim() ?? '';
    final footer = footerText?.trim() ?? '';

    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.14)
          : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(
                    color: scheme.primary.withValues(alpha: 0.68),
                    width: 1.4,
                  )
                : null,
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _cover(context)),
              const SizedBox(height: 7),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.displaySubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!selectionMode && onMore != null)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        tooltip: 'Más opciones',
                        color: scheme.onSurfaceVariant,
                        onPressed: onMore,
                      ),
                    ),
                ],
              ),
              if (hint.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else if (footer.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = item.effectiveThumbnail?.trim();
    final imageProvider = thumb == null || thumb.isEmpty
        ? null
        : (thumb.startsWith('http')
              ? NetworkImage(thumb)
              : FileImage(File(thumb)) as ImageProvider);

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              color: scheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: imageProvider != null
                  ? Image(
                      key: ValueKey<String>(thumb!),
                      image: imageProvider,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          _fallbackCover(scheme),
                    )
                  : _fallbackCover(scheme),
            ),
          ),
        ),
        if (selectionMode)
          Positioned(
            top: 4,
            right: 4,
            child: Icon(
              selected
                  ? Icons.check_circle_rounded
                  : (selectable
                        ? Icons.radio_button_unchecked_rounded
                        : Icons.block_rounded),
              size: 20,
              color: selected
                  ? scheme.primary
                  : (selectable ? scheme.onSurface : scheme.outline),
            ),
          ),
      ],
    );
  }

  Widget _fallbackCover(ColorScheme scheme) {
    return Icon(fallbackIcon, color: scheme.onSurfaceVariant);
  }
}

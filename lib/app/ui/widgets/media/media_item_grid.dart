import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../../utils/media_item_status_helper.dart';

import '../../themes/app_grid_theme.dart';

typedef MediaGridItemCallback = void Function(MediaItem item, int index);
typedef MediaGridTextBuilder = String? Function(MediaItem item, int index);
typedef MediaGridWidgetBuilder = Widget? Function(MediaItem item, int index);
typedef MediaGridBoolBuilder = bool Function(MediaItem item, int index);

class MediaItemGrid extends StatelessWidget {
  const MediaItemGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.onLongPress,
    this.onMore,
    this.hintBuilder,
    this.footerBuilder,
    this.coverOverlayBuilder,
    this.selectedBuilder,
    this.selectableBuilder,
    this.selectionMode = false,
    this.onSelectionTap,
    this.fallbackIcon = Icons.music_note_rounded,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.shrinkWrap = false,
    this.childAspectRatio = AppGridTheme.childAspectRatio,
    this.coverAspectRatio = 1,
    this.crossAxisCount,
    this.crossAxisSpacing = AppGridTheme.spacing,
    this.mainAxisSpacing = AppGridTheme.spacing,
  });

  final List<MediaItem> items;
  final MediaGridItemCallback onTap;
  final MediaGridItemCallback? onLongPress;
  final MediaGridItemCallback? onMore;
  final MediaGridTextBuilder? hintBuilder;
  final MediaGridTextBuilder? footerBuilder;
  final MediaGridWidgetBuilder? coverOverlayBuilder;
  final MediaGridBoolBuilder? selectedBuilder;
  final MediaGridBoolBuilder? selectableBuilder;
  final bool selectionMode;
  final MediaGridItemCallback? onSelectionTap;
  final IconData fallbackIcon;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final double childAspectRatio;
  final double coverAspectRatio;
  final int? crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedCrossAxisCount =
            crossAxisCount ??
            (coverAspectRatio > 1.2
                ? AppGridTheme.getVideoCrossAxisCount(constraints.maxWidth)
                : AppGridTheme.getCrossAxisCount(constraints.maxWidth));
        return GridView.builder(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: items.length,
          addAutomaticKeepAlives: false,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: resolvedCrossAxisCount,
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
      coverAspectRatio: coverAspectRatio,
      hintText: hintBuilder?.call(item, index),
      footerText: footerBuilder?.call(item, index),
      coverOverlay: coverOverlayBuilder?.call(item, index),
      selected: selectedBuilder?.call(item, index) ?? false,
      selectable: selectableBuilder?.call(item, index) ?? true,
      selectionMode: selectionMode,
      fallbackIcon: fallbackIcon,
      onTap: () => selectionMode
          ? (onSelectionTap ?? onTap).call(item, index)
          : onTap(item, index),
      onLongPress: onLongPress == null && onMore == null
          ? null
          : () => (onLongPress ?? onMore)!(item, index),
      onMore: onMore == null ? null : () => onMore!(item, index),
    );
  }
}

class MediaItemSliverGrid extends StatelessWidget {
  const MediaItemSliverGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.desktopSongGrid = false,
    this.desktopGridHorizontalInset = 80,
    this.onLongPress,
    this.onMore,
    this.hintBuilder,
    this.footerBuilder,
    this.coverOverlayBuilder,
    this.selectedBuilder,
    this.selectableBuilder,
    this.selectionMode = false,
    this.onSelectionTap,
    this.fallbackIcon = Icons.music_note_rounded,
    this.padding = EdgeInsets.zero,
    this.childAspectRatio = AppGridTheme.childAspectRatio,
    this.coverAspectRatio = 1,
    this.crossAxisCount,
    this.crossAxisSpacing = AppGridTheme.spacing,
    this.mainAxisSpacing = AppGridTheme.spacing,
  });

  final List<MediaItem> items;
  final bool desktopSongGrid;
  final double desktopGridHorizontalInset;
  final MediaGridItemCallback onTap;
  final MediaGridItemCallback? onLongPress;
  final MediaGridItemCallback? onMore;
  final MediaGridTextBuilder? hintBuilder;
  final MediaGridTextBuilder? footerBuilder;
  final MediaGridWidgetBuilder? coverOverlayBuilder;
  final MediaGridBoolBuilder? selectedBuilder;
  final MediaGridBoolBuilder? selectableBuilder;
  final bool selectionMode;
  final MediaGridItemCallback? onSelectionTap;
  final IconData fallbackIcon;
  final EdgeInsetsGeometry padding;
  final double childAspectRatio;
  final double coverAspectRatio;
  final int? crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        if (desktopSongGrid) {
          final insets = padding
              .resolve(Directionality.of(context))
              .add(
                EdgeInsets.symmetric(horizontal: desktopGridHorizontalInset),
              );
          final available = (constraints.crossAxisExtent - insets.horizontal)
              .clamp(1.0, double.infinity);
          final columns = ((available + 16) / 280).floor().clamp(1, 4);
          final scale = MediaQuery.textScalerOf(context).scale(1);
          return SliverPadding(
            padding: insets,
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 120 * scale,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildTile(index),
                childCount: items.length,
              ),
            ),
          );
        }
        final resolvedCrossAxisCount =
            crossAxisCount ??
            (coverAspectRatio > 1.2
                ? AppGridTheme.getVideoCrossAxisCount(
                    constraints.crossAxisExtent,
                  )
                : AppGridTheme.getCrossAxisCount(constraints.crossAxisExtent));
        return SliverPadding(
          padding: padding,
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildTile(index),
              childCount: items.length,
              addAutomaticKeepAlives: false,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: resolvedCrossAxisCount,
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
      desktopSongTile: desktopSongGrid,
      coverAspectRatio: coverAspectRatio,
      hintText: hintBuilder?.call(item, index),
      footerText: footerBuilder?.call(item, index),
      coverOverlay: coverOverlayBuilder?.call(item, index),
      selected: selectedBuilder?.call(item, index) ?? false,
      selectable: selectableBuilder?.call(item, index) ?? true,
      selectionMode: selectionMode,
      fallbackIcon: fallbackIcon,
      onTap: () => selectionMode
          ? (onSelectionTap ?? onTap).call(item, index)
          : onTap(item, index),
      onLongPress: onLongPress == null && onMore == null
          ? null
          : () => (onLongPress ?? onMore)!(item, index),
      onMore: onMore == null ? null : () => onMore!(item, index),
    );
  }
}

class MediaGridTile extends StatelessWidget {
  const MediaGridTile({
    super.key,
    required this.item,
    required this.onTap,
    this.desktopSongTile = false,
    this.onLongPress,
    this.onMore,
    this.hintText,
    this.footerText,
    this.coverOverlay,
    this.selected = false,
    this.selectable = true,
    this.selectionMode = false,
    this.fallbackIcon = Icons.music_note_rounded,
    this.coverAspectRatio = 1,
  });

  final MediaItem item;
  final bool desktopSongTile;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;
  final String? hintText;
  final String? footerText;
  final Widget? coverOverlay;
  final bool selected;
  final bool selectable;
  final bool selectionMode;
  final IconData fallbackIcon;
  final double coverAspectRatio;

  @override
  Widget build(BuildContext context) {
    if (desktopSongTile) return _DesktopSongGridTile(config: this);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hint = hintText?.trim() ?? '';
    final footer = footerText?.trim() ?? '';

    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.14)
          : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      elevation: selected ? 2 : 0,
      shadowColor: scheme.shadow.withValues(alpha: 0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.68)
                  : scheme.outlineVariant.withValues(alpha: 0.2),
              width: selected ? 1.4 : 1.0,
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: coverAspectRatio > 1.2 ? 5 : 7,
                child: AspectRatio(
                  aspectRatio: coverAspectRatio,
                  child: _cover(context),
                ),
              ),
              Expanded(
                flex: coverAspectRatio > 1.2 ? 3 : 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 9),
                    Text(
                      item.title,
                      maxLines: 1,
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
            borderRadius: BorderRadius.circular(12),
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
        Positioned(top: 6, left: 6, child: VideoBadgesOverlay(item: item)),
        if (!selectionMode && coverOverlay != null)
          Positioned(right: 6, bottom: 6, child: coverOverlay!),
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

class _DesktopSongGridTile extends StatefulWidget {
  const _DesktopSongGridTile({required this.config});
  final MediaGridTile config;
  @override
  State<_DesktopSongGridTile> createState() => _DesktopSongGridTileState();
}

class _DesktopSongGridTileState extends State<_DesktopSongGridTile> {
  bool hovered = false, focused = false;
  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extra = (config.hintText?.trim().isNotEmpty ?? false)
        ? config.hintText!
        : config.footerText?.trim() ?? '';
    return Focus(
      canRequestFocus: false,
      onFocusChange: (value) => setState(() => focused = value),
      child: Material(
        color: config.selected
            ? scheme.primaryContainer
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: config.onTap,
          onLongPress: config.onLongPress ?? config.onMore,
          onSecondaryTap: config.onLongPress ?? config.onMore,
          onHover: (value) => setState(() => hovered = value),
          hoverColor: scheme.primary.withValues(alpha: .07),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final coverSize = constraints.maxWidth < 220 ? 56.0 : 74.0;
                return Row(
                  children: [
                    SizedBox.square(
                      dimension: coverSize,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          config._cover(context),
                          if (!config.selectionMode)
                            Positioned(
                              left: 2,
                              bottom: 2,
                              child: Visibility(
                                visible: hovered || focused,
                                maintainState: true,
                                maintainAnimation: true,
                                maintainSize: true,
                                child: IconButton.filled(
                                  onPressed: config.onTap,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            config.item.displaySubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (extra.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              extra,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../../utils/media_item_status_helper.dart';
import '../../themes/app_grid_theme.dart';
import '../../themes/app_spacing.dart';
import 'media_item_grid.dart';

class AppMediaItemsSliver extends StatelessWidget {
  const AppMediaItemsSliver({
    super.key,
    required this.items,
    required this.gridView,
    required this.onTap,
    this.onLongPress,
    this.hintBuilder,
    this.footerBuilder,
    this.coverOverlayBuilder,
    this.selectedBuilder,
    this.selectableBuilder,
    this.selectionMode = false,
    this.onSelectionTap,
    this.videoStyle = false,
    this.fallbackIcon,
    this.compactListCard = false,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  });

  final List<MediaItem> items;
  final bool gridView;
  final MediaGridItemCallback onTap;
  final MediaGridItemCallback? onLongPress;
  final MediaGridTextBuilder? hintBuilder;
  final MediaGridTextBuilder? footerBuilder;
  final MediaGridWidgetBuilder? coverOverlayBuilder;
  final MediaGridBoolBuilder? selectedBuilder;
  final MediaGridBoolBuilder? selectableBuilder;
  final bool selectionMode;
  final MediaGridItemCallback? onSelectionTap;
  final bool videoStyle;
  final IconData? fallbackIcon;
  final bool compactListCard;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (gridView) {
      return MediaItemSliverGrid(
        items: items,
        padding: padding.add(const EdgeInsets.only(bottom: AppSpacing.lg)),
        childAspectRatio: videoStyle
            ? AppGridTheme.videoChildAspectRatio
            : AppGridTheme.childAspectRatio,
        coverAspectRatio: videoStyle ? 16 / 9 : 1,
        crossAxisCount: null,
        fallbackIcon:
            fallbackIcon ??
            (videoStyle ? Icons.videocam_rounded : Icons.music_note_rounded),
        hintBuilder: hintBuilder,
        footerBuilder: footerBuilder,
        coverOverlayBuilder: coverOverlayBuilder,
        selectedBuilder: selectedBuilder,
        selectableBuilder: selectableBuilder,
        selectionMode: selectionMode,
        onSelectionTap: onSelectionTap,
        onTap: onTap,
        onLongPress: onLongPress,
      );
    }

    return SliverPadding(
      padding: padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          return Padding(
            padding: EdgeInsets.only(bottom: videoStyle ? 18 : 8),
            child: AppMediaListTile(
              item: item,
              videoStyle: videoStyle,
              carded: compactListCard,
              onTap: () => onTap(item, index),
              onLongPress: onLongPress == null
                  ? null
                  : () => onLongPress!(item, index),
              onMore: onLongPress == null
                  ? null
                  : () => onLongPress!(item, index),
            ),
          );
        }, childCount: items.length),
      ),
    );
  }
}

class AppMediaItemsList extends StatelessWidget {
  const AppMediaItemsList({
    super.key,
    required this.items,
    required this.gridView,
    required this.onTap,
    this.onLongPress,
    this.hintBuilder,
    this.footerBuilder,
    this.coverOverlayBuilder,
    this.videoStyle = false,
    this.fallbackIcon,
    this.compactListCard = false,
    this.gridPadding = EdgeInsets.zero,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  final List<MediaItem> items;
  final bool gridView;
  final MediaGridItemCallback onTap;
  final MediaGridItemCallback? onLongPress;
  final MediaGridTextBuilder? hintBuilder;
  final MediaGridTextBuilder? footerBuilder;
  final MediaGridWidgetBuilder? coverOverlayBuilder;
  final bool videoStyle;
  final IconData? fallbackIcon;
  final bool compactListCard;
  final EdgeInsetsGeometry gridPadding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    if (gridView) {
      return MediaItemGrid(
        items: items,
        padding: gridPadding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        childAspectRatio: videoStyle
            ? AppGridTheme.videoChildAspectRatio
            : AppGridTheme.childAspectRatio,
        coverAspectRatio: videoStyle ? 16 / 9 : 1,
        crossAxisCount: null,
        crossAxisSpacing: AppGridTheme.spacing,
        mainAxisSpacing: AppGridTheme.spacing,
        fallbackIcon:
            fallbackIcon ??
            (videoStyle ? Icons.videocam_rounded : Icons.music_note_rounded),
        hintBuilder: hintBuilder,
        footerBuilder: footerBuilder,
        coverOverlayBuilder: coverOverlayBuilder,
        onTap: onTap,
        onLongPress: onLongPress,
      );
    }

    return Column(
      children: [
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: EdgeInsets.only(bottom: videoStyle ? 18 : 8),
            child: AppMediaListTile(
              item: items[index],
              videoStyle: videoStyle,
              carded: compactListCard,
              onTap: () => onTap(items[index], index),
              onLongPress: onLongPress == null
                  ? null
                  : () => onLongPress!(items[index], index),
              onMore: onLongPress == null
                  ? null
                  : () => onLongPress!(items[index], index),
            ),
          ),
      ],
    );
  }
}

class AppMediaListTile extends StatelessWidget {
  const AppMediaListTile({
    super.key,
    required this.item,
    this.videoStyle = false,
    this.carded = false,
    this.onTap,
    this.onLongPress,
    this.onMore,
  });

  final MediaItem item;
  final bool videoStyle;
  final bool carded;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return videoStyle ? _VideoListTile(this) : _AudioListTile(this);
  }
}

class AppMediaActionListTile extends StatelessWidget {
  const AppMediaActionListTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
    this.videoStyle = false,
    this.hintText,
    this.trailing,
    this.showFeedbackActions = false,
    this.selectionMode = false,
    this.selected = false,
    this.selectable = true,
    this.onToggleSelection,
    this.onInterested,
    this.onHideTrack,
    this.onHideArtist,
    this.onSelectMultiple,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool videoStyle;
  final String? hintText;
  final Widget? trailing;
  final bool showFeedbackActions;
  final bool selectionMode;
  final bool selected;
  final bool selectable;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onInterested;
  final VoidCallback? onHideTrack;
  final VoidCallback? onHideArtist;
  final VoidCallback? onSelectMultiple;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(videoStyle ? 12 : 16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.all(videoStyle ? 0 : 10),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : (videoStyle ? Colors.transparent : scheme.surfaceContainerHigh),
          borderRadius: BorderRadius.circular(videoStyle ? 12 : 16),
          border: selected
              ? Border.all(
                  color: scheme.primary.withValues(alpha: 0.55),
                  width: 1.2,
                )
              : null,
        ),
        child: Row(
          children: [
            _ActionThumb(item: item, videoStyle: videoStyle),
            SizedBox(width: videoStyle ? 16 : 12),
            Expanded(
              child: _ActionText(
                item: item,
                videoStyle: videoStyle,
                hintText: hintText,
              ),
            ),
            const SizedBox(width: 8),
            if (selectionMode)
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: selectable ? onToggleSelection : null,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : (selectable
                              ? Icons.radio_button_unchecked_rounded
                              : Icons.block_rounded),
                    color: selected
                        ? scheme.primary
                        : (selectable
                              ? scheme.onSurfaceVariant
                              : scheme.outline),
                    size: 22,
                  ),
                ),
              )
            else if (showFeedbackActions && !videoStyle)
              _FeedbackMenu(
                onInterested: onInterested,
                onHideTrack: onHideTrack,
                onHideArtist: onHideArtist,
                onSelectMultiple: onSelectMultiple,
              ),
            if (showFeedbackActions && !videoStyle) const SizedBox(width: 4),
            trailing ??
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: scheme.primary),
                ),
          ],
        ),
      ),
    );
  }
}

class _ActionText extends StatelessWidget {
  const _ActionText({
    required this.item,
    required this.videoStyle,
    required this.hintText,
  });

  final MediaItem item;
  final bool videoStyle;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: videoStyle ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        if (videoStyle) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if ((item.localVideoVariant?.format ?? '').trim().isNotEmpty)
                _VideoMetaChip(
                  label: item.localVideoVariant!.format.trim().toUpperCase(),
                ),
              if ((item.localVideoVariant?.size ?? 0) > 0)
                _VideoMetaChip(
                  label: _formatBytes(item.localVideoVariant!.size!),
                ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            item.displaySubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if ((hintText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              hintText!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _ActionThumb extends StatelessWidget {
  const _ActionThumb({required this.item, required this.videoStyle});

  final MediaItem item;
  final bool videoStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = _imageProvider(item.effectiveThumbnail);
    final width = videoStyle ? 148.0 : 56.0;
    final height = videoStyle ? 84.0 : 56.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(videoStyle ? 14 : 12),
      child: Stack(
        children: [
          SizedBox(
            width: width,
            height: height,
            child: provider != null
                ? Image(
                    key: ValueKey<String>(item.effectiveThumbnail ?? ''),
                    image: provider,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _fallbackActionThumb(scheme, width, height),
                  )
                : _fallbackActionThumb(scheme, width, height),
          ),
          if (videoStyle)
            Positioned(top: 8, left: 8, child: VideoBadgesOverlay(item: item)),
          if (videoStyle)
            Positioned(
              left: 8,
              bottom: 7,
              child: _DurationBadge(seconds: item.effectiveDurationSeconds),
            ),
        ],
      ),
    );
  }

  Widget _fallbackActionThumb(ColorScheme scheme, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(videoStyle ? 14 : 12),
      ),
      child: Icon(
        videoStyle ? Icons.videocam_rounded : Icons.music_note,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _FeedbackMenu extends StatelessWidget {
  const _FeedbackMenu({
    this.onInterested,
    this.onHideTrack,
    this.onHideArtist,
    this.onSelectMultiple,
  });

  final VoidCallback? onInterested;
  final VoidCallback? onHideTrack;
  final VoidCallback? onHideArtist;
  final VoidCallback? onSelectMultiple;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<_FeedbackAction>(
      tooltip: tr('media_actions.feedback'),
      icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        switch (value) {
          case _FeedbackAction.selectMultiple:
            onSelectMultiple?.call();
            break;
          case _FeedbackAction.interested:
            onInterested?.call();
            break;
          case _FeedbackAction.hideTrack:
            onHideTrack?.call();
            break;
          case _FeedbackAction.hideArtist:
            onHideArtist?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        if (onSelectMultiple != null)
          PopupMenuItem(
            value: _FeedbackAction.selectMultiple,
            child: _FeedbackItem(
              icon: Icons.checklist_rounded,
              color: scheme.primary,
              label: tr('media_actions.multi_select'),
            ),
          ),
        PopupMenuItem(
          value: _FeedbackAction.interested,
          child: _FeedbackItem(
            icon: Icons.thumb_up_alt_outlined,
            color: scheme.primary,
            label: tr('media_actions.interested'),
          ),
        ),
        PopupMenuItem(
          value: _FeedbackAction.hideTrack,
          child: _FeedbackItem(
            icon: Icons.visibility_off_outlined,
            color: scheme.error,
            label: tr('media_actions.hide_song'),
          ),
        ),
        PopupMenuItem(
          value: _FeedbackAction.hideArtist,
          child: _FeedbackItem(
            icon: Icons.person_off_outlined,
            color: scheme.tertiary,
            label: tr('media_actions.hide_artist'),
          ),
        ),
      ],
    );
  }
}

class _FeedbackItem extends StatelessWidget {
  const _FeedbackItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

enum _FeedbackAction { selectMultiple, interested, hideTrack, hideArtist }

class _AudioListTile extends StatelessWidget {
  const _AudioListTile(this.config);

  final AppMediaListTile config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = config.item;
    final imageProvider = _imageProvider(item.effectiveThumbnail);

    return Card(
      elevation: 0,
      color: config.carded ? scheme.surfaceContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(config.carded ? 18 : 12),
      ),
      child: ListTile(
        onTap: config.onTap,
        onLongPress: config.onLongPress ?? config.onMore,
        contentPadding: config.carded
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
            : EdgeInsets.zero,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 44,
            color: scheme.surfaceContainerHighest,
            child: imageProvider != null
                ? Image(image: imageProvider, fit: BoxFit.cover)
                : Icon(
                    Icons.music_note_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
          ),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        subtitle: item.displaySubtitle.trim().isEmpty
            ? null
            : Text(
                item.displaySubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: IconButton(
          icon: Icon(Icons.play_arrow_rounded, color: scheme.primary),
          onPressed: config.onTap,
        ),
      ),
    );
  }
}

class _VideoListTile extends StatelessWidget {
  const _VideoListTile(this.config);

  final AppMediaListTile config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = config.item;
    final videoVariant = item.localVideoVariant;
    final chips = <String>[
      if ((videoVariant?.format ?? '').trim().isNotEmpty)
        videoVariant!.format.trim().toUpperCase(),
      if ((videoVariant?.size ?? 0) > 0) _formatBytes(videoVariant!.size!),
    ];
    final meta = _buildMeta(item);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: config.onTap,
        onLongPress: config.onLongPress ?? config.onMore,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: EdgeInsets.zero,
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _VideoThumb(item: item),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final chip in chips) _VideoMetaChip(label: chip),
                        if (chips.isEmpty) _VideoMetaChip(label: meta),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageProvider = _imageProvider(item.effectiveThumbnail);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          SizedBox(
            width: 148,
            height: 84,
            child: imageProvider != null
                ? Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _fallbackThumb(scheme, Icons.videocam_rounded),
                  )
                : _fallbackThumb(scheme, Icons.videocam_rounded),
          ),
          Positioned(top: 8, left: 8, child: VideoBadgesOverlay(item: item)),
          Positioned(
            left: 8,
            bottom: 7,
            child: _DurationBadge(seconds: item.effectiveDurationSeconds),
          ),
        ],
      ),
    );
  }

  Widget _fallbackThumb(ColorScheme scheme, IconData icon) {
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(icon, color: scheme.onSurfaceVariant),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.seconds});

  final int? seconds;

  @override
  Widget build(BuildContext context) {
    final label = _formatDuration(seconds);
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VideoMetaChip extends StatelessWidget {
  const _VideoMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

ImageProvider? _imageProvider(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value.startsWith('http')
      ? NetworkImage(value)
      : FileImage(File(value)) as ImageProvider;
}

String _buildMeta(MediaItem item) {
  final parts = <String>[];
  if (item.hasAudioLocal && item.hasVideoLocal) {
    parts.add('Audio/Video');
  } else if (item.hasVideoLocal) {
    parts.add('Video');
  } else if (item.hasAudioLocal) {
    parts.add('Audio');
  }

  final dur = _formatDuration(item.effectiveDurationSeconds);
  if (dur != null) parts.add(dur);

  final origin = item.origin.name.trim();
  if (origin.isNotEmpty) parts.add(origin);

  return parts.isEmpty ? 'Media' : parts.join(' • ');
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}

String? _formatDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return null;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

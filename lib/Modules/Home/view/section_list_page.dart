import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/models/media_item.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';

class SectionListPage extends StatefulWidget {
  const SectionListPage({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
    required this.onItemLongPress,
    this.onShuffle,
    this.itemHintBuilder,
    this.onInterested,
    this.onHideTrack,
    this.onHideArtist,
  });

  final String title;
  final List<MediaItem> items;
  final FutureOr<void> Function(MediaItem item, int index) onItemTap;
  final FutureOr<void> Function(MediaItem item, int index) onItemLongPress;
  final void Function(List<MediaItem> queue)? onShuffle;
  final String? Function(MediaItem item, int index)? itemHintBuilder;
  final FutureOr<void> Function(MediaItem item, int index)? onInterested;
  final FutureOr<void> Function(MediaItem item, int index)? onHideTrack;
  final FutureOr<void> Function(MediaItem item, int index)? onHideArtist;

  @override
  State<SectionListPage> createState() => _SectionListPageState();
}

class _SectionListPageState extends State<SectionListPage> {
  late List<MediaItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List<MediaItem>.from(widget.items);
  }

  @override
  void didUpdateWidget(covariant SectionListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _items = List<MediaItem>.from(widget.items);
    }
  }

  bool get _hasFeedbackActions =>
      widget.onInterested != null ||
      widget.onHideTrack != null ||
      widget.onHideArtist != null;

  Future<void> _handleInterested(MediaItem item, int index) async {
    await widget.onInterested?.call(item, index);
    if (mounted) setState(() {});
  }

  Future<void> _handleHideTrack(MediaItem item, int index) async {
    await widget.onHideTrack?.call(item, index);
    if (!mounted) return;
    setState(() {
      _items.removeWhere((entry) => entry.id == item.id);
    });
  }

  Future<void> _handleHideArtist(MediaItem item, int index) async {
    await widget.onHideArtist?.call(item, index);
    if (!mounted) return;
    final artistKey = _artistKeyFromItem(item);
    setState(() {
      _items.removeWhere((entry) => _artistKeyFromItem(entry) == artistKey);
    });
  }

  String _artistKeyFromItem(MediaItem item) {
    final raw = item.displaySubtitle.trim();
    if (raw.isEmpty) return item.title.trim().toLowerCase();
    final normalized = raw
        .split('·')
        .first
        .split(',')
        .first
        .split(' - ')
        .first
        .trim()
        .toLowerCase();
    return normalized.isEmpty ? item.title.trim().toLowerCase() : normalized;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: ListenfyLogo(size: 28, color: scheme.primary),
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: AppGradientBackground(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          itemCount: _items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.onShuffle != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final queue = List<MediaItem>.from(widget.items);
                          queue.shuffle(Random());
                          if (queue.isEmpty) return;
                          widget.onShuffle?.call(queue);
                        },
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Reproducción aleatoria'),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
              );
            }

            final item = _items[index - 1];
            return _MediaRow(
              item: item,
              hintText: widget.itemHintBuilder?.call(item, index - 1),
              onTap: () async {
                await widget.onItemTap(item, index - 1);
                if (mounted) setState(() {});
              },
              onLongPress: () async {
                await widget.onItemLongPress(item, index - 1);
                if (mounted) setState(() {});
              },
              showFeedbackActions: _hasFeedbackActions,
              onInterested: widget.onInterested == null
                  ? null
                  : () => _handleInterested(item, index - 1),
              onHideTrack: widget.onHideTrack == null
                  ? null
                  : () => _handleHideTrack(item, index - 1),
              onHideArtist: widget.onHideArtist == null
                  ? null
                  : () => _handleHideArtist(item, index - 1),
            );
          },
        ),
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.item,
    required this.hintText,
    required this.onTap,
    required this.onLongPress,
    required this.showFeedbackActions,
    this.onInterested,
    this.onHideTrack,
    this.onHideArtist,
  });

  final MediaItem item;
  final String? hintText;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool showFeedbackActions;
  final FutureOr<void> Function()? onInterested;
  final FutureOr<void> Function()? onHideTrack;
  final FutureOr<void> Function()? onHideArtist;

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
            _Thumb(thumb: item.effectiveThumbnail),
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
                        color: scheme.primary.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (showFeedbackActions)
              PopupMenuButton<_FeedbackAction>(
                tooltip: 'Feedback',
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (value) async {
                  switch (value) {
                    case _FeedbackAction.interested:
                      await onInterested?.call();
                      break;
                    case _FeedbackAction.hideTrack:
                      await onHideTrack?.call();
                      break;
                    case _FeedbackAction.hideArtist:
                      await onHideArtist?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _FeedbackAction.interested,
                    child: Row(
                      children: [
                        Icon(
                          Icons.thumb_up_alt_outlined,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 10),
                        const Text('Me interesa'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _FeedbackAction.hideTrack,
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 18,
                          color: scheme.error,
                        ),
                        const SizedBox(width: 10),
                        const Text('Ocultar canción'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _FeedbackAction.hideArtist,
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 18,
                          color: scheme.tertiary,
                        ),
                        const SizedBox(width: 10),
                        const Text('Ocultar artista'),
                      ],
                    ),
                  ),
                ],
              ),
            if (showFeedbackActions) const SizedBox(width: 4),
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

enum _FeedbackAction { interested, hideTrack, hideArtist }

class _Thumb extends StatelessWidget {
  const _Thumb({required this.thumb});

  final String? thumb;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (thumb != null && thumb!.isNotEmpty) {
      final provider = thumb!.startsWith('http')
          ? NetworkImage(thumb!)
          : FileImage(File(thumb!)) as ImageProvider;
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          key: ValueKey<String>(thumb!),
          image: provider,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.music_note, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.music_note, color: scheme.onSurfaceVariant),
    );
  }
}

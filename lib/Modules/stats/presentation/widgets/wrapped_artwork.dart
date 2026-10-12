import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../app/models/media_item.dart';
import 'wrapped_panel_style.dart';

/// Artwork is decorative; labels stay on a solid themed surface.
class WrappedArtwork extends StatelessWidget {
  const WrappedArtwork({
    super.key,
    required this.item,
    this.size = 52,
    this.aspectRatio = 1,
  });
  final MediaItem item;
  final double size;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget fallback() => ColoredBox(
      color: scheme.primaryContainer,
      child: Center(
        child: Icon(
          aspectRatio > 1 ? Icons.movie_rounded : Icons.music_note_rounded,
          color: scheme.onPrimaryContainer,
          size: size * .35,
        ),
      ),
    );
    Widget remote() {
      final url = item.thumbnail?.trim() ?? '';
      final uri = Uri.tryParse(url);
      if (uri == null || !['http', 'https'].contains(uri.scheme)) {
        return fallback();
      }
      return Image.network(
        url,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    final local = item.thumbnailLocalPath?.trim() ?? '';
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: local.isEmpty
                ? remote()
                : Image.file(
                    File(local),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => remote(),
                  ),
          ),
        ),
      ),
    );
  }
}

class WrappedCoverStrip extends StatelessWidget {
  const WrappedCoverStrip({
    super.key,
    required this.items,
    this.aspectRatio = 1,
  });
  final List<MediaItem> items;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: aspectRatio == 1 ? 108 : 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < items.take(3).length; i++)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Transform.rotate(
                  angle: aspectRatio == 1 ? (i - 1) * .07 : 0,
                  child: WrappedArtwork(
                    item: items[i],
                    size: 88,
                    aspectRatio: aspectRatio,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WrappedTrackSpotlight extends StatelessWidget {
  const WrappedTrackSpotlight({
    super.key,
    required this.item,
    required this.badge,
    required this.caption,
    this.aspectRatio = 1,
  });
  final MediaItem item;
  final String badge;
  final String caption;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              badge,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          item.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        if (item.displaySubtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            item.displaySubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          caption,
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    return Container(
      decoration: wrappedPanelDecoration(context, highlighted: true),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 460;
          final artwork = Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Transform.rotate(
                angle: aspectRatio == 1 ? -.035 : 0,
                child: WrappedArtwork(
                  item: item,
                  aspectRatio: aspectRatio,
                  size: aspectRatio == 1
                      ? (wide ? 180 : 204)
                      : (wide
                            ? 240
                            : (constraints.maxWidth - 16)
                                  .clamp(0, 320)
                                  .toDouble()),
                ),
              ),
            ),
          );
          return wide
              ? Row(
                  children: [
                    artwork,
                    const SizedBox(width: 24),
                    Expanded(child: details),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [artwork, const SizedBox(height: 18), details],
                );
        },
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/models/media_item.dart';
import '../../../app/utils/format_bytes.dart';
import '../domain/source_origin.dart';

class SourceMediaListItem extends StatelessWidget {
  const SourceMediaListItem({
    super.key,
    required this.item,
    this.videoStyle = false,
    this.onTap,
    this.onLongPress,
    this.onMore,
  });

  final MediaItem item;
  final bool videoStyle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = item.displaySubtitle.trim();
    final meta = _buildMeta();
    final videoVariant = item.localVideoVariant;
    final chips = <String>[
      if ((videoVariant?.format ?? '').trim().isNotEmpty)
        videoVariant!.format.trim().toUpperCase(),
      if ((videoVariant?.size ?? 0) > 0) formatBytes(videoVariant!.size!),
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress ?? onMore,
        borderRadius: BorderRadius.circular(videoStyle ? 12 : 16),
        child: Ink(
          padding: EdgeInsets.all(videoStyle ? 0 : 10),
          decoration: BoxDecoration(
            color: videoStyle
                ? Colors.transparent
                : scheme.surfaceContainerHigh.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(videoStyle ? 12 : 16),
            border: videoStyle
                ? null
                : Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.32),
                  ),
          ),
          child: Row(
            crossAxisAlignment: videoStyle
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.center,
            children: [
              _SourceMediaThumb(item: item, videoStyle: videoStyle),
              SizedBox(width: videoStyle ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (videoStyle
                                  ? theme.textTheme.titleSmall
                                  : theme.textTheme.bodyMedium)
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                    ),
                    if (videoStyle) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final chip in chips) _VideoMetaChip(label: chip),
                          if (chips.isEmpty) _VideoMetaChip(label: meta),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle.isNotEmpty ? subtitle : meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.86,
                            ),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (!videoStyle) ...[
                const SizedBox(width: 8),
                Icon(Icons.play_arrow_rounded, color: scheme.primary, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildMeta() {
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

    final origin = item.origin.key.trim();
    if (origin.isNotEmpty) parts.add(origin);

    return parts.isEmpty ? 'Media' : parts.join(' • ');
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
}

class _SourceMediaThumb extends StatelessWidget {
  const _SourceMediaThumb({required this.item, required this.videoStyle});

  final MediaItem item;
  final bool videoStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = item.effectiveThumbnail?.trim();

    final fallbackIcon = item.hasVideoLocal && !item.hasAudioLocal
        ? Icons.videocam_rounded
        : Icons.music_note_rounded;

    if (thumb != null && thumb.isNotEmpty) {
      final provider = thumb.startsWith('http')
          ? NetworkImage(thumb)
          : FileImage(File(thumb)) as ImageProvider;
      return ClipRRect(
        borderRadius: BorderRadius.circular(videoStyle ? 14 : 12),
        child: Stack(
          children: [
            Image(
              image: provider,
              width: videoStyle ? 148 : 56,
              height: videoStyle ? 84 : 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _fallbackThumb(scheme, fallbackIcon);
              },
            ),
            if (videoStyle)
              Positioned(
                left: 8,
                bottom: 7,
                child: _DurationBadge(seconds: item.effectiveDurationSeconds),
              )
            else
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(fallbackIcon, size: 11, color: Colors.white),
                ),
              ),
          ],
        ),
      );
    }

    return _fallbackThumb(scheme, fallbackIcon);
  }

  Widget _fallbackThumb(ColorScheme scheme, IconData icon) {
    return Container(
      width: videoStyle ? 148 : 56,
      height: videoStyle ? 84 : 56,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(videoStyle ? 14 : 12),
      ),
      child: Icon(icon, color: scheme.onSurfaceVariant),
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

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.seconds});

  final int? seconds;

  @override
  Widget build(BuildContext context) {
    final label = _formatDuration(seconds);
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static String? _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

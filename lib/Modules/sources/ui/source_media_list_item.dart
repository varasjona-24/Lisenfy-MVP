import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/models/media_item.dart';
import '../domain/source_origin.dart';

class SourceMediaListItem extends StatelessWidget {
  const SourceMediaListItem({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.onMore,
  });

  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = item.displaySubtitle.trim();
    final meta = _buildMeta();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress ?? onMore,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.32),
            ),
          ),
          child: Row(
            children: [
              _SourceMediaThumb(item: item),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.play_arrow_rounded, color: scheme.primary, size: 22),
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
  const _SourceMediaThumb({required this.item});

  final MediaItem item;

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
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Image(
              image: provider,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _fallbackThumb(scheme, fallbackIcon);
              },
            ),
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
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: scheme.onSurfaceVariant),
    );
  }
}

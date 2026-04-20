import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/models/media_item.dart';
import '../../domain/entities/country_station_entity.dart';

class CountryStationCard extends StatelessWidget {
  const CountryStationCard({
    super.key,
    required this.station,
    required this.onPlay,
    required this.onContinue,
    required this.onTrackTap,
  });

  final CountryStationEntity station;
  final VoidCallback onPlay;
  final VoidCallback onContinue;
  final void Function(MediaItem item) onTrackTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StationArt(station: station),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        station.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ChipLabel(
                            icon: Icons.queue_music_rounded,
                            text: '${station.tracks.length} tracks',
                          ),
                          _ChipLabel(
                            icon: Icons.memory_rounded,
                            text: station.source,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Reproducir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Continuar'),
                  ),
                ),
              ],
            ),
            if (station.tracks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Preview',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ...station.tracks
                  .take(3)
                  .map(
                    (item) => _PreviewTrackTile(
                      item: item,
                      onTap: () => onTrackTap(item),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StationArt extends StatelessWidget {
  const _StationArt({required this.station});

  final CountryStationEntity station;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = station.tracks.isNotEmpty
        ? station.tracks.first.effectiveThumbnail
        : null;
    if (thumb != null && thumb.isNotEmpty) {
      final provider = thumb.startsWith('http')
          ? NetworkImage(thumb)
          : FileImage(File(thumb)) as ImageProvider;
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          key: ValueKey<String>('${station.stationId}-$thumb'),
          image: provider,
          fit: BoxFit.cover,
          width: 82,
          height: 82,
          errorBuilder: (context, error, stackTrace) => _fallback(scheme),
        ),
      );
    }
    return _fallback(scheme);
  }

  Widget _fallback(ColorScheme scheme) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainerHighest,
      ),
      child: Icon(Icons.public_rounded, color: scheme.primary),
    );
  }
}

class _PreviewTrackTile extends StatelessWidget {
  const _PreviewTrackTile({required this.item, required this.onTap});

  final MediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
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
                  Text(
                    item.displaySubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_outline_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(text, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

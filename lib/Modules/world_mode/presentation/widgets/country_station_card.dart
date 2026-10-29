import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

import '../../../../app/models/media_item.dart';
import '../../domain/entities/country_station_entity.dart';

class CountryStationCard extends StatelessWidget {
  const CountryStationCard({
    super.key,
    required this.station,
    this.desktop = false,
    required this.onPlay,
    required this.onContinue,
    required this.onTrackTap,
  });

  final CountryStationEntity station;
  final bool desktop;
  final VoidCallback onPlay;
  final VoidCallback onContinue;
  final void Function(MediaItem item) onTrackTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (desktop) {
      return Card(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StationArt(station: station),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: onPlay,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(tr('player.play')),
                            ),
                            OutlinedButton.icon(
                              onPressed: onContinue,
                              icon: const Icon(Icons.skip_next_rounded),
                              label: Text(tr('common.continue')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (station.tracks.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  tr('world_mode.preview'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 780
                        ? (constraints.maxWidth - 24) / 3
                        : 260.0;
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    return SizedBox(
                      height: 64 * scale,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: station.tracks.take(3).length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = station.tracks[index];
                          return SizedBox(
                            width: width,
                            child: _PreviewTrackTile(
                              item: item,
                              onTap: () => onTrackTap(item),
                              showCover: true,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

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
                    label: Text(tr('player.play')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: Text(tr('common.continue')),
                  ),
                ),
              ],
            ),
            if (station.tracks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                tr('world_mode.preview'),
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
      final ImageProvider provider = thumb.startsWith('assets/')
          ? AssetImage(thumb)
          : thumb.startsWith('http')
          ? NetworkImage(thumb)
          : FileImage(File(thumb));
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
  const _PreviewTrackTile({
    required this.item,
    required this.onTap,
    this.showCover = false,
  });
  final bool showCover;

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
            if (showCover) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox.square(
                  dimension: 40,
                  child: _trackCover(item, scheme),
                ),
              ),
              const SizedBox(width: 10),
            ],
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

Widget _trackCover(MediaItem item, ColorScheme scheme) {
  final thumb = item.effectiveThumbnail;
  final fallback = ColoredBox(
    color: scheme.surfaceContainerHighest,
    child: Icon(Icons.music_note_rounded, color: scheme.onSurfaceVariant),
  );
  if (thumb == null || thumb.isEmpty) return fallback;
  final ImageProvider provider = thumb.startsWith('assets/')
      ? AssetImage(thumb)
      : thumb.startsWith('http')
      ? NetworkImage(thumb)
      : FileImage(File(thumb));
  return Image(
    image: provider,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => fallback,
  );
}

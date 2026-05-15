import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../Modules/artists/data/artist_store.dart';
import '../../../../Modules/world_mode/agent/local_affinity_engine.dart';
import '../../../../Modules/world_mode/domain/entities/world_region_catalog.dart';
import '../../../../app/data/local/local_library_store.dart';
import '../../../../app/models/media_item.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../../app/utils/artist_credit_parser.dart';

class ListeningStatsPage extends StatelessWidget {
  const ListeningStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Get.find<LocalLibraryStore>();
    final artistStore = Get.isRegistered<ArtistStore>()
        ? Get.find<ArtistStore>()
        : null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Tus estadisticas'),
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: AppGradientBackground(
        child: FutureBuilder<List<MediaItem>>(
          future: store.readAll(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final stats = _ListeningStats.fromItems(
              snapshot.data ?? const [],
              artistStore: artistStore,
            );
            if (stats.hasAnyData == false) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aun no hay suficientes imports o reproducciones para armar tu resumen.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _HeroSummary(stats: stats),
                  const SizedBox(height: 14),
                  const _SectionTitle(
                    title: 'Reproduccion musical',
                    subtitle: 'Solo canciones con audio local.',
                  ),
                  const SizedBox(height: 10),
                  _MetricGrid(stats: stats),
                  const SizedBox(height: 14),
                  _TopTrackCard(
                    title: 'Tu cancion mas escuchada',
                    item: stats.topTrack,
                  ),
                  const SizedBox(height: 14),
                  _RankedListCard(
                    title: 'Top canciones escuchadas',
                    icon: Icons.leaderboard_rounded,
                    rows: stats.topTracks
                        .map(
                          (item) => _RankedRowData(
                            title: item.title,
                            subtitle: item.displaySubtitle,
                            value:
                                '${_ListeningStats.listenScoreFor(item)} escuchas',
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  _RankedListCard(
                    title: 'Top artistas escuchados',
                    icon: Icons.mic_external_on_rounded,
                    rows: stats.topArtists
                        .map(
                          (artist) => _RankedRowData(
                            title: artist.name,
                            subtitle: '${artist.tracks} canciones',
                            value: '${artist.plays} plays',
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  _RankedListCard(
                    title: 'Favoritos mas escuchados',
                    icon: Icons.favorite_rounded,
                    rows: stats.topFavoriteTracks
                        .map(
                          (item) => _RankedRowData(
                            title: item.title,
                            subtitle: item.displaySubtitle,
                            value:
                                '${_ListeningStats.listenScoreFor(item)} escuchas',
                          ),
                        )
                        .toList(),
                    emptyText: 'Aun no hay favoritos reproducidos.',
                  ),
                  const SizedBox(height: 14),
                  _RegionsCard(regions: stats.topRegions),
                  const SizedBox(height: 14),
                  _RankedListCard(
                    title: 'Completadas',
                    icon: Icons.check_circle_rounded,
                    rows: stats.mostCompleted
                        .map(
                          (item) => _RankedRowData(
                            title: item.title,
                            subtitle: item.displaySubtitle,
                            value:
                                '${_ListeningStats.effectiveCompletedFor(item)} completas',
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  _RankedListCard(
                    title: 'Saltadas temprano',
                    icon: Icons.skip_next_rounded,
                    rows: stats.mostSkipped
                        .map(
                          (item) => _RankedRowData(
                            title: item.title,
                            subtitle: item.displaySubtitle,
                            value: '${item.skipCount} skips',
                          ),
                        )
                        .toList(),
                    emptyText: 'No hay saltos tempranos registrados.',
                  ),
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    title: 'Imports',
                    subtitle:
                        'Descargas locales separadas por canciones y videos.',
                  ),
                  const SizedBox(height: 10),
                  _ImportSummaryCard(stats: stats),
                  const SizedBox(height: 14),
                  _RankedListCard(
                    title: 'Artistas con mas canciones descargadas este mes',
                    icon: Icons.calendar_month_rounded,
                    rows: stats.topImportedArtistsLastMonth
                        .map(
                          (artist) => _RankedRowData(
                            title: artist.name,
                            subtitle: '${artist.tracks} canciones distintas',
                            value: '${artist.imports} imports',
                          ),
                        )
                        .toList(),
                    emptyText:
                        'Sin canciones importadas en los ultimos 30 dias.',
                  ),
                  const SizedBox(height: 14),
                  _RankedListCard(
                    title: 'Top artistas por imports',
                    icon: Icons.library_music_rounded,
                    rows: stats.topImportedArtists
                        .map(
                          (artist) => _RankedRowData(
                            title: artist.name,
                            subtitle: '${artist.tracks} canciones distintas',
                            value: '${artist.imports} imports',
                          ),
                        )
                        .toList(),
                    emptyText: 'Sin imports de canciones suficientes.',
                  ),
                  const SizedBox(height: 14),
                  _ImportPeaksCard(stats: stats),
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    title: 'Videos',
                    subtitle:
                        'Metrica separada para no mezclarla con canciones.',
                  ),
                  const SizedBox(height: 10),
                  _VideoSummaryCard(stats: stats),
                  const SizedBox(height: 14),
                  _RankedListCard(
                    title: 'Videos mas reproducidos',
                    icon: Icons.ondemand_video_rounded,
                    rows: stats.topVideos
                        .map(
                          (item) => _RankedRowData(
                            title: item.title,
                            subtitle: item.displaySubtitle,
                            value:
                                '${_ListeningStats.listenScoreFor(item)} vistas',
                          ),
                        )
                        .toList(),
                    emptyText: 'Aun no hay reproducciones de video.',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.stats});

  final _ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topArtist = stats.topArtists.isEmpty
        ? 'tu biblioteca'
        : stats.topArtists.first.name;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_graph_rounded, color: scheme.onPrimaryContainer),
          const SizedBox(height: 12),
          Text(
            'Tu resumen Listenfy',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Has acumulado ${stats.totalPlays} reproducciones de audio, ${stats.totalImportFiles} archivos importados y tu artista dominante es $topArtist.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.84),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.stats});

  final _ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.42,
      children: [
        _MetricTile(label: 'Reproducciones', value: '${stats.totalPlays}'),
        _MetricTile(label: 'Completadas', value: '${stats.totalCompleted}'),
        _MetricTile(
          label: 'Promedio escuchado',
          value: '${stats.averageProgressPercent}%',
        ),
        _MetricTile(
          label: 'Actividad reciente',
          value: '${stats.recentTracks}',
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportSummaryCard extends StatelessWidget {
  const _ImportSummaryCard({required this.stats});

  final _ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download_done_rounded, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Imports',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.58,
            children: [
              _MiniStat(label: 'Archivos', value: '${stats.totalImportFiles}'),
              _MiniStat(
                label: 'Archivos audio',
                value: '${stats.importedAudioFiles}',
              ),
              _MiniStat(
                label: 'Canciones unicas',
                value: '${stats.importedAudioItems}',
              ),
              _MiniStat(
                label: 'Archivos video',
                value: '${stats.importedVideoFiles}',
              ),
              _MiniStat(
                label: 'Espacio local',
                value: stats.totalImportSizeLabel,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stats.latestImportLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportPeaksCard extends StatelessWidget {
  const _ImportPeaksCard({required this.stats});

  final _ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Picos de imports',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Mes mas fuerte',
                  value: stats.topImportMonthLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Semana mas fuerte',
                  value: stats.topImportWeekLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            stats.topImportPeriodDetail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoSummaryCard extends StatelessWidget {
  const _VideoSummaryCard({required this.stats});

  final _ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.48,
      children: [
        _MetricTile(
          label: 'Videos locales',
          value: '${stats.importedVideoItems}',
        ),
        _MetricTile(
          label: 'Archivos video',
          value: '${stats.importedVideoFiles}',
        ),
        _MetricTile(label: 'Reproducciones', value: '${stats.videoPlays}'),
        _MetricTile(
          label: 'Actividad reciente',
          value: '${stats.videoRecentItems}',
        ),
      ],
    );
  }
}

class _RegionsCard extends StatelessWidget {
  const _RegionsCard({required this.regions});

  final List<_RegionStats> regions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Regiones mas escuchadas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (regions.isEmpty)
            Text(
              'Aun no hay suficientes canciones con region de Atlas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            for (var i = 0; i < regions.length; i++) ...[
              _RegionBlock(rank: i + 1, region: regions[i]),
              if (i != regions.length - 1)
                Divider(color: scheme.outline.withValues(alpha: 0.10)),
            ],
        ],
      ),
    );
  }
}

class _RegionBlock extends StatelessWidget {
  const _RegionBlock({required this.rank, required this.region});

  final int rank;
  final _RegionStats region;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$rank',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  region.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${region.plays} escuchas',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < region.topTracks.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 3),
              child: Text(
                '${i + 1}. ${region.topTracks[i].title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopTrackCard extends StatelessWidget {
  const _TopTrackCard({required this.title, required this.item});

  final String title;
  final MediaItem? item;

  @override
  Widget build(BuildContext context) {
    if (item == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _StatsCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.music_note_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${_ListeningStats.listenScoreFor(item!)} escuchas',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankedListCard extends StatelessWidget {
  const _RankedListCard({
    required this.title,
    required this.icon,
    required this.rows,
    this.emptyText = 'Sin datos suficientes.',
  });

  final String title;
  final IconData icon;
  final List<_RankedRowData> rows;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsCardHeader(icon: icon, title: title),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text(
              emptyText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              _RankedRow(rank: i + 1, data: rows[i]),
              if (i != rows.length - 1)
                Divider(color: scheme.outline.withValues(alpha: 0.10)),
            ],
        ],
      ),
    );
  }
}

class _StatsCardHeader extends StatelessWidget {
  const _StatsCardHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({required this.rank, required this.data});

  final int rank;
  final _RankedRowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            data.value,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.12)),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _RankedRowData {
  const _RankedRowData({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final String title;
  final String subtitle;
  final String value;
}

class _ArtistStats {
  const _ArtistStats({
    required this.name,
    required this.plays,
    required this.tracks,
  });

  final String name;
  final int plays;
  final int tracks;
}

class _ImportArtistStats {
  const _ImportArtistStats({
    required this.name,
    required this.imports,
    required this.tracks,
  });

  final String name;
  final int imports;
  final int tracks;
}

class _ImportPeak {
  const _ImportPeak({required this.label, required this.count});

  final String label;
  final int count;
}

class _RegionStats {
  const _RegionStats({
    required this.code,
    required this.name,
    required this.plays,
    required this.topTracks,
  });

  final String code;
  final String name;
  final int plays;
  final List<MediaItem> topTracks;
}

class _ListeningStats {
  const _ListeningStats({
    required this.totalPlays,
    required this.totalCompleted,
    required this.averageProgressPercent,
    required this.recentTracks,
    required this.totalImportFiles,
    required this.importedAudioFiles,
    required this.importedVideoFiles,
    required this.importedAudioItems,
    required this.importedVideoItems,
    required this.totalImportSizeLabel,
    required this.latestImportLabel,
    required this.topImportedArtistsLastMonth,
    required this.topImportedArtists,
    required this.topImportMonthLabel,
    required this.topImportWeekLabel,
    required this.topImportPeriodDetail,
    required this.videoPlays,
    required this.videoRecentItems,
    required this.topVideos,
    required this.topTrack,
    required this.topTracks,
    required this.topFavoriteTracks,
    required this.topRegions,
    required this.topArtists,
    required this.mostCompleted,
    required this.mostSkipped,
  });

  final int totalPlays;
  final int totalCompleted;
  final int averageProgressPercent;
  final int recentTracks;
  final int totalImportFiles;
  final int importedAudioFiles;
  final int importedVideoFiles;
  final int importedAudioItems;
  final int importedVideoItems;
  final String totalImportSizeLabel;
  final String latestImportLabel;
  final List<_ImportArtistStats> topImportedArtistsLastMonth;
  final List<_ImportArtistStats> topImportedArtists;
  final String topImportMonthLabel;
  final String topImportWeekLabel;
  final String topImportPeriodDetail;
  final int videoPlays;
  final int videoRecentItems;
  final List<MediaItem> topVideos;
  final MediaItem? topTrack;
  final List<MediaItem> topTracks;
  final List<MediaItem> topFavoriteTracks;
  final List<_RegionStats> topRegions;
  final List<_ArtistStats> topArtists;
  final List<MediaItem> mostCompleted;
  final List<MediaItem> mostSkipped;

  bool get hasListeningData =>
      totalPlays > 0 || totalCompleted > 0 || topTracks.isNotEmpty;
  bool get hasAnyData => hasListeningData || totalImportFiles > 0;

  static _ListeningStats fromItems(
    List<MediaItem> items, {
    ArtistStore? artistStore,
  }) {
    final audioItems = items
        .where((item) => item.hasAudioLocal)
        .toList(growable: false);
    final videoItems = items
        .where((item) => item.hasVideoLocal && !item.hasAudioLocal)
        .toList(growable: false);

    final listened = audioItems
        .where(
          (item) =>
              item.playCount > 0 ||
              item.fullListenCount > 0 ||
              item.skipCount > 0 ||
              item.avgListenProgress > 0,
        )
        .toList(growable: false);
    final watched = videoItems
        .where(
          (item) =>
              item.playCount > 0 ||
              item.fullListenCount > 0 ||
              item.skipCount > 0 ||
              item.avgListenProgress > 0,
        )
        .toList(growable: false);

    final totalPlays = listened.fold<int>(
      0,
      (sum, item) => sum + item.playCount,
    );
    final totalCompleted = listened.fold<int>(
      0,
      (sum, item) => sum + effectiveCompletedFor(item),
    );
    final progressItems = listened
        .where((item) => item.avgListenProgress > 0)
        .toList(growable: false);
    final averageProgress = progressItems.isEmpty
        ? 0
        : progressItems.fold<double>(
                0,
                (sum, item) => sum + item.avgListenProgress.clamp(0, 1),
              ) /
              progressItems.length;

    final recentCutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    final recentTracks = listened
        .where((item) => (item.lastPlayedAt ?? 0) >= recentCutoff)
        .length;
    final videoRecentItems = watched
        .where((item) => (item.lastPlayedAt ?? 0) >= recentCutoff)
        .length;
    final videoPlays = watched.fold<int>(
      0,
      (sum, item) => sum + item.playCount,
    );

    final byPlays = listened.where((item) => listenScoreFor(item) > 0).toList()
      ..sort((a, b) {
        final plays = listenScoreFor(b).compareTo(listenScoreFor(a));
        if (plays != 0) return plays;
        return (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0);
      });

    final completed =
        listened
            .where((item) => effectiveCompletedFor(item) > 0)
            .toList(growable: false)
          ..sort(
            (a, b) =>
                effectiveCompletedFor(b).compareTo(effectiveCompletedFor(a)),
          );
    final skipped = listened.where((item) => item.skipCount > 0).toList()
      ..sort((a, b) => b.skipCount.compareTo(a.skipCount));
    final importStats = _ImportStats.fromItems(items);
    final videosByPlays =
        watched.where((item) => listenScoreFor(item) > 0).toList()
          ..sort((a, b) {
            final plays = listenScoreFor(b).compareTo(listenScoreFor(a));
            if (plays != 0) return plays;
            return (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0);
          });
    final favoritesByPlays =
        listened
            .where((item) => item.isFavorite && listenScoreFor(item) > 0)
            .toList()
          ..sort((a, b) {
            final plays = listenScoreFor(b).compareTo(listenScoreFor(a));
            if (plays != 0) return plays;
            return (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0);
          });
    final topRegions = _buildTopRegions(listened, artistStore: artistStore);

    return _ListeningStats(
      totalPlays: totalPlays,
      totalCompleted: totalCompleted,
      averageProgressPercent: (averageProgress * 100).round().clamp(0, 100),
      recentTracks: recentTracks,
      totalImportFiles: importStats.totalFiles,
      importedAudioFiles: importStats.audioFiles,
      importedVideoFiles: importStats.videoFiles,
      importedAudioItems: importStats.audioItems,
      importedVideoItems: importStats.videoItems,
      totalImportSizeLabel: _formatBytes(importStats.totalBytes),
      latestImportLabel: importStats.latestImportAt <= 0
          ? 'Aun no hay imports con fecha registrada.'
          : 'Ultimo import: ${_relativeDateLabel(importStats.latestImportAt)}',
      topImportedArtistsLastMonth: importStats.topArtistsLastMonth,
      topImportedArtists: importStats.topArtistsAllTime,
      topImportMonthLabel: importStats.topMonth.count <= 0
          ? 'Sin datos'
          : importStats.topMonth.label,
      topImportWeekLabel: importStats.topWeek.count <= 0
          ? 'Sin datos'
          : importStats.topWeek.label,
      topImportPeriodDetail: _topImportPeriodDetail(importStats),
      videoPlays: videoPlays,
      videoRecentItems: videoRecentItems,
      topVideos: videosByPlays.take(5).toList(growable: false),
      topTrack: byPlays.isEmpty ? null : byPlays.first,
      topTracks: byPlays.take(5).toList(growable: false),
      topFavoriteTracks: favoritesByPlays.take(5).toList(growable: false),
      topRegions: topRegions,
      topArtists: _buildTopArtists(listened),
      mostCompleted: completed.take(5).toList(growable: false),
      mostSkipped: skipped.take(5).toList(growable: false),
    );
  }

  static String _topImportPeriodDetail(_ImportStats stats) {
    if (stats.topMonth.count <= 0 && stats.topWeek.count <= 0) {
      return 'Aun no hay suficientes imports con fecha registrada.';
    }
    if (stats.topMonth.count <= 0) {
      return 'Semana destacada: ${stats.topWeek.count} imports.';
    }
    if (stats.topWeek.count <= 0) {
      return 'Mes destacado: ${stats.topMonth.count} imports.';
    }
    return 'Mes destacado: ${stats.topMonth.count} imports. Semana destacada: ${stats.topWeek.count} imports.';
  }

  static List<_ArtistStats> _buildTopArtists(List<MediaItem> items) {
    final playsByArtist = <String, int>{};
    final nameByKey = <String, String>{};
    final tracksByArtist = <String, Set<String>>{};

    for (final item in items) {
      final credits = ArtistCreditParser.parse(item.displaySubtitle);
      final name = ArtistCreditParser.cleanName(credits.primaryArtist);
      if (name.isEmpty) continue;
      final key = ArtistCreditParser.normalizeKey(name);
      if (key.isEmpty || key == 'unknown') continue;
      nameByKey[key] = name;
      playsByArtist[key] = (playsByArtist[key] ?? 0) + listenScoreFor(item);
      tracksByArtist.putIfAbsent(key, () => <String>{}).add(item.id);
    }

    final artists = playsByArtist.entries
        .map(
          (entry) => _ArtistStats(
            name: nameByKey[entry.key] ?? entry.key,
            plays: entry.value,
            tracks: tracksByArtist[entry.key]?.length ?? 0,
          ),
        )
        .where((artist) => artist.plays > 0)
        .toList();
    artists.sort((a, b) => b.plays.compareTo(a.plays));
    return artists.take(5).toList(growable: false);
  }

  static List<_RegionStats> _buildTopRegions(
    List<MediaItem> items, {
    ArtistStore? artistStore,
  }) {
    final affinity = LocalAffinityEngine(artistStore: artistStore);
    final playsByRegion = <String, int>{};
    final tracksByRegion = <String, List<MediaItem>>{};

    for (final item in items) {
      final score = listenScoreFor(item);
      if (score <= 0) continue;
      final countryCode = affinity.resolveCountryCode(item);
      if (countryCode == null) continue;
      final regionCodes = WorldRegionCatalog.regionCodesForCountry(countryCode);
      for (final regionCode in regionCodes) {
        playsByRegion[regionCode] = (playsByRegion[regionCode] ?? 0) + score;
        tracksByRegion.putIfAbsent(regionCode, () => <MediaItem>[]).add(item);
      }
    }

    final regions = playsByRegion.entries
        .map((entry) {
          final definition = WorldRegionCatalog.byCode(entry.key);
          if (definition == null) return null;
          final tracks =
              (tracksByRegion[entry.key] ?? const <MediaItem>[]).toList()
                ..sort((a, b) {
                  final plays = listenScoreFor(b).compareTo(listenScoreFor(a));
                  if (plays != 0) return plays;
                  return (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0);
                });
          return _RegionStats(
            code: definition.code,
            name: definition.name,
            plays: entry.value,
            topTracks: tracks.take(3).toList(growable: false),
          );
        })
        .whereType<_RegionStats>()
        .toList();
    regions.sort((a, b) => b.plays.compareTo(a.plays));
    return regions.take(5).toList(growable: false);
  }

  static int effectiveCompletedFor(MediaItem item) {
    if (item.playCount <= 0 && item.fullListenCount <= 0) {
      return 0;
    }
    final completedFromPlays = max(item.playCount - item.skipCount, 0);
    return max(item.fullListenCount, completedFromPlays);
  }

  static int listenScoreFor(MediaItem item) {
    if (item.playCount <= 0 && item.fullListenCount <= 0) {
      return 0;
    }
    final skipAdjustedPlays = max(item.playCount - item.skipCount, 0);
    return max(skipAdjustedPlays, 0) + max(item.fullListenCount, 0);
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final decimals = unit == 0 || value >= 10 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
  }

  static String _relativeDateLabel(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'hoy';
    if (diff == 1) return 'ayer';
    if (diff < 30) return 'hace $diff dias';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _ImportStats {
  const _ImportStats({
    required this.totalFiles,
    required this.audioFiles,
    required this.videoFiles,
    required this.audioItems,
    required this.videoItems,
    required this.totalBytes,
    required this.latestImportAt,
    required this.topArtistsLastMonth,
    required this.topArtistsAllTime,
    required this.topMonth,
    required this.topWeek,
  });

  final int totalFiles;
  final int audioFiles;
  final int videoFiles;
  final int audioItems;
  final int videoItems;
  final int totalBytes;
  final int latestImportAt;
  final List<_ImportArtistStats> topArtistsLastMonth;
  final List<_ImportArtistStats> topArtistsAllTime;
  final _ImportPeak topMonth;
  final _ImportPeak topWeek;

  static _ImportStats fromItems(List<MediaItem> items) {
    var totalFiles = 0;
    var audioFiles = 0;
    var videoFiles = 0;
    var audioItems = 0;
    var videoItems = 0;
    var totalBytes = 0;
    var latestImportAt = 0;
    final now = DateTime.now();
    final lastMonthCutoff = now
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    final monthCounts = <String, int>{};
    final weekCounts = <String, int>{};
    final importAllTime = _ArtistImportAccumulator();
    final importLastMonth = _ArtistImportAccumulator();

    for (final item in items) {
      var hasAudio = false;
      var hasVideo = false;
      var audioImportsForItem = 0;
      var recentAudioImportsForItem = 0;
      for (final variant in item.variants) {
        if ((variant.localPath ?? '').trim().isEmpty) continue;
        totalFiles++;
        totalBytes += max(variant.size ?? 0, 0);
        if (variant.createdAt > latestImportAt) {
          latestImportAt = variant.createdAt;
        }
        if (variant.kind == MediaVariantKind.audio) {
          audioFiles++;
          hasAudio = true;
          audioImportsForItem++;
          if (variant.createdAt >= lastMonthCutoff) {
            recentAudioImportsForItem++;
          }
        } else {
          videoFiles++;
          hasVideo = true;
        }
        if (variant.createdAt > 0) {
          _increment(monthCounts, _monthKey(variant.createdAt));
          _increment(weekCounts, _weekKey(variant.createdAt));
        }
      }
      if (hasAudio) audioItems++;
      if (hasVideo) videoItems++;
      if (audioImportsForItem > 0) {
        importAllTime.add(item, audioImportsForItem);
      }
      if (recentAudioImportsForItem > 0) {
        importLastMonth.add(item, recentAudioImportsForItem);
      }
    }

    return _ImportStats(
      totalFiles: totalFiles,
      audioFiles: audioFiles,
      videoFiles: videoFiles,
      audioItems: audioItems,
      videoItems: videoItems,
      totalBytes: totalBytes,
      latestImportAt: latestImportAt,
      topArtistsLastMonth: importLastMonth.top(5),
      topArtistsAllTime: importAllTime.top(5),
      topMonth: _topPeriod(monthCounts),
      topWeek: _topPeriod(weekCounts),
    );
  }

  static void _increment(Map<String, int> counts, String key) {
    counts[key] = (counts[key] ?? 0) + 1;
  }

  static String _monthKey(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final month = date.month.toString().padLeft(2, '0');
    return '$month/${date.year}';
  }

  static String _weekKey(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final day = DateTime(date.year, date.month, date.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    String short(DateTime value) =>
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
    return '${short(monday)} - ${short(sunday)}';
  }

  static _ImportPeak _topPeriod(Map<String, int> counts) {
    if (counts.isEmpty) {
      return const _ImportPeak(label: 'Sin datos', count: 0);
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return b.key.compareTo(a.key);
      });
    final top = entries.first;
    return _ImportPeak(label: top.key, count: top.value);
  }
}

class _ArtistImportAccumulator {
  final Map<String, int> _importsByArtist = {};
  final Map<String, String> _nameByKey = {};
  final Map<String, Set<String>> _tracksByArtist = {};

  void add(MediaItem item, int imports) {
    if (imports <= 0) return;
    final credits = ArtistCreditParser.parse(item.displaySubtitle);
    final name = ArtistCreditParser.cleanName(credits.primaryArtist);
    if (name.isEmpty) return;
    final key = ArtistCreditParser.normalizeKey(name);
    if (key.isEmpty || key == 'unknown') return;
    _nameByKey[key] = name;
    _importsByArtist[key] = (_importsByArtist[key] ?? 0) + imports;
    _tracksByArtist.putIfAbsent(key, () => <String>{}).add(item.id);
  }

  List<_ImportArtistStats> top(int limit) {
    final artists = _importsByArtist.entries
        .map(
          (entry) => _ImportArtistStats(
            name: _nameByKey[entry.key] ?? entry.key,
            imports: entry.value,
            tracks: _tracksByArtist[entry.key]?.length ?? 0,
          ),
        )
        .where((artist) => artist.imports > 0)
        .toList();
    artists.sort((a, b) {
      final byImports = b.imports.compareTo(a.imports);
      if (byImports != 0) return byImports;
      return b.tracks.compareTo(a.tracks);
    });
    return artists.take(limit).toList(growable: false);
  }
}

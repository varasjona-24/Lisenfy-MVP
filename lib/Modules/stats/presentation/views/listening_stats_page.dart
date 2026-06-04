import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../controller/listening_stats_controller.dart';
import '../../domain/entities/listening_stats_entities.dart';

part '../widgets/imports_tab.dart';
part '../widgets/audio_tab.dart';
part '../widgets/video_tab.dart';

// ─────────────────────────────────────────────
// Paleta de colores para charts
// ─────────────────────────────────────────────
const kArtistColors = [
  Color(0xFFFF6B6B),
  Color(0xFFFF8E53),
  Color(0xFFFFD166),
  Color(0xFF06D6A0),
  Color(0xFF118AB2),
];

const kMusicGradient = [Color(0xFF7B2FF7), Color(0xFFE040FB)];
const kImportGradient = [Color(0xFF0575E6), Color(0xFF00F260)];
const kVideoGradient = [Color(0xFFFF4E50), Color(0xFFF9D423)];

// ─────────────────────────────────────────────
// Page root
// ─────────────────────────────────────────────
class ListeningStatsPage extends GetView<ListeningStatsController> {
  const ListeningStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          'Listenfy Wrapped',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        forceMaterialTransparency: true,
        foregroundColor: scheme.onSurface,
        leading: const BackButton(),
      ),
      body: AppGradientBackground(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = controller.stats.value;
          if (stats == null || !stats.hasAnyData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_off_rounded,
                      size: 72,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no hay suficientes datos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Importa canciones y empieza a escuchar para ver tu Wrapped.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.refreshStats,
            child: _WrappedBody(stats: stats),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Body with staggered entrance and tabs
// ─────────────────────────────────────────────
class _WrappedBody extends StatefulWidget {
  const _WrappedBody({required this.stats});
  final ListeningStats stats;

  @override
  State<_WrappedBody> createState() => _WrappedBodyState();
}

class _WrappedBodyState extends State<_WrappedBody>
    with TickerProviderStateMixin {
  late final AnimationController _masterCtrl;
  late final List<Animation<double>> _staggered;
  late final AnimationController _counterCtrl;

  static const _staggerCount = 11;

  @override
  void initState() {
    super.initState();

    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _staggered = List.generate(_staggerCount, (i) {
      final start = i / _staggerCount;
      final end = (i + 1) / _staggerCount;
      return CurvedAnimation(
        parent: _masterCtrl,
        curve: Interval(start, end.clamp(0, 1), curve: Curves.easeOutCubic),
      );
    });

    _counterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _masterCtrl.forward();
        _counterCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _counterCtrl.dispose();
    super.dispose();
  }

  Widget _fade(int idx, Widget child) {
    return FadeTransition(
      opacity: _staggered[idx.clamp(0, _staggerCount - 1)],
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(_staggered[idx.clamp(0, _staggerCount - 1)]),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(colors: kMusicGradient),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kMusicGradient[0].withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: scheme.onSurfaceVariant,
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Imports'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.graphic_eq_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Audio'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_collection_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Video'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                ImportsTab(stats: s, fade: _fade),
                AudioTab(
                  stats: s,
                  fade: _fade,
                  masterCtrl: _masterCtrl,
                  counterCtrl: _counterCtrl,
                ),
                VideoTab(stats: s, fade: _fade, masterCtrl: _masterCtrl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 1: Imports
// ─────────────────────────────────────────────
class _ImportsTab extends StatelessWidget {
  const _ImportsTab({super.key, required this.stats, required this.fade});
  final ListeningStats stats;
  final Widget Function(int, Widget) fade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rows = stats.topImportedArtists
        .map(
          (artist) => RankedRowData(
            title: artist.name,
            subtitle: '${artist.tracks} canciones importadas',
            value: '${artist.imports}',
            maxValue: stats.topImportedArtists.isEmpty
                ? 1
                : stats.topImportedArtists.first.imports,
            currentValue: artist.imports,
            color: kImportGradient.first,
          ),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        fade(
          0,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: kImportGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kImportGradient[0].withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('📥', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 8),
                    Text(
                      'Tus Descargas e Imports',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  stats.latestImportLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        fade(
          1,
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final itemWidth = isWide
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;

              final metrics = [
                FieldMetricData(
                  icon: Icons.file_download_done_rounded,
                  label: 'Archivos',
                  value: '${stats.totalImportFiles}',
                  caption:
                      '${stats.importedAudioFiles} audio · ${stats.importedVideoFiles} video',
                ),
                FieldMetricData(
                  icon: Icons.sd_storage_rounded,
                  label: 'Peso local',
                  value: stats.totalImportSizeLabel,
                  caption: 'Tamaño total en almacenamiento',
                ),
                FieldMetricData(
                  icon: Icons.analytics_rounded,
                  label: 'Tamaño medio',
                  value: stats.averageFileSizeLabel,
                  caption: 'Peso promedio por archivo',
                ),
                FieldMetricData(
                  icon: Icons.file_present_rounded,
                  label: 'Formato común',
                  value: stats.mostCommonFormat,
                  caption: 'Tipo de archivo predominante',
                ),
                FieldMetricData(
                  icon: Icons.calendar_month_rounded,
                  label: 'Mes fuerte',
                  value: stats.topImportMonthLabel,
                  caption: 'Mayor cantidad de descargas',
                ),
                FieldMetricData(
                  icon: Icons.today_rounded,
                  label: 'Día activo',
                  value: stats.mostActiveImportWeekday,
                  caption: 'Día favorito para importar',
                ),
              ];

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: metrics
                    .map(
                      (m) => SizedBox(
                        width: itemWidth,
                        child: FieldMetricTile(
                          data: m,
                          accent: kImportGradient.first,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        if (stats.monthlyImports.isNotEmpty) ...[
          fade(
            2,
            SectionHeader(
              emoji: '📊',
              title: 'Actividad de Imports',
              subtitle: 'Archivos importados por mes',
              gradient: kImportGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(2, _MonthlyImportsChart(months: stats.monthlyImports)),
          const SizedBox(height: 14),
        ],

        if (rows.isNotEmpty) ...[
          fade(
            3,
            SectionHeader(
              emoji: '🎤',
              title: 'Artistas más Importados',
              subtitle: 'Basado en archivos locales',
              gradient: kImportGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(3, CompactRankedRows(rows: rows)),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Tab 2: Audio
// ─────────────────────────────────────────────
class _AudioTab extends StatelessWidget {
  const _AudioTab({
    super.key,
    required this.stats,
    required this.fade,
    required this.masterCtrl,
    required this.counterCtrl,
  });

  final ListeningStats stats;
  final Widget Function(int, Widget) fade;
  final AnimationController masterCtrl;
  final AnimationController counterCtrl;

  @override
  Widget build(BuildContext context) {
    final topTrack = stats.topTrack;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        fade(0, _AnimatedHeroCard(stats: stats, counterCtrl: counterCtrl)),
        const SizedBox(height: 14),

        fade(1, _MoodCard(stats: stats)),
        const SizedBox(height: 14),

        fade(
          2,
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final itemWidth = isWide
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;

              final metrics = [
                FieldMetricData(
                  icon: Icons.library_music_rounded,
                  label: 'Canciones',
                  value: '${stats.importedAudioItems}',
                  caption: '${stats.audioLibraryDurationLabel} guardadas',
                ),
                FieldMetricData(
                  icon: Icons.watch_later_rounded,
                  label: 'Tiempo escuchado',
                  value: stats.estimatedListeningTimeLabel,
                  caption: 'Tiempo estimado de reproducción',
                ),
                FieldMetricData(
                  icon: Icons.access_time_filled_rounded,
                  label: 'Horario favorito',
                  value: stats.favoriteTimeOfDay,
                  caption: 'Momento con más actividad',
                ),
                FieldMetricData(
                  icon: Icons.people_rounded,
                  label: 'Diversidad de artistas',
                  value: '${stats.artistDiversityCount}',
                  caption: 'Artistas distintos escuchados',
                ),
                FieldMetricData(
                  icon: Icons.repeat_rounded,
                  label: 'Reproducciones',
                  value: '${stats.totalPlays}',
                  caption: '${stats.recentTracks} activas en 30 días',
                ),
                FieldMetricData(
                  icon: Icons.done_all_rounded,
                  label: 'Completadas',
                  value: '${stats.totalCompleted}',
                  caption: stats.audioCompletionRateLabel,
                ),
              ];

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: metrics
                    .map(
                      (m) => SizedBox(
                        width: itemWidth,
                        child: FieldMetricTile(
                          data: m,
                          accent: kMusicGradient.first,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        fade(3, _MetricsCard(stats: stats)),
        const SizedBox(height: 14),

        fade(
          4,
          SectionHeader(
            emoji: '📊',
            title: 'Tu Biblioteca',
            subtitle: 'Distribución de contenido',
            gradient: kMusicGradient,
          ),
        ),
        const SizedBox(height: 10),
        fade(4, _DonutDistributionCard(stats: stats)),
        const SizedBox(height: 14),

        if (stats.topArtists.isNotEmpty) ...[
          fade(
            5,
            SectionHeader(
              emoji: '🎤',
              title: 'Top Artistas',
              subtitle: 'Por número de escuchas',
              gradient: kMusicGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(5, _ArtistBarChart(artists: stats.topArtists)),
          const SizedBox(height: 14),
        ],

        if (topTrack != null) ...[
          fade(6, _TopTrackHero(item: topTrack, stats: stats)),
          const SizedBox(height: 14),
        ],

        if (stats.topTracks.isNotEmpty) ...[
          fade(
            7,
            SectionHeader(
              emoji: '🏆',
              title: 'Top Canciones',
              subtitle: 'Las que más sonaron',
              gradient: kMusicGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(
            7,
            AnimatedRankedList(
              rows: stats.topTracks
                  .map(
                    (item) => RankedRowData(
                      title: item.title,
                      subtitle: item.displaySubtitle,
                      value: '${ListeningStats.listenScoreFor(item)} plays',
                      maxValue: stats.topTracks.isNotEmpty
                          ? ListeningStats.listenScoreFor(stats.topTracks.first)
                          : 1,
                      currentValue: ListeningStats.listenScoreFor(item),
                      color: kMusicGradient[0],
                    ),
                  )
                  .toList(),
              masterCtrl: masterCtrl,
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (stats.topRegions.isNotEmpty) ...[
          fade(
            8,
            SectionHeader(
              emoji: '🌍',
              title: 'Regiones Favoritas',
              subtitle: 'Tu música por origen',
              gradient: kMusicGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(8, _RegionsBarCard(regions: stats.topRegions)),
          const SizedBox(height: 14),
        ],

        fade(
          9,
          SectionHeader(
            emoji: '⏭',
            title: 'Completadas vs Saltadas',
            subtitle: 'Tu paciencia musical',
            gradient: kMusicGradient,
          ),
        ),
        const SizedBox(height: 10),
        fade(9, _CompletedVsSkippedCard(stats: stats)),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Tab 3: Video & Collections
// ─────────────────────────────────────────────
class _VideoTab extends StatelessWidget {
  const _VideoTab({
    super.key,
    required this.stats,
    required this.fade,
    required this.masterCtrl,
  });

  final ListeningStats stats;
  final Widget Function(int, Widget) fade;
  final AnimationController masterCtrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final videoRows = stats.topVideos
        .map(
          (item) => RankedRowData(
            title: item.title,
            subtitle: item.displaySubtitle.isEmpty
                ? 'Video'
                : item.displaySubtitle,
            value: '${ListeningStats.listenScoreFor(item)} plays',
            maxValue: stats.topVideos.isEmpty
                ? 1
                : ListeningStats.listenScoreFor(stats.topVideos.first),
            currentValue: ListeningStats.listenScoreFor(item),
            color: kVideoGradient.first,
          ),
        )
        .toList();

    final collectionRows = stats.topCollections
        .map(
          (col) => RankedRowData(
            title: col.name,
            subtitle: col.subtitle,
            value: '${col.items} videos',
            maxValue: stats.topCollections.isEmpty
                ? 1
                : stats.topCollections.first.items,
            currentValue: col.items,
            color: kVideoGradient.first,
          ),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        fade(
          0,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: kVideoGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kVideoGradient[0].withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🎬', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 8),
                    Text(
                      'Video + Collections',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  stats.largestCollectionCount <= 0
                      ? 'Organiza tus videos en Collections para ver más señales.'
                      : 'Collection dominante: ${stats.largestCollectionName} con ${stats.largestCollectionCount} items.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        fade(
          1,
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final itemWidth = isWide
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;

              final metrics = [
                FieldMetricData(
                  icon: Icons.video_library_rounded,
                  label: 'Videos',
                  value: '${stats.importedVideoItems}',
                  caption: '${stats.videoLibraryDurationLabel} guardados',
                ),
                FieldMetricData(
                  icon: Icons.play_circle_rounded,
                  label: 'Reproducciones',
                  value: '${stats.videoPlays}',
                  caption: '${stats.videoRecentItems} activos en 30 días',
                ),
                FieldMetricData(
                  icon: Icons.folder_special_rounded,
                  label: 'Collections',
                  value: '${stats.totalVideoCollections}',
                  caption:
                      '${stats.rootVideoCollections} principales · ${stats.videoSubCollections} subcarpetas',
                ),
                FieldMetricData(
                  icon: Icons.pie_chart_rounded,
                  label: 'Organización',
                  value: stats.organizedVideoPercentageLabel,
                  caption: 'Videos organizados en carpetas',
                ),
                FieldMetricData(
                  icon: Icons.linked_camera_rounded,
                  label: 'Promedio por carpeta',
                  value: stats.averageVideosPerCollectionLabel,
                  caption: 'Videos por Collection',
                ),
                FieldMetricData(
                  icon: Icons.link_rounded,
                  label: 'Items enlazados',
                  value: '${stats.collectionLinkedItems}',
                  caption: '${stats.emptyVideoCollections} Collections vacías',
                ),
              ];

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: metrics
                    .map(
                      (m) => SizedBox(
                        width: itemWidth,
                        child: FieldMetricTile(
                          data: m,
                          accent: kVideoGradient.first,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        if (videoRows.isNotEmpty) ...[
          fade(
            2,
            SectionHeader(
              emoji: '📺',
              title: 'Videos más Vistos',
              subtitle: 'Por número de reproducciones',
              gradient: kVideoGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(2, AnimatedRankedList(rows: videoRows, masterCtrl: masterCtrl)),
          const SizedBox(height: 14),
        ],

        if (collectionRows.isNotEmpty) ...[
          fade(
            3,
            SectionHeader(
              emoji: '📁',
              title: 'Top Colecciones',
              subtitle: 'Las más grandes',
              gradient: kVideoGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(
            3,
            AnimatedRankedList(rows: collectionRows, masterCtrl: masterCtrl),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class FieldMetricData {
  const FieldMetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
}

class FieldMetricTile extends StatelessWidget {
  const FieldMetricTile({super.key, required this.data, required this.accent});

  final FieldMetricData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.2,
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

class CompactRankedRows extends StatelessWidget {
  const CompactRankedRows({super.key, required this.rows});

  final List<RankedRowData> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: List.generate(rows.take(5).length, (index) {
        final row = rows[index];
        final ratio = row.maxValue <= 0 ? 0.0 : row.currentValue / row.maxValue;
        final color = kArtistColors[index % kArtistColors.length];
        return Padding(
          padding: EdgeInsets.only(bottom: index == rows.length - 1 ? 0 : 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          row.value,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      row.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Hero Card con contador animado
// ─────────────────────────────────────────────
class _AnimatedHeroCard extends StatelessWidget {
  const _AnimatedHeroCard({required this.stats, required this.counterCtrl});

  final ListeningStats stats;
  final AnimationController counterCtrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topArtist = stats.topArtists.isEmpty
        ? 'tu biblioteca'
        : stats.topArtists.first.name;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: kMusicGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kMusicGradient[0].withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎵', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Text(
                'Listenfy Wrapped',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Contador animado
          AnimatedBuilder(
            animation: counterCtrl,
            builder: (context, child) {
              final current = (stats.totalPlays * counterCtrl.value).round();
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$current',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'reproducciones',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Text(
            'Tu artista dominante es $topArtist con ${stats.topArtists.isEmpty ? 0 : stats.topArtists.first.plays} plays.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Mood Card
// ─────────────────────────────────────────────
class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.stats});
  final ListeningStats stats;

  String get _emoji {
    final ratio = stats.totalPlays == 0
        ? 0.0
        : stats.totalCompleted / stats.totalPlays;
    if (ratio >= 0.75) return '🔥';
    if (ratio >= 0.5) return '🎯';
    if (ratio >= 0.25) return '⚡';
    return '💤';
  }

  String get _mood {
    final ratio = stats.totalPlays == 0
        ? 0.0
        : stats.totalCompleted / stats.totalPlays;
    if (ratio >= 0.75) return 'Oyente Fiel';
    if (ratio >= 0.5) return 'Melómano';
    if (ratio >= 0.25) return 'Explorador';
    return 'Selectivo';
  }

  String get _desc {
    final ratio = stats.totalPlays == 0
        ? 0.0
        : stats.totalCompleted / stats.totalPlays;
    if (ratio >= 0.75) {
      return 'Escuchas tus canciones de principio a fin. ¡Eres muy fiel!';
    }
    if (ratio >= 0.5) {
      return 'Buen balance entre exploración y disfrute profundo.';
    }
    if (ratio >= 0.25) {
      return 'Te gusta descubrir, aunque a veces saltas rápido.';
    }
    return 'Eres muy selectivo. Das pocas canciones por terminadas.';
  }

  Color get _color {
    final ratio = stats.totalPlays == 0
        ? 0.0
        : stats.totalCompleted / stats.totalPlays;
    if (ratio >= 0.75) return const Color(0xFFFF6B6B);
    if (ratio >= 0.5) return const Color(0xFF06D6A0);
    if (ratio >= 0.25) return const Color(0xFFFFD166);
    return const Color(0xFF118AB2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.35), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(_emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Tu mood: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _mood,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _desc,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Metrics Card con barras de progreso animadas
// ─────────────────────────────────────────────
class _MetricsCard extends StatefulWidget {
  const _MetricsCard({required this.stats});
  final ListeningStats stats;

  @override
  State<_MetricsCard> createState() => _MetricsCardState();
}

class _MetricsCardState extends State<_MetricsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = widget.stats;

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Métricas clave',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _anim,
            builder: (context, child) => Column(
              children: [
                _ProgressMetric(
                  label: 'Promedio escuchado',
                  value: s.averageProgressPercent / 100,
                  displayText: '${s.averageProgressPercent}%',
                  color: kMusicGradient[0],
                  anim: _anim.value,
                ),
                const SizedBox(height: 12),
                _ProgressMetric(
                  label: 'Tasa de completadas',
                  value: s.totalPlays == 0
                      ? 0
                      : s.totalCompleted / s.totalPlays,
                  displayText: '${s.totalCompleted} / ${s.totalPlays}',
                  color: const Color(0xFF06D6A0),
                  anim: _anim.value,
                ),
                const SizedBox(height: 12),
                _ProgressMetric(
                  label: 'Actividad reciente (30d)',
                  value: (s.totalPlays == 0)
                      ? 0
                      : (s.recentTracks / max(s.totalPlays, 1))
                            .clamp(0, 1)
                            .toDouble(),
                  displayText: '${s.recentTracks} canciones',
                  color: const Color(0xFFFFD166),
                  anim: _anim.value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.label,
    required this.value,
    required this.displayText,
    required this.color,
    required this.anim,
  });

  final String label;
  final double value;
  final String displayText;
  final Color color;
  final double anim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final animated = (value * anim).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              displayText,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: animated,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Artist Bar Chart horizontal
// ─────────────────────────────────────────────
class _ArtistBarChart extends StatefulWidget {
  const _ArtistBarChart({required this.artists});
  final List<ArtistStats> artists;

  @override
  State<_ArtistBarChart> createState() => _ArtistBarChartState();
}

class _ArtistBarChartState extends State<_ArtistBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final artists = widget.artists;
    final maxPlays = artists.isEmpty
        ? 1
        : artists.map((a) => a.plays).reduce(max);

    return StatsCard(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          return Column(
            children: List.generate(artists.length, (i) {
              final artist = artists[i];
              final ratio = maxPlays == 0 ? 0.0 : artist.plays / maxPlays;
              final animRatio = ratio * _anim.value;
              final color = kArtistColors[i % kArtistColors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${artist.plays} plays',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const SizedBox(width: 30),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                Container(
                                  height: 10,
                                  color: scheme.surfaceContainerHighest,
                                ),
                                FractionallySizedBox(
                                  widthFactor: animRatio.clamp(0.0, 1.0),
                                  child: Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          color,
                                          color.withValues(alpha: 0.6),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Top Track Hero Card
// ─────────────────────────────────────────────
class _TopTrackHero extends StatelessWidget {
  const _TopTrackHero({required this.item, required this.stats});
  final MediaItem item;
  final ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plays = ListeningStats.listenScoreFor(item);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: kMusicGradient[0].withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: kMusicGradient),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: kMusicGradient),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '🏆 #1 MÁS ESCUCHADA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  item.displaySubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$plays reproducciones',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kMusicGradient[1],
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

// ─────────────────────────────────────────────
// Animated Ranked List con barras proporcionales
// ─────────────────────────────────────────────
class AnimatedRankedList extends StatefulWidget {
  const AnimatedRankedList({
    super.key,
    required this.rows,
    required this.masterCtrl,
  });

  final List<RankedRowData> rows;
  final AnimationController masterCtrl;

  @override
  State<AnimatedRankedList> createState() => AnimatedRankedListState();
}

class AnimatedRankedListState extends State<AnimatedRankedList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barCtrl;
  late final Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _barAnim = CurvedAnimation(parent: _barCtrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _barCtrl.forward();
    });
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return StatsCard(
      child: Column(
        children: List.generate(widget.rows.length, (i) {
          final row = widget.rows[i];
          final ratio = row.maxValue == 0
              ? 0.0
              : row.currentValue / row.maxValue;
          final color = kArtistColors[i % kArtistColors.length];

          return AnimatedBuilder(
            animation: _barAnim,
            builder: (context, child) {
              final animRatio = (ratio * _barAnim.value).clamp(0.0, 1.0);
              return Column(
                children: [
                  if (i > 0)
                    Divider(
                      color: scheme.outline.withValues(alpha: 0.08),
                      height: 16,
                    ),
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  row.value,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: animRatio,
                                minHeight: 4,
                                backgroundColor: scheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Donut Chart — distribución biblioteca
// ─────────────────────────────────────────────
class _DonutDistributionCard extends StatefulWidget {
  const _DonutDistributionCard({required this.stats});
  final ListeningStats stats;

  @override
  State<_DonutDistributionCard> createState() => _DonutDistributionCardState();
}

class _DonutDistributionCardState extends State<_DonutDistributionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  int _touched = -1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.stats;
    final audio = s.importedAudioItems.toDouble();
    final video = s.importedVideoItems.toDouble();
    final favs = s.topFavoriteTracks.length.toDouble();
    final total = audio + video + favs;

    if (total == 0) return const SizedBox.shrink();

    final sections = [
      _DonutSection('Audio', audio, kMusicGradient[0]),
      _DonutSection('Video', video, kVideoGradient[0]),
      _DonutSection('Favoritos', favs, const Color(0xFF06D6A0)),
    ].where((s) => s.value > 0).toList();

    return StatsCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, child) {
                    return SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 42,
                          startDegreeOffset: -90,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    response == null ||
                                    response.touchedSection == null) {
                                  _touched = -1;
                                  return;
                                }
                                _touched = response
                                    .touchedSection!
                                    .touchedSectionIndex;
                              });
                            },
                          ),
                          sections: List.generate(sections.length, (i) {
                            final sec = sections[i];
                            final pct = total == 0
                                ? 0.0
                                : sec.value / total * 100;
                            final isTouched = i == _touched;
                            return PieChartSectionData(
                              value: sec.value * _anim.value,
                              color: sec.color,
                              radius: isTouched ? 52 : 44,
                              title: isTouched
                                  ? '${pct.toStringAsFixed(0)}%'
                                  : '',
                              titleStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: sections.map((sec) {
                    final pct = total == 0 ? 0.0 : sec.value / total * 100;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: sec.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sec.label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${sec.value.toInt()} · ${pct.toStringAsFixed(0)}%',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutSection {
  const _DonutSection(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

// ─────────────────────────────────────────────
// Monthly Imports Bar Chart vertical
// ─────────────────────────────────────────────
class _MonthlyImportsChart extends StatefulWidget {
  const _MonthlyImportsChart({required this.months});
  final List<MonthData> months;

  @override
  State<_MonthlyImportsChart> createState() => _MonthlyImportsChartState();
}

class _MonthlyImportsChartState extends State<_MonthlyImportsChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = widget.months;
    final maxVal = months.isEmpty ? 1 : months.map((m) => m.count).reduce(max);

    return StatsCard(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          return SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal.toDouble() * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gIdx, rod, rIdx) {
                      return BarTooltipItem(
                        '${months[gIdx].label}\n${rod.toY.toInt()} imports',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            months[idx].shortLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(months.length, (i) {
                  final month = months[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: month.count.toDouble() * _anim.value,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        gradient: const LinearGradient(
                          colors: kImportGradient,
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Regions bar card
// ─────────────────────────────────────────────
class _RegionsBarCard extends StatefulWidget {
  const _RegionsBarCard({required this.regions});
  final List<RegionStats> regions;

  @override
  State<_RegionsBarCard> createState() => _RegionsBarCardState();
}

class _RegionsBarCardState extends State<_RegionsBarCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final regions = widget.regions;
    final maxPlays = regions.isEmpty
        ? 1
        : regions.map((r) => r.plays).reduce(max);

    return StatsCard(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          return Column(
            children: List.generate(regions.length, (i) {
              final r = regions[i];
              final ratio = maxPlays == 0 ? 0.0 : r.plays / maxPlays;
              final animRatio = (ratio * _anim.value).clamp(0.0, 1.0);
              final color = kVideoGradient[i % 2 == 0 ? 0 : 1];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            r.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${r.plays} plays',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 26),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: animRatio,
                              minHeight: 6,
                              backgroundColor: scheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Completadas vs Saltadas
// ─────────────────────────────────────────────
class _CompletedVsSkippedCard extends StatefulWidget {
  const _CompletedVsSkippedCard({required this.stats});
  final ListeningStats stats;

  @override
  State<_CompletedVsSkippedCard> createState() =>
      _CompletedVsSkippedCardState();
}

class _CompletedVsSkippedCardState extends State<_CompletedVsSkippedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = widget.stats;
    final totalSkips = s.mostSkipped.fold<int>(
      0,
      (acc, i) => acc + i.skipCount,
    );
    final total = s.totalCompleted + totalSkips;

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatBubble(
                label: 'Completadas',
                value: '${s.totalCompleted}',
                color: const Color(0xFF06D6A0),
              ),
              const SizedBox(width: 12),
              StatBubble(
                label: 'Saltadas',
                value: '$totalSkips',
                color: const Color(0xFFFF6B6B),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (total > 0)
            AnimatedBuilder(
              animation: _anim,
              builder: (context, child) {
                final completedRatio =
                    ((s.totalCompleted / total) * _anim.value).clamp(0.0, 1.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 14,
                        child: Row(
                          children: [
                            Expanded(
                              flex: (completedRatio * 1000).round(),
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF06D6A0),
                                      Color(0xFF00B894),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: ((1 - completedRatio) * 1000).round().clamp(
                                0,
                                1000,
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFFF6B6B),
                                      Color(0xFFEE5A24),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(s.totalCompleted / total * 100).toStringAsFixed(0)}% de tus reproducciones fueron completadas',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class StatBubble extends StatelessWidget {
  const StatBubble({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared: Stats Card container
// ─────────────────────────────────────────────
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

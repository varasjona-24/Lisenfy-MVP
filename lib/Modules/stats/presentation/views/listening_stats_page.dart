import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../Modules/artists/data/artist_store.dart';
import '../../../../Modules/sources/binding/sources_binding.dart';
import '../../../../Modules/sources/controller/sources_controller.dart';
import '../../../../Modules/world_mode/agent/local_affinity_engine.dart';
import '../../../../Modules/world_mode/domain/entities/world_region_catalog.dart';
import '../../../../app/data/local/local_library_store.dart';
import '../../../../app/models/media_item.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../../app/utils/artist_credit_parser.dart';

// ─────────────────────────────────────────────
// Paleta de colores para charts
// ─────────────────────────────────────────────
const _kArtistColors = [
  Color(0xFFFF6B6B),
  Color(0xFFFF8E53),
  Color(0xFFFFD166),
  Color(0xFF06D6A0),
  Color(0xFF118AB2),
];

const _kMusicGradient = [Color(0xFF7B2FF7), Color(0xFFE040FB)];
const _kImportGradient = [Color(0xFF0575E6), Color(0xFF00F260)];
const _kVideoGradient = [Color(0xFFFF4E50), Color(0xFFF9D423)];

// ─────────────────────────────────────────────
// Page root
// ─────────────────────────────────────────────
class ListeningStatsPage extends StatelessWidget {
  const ListeningStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SourcesController>()) {
      SourcesBinding().dependencies();
    }
    final store = Get.find<LocalLibraryStore>();
    final artistStore = Get.isRegistered<ArtistStore>()
        ? Get.find<ArtistStore>()
        : null;
    final sourcesController = Get.find<SourcesController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🎧', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'Tu Wrapped',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
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

            return Obx(() {
              // Access topics and playlists to trigger reactivity
              sourcesController.topics.length;
              sourcesController.topicPlaylists.length;

              final stats = _ListeningStats.fromItems(
                snapshot.data ?? const [],
                artistStore: artistStore,
                sourcesController: sourcesController,
              );

              if (!stats.hasAnyData) {
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

              return _WrappedBody(stats: stats);
            });
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Body with staggered entrance and tabs
// ─────────────────────────────────────────────
class _WrappedBody extends StatefulWidget {
  const _WrappedBody({required this.stats});
  final _ListeningStats stats;

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
          SizedBox(
            height: MediaQuery.of(context).padding.top + kToolbarHeight + 4,
          ),
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
                  gradient: const LinearGradient(colors: _kMusicGradient),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _kMusicGradient[0].withValues(alpha: 0.3),
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
                _ImportsTab(stats: s, fade: _fade),
                _AudioTab(
                  stats: s,
                  fade: _fade,
                  masterCtrl: _masterCtrl,
                  counterCtrl: _counterCtrl,
                ),
                _VideoTab(stats: s, fade: _fade, masterCtrl: _masterCtrl),
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
  const _ImportsTab({required this.stats, required this.fade});
  final _ListeningStats stats;
  final Widget Function(int, Widget) fade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rows = stats.topImportedArtists
        .map(
          (artist) => _RankedRowData(
            title: artist.name,
            subtitle: '${artist.tracks} canciones importadas',
            value: '${artist.imports}',
            maxValue: stats.topImportedArtists.isEmpty
                ? 1
                : stats.topImportedArtists.first.imports,
            currentValue: artist.imports,
            color: _kImportGradient.first,
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
                colors: _kImportGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _kImportGradient[0].withValues(alpha: 0.3),
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
                _FieldMetricData(
                  icon: Icons.file_download_done_rounded,
                  label: 'Archivos',
                  value: '${stats.totalImportFiles}',
                  caption:
                      '${stats.importedAudioFiles} audio · ${stats.importedVideoFiles} video',
                ),
                _FieldMetricData(
                  icon: Icons.sd_storage_rounded,
                  label: 'Peso local',
                  value: stats.totalImportSizeLabel,
                  caption: 'Tamaño total en almacenamiento',
                ),
                _FieldMetricData(
                  icon: Icons.analytics_rounded,
                  label: 'Tamaño medio',
                  value: stats.averageFileSizeLabel,
                  caption: 'Peso promedio por archivo',
                ),
                _FieldMetricData(
                  icon: Icons.file_present_rounded,
                  label: 'Formato común',
                  value: stats.mostCommonFormat,
                  caption: 'Tipo de archivo predominante',
                ),
                _FieldMetricData(
                  icon: Icons.calendar_month_rounded,
                  label: 'Mes fuerte',
                  value: stats.topImportMonthLabel,
                  caption: 'Mayor cantidad de descargas',
                ),
                _FieldMetricData(
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
                        child: _FieldMetricTile(
                          data: m,
                          accent: _kImportGradient.first,
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
            _SectionHeader(
              emoji: '📊',
              title: 'Actividad de Imports',
              subtitle: 'Archivos importados por mes',
              gradient: _kImportGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(2, _MonthlyImportsChart(months: stats.monthlyImports)),
          const SizedBox(height: 14),
        ],

        if (rows.isNotEmpty) ...[
          fade(
            3,
            _SectionHeader(
              emoji: '🎤',
              title: 'Artistas más Importados',
              subtitle: 'Basado en archivos locales',
              gradient: _kImportGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(3, _CompactRankedRows(rows: rows)),
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
    required this.stats,
    required this.fade,
    required this.masterCtrl,
    required this.counterCtrl,
  });

  final _ListeningStats stats;
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
                _FieldMetricData(
                  icon: Icons.library_music_rounded,
                  label: 'Canciones',
                  value: '${stats.importedAudioItems}',
                  caption: '${stats.audioLibraryDurationLabel} guardadas',
                ),
                _FieldMetricData(
                  icon: Icons.watch_later_rounded,
                  label: 'Tiempo escuchado',
                  value: stats.estimatedListeningTimeLabel,
                  caption: 'Tiempo estimado de reproducción',
                ),
                _FieldMetricData(
                  icon: Icons.access_time_filled_rounded,
                  label: 'Horario favorito',
                  value: stats.favoriteTimeOfDay,
                  caption: 'Momento con más actividad',
                ),
                _FieldMetricData(
                  icon: Icons.people_rounded,
                  label: 'Diversidad de artistas',
                  value: '${stats.artistDiversityCount}',
                  caption: 'Artistas distintos escuchados',
                ),
                _FieldMetricData(
                  icon: Icons.repeat_rounded,
                  label: 'Reproducciones',
                  value: '${stats.totalPlays}',
                  caption: '${stats.recentTracks} activas en 30 días',
                ),
                _FieldMetricData(
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
                        child: _FieldMetricTile(
                          data: m,
                          accent: _kMusicGradient.first,
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
          _SectionHeader(
            emoji: '📊',
            title: 'Tu Biblioteca',
            subtitle: 'Distribución de contenido',
            gradient: _kMusicGradient,
          ),
        ),
        const SizedBox(height: 10),
        fade(4, _DonutDistributionCard(stats: stats)),
        const SizedBox(height: 14),

        if (stats.topArtists.isNotEmpty) ...[
          fade(
            5,
            _SectionHeader(
              emoji: '🎤',
              title: 'Top Artistas',
              subtitle: 'Por número de escuchas',
              gradient: _kMusicGradient,
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
            _SectionHeader(
              emoji: '🏆',
              title: 'Top Canciones',
              subtitle: 'Las que más sonaron',
              gradient: _kMusicGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(
            7,
            _AnimatedRankedList(
              rows: stats.topTracks
                  .map(
                    (item) => _RankedRowData(
                      title: item.title,
                      subtitle: item.displaySubtitle,
                      value: '${_ListeningStats.listenScoreFor(item)} plays',
                      maxValue: stats.topTracks.isNotEmpty
                          ? _ListeningStats.listenScoreFor(
                              stats.topTracks.first,
                            )
                          : 1,
                      currentValue: _ListeningStats.listenScoreFor(item),
                      color: _kMusicGradient[0],
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
            _SectionHeader(
              emoji: '🌍',
              title: 'Regiones Favoritas',
              subtitle: 'Tu música por origen',
              gradient: _kMusicGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(8, _RegionsBarCard(regions: stats.topRegions)),
          const SizedBox(height: 14),
        ],

        fade(
          9,
          _SectionHeader(
            emoji: '⏭',
            title: 'Completadas vs Saltadas',
            subtitle: 'Tu paciencia musical',
            gradient: _kMusicGradient,
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
    required this.stats,
    required this.fade,
    required this.masterCtrl,
  });

  final _ListeningStats stats;
  final Widget Function(int, Widget) fade;
  final AnimationController masterCtrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final videoRows = stats.topVideos
        .map(
          (item) => _RankedRowData(
            title: item.title,
            subtitle: item.displaySubtitle.isEmpty
                ? 'Video'
                : item.displaySubtitle,
            value: '${_ListeningStats.listenScoreFor(item)} plays',
            maxValue: stats.topVideos.isEmpty
                ? 1
                : _ListeningStats.listenScoreFor(stats.topVideos.first),
            currentValue: _ListeningStats.listenScoreFor(item),
            color: _kVideoGradient.first,
          ),
        )
        .toList();

    final collectionRows = stats.topCollections
        .map(
          (col) => _RankedRowData(
            title: col.name,
            subtitle: col.subtitle,
            value: '${col.items} videos',
            maxValue: stats.topCollections.isEmpty
                ? 1
                : stats.topCollections.first.items,
            currentValue: col.items,
            color: _kVideoGradient.first,
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
                colors: _kVideoGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _kVideoGradient[0].withValues(alpha: 0.3),
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
                _FieldMetricData(
                  icon: Icons.video_library_rounded,
                  label: 'Videos',
                  value: '${stats.importedVideoItems}',
                  caption: '${stats.videoLibraryDurationLabel} guardados',
                ),
                _FieldMetricData(
                  icon: Icons.play_circle_rounded,
                  label: 'Reproducciones',
                  value: '${stats.videoPlays}',
                  caption: '${stats.videoRecentItems} activos en 30 días',
                ),
                _FieldMetricData(
                  icon: Icons.folder_special_rounded,
                  label: 'Collections',
                  value: '${stats.totalVideoCollections}',
                  caption:
                      '${stats.rootVideoCollections} principales · ${stats.videoSubCollections} subcarpetas',
                ),
                _FieldMetricData(
                  icon: Icons.pie_chart_rounded,
                  label: 'Organización',
                  value: stats.organizedVideoPercentageLabel,
                  caption: 'Videos organizados en carpetas',
                ),
                _FieldMetricData(
                  icon: Icons.linked_camera_rounded,
                  label: 'Promedio por carpeta',
                  value: stats.averageVideosPerCollectionLabel,
                  caption: 'Videos por Collection',
                ),
                _FieldMetricData(
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
                        child: _FieldMetricTile(
                          data: m,
                          accent: _kVideoGradient.first,
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
            _SectionHeader(
              emoji: '📺',
              title: 'Videos más Vistos',
              subtitle: 'Por número de reproducciones',
              gradient: _kVideoGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(2, _AnimatedRankedList(rows: videoRows, masterCtrl: masterCtrl)),
          const SizedBox(height: 14),
        ],

        if (collectionRows.isNotEmpty) ...[
          fade(
            3,
            _SectionHeader(
              emoji: '📁',
              title: 'Top Colecciones',
              subtitle: 'Las más grandes',
              gradient: _kVideoGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(
            3,
            _AnimatedRankedList(rows: collectionRows, masterCtrl: masterCtrl),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _FieldMetricData {
  const _FieldMetricData({
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

class _FieldMetricTile extends StatelessWidget {
  const _FieldMetricTile({required this.data, required this.accent});

  final _FieldMetricData data;
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

class _CompactRankedRows extends StatelessWidget {
  const _CompactRankedRows({required this.rows});

  final List<_RankedRowData> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: List.generate(rows.take(5).length, (index) {
        final row = rows[index];
        final ratio = row.maxValue <= 0 ? 0.0 : row.currentValue / row.maxValue;
        final color = _kArtistColors[index % _kArtistColors.length];
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
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
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

  final _ListeningStats stats;
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
          colors: _kMusicGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kMusicGradient[0].withValues(alpha: 0.4),
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
  final _ListeningStats stats;

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
  final _ListeningStats stats;

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

    return _StatsCard(
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
                  color: _kMusicGradient[0],
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
  final List<_ArtistStats> artists;

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

    return _StatsCard(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          return Column(
            children: List.generate(artists.length, (i) {
              final artist = artists[i];
              final ratio = maxPlays == 0 ? 0.0 : artist.plays / maxPlays;
              final animRatio = ratio * _anim.value;
              final color = _kArtistColors[i % _kArtistColors.length];

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
  final _ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plays = _ListeningStats.listenScoreFor(item);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _kMusicGradient[0].withValues(alpha: 0.4),
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
              gradient: const LinearGradient(colors: _kMusicGradient),
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
                    gradient: const LinearGradient(colors: _kMusicGradient),
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
                    color: _kMusicGradient[1],
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
class _AnimatedRankedList extends StatefulWidget {
  const _AnimatedRankedList({required this.rows, required this.masterCtrl});

  final List<_RankedRowData> rows;
  final AnimationController masterCtrl;

  @override
  State<_AnimatedRankedList> createState() => _AnimatedRankedListState();
}

class _AnimatedRankedListState extends State<_AnimatedRankedList>
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

    return _StatsCard(
      child: Column(
        children: List.generate(widget.rows.length, (i) {
          final row = widget.rows[i];
          final ratio = row.maxValue == 0
              ? 0.0
              : row.currentValue / row.maxValue;
          final color = _kArtistColors[i % _kArtistColors.length];

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
  final _ListeningStats stats;

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
      _DonutSection('Audio', audio, _kMusicGradient[0]),
      _DonutSection('Video', video, _kVideoGradient[0]),
      _DonutSection('Favoritos', favs, const Color(0xFF06D6A0)),
    ].where((s) => s.value > 0).toList();

    return _StatsCard(
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
  final List<_MonthData> months;

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

    return _StatsCard(
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
                          colors: _kImportGradient,
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
  final List<_RegionStats> regions;

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

    return _StatsCard(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          return Column(
            children: List.generate(regions.length, (i) {
              final r = regions[i];
              final ratio = maxPlays == 0 ? 0.0 : r.plays / maxPlays;
              final animRatio = (ratio * _anim.value).clamp(0.0, 1.0);
              final color = _kVideoGradient[i % 2 == 0 ? 0 : 1];

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
  final _ListeningStats stats;

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

    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatBubble(
                label: 'Completadas',
                value: '${s.totalCompleted}',
                color: const Color(0xFF06D6A0),
              ),
              const SizedBox(width: 12),
              _StatBubble(
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

class _StatBubble extends StatelessWidget {
  const _StatBubble({
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
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.child});
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

// ─────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────
class _RankedRowData {
  const _RankedRowData({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.maxValue,
    required this.currentValue,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String value;
  final int maxValue;
  final int currentValue;
  final Color color;
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

class _MonthData {
  const _MonthData({
    required this.label,
    required this.shortLabel,
    required this.count,
  });

  final String label;
  final String shortLabel;
  final int count;
}

// ─────────────────────────────────────────────
// Main stats computation
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// Aux: Collection stats
// ─────────────────────────────────────────────
class _CollectionStats {
  const _CollectionStats({
    required this.name,
    required this.subtitle,
    required this.items,
  });

  final String name;
  final String subtitle;
  final int items;
}

// ─────────────────────────────────────────────
// Main stats computation
// ─────────────────────────────────────────────
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
    required this.monthlyImports,
    // Faltantes y nuevas
    required this.audioLibraryDurationLabel,
    required this.audioCompletionRateLabel,
    required this.audioImportSizeLabel,
    required this.videoLibraryDurationLabel,
    required this.totalVideoCollections,
    required this.rootVideoCollections,
    required this.videoSubCollections,
    required this.collectionLinkedItems,
    required this.emptyVideoCollections,
    required this.largestCollectionName,
    required this.largestCollectionCount,
    required this.topCollections,
    // Avanzadas de Imports
    required this.averageFileSizeLabel,
    required this.mostCommonFormat,
    required this.mostActiveImportWeekday,
    // Avanzadas de Audio
    required this.estimatedListeningTimeLabel,
    required this.favoriteTimeOfDay,
    required this.artistDiversityCount,
    // Avanzadas de Video
    required this.organizedVideoPercentageLabel,
    required this.averageVideosPerCollectionLabel,
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
  final List<_MonthData> monthlyImports;

  // Faltantes y nuevas
  final String audioLibraryDurationLabel;
  final String audioCompletionRateLabel;
  final String audioImportSizeLabel;
  final String videoLibraryDurationLabel;
  final int totalVideoCollections;
  final int rootVideoCollections;
  final int videoSubCollections;
  final int collectionLinkedItems;
  final int emptyVideoCollections;
  final String largestCollectionName;
  final int largestCollectionCount;
  final List<_CollectionStats> topCollections;

  // Avanzadas de Imports
  final String averageFileSizeLabel;
  final String mostCommonFormat;
  final String mostActiveImportWeekday;

  // Avanzadas de Audio
  final String estimatedListeningTimeLabel;
  final String favoriteTimeOfDay;
  final int artistDiversityCount;

  // Avanzadas de Video
  final String organizedVideoPercentageLabel;
  final String averageVideosPerCollectionLabel;

  bool get hasListeningData =>
      totalPlays > 0 || totalCompleted > 0 || topTracks.isNotEmpty;

  bool get hasAnyData =>
      hasListeningData || totalImportFiles > 0 || totalVideoCollections > 0;

  static _ListeningStats fromItems(
    List<MediaItem> items, {
    ArtistStore? artistStore,
    SourcesController? sourcesController,
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
    final monthlyImports = _buildMonthlyImports(importStats.monthCounts);

    // ─── CÁLCULOS FALTANTES / NUEVOS ───
    final audioDurationSeconds = audioItems.fold<int>(
      0,
      (sum, item) => sum + (item.effectiveDurationSeconds ?? 0),
    );
    final audioLibraryDurationLabel = _formatDuration(audioDurationSeconds);

    final videoDurationSeconds = videoItems.fold<int>(
      0,
      (sum, item) => sum + (item.effectiveDurationSeconds ?? 0),
    );
    final videoLibraryDurationLabel = _formatDuration(videoDurationSeconds);

    final audioCompletionRateLabel = totalPlays == 0
        ? '0% completadas'
        : '${(totalCompleted / totalPlays * 100).toStringAsFixed(0)}% completadas';

    var audioBytes = 0;
    for (final item in audioItems) {
      for (final v in item.variants) {
        if (v.kind == MediaVariantKind.audio) {
          audioBytes += max(v.size ?? 0, 0);
        }
      }
    }
    final audioImportSizeLabel = _formatBytes(audioBytes);

    final topics = sourcesController?.topics ?? const [];
    final playlists = sourcesController?.topicPlaylists ?? const [];
    final totalVideoCollections = topics.length + playlists.length;
    final rootVideoCollections = topics.length;
    final videoSubCollections = playlists.length;

    final allLinkedIds = <String>{
      ...topics.expand((t) => t.itemIds),
      ...playlists.expand((p) => p.itemIds),
    };
    final collectionLinkedItems = allLinkedIds.length;

    final emptyTopics = topics.where((t) => t.itemIds.isEmpty).length;
    final emptyPlaylists = playlists.where((p) => p.itemIds.isEmpty).length;
    final emptyVideoCollections = emptyTopics + emptyPlaylists;

    var largestCount = 0;
    var largestName = 'Ninguna';
    for (final t in topics) {
      if (t.itemIds.length > largestCount) {
        largestCount = t.itemIds.length;
        largestName = t.title;
      }
    }
    for (final p in playlists) {
      if (p.itemIds.length > largestCount) {
        largestCount = p.itemIds.length;
        largestName = p.name;
      }
    }
    final largestCollectionName = largestName;
    final largestCollectionCount = largestCount;

    final allCollections = [
      ...topics.map(
        (t) => _CollectionStats(
          name: t.title,
          subtitle: 'Collection',
          items: t.itemIds.length,
        ),
      ),
      ...playlists.map(
        (p) => _CollectionStats(
          name: p.name,
          subtitle: 'Sub-collection',
          items: p.itemIds.length,
        ),
      ),
    ];
    allCollections.sort((a, b) => b.items.compareTo(a.items));
    final topCollections = allCollections.take(5).toList();

    // ─── CÁLCULOS AVANZADOS IMPORTS ───
    final averageFileSizeLabel = importStats.totalFiles == 0
        ? '0 B'
        : _formatBytes(importStats.totalBytes ~/ importStats.totalFiles);

    final formatCounts = <String, int>{};
    final weekdayCounts = <int, int>{};
    for (final item in items) {
      for (final v in item.variants) {
        final fmt = v.format.toLowerCase().trim();
        if (fmt.isNotEmpty) {
          formatCounts[fmt] = (formatCounts[fmt] ?? 0) + 1;
        }
        if (v.createdAt > 0) {
          final dt = DateTime.fromMillisecondsSinceEpoch(v.createdAt);
          weekdayCounts[dt.weekday] = (weekdayCounts[dt.weekday] ?? 0) + 1;
        }
      }
    }
    final mostCommonFormat = formatCounts.isEmpty
        ? 'Ninguno'
        : (formatCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key
              .toUpperCase();

    const weekdays = [
      '',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final mostActiveImportWeekday = weekdayCounts.isEmpty
        ? 'Sin datos'
        : weekdays[(weekdayCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key];

    // ─── CÁLCULOS AVANZADOS AUDIO ───
    var totalListeningTimeSeconds = 0.0;
    for (final item in listened) {
      final duration = item.effectiveDurationSeconds ?? 0;
      if (duration <= 0) continue;
      final fullCount = effectiveCompletedFor(item);
      totalListeningTimeSeconds += fullCount * duration;
      final partialCount = max(item.playCount - fullCount, 0);
      totalListeningTimeSeconds +=
          partialCount * duration * item.avgListenProgress;
    }
    final estimatedListeningTimeLabel = _formatDuration(
      totalListeningTimeSeconds.round(),
    );

    final hourCounts = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};
    for (final item in listened) {
      if (item.lastPlayedAt != null && item.lastPlayedAt! > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(item.lastPlayedAt!);
        final hour = dt.hour;
        if (hour >= 6 && hour < 12) {
          hourCounts[1] = hourCounts[1]! + 1;
        } else if (hour >= 12 && hour < 18) {
          hourCounts[2] = hourCounts[2]! + 1;
        } else if (hour >= 18 && hour < 24) {
          hourCounts[3] = hourCounts[3]! + 1;
        } else {
          hourCounts[0] = hourCounts[0]! + 1;
        }
      }
    }
    final maxPeriodEntry = hourCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final favoriteTimeOfDay = maxPeriodEntry.first.value == 0
        ? 'Sin datos'
        : switch (maxPeriodEntry.first.key) {
            0 => 'Madrugada (0am - 6am)',
            1 => 'Mañana (6am - 12pm)',
            2 => 'Tarde (12pm - 6pm)',
            3 => 'Noche (6pm - 12am)',
            _ => 'Sin datos',
          };

    final uniqueArtists = <String>{};
    for (final item in listened) {
      final credits = ArtistCreditParser.parse(item.displaySubtitle);
      final name = ArtistCreditParser.cleanName(credits.primaryArtist);
      if (name.isNotEmpty) {
        uniqueArtists.add(ArtistCreditParser.normalizeKey(name));
      }
    }
    final artistDiversityCount = uniqueArtists.length;

    // ─── CÁLCULOS AVANZADOS VIDEO ───
    final videoItemKeys = videoItems.map((e) => e.fileId).toSet();
    if (videoItemKeys.isEmpty) {
      videoItemKeys.addAll(videoItems.map((e) => e.id));
    }
    final linkedVideosCount = allLinkedIds.intersection(videoItemKeys).length;
    final organizedVideoPercentageLabel = videoItems.isEmpty
        ? '0%'
        : '${(linkedVideosCount / videoItems.length * 100).toStringAsFixed(0)}%';

    final totalCollectionsCount = topics.length + playlists.length;
    final averageVideosPerCollectionLabel = totalCollectionsCount == 0
        ? '0'
        : (allLinkedIds.length / totalCollectionsCount).toStringAsFixed(1);

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
          ? 'Aún no hay imports con fecha registrada.'
          : 'Último import: ${_relativeDateLabel(importStats.latestImportAt)}',
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
      monthlyImports: monthlyImports,
      // Faltantes y nuevas
      audioLibraryDurationLabel: audioLibraryDurationLabel,
      audioCompletionRateLabel: audioCompletionRateLabel,
      audioImportSizeLabel: audioImportSizeLabel,
      videoLibraryDurationLabel: videoLibraryDurationLabel,
      totalVideoCollections: totalVideoCollections,
      rootVideoCollections: rootVideoCollections,
      videoSubCollections: videoSubCollections,
      collectionLinkedItems: collectionLinkedItems,
      emptyVideoCollections: emptyVideoCollections,
      largestCollectionName: largestCollectionName,
      largestCollectionCount: largestCollectionCount,
      topCollections: topCollections,
      // Avanzadas de Imports
      averageFileSizeLabel: averageFileSizeLabel,
      mostCommonFormat: mostCommonFormat,
      mostActiveImportWeekday: mostActiveImportWeekday,
      // Avanzadas de Audio
      estimatedListeningTimeLabel: estimatedListeningTimeLabel,
      favoriteTimeOfDay: favoriteTimeOfDay,
      artistDiversityCount: artistDiversityCount,
      // Avanzadas de Video
      organizedVideoPercentageLabel: organizedVideoPercentageLabel,
      averageVideosPerCollectionLabel: averageVideosPerCollectionLabel,
    );
  }

  static List<_MonthData> _buildMonthlyImports(Map<String, int> monthCounts) {
    if (monthCounts.isEmpty) return [];

    final sorted = monthCounts.entries.toList()
      ..sort((a, b) {
        final aDate = _parseMonthKey(a.key);
        final bDate = _parseMonthKey(b.key);
        return aDate.compareTo(bDate);
      });

    final recent = sorted.length > 6
        ? sorted.sublist(sorted.length - 6)
        : sorted;

    const monthNames = [
      '',
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];

    return recent.map((e) {
      final parts = e.key.split('/');
      final month = int.tryParse(parts[0]) ?? 0;
      final year = parts.length > 1 ? parts[1] : '';
      final shortLabel = month >= 1 && month <= 12 ? monthNames[month] : e.key;
      return _MonthData(
        label: '${monthNames.elementAtOrNull(month) ?? ''} $year',
        shortLabel: shortLabel,
        count: e.value,
      );
    }).toList();
  }

  static DateTime _parseMonthKey(String key) {
    final parts = key.split('/');
    if (parts.length < 2) return DateTime(0);
    final month = int.tryParse(parts[0]) ?? 1;
    final year = int.tryParse(parts[1]) ?? 0;
    return DateTime(year, month);
  }

  static String _topImportPeriodDetail(_ImportStats stats) {
    if (stats.topMonth.count <= 0 && stats.topWeek.count <= 0) {
      return 'Aún no hay suficientes imports con fecha registrada.';
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

  static String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0s';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  static String _relativeDateLabel(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'hoy';
    if (diff == 1) return 'ayer';
    if (diff < 30) return 'hace $diff días';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ─────────────────────────────────────────────
// Import Stats computation
// ─────────────────────────────────────────────
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
    required this.monthCounts,
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
  final Map<String, int> monthCounts;

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
      monthCounts: monthCounts,
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

import '../../../../app/ui/widgets/navigation/app_navigation_scaffold.dart';
import '../../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../controller/listening_stats_controller.dart';
import '../../domain/entities/listening_stats_entities.dart';
import 'weekly_collage_page.dart';
import '../widgets/wrapped_panel_style.dart';
import '../widgets/wrapped_artwork.dart';

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

    return AppNavigationScaffold(
      navigationIndex: 4,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          tr('wrapped.title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        leading: const BackButton(),
        actions: [
          if (AppBottomNav.desktopSidebarEnabled)
            IconButton(
              tooltip: tr('weekly_collage.open'),
              icon: const Icon(Icons.calendar_view_week_rounded),
              onPressed: () => Get.to(() => const WeeklyCollagePage()),
            )
          else
            TextButton.icon(
              label: Text(tr('weekly_collage.open')),
              icon: const Icon(Icons.calendar_view_week_rounded),
              onPressed: () => Get.to(() => const WeeklyCollagePage()),
            ),
        ],
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
                child: StatsCard(
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
                        tr('wrapped.empty_title'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('wrapped.empty_body'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.refreshStats,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: _WrappedBody(stats: stats),
              ),
            ),
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
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: scheme.onPrimary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.download_rounded, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tr('wrapped.tabs.imports'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.graphic_eq_rounded, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tr('wrapped.tabs.audio'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.video_collection_rounded, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tr('wrapped.tabs.video'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
            subtitle: tr(
              'wrapped.imports.imported_songs',
              args: ['${artist.tracks}'],
            ),
            value: tr('wrapped.ui.import_count', args: ['${artist.imports}']),
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
            decoration: wrappedPanelDecoration(context, highlighted: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.download_rounded,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tr('wrapped.imports.hero_title'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  stats.latestImportLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
              final isWide = constraints.maxWidth >= 300;
              final itemWidth = isWide
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;

              final metrics = [
                FieldMetricData(
                  icon: Icons.file_download_done_rounded,
                  label: tr('wrapped.imports.files'),
                  value: '${stats.totalImportFiles}',
                  caption: tr(
                    'wrapped.imports.files_caption',
                    args: [
                      '${stats.importedAudioFiles}',
                      '${stats.importedVideoFiles}',
                    ],
                  ),
                ),
                FieldMetricData(
                  icon: Icons.sd_storage_rounded,
                  label: tr('wrapped.imports.local_weight'),
                  value: stats.totalImportSizeLabel,
                  caption: tr('wrapped.imports.local_weight_caption'),
                ),
                FieldMetricData(
                  icon: Icons.analytics_rounded,
                  label: tr('wrapped.imports.avg_size'),
                  value: stats.averageFileSizeLabel,
                  caption: tr('wrapped.imports.avg_size_caption'),
                ),
                FieldMetricData(
                  icon: Icons.file_present_rounded,
                  label: tr('wrapped.imports.common_format'),
                  value: stats.mostCommonFormat,
                  caption: tr('wrapped.imports.common_format_caption'),
                ),
                FieldMetricData(
                  icon: Icons.calendar_month_rounded,
                  label: tr('wrapped.imports.strong_month'),
                  value: stats.topImportMonthLabel,
                  caption: tr('wrapped.imports.strong_month_caption'),
                ),
                FieldMetricData(
                  icon: Icons.today_rounded,
                  label: tr('wrapped.imports.active_day'),
                  value: stats.mostActiveImportWeekday,
                  caption: tr('wrapped.imports.active_day_caption'),
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
              title: tr('wrapped.imports.activity_title'),
              subtitle: tr('wrapped.imports.activity_subtitle'),
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
              title: tr('wrapped.imports.top_artists_title'),
              subtitle: tr('wrapped.imports.top_artists_subtitle'),
              gradient: kImportGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(
            3,
            WrappedRankedRecap(
              rows: rows,
              artworkItems: stats.topImportedArtists
                  .map(
                    (a) =>
                        a.artwork ??
                        MediaItem.fromJson({
                          'id': a.name,
                          'title': a.name,
                          'variants': [],
                        }),
                  )
                  .toList(),
              badge: tr('wrapped.imports.top_artist_badge'),
            ),
          ),
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
              final isWide = constraints.maxWidth >= 300;
              final itemWidth = isWide
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;

              final metrics = [
                FieldMetricData(
                  icon: Icons.library_music_rounded,
                  label: tr('wrapped.audio.songs'),
                  value: '${stats.importedAudioItems}',
                  caption: tr(
                    'wrapped.audio.saved_duration',
                    args: [stats.audioLibraryDurationLabel],
                  ),
                ),
                FieldMetricData(
                  icon: Icons.watch_later_rounded,
                  label: tr('wrapped.audio.listening_time'),
                  value: stats.estimatedListeningTimeLabel,
                  caption: tr('wrapped.audio.listening_time_caption'),
                ),
                FieldMetricData(
                  icon: Icons.access_time_filled_rounded,
                  label: tr('wrapped.audio.favorite_time'),
                  value: stats.favoriteTimeOfDay,
                  caption: tr('wrapped.audio.favorite_time_caption'),
                ),
                FieldMetricData(
                  icon: Icons.people_rounded,
                  label: tr('wrapped.audio.artist_diversity'),
                  value: '${stats.artistDiversityCount}',
                  caption: tr('wrapped.audio.artist_diversity_caption'),
                ),
                FieldMetricData(
                  icon: Icons.repeat_rounded,
                  label: tr('wrapped.audio.plays'),
                  value: '${stats.totalPlays}',
                  caption: tr(
                    'wrapped.audio.recent_tracks_caption',
                    args: ['${stats.recentTracks}'],
                  ),
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
            title: tr('wrapped.audio.library_title'),
            subtitle: tr('wrapped.audio.library_subtitle'),
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
              title: tr('wrapped.audio.top_artists_title'),
              subtitle: tr('wrapped.audio.top_artists_subtitle'),
              gradient: kMusicGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(5, _ArtistRecap(artists: stats.topArtists)),
          const SizedBox(height: 14),
        ],

        if (stats.topTracks.isNotEmpty) ...[
          fade(
            7,
            SectionHeader(
              emoji: '🏆',
              title: tr('wrapped.audio.top_tracks_title'),
              subtitle: tr('wrapped.audio.top_tracks_subtitle'),
              gradient: kMusicGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(
            7,
            Column(
              children: [
                if (topTrack != null) ...[
                  _TopTrackHero(item: topTrack, stats: stats),
                  const SizedBox(height: 14),
                ],
                if (stats.topTracks.length > 1)
                  AnimatedRankedList(
                    startRank: 2,
                    artworkItems: stats.topTracks.skip(1).toList(),
                    rows: stats.topTracks
                        .skip(1)
                        .map(
                          (item) => RankedRowData(
                            title: item.title,
                            subtitle: item.displaySubtitle,
                            value:
                                '${ListeningStats.countedPlaysFor(item)} ${tr('wrapped.audio.plays_unit')}',
                            maxValue: stats.topTracks.isNotEmpty
                                ? ListeningStats.countedPlaysFor(
                                    stats.topTracks.first,
                                  )
                                : 1,
                            currentValue: ListeningStats.countedPlaysFor(item),
                            color: kMusicGradient[0],
                          ),
                        )
                        .toList(),
                    masterCtrl: masterCtrl,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (stats.topFavoriteTracks.isNotEmpty) ...[
          fade(
            8,
            SectionHeader(
              emoji: '❤️',
              title: tr('wrapped.audio.favorites_title'),
              subtitle: tr('wrapped.audio.favorites_subtitle'),
              gradient: kMusicGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(
            8,
            WrappedRankedRecap(
              badge: tr('wrapped.audio.favorite_badge'),
              artworkItems: stats.topFavoriteTracks,
              rows: stats.topFavoriteTracks
                  .map(
                    (item) => RankedRowData(
                      title: item.title,
                      subtitle: item.displaySubtitle,
                      value: tr(
                        'wrapped.ui.play_count',
                        args: ['${ListeningStats.countedPlaysFor(item)}'],
                      ),
                      maxValue: ListeningStats.countedPlaysFor(
                        stats.topFavoriteTracks.first,
                      ),
                      currentValue: ListeningStats.countedPlaysFor(item),
                      color: kMusicGradient.first,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (stats.topRegions.isNotEmpty) ...[
          fade(
            8,
            SectionHeader(
              emoji: '🌍',
              title: tr('wrapped.audio.regions_title'),
              subtitle: tr('wrapped.audio.regions_subtitle'),
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
            title: tr('wrapped.audio.completed_skipped_title'),
            subtitle: tr('wrapped.audio.completed_skipped_subtitle'),
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
                ? tr('wrapped.video.fallback')
                : item.displaySubtitle,
            value:
                '${ListeningStats.countedPlaysFor(item)} ${tr('wrapped.audio.plays_unit')}',
            maxValue: stats.topVideos.isEmpty
                ? 1
                : ListeningStats.countedPlaysFor(stats.topVideos.first),
            currentValue: ListeningStats.countedPlaysFor(item),
            color: kVideoGradient.first,
          ),
        )
        .toList();

    final collectionRows = stats.topCollections
        .map(
          (col) => RankedRowData(
            title: col.name,
            subtitle: col.subtitle,
            value: tr('wrapped.video.videos_unit', args: ['${col.items}']),
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
            decoration: wrappedPanelDecoration(context, highlighted: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.video_collection_rounded,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tr('wrapped.video.hero_title'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  stats.largestCollectionCount <= 0
                      ? tr('wrapped.video.hero_empty')
                      : tr(
                          'wrapped.video.hero_dominant',
                          args: [
                            stats.largestCollectionName,
                            '${stats.largestCollectionCount}',
                          ],
                        ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (stats.topVideos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  WrappedCoverStrip(
                    items: stats.topVideos,
                    aspectRatio: 16 / 9,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        fade(
          1,
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 300;
              final itemWidth = isWide
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;

              final metrics = [
                FieldMetricData(
                  icon: Icons.video_library_rounded,
                  label: tr('wrapped.video.videos'),
                  value: '${stats.importedVideoItems}',
                  caption: tr(
                    'wrapped.video.saved',
                    args: [stats.videoLibraryDurationLabel],
                  ),
                ),
                FieldMetricData(
                  icon: Icons.play_circle_rounded,
                  label: tr('wrapped.video.plays'),
                  value: '${stats.videoPlays}',
                  caption: tr(
                    'wrapped.video.active_30d',
                    args: ['${stats.videoRecentItems}'],
                  ),
                ),
                FieldMetricData(
                  icon: Icons.folder_special_rounded,
                  label: tr('wrapped.video.collections'),
                  value: '${stats.totalVideoCollections}',
                  caption: tr(
                    'wrapped.video.collections_caption',
                    args: [
                      '${stats.rootVideoCollections}',
                      '${stats.videoSubCollections}',
                    ],
                  ),
                ),
                FieldMetricData(
                  icon: Icons.pie_chart_rounded,
                  label: tr('wrapped.video.organization'),
                  value: stats.organizedVideoPercentageLabel,
                  caption: tr('wrapped.video.organization_caption'),
                ),
                FieldMetricData(
                  icon: Icons.linked_camera_rounded,
                  label: tr('wrapped.video.avg_folder'),
                  value: stats.averageVideosPerCollectionLabel,
                  caption: tr('wrapped.video.avg_folder_caption'),
                ),
                FieldMetricData(
                  icon: Icons.link_rounded,
                  label: tr('wrapped.video.linked_items'),
                  value: '${stats.collectionLinkedItems}',
                  caption: tr(
                    'wrapped.video.empty_collections',
                    args: ['${stats.emptyVideoCollections}'],
                  ),
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
              title: tr('wrapped.video.top_videos_title'),
              subtitle: tr('wrapped.video.top_videos_subtitle'),
              gradient: kVideoGradient,
            ),
          ),
          const SizedBox(height: 10),
          fade(
            2,
            WrappedRankedRecap(
              rows: videoRows,
              artworkItems: stats.topVideos,
              artworkAspectRatio: 16 / 9,
              badge: tr('wrapped.video.top_video_badge'),
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (collectionRows.isNotEmpty) ...[
          fade(
            3,
            SectionHeader(
              emoji: '📁',
              title: tr('wrapped.video.top_collections_title'),
              subtitle: tr('wrapped.video.top_collections_subtitle'),
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
      decoration: wrappedPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: scheme.onSurface, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.1,
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
    );
  }
}

class CompactRankedRows extends StatelessWidget {
  const CompactRankedRows({
    super.key,
    required this.rows,
    this.artworkItems = const [],
    this.startRank = 1,
    this.artworkAspectRatio = 1,
  });

  final List<RankedRowData> rows;
  final List<MediaItem> artworkItems;
  final int startRank;
  final double artworkAspectRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return StatsCard(
      child: Column(
        children: List.generate(rows.take(5).length, (index) {
          final row = rows[index];
          final ratio = row.maxValue <= 0
              ? 0.0
              : row.currentValue / row.maxValue;
          final color = kArtistColors[index % kArtistColors.length];
          return Padding(
            padding: EdgeInsets.only(bottom: index == rows.length - 1 ? 0 : 10),
            child: Row(
              children: [
                if (index < artworkItems.length) ...[
                  WrappedArtwork(
                    item: artworkItems[index],
                    aspectRatio: artworkAspectRatio,
                    size: artworkAspectRatio == 1 ? 52 : 88,
                  ),
                  const SizedBox(width: 10),
                ],
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + startRank}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
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
                      Text(
                        row.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        row.value,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────
class WrappedRankedRecap extends StatelessWidget {
  const WrappedRankedRecap({
    super.key,
    required this.rows,
    required this.artworkItems,
    required this.badge,
    this.artworkAspectRatio = 1,
  });
  final List<RankedRowData> rows;
  final List<MediaItem> artworkItems;
  final String badge;
  final double artworkAspectRatio;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final first = rows.first;
    final image = artworkItems.isEmpty
        ? MediaItem.fromJson({
            'id': first.title,
            'title': first.title,
            'variants': [],
          })
        : artworkItems.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WrappedTrackSpotlight(
          aspectRatio: artworkAspectRatio,
          item: image.copyWith(title: first.title, subtitle: first.subtitle),
          badge: badge,
          caption: first.value,
        ),
        if (rows.length > 1) ...[
          const SizedBox(height: 14),
          CompactRankedRows(
            rows: rows.skip(1).toList(),
            artworkItems: artworkItems.skip(1).toList(),
            startRank: 2,
            artworkAspectRatio: artworkAspectRatio,
          ),
        ],
      ],
    );
  }
}

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
    return Container(
      decoration: wrappedPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              switch (emoji) {
                '📊' => Icons.bar_chart_rounded,
                '🎤' => Icons.mic_rounded,
                '🏆' => Icons.emoji_events_rounded,
                '❤️' => Icons.favorite_rounded,
                '🌍' => Icons.public_rounded,
                '⏭' => Icons.skip_next_rounded,
                '📺' => Icons.video_library_rounded,
                _ => Icons.folder_rounded,
              },
              color: theme.colorScheme.onPrimaryContainer,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
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
          ),
        ],
      ),
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
        ? tr('wrapped.audio.hero_library')
        : stats.topArtists.first.name;

    return Container(
      decoration: wrappedPanelDecoration(context, highlighted: true),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  tr('wrapped.title'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
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
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(
                    '$current',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      tr('wrapped.audio.hero_plays'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Divider(color: theme.colorScheme.outlineVariant),
          if (stats.topTracks.isNotEmpty)
            WrappedCoverStrip(items: stats.topTracks),
          const SizedBox(height: 12),
          Text(
            tr(
              'wrapped.audio.hero_dominant_artist',
              args: [
                topArtist,
                '${stats.topArtists.isEmpty ? 0 : stats.topArtists.first.plays}',
              ],
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
    final ratio = stats.moodCompletionRatio;
    if (ratio >= 0.75) return '🔥';
    if (ratio >= 0.5) return '🎯';
    if (ratio >= 0.25) return '⚡';
    return '💤';
  }

  String get _mood {
    final ratio = stats.moodCompletionRatio;
    if (ratio >= 0.75) return tr('wrapped.audio.mood_faithful');
    if (ratio >= 0.5) return tr('wrapped.audio.mood_melomaniac');
    if (ratio >= 0.25) return tr('wrapped.audio.mood_explorer');
    return tr('wrapped.audio.mood_selective');
  }

  String get _desc {
    final ratio = stats.moodCompletionRatio;
    if (ratio >= 0.75) {
      return tr('wrapped.audio.mood_faithful_desc');
    }
    if (ratio >= 0.5) {
      return tr('wrapped.audio.mood_melomaniac_desc');
    }
    if (ratio >= 0.25) {
      return tr('wrapped.audio.mood_explorer_desc');
    }
    return tr('wrapped.audio.mood_selective_desc');
  }

  Color get _color {
    final ratio = stats.moodCompletionRatio;
    if (ratio >= 0.75) return const Color(0xFFFF6B6B);
    if (ratio >= 0.5) return const Color(0xFF06D6A0);
    if (ratio >= 0.25) return const Color(0xFFFFD166);
    return const Color(0xFF118AB2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: wrappedPanelDecoration(context),
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
                Wrap(
                  children: [
                    Text(
                      tr('wrapped.audio.mood_prefix'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _mood,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _desc,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
                if (stats.moodIncludesEstimates) ...[
                  const SizedBox(height: 4),
                  Text(
                    tr('wrapped.audio.mood_legacy_caption'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
                tr('wrapped.audio.key_metrics'),
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
                  label: tr('wrapped.audio.avg_listened'),
                  value: s.averageProgressPercent / 100,
                  displayText: s.hasAverageCoverage
                      ? '${s.averageProgressPercent}%'
                      : '—',
                  color: kMusicGradient[0],
                  anim: _anim.value,
                ),
                Text(
                  tr(
                    s.hasAverageCoverage
                        ? 'wrapped.audio.coverage_caption'
                        : 'wrapped.audio.coverage_empty',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _ProgressMetric(
                  label: tr('wrapped.audio.listened_rate'),
                  value: s.listenedRate,
                  displayText: s.combinedListened + s.combinedSkips == 0
                      ? '—'
                      : '${(s.listenedRate * 100).round()}%',
                  color: const Color(0xFF06D6A0),
                  anim: _anim.value,
                ),
                Text(
                  tr('wrapped.audio.listened_rate_caption'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _ProgressMetric(
                  label: tr('wrapped.audio.favorite_rate'),
                  value: s.importedAudioItems == 0
                      ? 0
                      : s.favoriteAudioCount / s.importedAudioItems,
                  displayText: s.importedAudioItems == 0
                      ? '—'
                      : '${(s.favoriteAudioCount / s.importedAudioItems * 100).round()}%',
                  color: scheme.primary,
                  anim: _anim.value,
                ),
                Text(
                  tr(
                    'wrapped.audio.favorite_rate_caption',
                    args: [
                      '${s.favoriteAudioCount}',
                      '${s.importedAudioItems}',
                    ],
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _ProgressMetric(
                  label: tr('wrapped.audio.recent_activity_30d'),
                  value: (s.totalPlays == 0)
                      ? 0
                      : (s.recentTracks / max(s.totalPlays, 1))
                            .clamp(0, 1)
                            .toDouble(),
                  displayText: tr(
                    s.recentTracks == 1
                        ? 'common.songs.one'
                        : 'common.songs.other',
                    args: ['${s.recentTracks}'],
                  ),
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
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              displayText,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
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
// Artist recap: featured first place and illustrated remaining rows
// ─────────────────────────────────────────────
class _ArtistRecap extends StatelessWidget {
  const _ArtistRecap({required this.artists});
  final List<ArtistStats> artists;

  @override
  Widget build(BuildContext context) {
    return WrappedRankedRecap(
      badge: tr('wrapped.audio.top_artist_badge'),
      artworkItems: artists
          .map(
            (a) =>
                a.artwork ??
                MediaItem.fromJson({
                  'id': a.name,
                  'title': a.name,
                  'variants': [],
                }),
          )
          .toList(),
      rows: artists
          .map(
            (a) => RankedRowData(
              title: a.name,
              subtitle: tr(
                'wrapped.imports.imported_songs',
                args: ['${a.tracks}'],
              ),
              value: tr('wrapped.ui.play_count', args: ['${a.plays}']),
              maxValue: artists.isEmpty ? 1 : artists.first.plays,
              currentValue: a.plays,
              color: kMusicGradient.first,
            ),
          )
          .toList(),
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
    final plays = ListeningStats.countedPlaysFor(item);
    return WrappedTrackSpotlight(
      item: item,
      badge: tr('wrapped.labels.top_track_badge'),
      caption: tr('wrapped.ui.play_count', args: ['$plays']),
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
    this.artworkItems = const [],
    this.startRank = 1,
    this.artworkAspectRatio = 1,
  });

  final List<RankedRowData> rows;
  final List<MediaItem> artworkItems;
  final int startRank;
  final double artworkAspectRatio;
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
                      if (i < widget.artworkItems.length) ...[
                        WrappedArtwork(
                          item: widget.artworkItems[i],
                          aspectRatio: widget.artworkAspectRatio,
                          size: widget.artworkAspectRatio == 1 ? 52 : 88,
                        ),
                        const SizedBox(width: 10),
                      ],
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + widget.startRank}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: scheme.onSurface,
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
                                    color: scheme.onSurface,
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
    final total = audio + video;

    if (total == 0) return const SizedBox.shrink();

    final sections = [
      _DonutSection('Audio', audio, kMusicGradient[0]),
      _DonutSection('Video', video, kVideoGradient[0]),
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
                        '${months[gIdx].label}\n${tr('wrapped.ui.import_count', args: ['${rod.toY.toInt()}'])}',
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
                              color: scheme.onSurface,
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
                          tr('wrapped.ui.play_count', args: ['${r.plays}']),
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
    final totalSkips = s.observedSkips;
    final totalCompleted = s.observedCompleted;
    final total = totalCompleted + totalSkips;

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatBubble(
                label: tr('wrapped.audio.completed'),
                value: '$totalCompleted',
                color: const Color(0xFF06D6A0),
              ),
              const SizedBox(width: 12),
              StatBubble(
                label: tr('wrapped.audio.skipped'),
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
                final completedRatio = ((totalCompleted / total) * _anim.value)
                    .clamp(0.0, 1.0);
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
                    if (s.observedCompletionSamples > 0)
                      Text(
                        tr(
                          'wrapped.ui.completion_ratio',
                          args: [
                            (s.observedCompleted /
                                    s.observedCompletionSamples *
                                    100)
                                .toStringAsFixed(0),
                          ],
                        ),
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
                color: theme.colorScheme.onSurface,
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
    return Container(
      decoration: wrappedPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

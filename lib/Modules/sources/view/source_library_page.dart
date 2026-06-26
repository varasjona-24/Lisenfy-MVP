import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/models/media_item.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/dialogs/sort_options_sheet.dart';
import '../../../app/ui/widgets/media/app_media_items_view.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/services/audio_service.dart';
import '../../Home/Controller/home_controller.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../controller/sources_controller.dart';
import '../domain/source_origin.dart';
import '../domain/source_theme.dart';
import '../domain/source_theme_topic.dart';
import '../ui/source_collection_card.dart';
import '../ui/source_collection_grid.dart';
import '../ui/source_filter_toolbar.dart';
import '../../../app/utils/media_item_status_helper.dart';

// ============================
// 🧭 PAGE: SOURCE LIBRARY
// ============================
class SourceLibraryPage extends StatefulWidget {
  const SourceLibraryPage({
    super.key,
    this.origin,
    this.origins,
    this.onlyOffline = false,
    this.forceKind,
    this.themeId,
    required this.title,
  });

  final SourceOrigin? origin;
  final List<SourceOrigin>? origins;
  final bool onlyOffline;
  final MediaVariantKind? forceKind;
  final String? themeId;
  final String title;

  @override
  State<SourceLibraryPage> createState() => _SourceLibraryPageState();
}

class _SourceLibraryPageState extends State<SourceLibraryPage> {
  final SourcesController _sources = Get.find<SourcesController>();
  final MediaActionsController _actions = Get.find<MediaActionsController>();
  final GetStorage _storage = GetStorage();
  final TextEditingController _topicSearchController = TextEditingController();
  bool _gridView = false;
  bool _topicsGridView = false;
  String _topicQuery = '';
  _TopicSort _topicSort = _TopicSort.recent;
  Future<List<MediaItem>>? _itemsFuture;
  HomeMode? _itemsFutureMode;

  @override
  void initState() {
    super.initState();
    _topicSort = _readTopicSort();
    _topicsGridView = _storage.read('source_library_topics_grid_view') ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !Get.isRegistered<AudioService>()) return;
      Get.find<AudioService>().pauseAndHideMiniPlayer();
    });
  }

  @override
  void dispose() {
    _topicSearchController.dispose();
    super.dispose();
  }

  // ============================
  // 📚 DATA
  // ============================
  Future<List<MediaItem>> _load([HomeMode? mode]) async {
    if (widget.forceKind != null) {
      return _sources.loadLibraryItems(
        onlyOffline: widget.onlyOffline,
        origin: widget.origin,
        origins: widget.origins,
        forceKind: widget.forceKind,
      );
    }

    final modeKind = mode == null
        ? null
        : (mode == HomeMode.audio
              ? MediaVariantKind.audio
              : MediaVariantKind.video);

    return _sources.loadLibraryItems(
      onlyOffline: widget.onlyOffline,
      origin: widget.origin,
      origins: widget.origins,
      modeKind: modeKind,
    );
  }

  Future<List<MediaItem>> _itemsFutureFor(HomeMode mode) {
    final cached = _itemsFuture;
    if (cached != null && _itemsFutureMode == mode) return cached;
    _itemsFutureMode = mode;
    _itemsFuture = _load(mode);
    return _itemsFuture!;
  }

  Future<void> _refreshItems(HomeMode mode) async {
    await _sources.refreshAll();
    _itemsFutureMode = mode;
    _itemsFuture = _load(mode);
    await _itemsFuture;
  }

  // ============================
  // 🧱 UI
  // ============================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final HomeController home = Get.find<HomeController>();
    SourceTheme? themeMeta;
    if (widget.themeId != null) {
      for (final t in _sources.themes) {
        if (t.id == widget.themeId) {
          themeMeta = t;
          break;
        }
      }
    }

    return Obx(() {
      final homeMode = home.mode.value;
      // Biblioteca offline: siempre en modo video
      final displayMode = widget.onlyOffline
          ? HomeMode.video
          : (widget.forceKind == MediaVariantKind.audio
                ? HomeMode.audio
                : (widget.forceKind == MediaVariantKind.video
                      ? HomeMode.video
                      : homeMode));

      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppTopBar(
          leading: IconButton(
            tooltip: tr('sources.back'),
            onPressed: Get.back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: widget.onlyOffline
              ? ListenfyLogo(size: 28, color: scheme.primary)
              : Text(widget.title),
          // Sin toggle cuando es offline (solo video) o forceKind fijo
          onToggleMode: (widget.onlyOffline || widget.forceKind != null)
              ? null
              : home.toggleMode,
          showLocalConnectAction: false,
          mode: displayMode == HomeMode.audio
              ? AppMediaMode.audio
              : AppMediaMode.video,
        ),
        body: AppGradientBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: FutureBuilder<List<MediaItem>>(
                  future: _itemsFutureFor(displayMode),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final list = snap.data ?? const <MediaItem>[];

                    bool hasAudio(MediaItem e) =>
                        e.variants.any((v) => v.kind == MediaVariantKind.audio);
                    bool hasVideo(MediaItem e) =>
                        e.variants.any((v) => v.kind == MediaVariantKind.video);

                    final modeList = widget.forceKind != null
                        ? list
                        : (displayMode == HomeMode.audio
                              ? list.where(hasAudio).toList()
                              : list.where(hasVideo).toList());

                    return RefreshIndicator(
                      onRefresh: () async {
                        await _refreshItems(displayMode);
                        if (mounted) setState(() {});
                      },
                      child: ScrollConfiguration(
                        behavior: const _NoGlowScrollBehavior(),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(
                            top: 12,
                            bottom: kBottomNavigationBarHeight + 18,
                            left: 12,
                            right: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.onlyOffline) ...[
                                _offlineHeader(theme),
                                const SizedBox(height: 10),
                                _offlineSummary(
                                  theme,
                                  modeList.length,
                                  displayMode,
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              if (themeMeta != null &&
                                  themeMeta.onlyOffline != true) ...[
                                _topicHeader(themeMeta),
                                const SizedBox(height: 8),
                                _topicList(themeMeta),
                                const SizedBox(height: 18),
                              ],
                              if (themeMeta == null ||
                                  themeMeta.onlyOffline == true) ...[
                                if (!widget.onlyOffline) ...[
                                  _librarySummary(
                                    theme,
                                    modeList.length,
                                    displayMode,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (modeList.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      tr('sources.empty_content'),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  )
                                else
                                  AppMediaItemsList(
                                    items: modeList,
                                    gridView: _gridView,
                                    videoStyle: displayMode == HomeMode.video,
                                    compactListCard: widget.onlyOffline,
                                    onTap: (item, index) => _playSourceItem(
                                      item,
                                      modeList,
                                      displayMode,
                                    ),
                                    onLongPress: (item, index) =>
                                        _openGridItemActions(
                                          item,
                                          modeList,
                                          displayMode,
                                        ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // NAV
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomNav(
                  currentIndex: 4,
                  onTap: (index) {
                    switch (index) {
                      case 0:
                        home.enterHome();
                        break;
                      case 1:
                        home.goToPlaylists();
                        break;
                      case 2:
                        home.goToArtists();
                        break;
                      case 3:
                        home.goToDownloads();
                        break;
                      case 4:
                        home.goToSources();
                        break;
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _openGridItemActions(
    MediaItem item,
    List<MediaItem> queue,
    HomeMode mode,
  ) {
    return _actions.showItemActions(
      context,
      item,
      onChanged: () async {
        await _sources.refreshAll();
        if (mounted) setState(() {});
      },
      onStartMultiSelect: () {
        Get.toNamed(
          AppRoutes.homeSectionList,
          arguments: {
            'title': widget.title,
            'items': queue,
            'onItemTap': (MediaItem tapped, int index) {
              _playSourceItem(tapped, queue, mode);
            },
            'onItemLongPress':
                (MediaItem target, int _, {VoidCallback? onStartMultiSelect}) =>
                    _actions.showItemActions(
                      context,
                      target,
                      onChanged: () async {
                        await _sources.refreshAll();
                        if (mounted) setState(() {});
                      },
                      onStartMultiSelect: onStartMultiSelect,
                    ),
            'onDeleteSelected': (List<MediaItem> selected) async {
              await _actions.confirmDeleteMultiple(
                context,
                selected,
                onChanged: () async {
                  await _sources.refreshAll();
                  if (mounted) setState(() {});
                },
              );
            },
            'startInSelectionMode': true,
            'initialSelectionItemId': item.id,
          },
        );
      },
    );
  }

  void _playSourceItem(MediaItem item, List<MediaItem> queue, HomeMode mode) {
    final idx = queue.indexWhere((e) => e.id == item.id);
    final safeIdx = idx == -1 ? 0 : idx;
    final variant = _variantForMode(item, mode);
    final route = mode == HomeMode.audio
        ? AppRoutes.audioPlayer
        : AppRoutes.videoPlayer;

    Get.toNamed(
      route,
      arguments: {
        'queue': queue,
        'index': safeIdx,
        if (variant?.playableUrl.isNotEmpty == true)
          'playableUrl': variant!.playableUrl,
      },
    );
  }

  MediaVariant? _variantForMode(MediaItem item, HomeMode mode) {
    return mode == HomeMode.audio
        ? item.localAudioVariant
        : item.localVideoVariant;
  }

  Widget _offlineHeader(ThemeData theme) {
    return Text(
      'Biblioteca offline',
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _offlineSummary(ThemeData theme, int total, HomeMode mode) {
    return _librarySummary(theme, total, mode);
  }

  Widget _librarySummary(ThemeData theme, int total, HomeMode mode) {
    final label = mode == HomeMode.audio ? 'audio' : 'video';
    return Row(
      children: [
        Expanded(
          child: Text(
            '$total elementos de $label',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: _gridView
              ? tr('home.section.list_view')
              : tr('home.section.grid_view'),
          onPressed: () => setState(() => _gridView = !_gridView),
          icon: Icon(
            _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
          ),
        ),
      ],
    );
  }

  Widget _topicHeader(SourceTheme themeMeta) {
    final limitReached = _sources.topicsForTheme(themeMeta.id).length >= 10;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Collections',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Obx(() {
              final count = _sources.topicsForTheme(themeMeta.id).length;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count/10',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }),
            const Spacer(),
            IconButton.filledTonal(
              tooltip: tr('sources.new_collection'),
              icon: const Icon(Icons.create_new_folder_rounded),
              onPressed: () {
                if (limitReached) {
                  Get.snackbar(
                    tr('sources.collection'),
                    tr('sources.collection_limit'),
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }
                _openCreateTopic(themeMeta);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        SourceFilterToolbar(
          controller: _topicSearchController,
          query: _topicQuery,
          hintText: tr('sources.search_collection'),
          onQueryChanged: (value) => setState(() => _topicQuery = value),
          onClearQuery: () {
            _topicSearchController.clear();
            setState(() => _topicQuery = '');
          },
          onSort: _openTopicSortSheet,
          gridView: _topicsGridView,
          onToggleGridView: () {
            setState(() => _topicsGridView = !_topicsGridView);
            _storage.write('source_library_topics_grid_view', _topicsGridView);
          },
          gridTooltip: tr('sources.view_grid'),
          listTooltip: tr('sources.view_list'),
        ),
      ],
    );
  }

  _TopicSort _readTopicSort() {
    final raw = (_storage.read('source_library_collection_sort') as String?)
        ?.trim();
    for (final option in _TopicSort.values) {
      if (option.name == raw) return option;
    }
    return _TopicSort.recent;
  }

  Future<void> _openTopicSortSheet() async {
    await showSortOptionsSheet(
      context: context,
      title: tr('sources.sort_collections'),
      optionsBuilder: () => [
        SortSheetOption(
          label: tr('sources.recent_first'),
          selected: _topicSort == _TopicSort.recent,
          onTap: () {
            setState(() => _topicSort = _TopicSort.recent);
            _storage.write('source_library_collection_sort', _topicSort.name);
          },
        ),
        SortSheetOption(
          label: tr('sources.name'),
          selected: _topicSort == _TopicSort.name,
          onTap: () {
            setState(() => _topicSort = _TopicSort.name);
            _storage.write('source_library_collection_sort', _topicSort.name);
          },
        ),
        SortSheetOption(
          label: tr('sources.more_items'),
          selected: _topicSort == _TopicSort.items,
          onTap: () {
            setState(() => _topicSort = _TopicSort.items);
            _storage.write('source_library_collection_sort', _topicSort.name);
          },
        ),
        SortSheetOption(
          label: tr('sources.more_collections'),
          selected: _topicSort == _TopicSort.lists,
          onTap: () {
            setState(() => _topicSort = _TopicSort.lists);
            _storage.write('source_library_collection_sort', _topicSort.name);
          },
        ),
      ],
      onOpened: _markOverlayOpen,
      onClosed: _markOverlayClosed,
    );
  }

  void _markOverlayOpen() {
    if (Get.isRegistered<NavigationController>()) {
      Get.find<NavigationController>().setOverlayOpen(true);
    }
  }

  void _markOverlayClosed() {
    if (Get.isRegistered<NavigationController>()) {
      Get.find<NavigationController>().setOverlayOpen(false);
    }
  }

  Widget _topicList(SourceTheme themeMeta) {
    return Obx(() {
      final allTopics = _sources.topicsForTheme(themeMeta.id);
      final query = _topicQuery.trim().toLowerCase();
      final topics = allTopics.where((topic) {
        if (query.isEmpty) return true;
        return topic.title.toLowerCase().contains(query);
      }).toList();
      topics.sort((a, b) {
        switch (_topicSort) {
          case _TopicSort.name:
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          case _TopicSort.items:
            return b.itemIds.length.compareTo(a.itemIds.length);
          case _TopicSort.lists:
            return _sources
                .playlistsForTopic(b.id)
                .length
                .compareTo(_sources.playlistsForTopic(a.id).length);
          case _TopicSort.recent:
            return b.createdAt.compareTo(a.createdAt);
        }
      });
      if (topics.isEmpty) {
        final emptyText = allTopics.isEmpty
            ? tr('sources.create_collection_first')
            : tr('sources.no_items_found');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            emptyText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }

      if (_topicsGridView) {
        return SourceCollectionGrid(
          itemCount: topics.length,
          itemBuilder: (context, index) {
            final topic = topics[index];
            return _topicCard(themeMeta, topic, gridStyle: true);
          },
        );
      }

      return Column(
        children: [
          for (final topic in topics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _topicCard(themeMeta, topic),
            ),
        ],
      );
    });
  }

  Widget _topicCard(
    SourceTheme themeMeta,
    SourceThemeTopic topic, {
    bool gridStyle = false,
  }) {
    final progress = CollectionProgressHelper.getProgress(topic.itemIds);
    final completedCount = progress.$1;

    return SourceCollectionCard(
      name: topic.title,
      itemCount: topic.itemIds.length,
      childCollectionCount: _sources.playlistsForTopic(topic.id).length,
      baseColor: topic.colorValue != null
          ? Color(topic.colorValue!)
          : themeMeta.colors.first,
      coverLocalPath: topic.coverLocalPath,
      coverUrl: topic.coverUrl,
      gridStyle: gridStyle,
      onOpen: () => Get.toNamed(
        AppRoutes.sourceTheme,
        arguments: {
          'topicId': topic.id,
          'theme': themeMeta,
          'origins': widget.origins,
        },
      ),
      onEdit: () => _openEditTopic(topic),
      onDelete: () => _confirmDeleteTopic(topic),
      completedCount: completedCount,
    );
  }

  // ============================
  // 🪄 DIALOGOS
  // ============================
  Future<void> _openCreateTopic(SourceTheme themeMeta) async {
    await Get.toNamed(
      AppRoutes.createEntity,
      preventDuplicates: false,
      arguments: CreateEntityArgs.topic(
        storageId: 'stt_${themeMeta.id}_create',
        themeId: themeMeta.id,
      ),
    );
  }

  Future<void> _openEditTopic(SourceThemeTopic topic) async {
    await Get.toNamed(
      AppRoutes.editEntity,
      arguments: EditEntityArgs.topic(topic),
    );
  }

  Future<void> _confirmDeleteTopic(SourceThemeTopic topic) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('sources.delete_collection')),
        content: Text(
          tr('sources.delete_collection_body', args: [topic.title]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('common.cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('common.delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _sources.deleteTopic(topic);
    }
  }
}

enum _TopicSort { recent, name, items, lists }

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/models/media_item.dart';
import '../../../app/services/audio_service.dart';
import '../../../app/ui/widgets/dialogs/sort_options_sheet.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/media/app_media_items_view.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/routes/app_routes.dart';
import '../../home/controller/home_controller.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../controller/sources_controller.dart';
import '../domain/source_origin.dart';
import '../domain/source_theme.dart';
import '../domain/source_theme_topic.dart';
import '../domain/source_theme_topic_playlist.dart';
import '../ui/source_add_items_sheet.dart';
import '../ui/source_collection_grid.dart';
import '../ui/source_filter_toolbar.dart';
import '../ui/source_playlist_card.dart';
import '../../../app/utils/format_bytes.dart';

// ============================
// 🧭 PAGE: TOPIC
// ============================
class SourceThemeTopicPage extends StatefulWidget {
  const SourceThemeTopicPage({
    super.key,
    required this.topicId,
    required this.theme,
    required this.origins,
  });

  final String topicId;
  final SourceTheme theme;
  final List<SourceOrigin>? origins;

  @override
  State<SourceThemeTopicPage> createState() => _SourceThemeTopicPageState();
}

class _SourceThemeTopicPageState extends State<SourceThemeTopicPage> {
  // ============================
  // 🔌 DEPENDENCIAS
  // ============================
  final SourcesController _sources = Get.find<SourcesController>();
  final MediaActionsController _actions = Get.find<MediaActionsController>();
  final GetStorage _storage = GetStorage();
  final TextEditingController _itemSearchController = TextEditingController();
  final TextEditingController _listSearchController = TextEditingController();
  String? _topicSizeLabel;
  String _itemQuery = '';
  String _listQuery = '';
  _SourceItemSort _itemSort = _SourceItemSort.recent;
  _SourceListSort _listSort = _SourceListSort.recent;
  bool _itemsGridView = false;
  bool _collectionsGridView = false;

  @override
  void initState() {
    super.initState();
    _itemSort = _readItemSort();
    _listSort = _readListSort();
    _itemsGridView = _storage.read('source_topic_items_grid_view') ?? false;
    _collectionsGridView =
        _storage.read('source_topic_collections_grid_view') ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !Get.isRegistered<AudioService>()) return;
      Get.find<AudioService>().pauseAndHideMiniPlayer();
    });
  }

  @override
  void dispose() {
    _itemSearchController.dispose();
    _listSearchController.dispose();
    super.dispose();
  }

  SourceThemeTopic? get _topic {
    for (final t in _sources.topics) {
      if (t.id == widget.topicId) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // ============================
    // 🧱 UI
    // ============================
    final theme = Theme.of(context);

    return Obx(() {
      final topic = _topic;
      if (topic == null) {
        return const Scaffold(
          body: Center(child: Text('Collection no encontrada')),
        );
      }
      final lists = _sources.playlistsForTopic(topic.id);

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: Get.back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(topic.title),
          onToggleMode: null,
          showLocalConnectAction: false,
        ),
        body: AppGradientBackground(
          child: RefreshIndicator(
            onRefresh: () async {
              await _sources.refreshAll();
              if (mounted) setState(() {});
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(topic, theme, lists.length),
                        const SizedBox(height: 14),
                        _actionRow(topic),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
                _itemsSection(topic),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    18,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _playlistsSection(topic, lists),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _header(SourceThemeTopic topic, ThemeData theme, int listCount) {
    final scheme = theme.colorScheme;
    final cover = topic.coverLocalPath?.trim().isNotEmpty == true
        ? topic.coverLocalPath
        : topic.coverUrl;
    ImageProvider? provider;
    if (cover != null && cover.isNotEmpty) {
      provider = cover.startsWith('http')
          ? NetworkImage(cover)
          : FileImage(File(cover));
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 72,
            height: 72,
            color: scheme.surfaceContainerHighest,
            child: provider != null
                ? Image(image: provider, fit: BoxFit.cover)
                : Icon(Icons.folder_rounded, color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _buildTopicMetaLine(topic, listCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _buildTopicMetaLine(SourceThemeTopic topic, int listCount) {
    final base = '${topic.itemIds.length} items · $listCount Collections';
    if (_topicSizeLabel == null || _topicSizeLabel!.isEmpty) return base;
    return '$base · ${_topicSizeLabel!}';
  }

  Widget _actionRow(SourceThemeTopic topic) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _addItems(topic),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Items'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _addTopicPlaylist(topic),
            icon: const Icon(Icons.playlist_add_rounded),
            label: const Text('Collection'),
          ),
        ),
      ],
    );
  }

  Widget _itemsSection(SourceThemeTopic topic) {
    // ============================
    // 📚 DATA: ITEMS
    // ============================
    return FutureBuilder<List<MediaItem>>(
      future: _loadItems(topic),
      builder: (context, snap) {
        final items = snap.data ?? const <MediaItem>[];
        final nextSize = _formatSizeLabel(items);
        if (nextSize != _topicSizeLabel) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _topicSizeLabel = nextSize);
          });
        }
        if (items.isEmpty) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverToBoxAdapter(
              child: Text(
                'No hay items todavía.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        final filtered = _filteredTopicItems(items);
        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _itemsToolbar(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'No hay items con ese título.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else if (_itemsGridView)
              AppMediaItemsSliver(
                items: filtered,
                gridView: true,
                videoStyle: true,
                onTap: (item, index) => _playItem(filtered, item),
                onLongPress: (item, index) => _showItemActions(topic, item),
              )
            else
              AppMediaItemsSliver(
                items: filtered,
                gridView: false,
                videoStyle: true,
                onTap: (item, index) => _playItem(filtered, item),
                onLongPress: (item, index) => _showItemActions(topic, item),
              ),
          ],
        );
      },
    );
  }

  List<MediaItem> _filteredTopicItems(List<MediaItem> items) {
    final query = _itemQuery.trim().toLowerCase();
    final filtered = items.where((item) {
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query);
    }).toList();
    filtered.sort((a, b) {
      switch (_itemSort) {
        case _SourceItemSort.recent:
          return _createdAtForItem(b).compareTo(_createdAtForItem(a));
        case _SourceItemSort.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case _SourceItemSort.size:
          return _sizeForItem(b).compareTo(_sizeForItem(a));
        case _SourceItemSort.duration:
          return _durationForItem(b).compareTo(_durationForItem(a));
      }
    });
    return filtered;
  }

  int _createdAtForItem(MediaItem item) {
    final variant = item.localVideoVariant ?? item.localAudioVariant;
    return variant?.createdAt ?? 0;
  }

  int _sizeForItem(MediaItem item) {
    final variant = item.localVideoVariant ?? item.localAudioVariant;
    return variant?.size ?? 0;
  }

  int _durationForItem(MediaItem item) {
    final variant = item.localVideoVariant ?? item.localAudioVariant;
    return variant?.durationSeconds ?? item.durationSeconds ?? 0;
  }

  String? _formatSizeLabel(List<MediaItem> items) {
    var total = 0;
    for (final item in items) {
      final v = item.localAudioVariant ?? item.localVideoVariant;
      final size = v?.size ?? 0;
      if (size > 0) total += size;
    }
    if (total <= 0) return null;
    return formatBytes(total);
  }

  Widget _playlistsSection(
    SourceThemeTopic topic,
    List<SourceThemeTopicPlaylist> list,
  ) {
    // ============================
    // 📚 DATA: PLAYLISTS
    // ============================
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _listQuery.trim().toLowerCase();
    final filtered = list.where((playlist) {
      if (query.isEmpty) return true;
      return playlist.name.toLowerCase().contains(query);
    }).toList();
    filtered.sort((a, b) {
      switch (_listSort) {
        case _SourceListSort.recent:
          return b.createdAt.compareTo(a.createdAt);
        case _SourceListSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SourceListSort.items:
          return b.itemIds.length.compareTo(a.itemIds.length);
        case _SourceListSort.subfolders:
          return _sources
              .playlistsForTopic(topic.id, parentId: b.id)
              .length
              .compareTo(
                _sources.playlistsForTopic(topic.id, parentId: a.id).length,
              );
      }
    });

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${list.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (list.isNotEmpty) _listToolbar(),
        if (list.isNotEmpty) const SizedBox(height: 10),
        if (filtered.isEmpty)
          Text(
            list.isEmpty
                ? 'No hay Collections aún.'
                : 'No hay Collections con ese nombre.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else if (_collectionsGridView)
          SourceCollectionGrid(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final pl = filtered[index];
              return _collectionCard(topic.id, pl, gridStyle: true);
            },
          )
        else
          ...filtered.map(
            (pl) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _collectionCard(topic.id, pl),
            ),
          ),
      ],
    );
  }

  Widget _collectionCard(
    String topicId,
    SourceThemeTopicPlaylist playlist, {
    bool gridStyle = false,
  }) {
    return SourcePlaylistCard(
      theme: widget.theme,
      playlist: playlist,
      gridStyle: gridStyle,
      childListCount: _sources
          .playlistsForTopic(topicId, parentId: playlist.id)
          .length,
      onOpen: () => Get.toNamed(
        AppRoutes.sourcePlaylist,
        preventDuplicates: false,
        arguments: {
          'playlistId': playlist.id,
          'theme': widget.theme,
          'origins': widget.origins,
        },
      ),
      onEdit: () => _openEditPlaylist(playlist),
      onDelete: () => _sources.deleteTopicPlaylist(playlist),
    );
  }

  Widget _listToolbar() {
    return SourceFilterToolbar(
      controller: _listSearchController,
      query: _listQuery,
      hintText: 'Buscar Collection',
      onQueryChanged: (value) => setState(() => _listQuery = value),
      onClearQuery: () {
        _listSearchController.clear();
        setState(() => _listQuery = '');
      },
      onSort: _openCollectionSortSheet,
      gridView: _collectionsGridView,
      onToggleGridView: () {
        setState(() => _collectionsGridView = !_collectionsGridView);
        _storage.write(
          'source_topic_collections_grid_view',
          _collectionsGridView,
        );
      },
      gridTooltip: 'Ver Collections como grid',
      listTooltip: 'Ver Collections como lista',
    );
  }

  Widget _itemsToolbar() {
    return SourceFilterToolbar(
      controller: _itemSearchController,
      query: _itemQuery,
      hintText: 'Buscar item',
      onQueryChanged: (value) => setState(() => _itemQuery = value),
      onClearQuery: () {
        _itemSearchController.clear();
        setState(() => _itemQuery = '');
      },
      onSort: _openItemSortSheet,
      gridView: _itemsGridView,
      onToggleGridView: () {
        setState(() => _itemsGridView = !_itemsGridView);
        _storage.write('source_topic_items_grid_view', _itemsGridView);
      },
      gridTooltip: 'Ver items como grid',
      listTooltip: 'Ver items como lista',
    );
  }

  Future<void> _openItemSortSheet() async {
    await showSortOptionsSheet(
      context: context,
      title: 'Ordenar items',
      optionsBuilder: () => [
        SortSheetOption(
          label: 'Recientes primero',
          selected: _itemSort == _SourceItemSort.recent,
          onTap: () {
            setState(() => _itemSort = _SourceItemSort.recent);
            _storage.write('source_topic_item_sort', _itemSort.name);
          },
        ),
        SortSheetOption(
          label: 'Nombre',
          selected: _itemSort == _SourceItemSort.title,
          onTap: () {
            setState(() => _itemSort = _SourceItemSort.title);
            _storage.write('source_topic_item_sort', _itemSort.name);
          },
        ),
        SortSheetOption(
          label: 'Tamaño',
          selected: _itemSort == _SourceItemSort.size,
          onTap: () {
            setState(() => _itemSort = _SourceItemSort.size);
            _storage.write('source_topic_item_sort', _itemSort.name);
          },
        ),
        SortSheetOption(
          label: 'Duración',
          selected: _itemSort == _SourceItemSort.duration,
          onTap: () {
            setState(() => _itemSort = _SourceItemSort.duration);
            _storage.write('source_topic_item_sort', _itemSort.name);
          },
        ),
      ],
      onOpened: _markOverlayOpen,
      onClosed: _markOverlayClosed,
    );
  }

  Future<void> _openCollectionSortSheet() async {
    await showSortOptionsSheet(
      context: context,
      title: 'Ordenar Collections',
      optionsBuilder: () => [
        SortSheetOption(
          label: 'Recientes primero',
          selected: _listSort == _SourceListSort.recent,
          onTap: () {
            setState(() => _listSort = _SourceListSort.recent);
            _storage.write('source_topic_collection_sort', _listSort.name);
          },
        ),
        SortSheetOption(
          label: 'Nombre',
          selected: _listSort == _SourceListSort.name,
          onTap: () {
            setState(() => _listSort = _SourceListSort.name);
            _storage.write('source_topic_collection_sort', _listSort.name);
          },
        ),
        SortSheetOption(
          label: 'Más items',
          selected: _listSort == _SourceListSort.items,
          onTap: () {
            setState(() => _listSort = _SourceListSort.items);
            _storage.write('source_topic_collection_sort', _listSort.name);
          },
        ),
        SortSheetOption(
          label: 'Más Collections',
          selected: _listSort == _SourceListSort.subfolders,
          onTap: () {
            setState(() => _listSort = _SourceListSort.subfolders);
            _storage.write('source_topic_collection_sort', _listSort.name);
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

  _SourceItemSort _readItemSort() {
    final raw = (_storage.read('source_topic_item_sort') as String?)?.trim();
    for (final option in _SourceItemSort.values) {
      if (option.name == raw) return option;
    }
    return _SourceItemSort.recent;
  }

  _SourceListSort _readListSort() {
    final raw = (_storage.read('source_topic_collection_sort') as String?)
        ?.trim();
    for (final option in _SourceListSort.values) {
      if (option.name == raw) return option;
    }
    return _SourceListSort.recent;
  }

  Future<List<MediaItem>> _loadItems(SourceThemeTopic topic) async {
    // ============================
    // 📚 DATA: CARGA
    // ============================
    return _sources.loadTopicItems(
      theme: widget.theme,
      topic: topic,
      origins: widget.origins,
    );
  }

  Future<void> _addItems(SourceThemeTopic topic) async {
    final list = await _candidateItems();
    if (!mounted) return;
    final sheetColor = Theme.of(context).colorScheme.surface;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: sheetColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SourceAddItemsSheet(
        items: list,
        keyForItem: _sources.keyForItem,
        onAdd: (selected) => _sources.addItemsToTopic(topic, selected),
      ),
    );
  }

  Future<void> _addTopicPlaylist(SourceThemeTopic topic) async {
    await Get.toNamed(
      AppRoutes.createEntity,
      preventDuplicates: false,
      arguments: CreateEntityArgs.topicPlaylist(
        storageId: 'stpl_${topic.id}_create',
        topicId: topic.id,
        depth: 1,
      ),
    );
  }

  void _playItem(List<MediaItem> list, MediaItem item) {
    final home = Get.find<HomeController>();
    final idx = list.indexWhere((e) => e.id == item.id);
    final safeIdx = idx == -1 ? 0 : idx;

    if (item.hasVideoLocal && !item.hasAudioLocal) {
      home.mode.value = HomeMode.video;
    } else if (item.hasAudioLocal && !item.hasVideoLocal) {
      home.mode.value = HomeMode.audio;
    }

    home.openMedia(item, safeIdx, list);
  }

  Future<List<MediaItem>> _candidateItems() async {
    return _sources.loadCandidateItems(
      theme: widget.theme,
      origins: widget.origins,
    );
  }

  Future<void> _showItemActions(SourceThemeTopic topic, MediaItem item) async {
    final nav = Get.isRegistered<NavigationController>()
        ? Get.find<NavigationController>()
        : null;
    nav?.setOverlayOpen(true);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Editar'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _actions.openEditPage(item);
                  if (mounted) setState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Quitar de la lista'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _sources.removeItemFromTopic(topic, item);
                },
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => nav?.setOverlayOpen(false));
  }

  Future<void> _openEditPlaylist(SourceThemeTopicPlaylist playlist) async {
    await Get.toNamed(
      AppRoutes.editEntity,
      arguments: EditEntityArgs.topicPlaylist(playlist),
    );
  }
}

enum _SourceItemSort { recent, title, size, duration }

enum _SourceListSort { recent, name, items, subfolders }

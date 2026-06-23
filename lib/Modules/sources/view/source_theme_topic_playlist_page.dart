import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/models/media_item.dart';
import '../../../app/services/audio_service.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/dialogs/sort_options_sheet.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/media/app_media_items_view.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/routes/app_routes.dart';
import '../../Home/Controller/home_controller.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../controller/sources_controller.dart';
import '../domain/source_origin.dart';
import '../domain/source_theme.dart';
import '../domain/source_theme_topic_playlist.dart';
import '../ui/source_add_items_sheet.dart';
import '../ui/source_collection_grid.dart';
import '../ui/source_filter_toolbar.dart';
import '../ui/source_playlist_card.dart';
import '../../../app/utils/format_bytes.dart';
import '../../../app/utils/media_item_status_helper.dart';

/// UI-only: Fuente / Theme Topic Playlist Page
/// Nota: este archivo asume que `ImageSearchDialog` ahora devuelve `String` (url)
/// usando: `Navigator.pop(context, url)`
class SourceThemeTopicPlaylistPage extends StatefulWidget {
  const SourceThemeTopicPlaylistPage({
    super.key,
    required this.playlistId,
    required this.theme,
    required this.origins,
  });

  final String playlistId;
  final SourceTheme theme;
  final List<SourceOrigin>? origins;

  @override
  State<SourceThemeTopicPlaylistPage> createState() =>
      _SourceThemeTopicPlaylistPageState();
}

class _SourceThemeTopicPlaylistPageState
    extends State<SourceThemeTopicPlaylistPage> {
  // ============================
  // 🔌 DEPENDENCIAS
  // ============================
  final SourcesController _sources = Get.find<SourcesController>();
  final MediaActionsController _actions = Get.find<MediaActionsController>();
  final GetStorage _storage = GetStorage();
  final TextEditingController _itemSearchController = TextEditingController();
  final TextEditingController _subListSearchController =
      TextEditingController();

  String? _playlistSizeLabel;
  String _itemQuery = '';
  String _subListQuery = '';
  _SourcePlaylistItemSort _itemSort = _SourcePlaylistItemSort.recent;
  _SourceSubListSort _subListSort = _SourceSubListSort.recent;
  bool _itemsGridView = false;
  bool _collectionsGridView = false;

  @override
  void initState() {
    super.initState();
    _itemSort = _readItemSort();
    _subListSort = _readSubListSort();
    _itemsGridView = _storage.read('source_playlist_items_grid_view') ?? false;
    _collectionsGridView =
        _storage.read('source_playlist_collections_grid_view') ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !Get.isRegistered<AudioService>()) return;
      Get.find<AudioService>().pauseAndHideMiniPlayer();
    });
  }

  @override
  void dispose() {
    _itemSearchController.dispose();
    _subListSearchController.dispose();
    super.dispose();
  }

  SourceThemeTopicPlaylist? get _playlist {
    for (final p in _sources.topicPlaylists) {
      if (p.id == widget.playlistId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final playlist = _playlist;
      if (playlist == null) {
        return const Scaffold(
          body: Center(child: Text('Collection no encontrada')),
        );
      }

      final children = _sources.playlistsForTopic(
        playlist.topicId,
        parentId: playlist.id,
      );

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: Get.back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(playlist.name),
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
                        Text(
                          _buildMetaLine(
                            playlist.itemIds.length,
                            children.length,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _actionRow(playlist),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
                _itemsSection(playlist),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    18,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _subListsSection(playlist, children),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ============================
  // 🧱 UI SECTIONS
  // ============================
  Widget _actionRow(SourceThemeTopicPlaylist playlist) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _addItems(playlist),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Items'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _addSubList(playlist),
            icon: const Icon(Icons.create_new_folder_rounded),
            label: const Text('Collection'),
          ),
        ),
      ],
    );
  }

  Widget _itemsSection(SourceThemeTopicPlaylist playlist) {
    return FutureBuilder<List<MediaItem>>(
      future: _loadItems(playlist),
      builder: (context, snap) {
        final items = snap.data ?? const <MediaItem>[];
        final nextSize = _formatSizeLabel(items);
        if (nextSize != _playlistSizeLabel) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _playlistSizeLabel = nextSize);
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
        final filtered = _filteredItems(items);

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
                onLongPress: (item, index) => _showItemActions(playlist, item),
              )
            else
              AppMediaItemsSliver(
                items: filtered,
                gridView: false,
                videoStyle: true,
                onTap: (item, index) => _playItem(filtered, item),
                onLongPress: (item, index) => _showItemActions(playlist, item),
              ),
          ],
        );
      },
    );
  }

  List<MediaItem> _filteredItems(List<MediaItem> items) {
    final query = _itemQuery.trim().toLowerCase();
    final filtered = items.where((item) {
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query);
    }).toList();
    filtered.sort((a, b) {
      switch (_itemSort) {
        case _SourcePlaylistItemSort.recent:
          return _createdAtForItem(b).compareTo(_createdAtForItem(a));
        case _SourcePlaylistItemSort.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case _SourcePlaylistItemSort.size:
          return _sizeForItem(b).compareTo(_sizeForItem(a));
        case _SourcePlaylistItemSort.duration:
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

  Widget _subListsSection(
    SourceThemeTopicPlaylist playlist,
    List<SourceThemeTopicPlaylist> lists,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _subListQuery.trim().toLowerCase();
    final filtered = lists.where((entry) {
      if (query.isEmpty) return true;
      return entry.name.toLowerCase().contains(query);
    }).toList();
    filtered.sort((a, b) {
      switch (_subListSort) {
        case _SourceSubListSort.recent:
          return b.createdAt.compareTo(a.createdAt);
        case _SourceSubListSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SourceSubListSort.items:
          return b.itemIds.length.compareTo(a.itemIds.length);
        case _SourceSubListSort.subfolders:
          return _sources
              .playlistsForTopic(playlist.topicId, parentId: b.id)
              .length
              .compareTo(
                _sources
                    .playlistsForTopic(playlist.topicId, parentId: a.id)
                    .length,
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
                '${lists.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (lists.isNotEmpty) _subListToolbar(),
        if (lists.isNotEmpty) const SizedBox(height: 10),
        if (filtered.isEmpty)
          Text(
            lists.isEmpty
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
              return _collectionCard(playlist.topicId, pl, gridStyle: true);
            },
          )
        else
          ...filtered.map(
            (pl) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _collectionCard(playlist.topicId, pl),
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
    final progress = CollectionProgressHelper.getProgress(playlist.itemIds);
    final completedCount = progress.$1;

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
      completedCount: completedCount,
    );
  }

  Widget _subListToolbar() {
    return SourceFilterToolbar(
      controller: _subListSearchController,
      query: _subListQuery,
      hintText: 'Buscar Collection',
      onQueryChanged: (value) => setState(() => _subListQuery = value),
      onClearQuery: () {
        _subListSearchController.clear();
        setState(() => _subListQuery = '');
      },
      onSort: _openCollectionSortSheet,
      gridView: _collectionsGridView,
      onToggleGridView: () {
        setState(() => _collectionsGridView = !_collectionsGridView);
        _storage.write(
          'source_playlist_collections_grid_view',
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
        _storage.write('source_playlist_items_grid_view', _itemsGridView);
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
          selected: _itemSort == _SourcePlaylistItemSort.recent,
          onTap: () {
            setState(() => _itemSort = _SourcePlaylistItemSort.recent);
            _storage.write('source_playlist_item_sort', _itemSort.name);
          },
        ),
        SortSheetOption(
          label: 'Nombre',
          selected: _itemSort == _SourcePlaylistItemSort.title,
          onTap: () {
            setState(() => _itemSort = _SourcePlaylistItemSort.title);
            _storage.write('source_playlist_item_sort', _itemSort.name);
          },
        ),
        SortSheetOption(
          label: 'Tamaño',
          selected: _itemSort == _SourcePlaylistItemSort.size,
          onTap: () {
            setState(() => _itemSort = _SourcePlaylistItemSort.size);
            _storage.write('source_playlist_item_sort', _itemSort.name);
          },
        ),
        SortSheetOption(
          label: 'Duración',
          selected: _itemSort == _SourcePlaylistItemSort.duration,
          onTap: () {
            setState(() => _itemSort = _SourcePlaylistItemSort.duration);
            _storage.write('source_playlist_item_sort', _itemSort.name);
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
          selected: _subListSort == _SourceSubListSort.recent,
          onTap: () {
            setState(() => _subListSort = _SourceSubListSort.recent);
            _storage.write(
              'source_playlist_collection_sort',
              _subListSort.name,
            );
          },
        ),
        SortSheetOption(
          label: 'Nombre',
          selected: _subListSort == _SourceSubListSort.name,
          onTap: () {
            setState(() => _subListSort = _SourceSubListSort.name);
            _storage.write(
              'source_playlist_collection_sort',
              _subListSort.name,
            );
          },
        ),
        SortSheetOption(
          label: 'Más items',
          selected: _subListSort == _SourceSubListSort.items,
          onTap: () {
            setState(() => _subListSort = _SourceSubListSort.items);
            _storage.write(
              'source_playlist_collection_sort',
              _subListSort.name,
            );
          },
        ),
        SortSheetOption(
          label: 'Más Collections',
          selected: _subListSort == _SourceSubListSort.subfolders,
          onTap: () {
            setState(() => _subListSort = _SourceSubListSort.subfolders);
            _storage.write(
              'source_playlist_collection_sort',
              _subListSort.name,
            );
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

  _SourcePlaylistItemSort _readItemSort() {
    final raw = (_storage.read('source_playlist_item_sort') as String?)?.trim();
    for (final option in _SourcePlaylistItemSort.values) {
      if (option.name == raw) return option;
    }
    return _SourcePlaylistItemSort.recent;
  }

  _SourceSubListSort _readSubListSort() {
    final raw = (_storage.read('source_playlist_collection_sort') as String?)
        ?.trim();
    for (final option in _SourceSubListSort.values) {
      if (option.name == raw) return option;
    }
    return _SourceSubListSort.recent;
  }

  // ============================
  // 🧾 META / SIZE
  // ============================
  String _buildMetaLine(int itemCount, int listCount) {
    final base = '$itemCount items · $listCount Collections';
    if (_playlistSizeLabel == null || _playlistSizeLabel!.isEmpty) return base;
    return '$base · ${_playlistSizeLabel!}';
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

  // ============================
  // 📚 DATA
  // ============================
  Future<List<MediaItem>> _loadItems(SourceThemeTopicPlaylist playlist) async {
    return _sources.loadPlaylistItems(
      theme: widget.theme,
      playlist: playlist,
      origins: widget.origins,
    );
  }

  Future<List<MediaItem>> _candidateItems() async {
    return _sources.loadCandidateItems(
      theme: widget.theme,
      origins: widget.origins,
    );
  }

  // ============================
  // 🪄 ACTIONS
  // ============================
  Future<void> _addItems(SourceThemeTopicPlaylist playlist) async {
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
        onAdd: (selected) async {
          final mergedIds = {
            ...playlist.itemIds,
            ...selected.map(_sources.keyForItem),
          }.toList();
          await _sources.updateTopicPlaylist(
            playlist.copyWith(itemIds: mergedIds),
          );
        },
      ),
    );
  }

  Future<void> _addSubList(SourceThemeTopicPlaylist playlist) async {
    await Get.toNamed(
      AppRoutes.createEntity,
      preventDuplicates: false,
      arguments: CreateEntityArgs.topicPlaylist(
        storageId: 'stpl_${playlist.id}_create',
        topicId: playlist.topicId,
        parentId: playlist.id,
        depth: playlist.depth + 1,
      ),
    );
  }

  Future<void> _removeItem(
    SourceThemeTopicPlaylist playlist,
    MediaItem item,
  ) async {
    final key = _sources.keyForItem(item);
    final updated = playlist.copyWith(
      itemIds: playlist.itemIds.where((e) => e != key).toList(),
    );
    await _sources.updateTopicPlaylist(updated);
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

  Future<void> _showItemActions(
    SourceThemeTopicPlaylist playlist,
    MediaItem item,
  ) async {
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
                  await _removeItem(playlist, item);
                },
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => nav?.setOverlayOpen(false));
  }

  // ============================
  // ✏️ EDIT PLAYLIST DIALOG (UI)
  // ============================
  Future<void> _openEditPlaylist(SourceThemeTopicPlaylist playlist) async {
    await Get.toNamed(
      AppRoutes.editEntity,
      arguments: EditEntityArgs.topicPlaylist(playlist),
    );
  }
}

enum _SourcePlaylistItemSort { recent, title, size, duration }

enum _SourceSubListSort { recent, name, items, subfolders }

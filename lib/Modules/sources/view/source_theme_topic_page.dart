import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/models/media_item.dart';
import '../../../app/services/audio_service.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/media/media_item_grid.dart';
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
import '../ui/source_media_list_item.dart';
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
  final TextEditingController _listSearchController = TextEditingController();
  String? _topicSizeLabel;
  String _listQuery = '';
  _SourceListSort _listSort = _SourceListSort.recent;
  bool _itemsGridView = false;
  bool _collectionsGridView = false;

  @override
  void initState() {
    super.initState();
    _listSort = _readListSort();
    _itemsGridView = _storage.read('source_topic_items_grid_view') ?? false;
    _collectionsGridView =
        _storage.read('source_topic_collections_grid_view') ?? false;
    if (Get.isRegistered<AudioService>()) {
      Get.find<AudioService>().pauseAndHideMiniPlayer();
    }
  }

  @override
  void dispose() {
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
          extraActions: [
            IconButton(
              tooltip: _itemsGridView ? 'Ver como lista' : 'Ver cuadrícula',
              onPressed: () {
                setState(() => _itemsGridView = !_itemsGridView);
                _storage.write('source_topic_items_grid_view', _itemsGridView);
              },
              icon: Icon(
                _itemsGridView
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
              ),
            ),
          ],
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
        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Items',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            if (_itemsGridView)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                sliver: MediaItemSliverGrid(
                  items: items,
                  childAspectRatio: 0.95,
                  coverAspectRatio: 16 / 9,
                  crossAxisCount: 2,
                  fallbackIcon: Icons.videocam_rounded,
                  onTap: (item, index) => _playItem(items, item),
                  onLongPress: (item, index) => _showItemActions(topic, item),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: SourceMediaListItem(
                        item: item,
                        videoStyle: true,
                        onTap: () => _playItem(items, item),
                        onLongPress: () => _showItemActions(topic, item),
                        onMore: () => _showItemActions(topic, item),
                      ),
                    );
                  }, childCount: items.length),
                ),
              ),
          ],
        );
      },
    );
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
        if (list.isNotEmpty) _listToolbar(scheme),
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
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

  Widget _listToolbar(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _listSearchController,
              onChanged: (value) => setState(() => _listQuery = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar Collection',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _listQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        onPressed: () {
                          _listSearchController.clear();
                          setState(() => _listQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<_SourceListSort>(
          tooltip: 'Ordenar',
          initialValue: _listSort,
          onOpened: _markOverlayOpen,
          onCanceled: _markOverlayClosed,
          onSelected: (value) {
            _markOverlayClosed();
            setState(() => _listSort = value);
            _storage.write('source_topic_collection_sort', value.name);
          },
          icon: const Icon(Icons.sort_rounded),
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: _SourceListSort.recent,
              child: Text('Recientes primero'),
            ),
            PopupMenuItem(value: _SourceListSort.name, child: Text('Nombre')),
            PopupMenuItem(
              value: _SourceListSort.items,
              child: Text('Más items'),
            ),
            PopupMenuItem(
              value: _SourceListSort.subfolders,
              child: Text('Más Collections'),
            ),
          ],
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: _collectionsGridView
              ? 'Ver Collections como lista'
              : 'Ver Collections como grid',
          onPressed: () {
            setState(() => _collectionsGridView = !_collectionsGridView);
            _storage.write(
              'source_topic_collections_grid_view',
              _collectionsGridView,
            );
          },
          icon: Icon(
            _collectionsGridView
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded,
          ),
        ),
      ],
    );
  }

  _SourceListSort _readListSort() {
    final raw = (_storage.read('source_topic_collection_sort') as String?)
        ?.trim();
    for (final option in _SourceListSort.values) {
      if (option.name == raw) return option;
    }
    return _SourceListSort.recent;
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

enum _SourceListSort { recent, name, items, subfolders }

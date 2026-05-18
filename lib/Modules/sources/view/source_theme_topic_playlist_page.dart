import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/models/media_item.dart';
import '../../../app/services/audio_service.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/routes/app_routes.dart';
import '../../home/controller/home_controller.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../controller/sources_controller.dart';
import '../domain/source_origin.dart';
import '../domain/source_theme.dart';
import '../domain/source_theme_topic_playlist.dart';
import '../ui/source_media_list_item.dart';
import '../ui/source_playlist_card.dart';
import '../../../app/utils/format_bytes.dart';

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
  final TextEditingController _subListSearchController =
      TextEditingController();

  String? _playlistSizeLabel;
  String _subListQuery = '';
  _SourceSubListSort _subListSort = _SourceSubListSort.recent;

  @override
  void initState() {
    super.initState();
    _subListSort = _readSubListSort();
    if (Get.isRegistered<AudioService>()) {
      Get.find<AudioService>().pauseAndHideMiniPlayer();
    }
  }

  @override
  void dispose() {
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

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SourceMediaListItem(
                      item: item,
                      onTap: () => _playItem(items, item),
                      onLongPress: () => _showItemActions(playlist, item),
                      onMore: () => _showItemActions(playlist, item),
                    ),
                  );
                }, childCount: items.length),
              ),
            ],
          ),
        );
      },
    );
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
        if (lists.isNotEmpty) _subListToolbar(scheme),
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
        else
          ...filtered.map(
            (pl) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SourcePlaylistCard(
                theme: widget.theme,
                playlist: pl,
                childListCount: _sources
                    .playlistsForTopic(playlist.topicId, parentId: pl.id)
                    .length,
                onOpen: () => Get.toNamed(
                  AppRoutes.sourcePlaylist,
                  preventDuplicates: false,
                  arguments: {
                    'playlistId': pl.id,
                    'theme': widget.theme,
                    'origins': widget.origins,
                  },
                ),
                onEdit: () => _openEditPlaylist(pl),
                onDelete: () => _sources.deleteTopicPlaylist(pl),
              ),
            ),
          ),
      ],
    );
  }

  Widget _subListToolbar(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _subListSearchController,
              onChanged: (value) => setState(() => _subListQuery = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar Collection',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _subListQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        onPressed: () {
                          _subListSearchController.clear();
                          setState(() => _subListQuery = '');
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
        PopupMenuButton<_SourceSubListSort>(
          tooltip: 'Ordenar',
          initialValue: _subListSort,
          onOpened: _markOverlayOpen,
          onCanceled: _markOverlayClosed,
          onSelected: (value) {
            _markOverlayClosed();
            setState(() => _subListSort = value);
            _storage.write('source_playlist_collection_sort', value.name);
          },
          icon: const Icon(Icons.sort_rounded),
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: _SourceSubListSort.recent,
              child: Text('Recientes primero'),
            ),
            PopupMenuItem(
              value: _SourceSubListSort.name,
              child: Text('Nombre'),
            ),
            PopupMenuItem(
              value: _SourceSubListSort.items,
              child: Text('Más items'),
            ),
            PopupMenuItem(
              value: _SourceSubListSort.subfolders,
              child: Text('Más Collections'),
            ),
          ],
        ),
      ],
    );
  }

  _SourceSubListSort _readSubListSort() {
    final raw = (_storage.read('source_playlist_collection_sort') as String?)
        ?.trim();
    for (final option in _SourceSubListSort.values) {
      if (option.name == raw) return option;
    }
    return _SourceSubListSort.recent;
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
    final selected = <String>{};
    final sheetColor = Theme.of(context).colorScheme.surface;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: sheetColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx2).size.height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.playlist_add_rounded),
                          const SizedBox(width: 8),
                          Text(
                            'Agregar items',
                            style: Theme.of(ctx2).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(ctx2).pop(),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Text(
                                'No hay items disponibles para esta Collection.',
                                style: Theme.of(ctx2).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        ctx2,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (ctx3, i) {
                                final item = list[i];
                                final key = _sources.keyForItem(item);
                                final checked = selected.contains(key);
                                return CheckboxListTile(
                                  value: checked,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        selected.add(key);
                                      } else {
                                        selected.remove(key);
                                      }
                                    });
                                  },
                                  title: Text(item.title),
                                  subtitle: Text(item.displaySubtitle),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: () async {
                          final toAdd = list
                              .where(
                                (item) => selected.contains(
                                  _sources.keyForItem(item),
                                ),
                              )
                              .toList();

                          final mergedIds = {
                            ...playlist.itemIds,
                            ...toAdd.map(_sources.keyForItem),
                          }.toList();

                          await _sources.updateTopicPlaylist(
                            playlist.copyWith(itemIds: mergedIds),
                          );

                          if (ctx2.mounted) Navigator.of(ctx2).pop();
                        },
                        child: const Text('Agregar seleccionados'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

enum _SourceSubListSort { recent, name, items, subfolders }

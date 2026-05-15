import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/models/media_item.dart';
import '../../../app/services/audio_service.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
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
  final TextEditingController _listSearchController = TextEditingController();
  String? _topicSizeLabel;
  String _listQuery = '';
  _SourceListSort _listSort = _SourceListSort.recent;

  @override
  void initState() {
    super.initState();
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
                      onLongPress: () => _showItemActions(topic, item),
                      onMore: () => _showItemActions(topic, item),
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
        else
          ...filtered.map(
            (pl) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SourcePlaylistCard(
                theme: widget.theme,
                playlist: pl,
                childListCount: _sources
                    .playlistsForTopic(topic.id, parentId: pl.id)
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
          onSelected: (value) => setState(() => _listSort = value),
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
      ],
    );
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
    // ============================
    // 🪄 DIALOGO: AGREGAR ITEMS
    // ============================
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
                          await _sources.addItemsToTopic(topic, toAdd);
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

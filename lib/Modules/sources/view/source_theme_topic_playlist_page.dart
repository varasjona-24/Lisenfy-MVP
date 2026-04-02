import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/models/media_item.dart';
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

  String? _playlistSizeLabel;

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
        return const Scaffold(body: Center(child: Text('Lista no encontrada')));
      }

      final children = _sources.playlistsForTopic(
        playlist.topicId,
        parentId: playlist.id,
      );

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
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
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                Text(
                  _buildMetaLine(playlist.itemIds.length, children.length),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _actionRow(playlist),
                const SizedBox(height: 18),
                _itemsSection(playlist),
                const SizedBox(height: 18),
                _subListsSection(playlist, children),
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
          child: FilledButton.icon(
            onPressed: () => _addItems(playlist),
            icon: const Icon(Icons.add),
            label: const Text('Agregar item'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _addSubList(playlist),
            icon: const Icon(Icons.create_new_folder_rounded),
            label: const Text('Agregar lista'),
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
          return Text(
            'No hay items todavía.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SourceMediaListItem(
                  item: item,
                  onTap: () => _playItem(items, item),
                  onLongPress: () => _showItemActions(playlist, item),
                  onMore: () => _showItemActions(playlist, item),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _subListsSection(
    SourceThemeTopicPlaylist playlist,
    List<SourceThemeTopicPlaylist> lists,
  ) {
    if (lists.isEmpty) {
      return Text(
        'No hay listas aún.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Listas',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...lists.map(
          (pl) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SourcePlaylistCard(
              theme: widget.theme,
              playlist: pl,
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

  // ============================
  // 🧾 META / SIZE
  // ============================
  String _buildMetaLine(int itemCount, int listCount) {
    final base = '$itemCount items · $listCount listas';
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
    final selected = <String>{};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                                'No hay items disponibles para esta temática.',
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
    );
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

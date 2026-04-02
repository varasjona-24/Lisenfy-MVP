import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/models/media_item.dart';
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
  String? _topicSizeLabel;

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
          body: Center(child: Text('Temática no encontrada')),
        );
      }
      final lists = _sources.playlistsForTopic(topic.id);

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
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
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                _header(topic, theme, lists.length),
                const SizedBox(height: 14),
                _actionRow(topic),
                const SizedBox(height: 18),
                _itemsSection(topic),
                const SizedBox(height: 18),
                _playlistsSection(topic, lists),
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
    final base = '${topic.itemIds.length} items · $listCount listas';
    if (_topicSizeLabel == null || _topicSizeLabel!.isEmpty) return base;
    return '$base · ${_topicSizeLabel!}';
  }

  Widget _actionRow(SourceThemeTopic topic) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _addItems(topic),
            icon: const Icon(Icons.add),
            label: const Text('Agregar item'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _addTopicPlaylist(topic),
            icon: const Icon(Icons.playlist_add_rounded),
            label: const Text('Agregar lista'),
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
                  onLongPress: () => _showItemActions(topic, item),
                  onMore: () => _showItemActions(topic, item),
                ),
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
    if (list.isEmpty) {
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
        ...list.map(
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
    );
  }

  Future<void> _openEditPlaylist(SourceThemeTopicPlaylist playlist) async {
    await Get.toNamed(
      AppRoutes.editEntity,
      arguments: EditEntityArgs.topicPlaylist(playlist),
    );
  }
}

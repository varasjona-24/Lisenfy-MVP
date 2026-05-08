import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/themes/app_grid_theme.dart';
import '../../../app/ui/widgets/media/media_item_grid.dart';
import '../../../app/models/media_item.dart';
import '../controller/playlists_controller.dart';
import '../domain/playlist.dart';
import '../../../app/utils/format_bytes.dart';

class PlaylistDetailPage extends GetView<PlaylistsController> {
  const PlaylistDetailPage._({required this.playlistId, required this.isSmart});

  factory PlaylistDetailPage.smart({required String playlistId}) {
    return PlaylistDetailPage._(playlistId: playlistId, isSmart: true);
  }

  factory PlaylistDetailPage.custom({required String playlistId}) {
    return PlaylistDetailPage._(playlistId: playlistId, isSmart: false);
  }

  final String playlistId;
  final bool isSmart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = Get.find<MediaActionsController>();

    return Obx(() {
      final smart = isSmart ? controller.getSmartById(playlistId) : null;
      final playlist = !isSmart ? controller.getPlaylistById(playlistId) : null;

      final title = isSmart ? smart?.title : playlist?.name;
      final items = isSmart
          ? (smart?.items ?? const <MediaItem>[])
          : (playlist != null
                ? controller.resolvePlaylistItems(playlist)
                : const <MediaItem>[]);

      final cover = _resolveCover(playlist, items);
      final totalBytes = _totalBytes(items);

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: ListenfyLogo(size: 28, color: theme.colorScheme.primary),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: Get.back,
          ),
        ),
        body: AppGradientBackground(
          child: RefreshIndicator(
            onRefresh: controller.load,
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
                        _header(theme, title, cover, items.length, totalBytes),
                        const SizedBox(height: 14),
                        _actionRow(context, items, playlist, isSmart),
                        const SizedBox(height: 16),
                        if (items.isEmpty)
                          Text(
                            'No hay canciones en esta lista.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        else ...[
                          _tracksHeader(theme, items.length),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty)
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.lg),
                  )
                else if (controller.detailGridView.value)
                  MediaItemSliverGrid(
                    items: items,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    childAspectRatio: AppGridTheme.childAspectRatio,
                    crossAxisSpacing: AppGridTheme.spacing,
                    mainAxisSpacing: AppGridTheme.spacing,
                    onTap: (item, index) => _play(items, index),
                    onMore: (item, index) => _openTrackActionSheet(
                      context: context,
                      item: item,
                      queue: items,
                      playlist: playlist,
                      isSmartPlaylist: isSmart,
                      actions: actions,
                      canRemoveFromPlaylist: !isSmart && playlist != null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _trackTile(
                          context,
                          theme,
                          items[index],
                          index,
                          items,
                          playlist,
                          isSmart,
                          actions,
                        ),
                        childCount: items.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _header(
    ThemeData theme,
    String? title,
    ImageProvider? cover,
    int count,
    int totalBytes,
  ) {
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 96,
            height: 96,
            color: scheme.surfaceContainer,
            child: cover != null
                ? Image(image: cover, fit: BoxFit.cover)
                : Icon(
                    Icons.music_note_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 36,
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? 'Lista',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _buildMetaLine(count, totalBytes),
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

  String _buildMetaLine(int count, int totalBytes) {
    final sizeLabel = totalBytes > 0 ? formatBytes(totalBytes) : '';
    if (sizeLabel.isEmpty) return '$count canciones';
    return '$count canciones · $sizeLabel';
  }

  int _totalBytes(List<MediaItem> items) {
    var total = 0;
    for (final item in items) {
      final v = item.localAudioVariant ?? item.localVideoVariant;
      final size = v?.size ?? 0;
      if (size > 0) total += size;
    }
    return total;
  }

  Widget _actionRow(
    BuildContext context,
    List<MediaItem> items,
    Playlist? playlist,
    bool isSmartPlaylist,
  ) {
    return Row(
      children: [
        if (!isSmartPlaylist)
          Expanded(
            child: _PlaylistCommandButton(
              icon: Icons.add_rounded,
              label: 'Agregar',
              onPressed: () => _openAddSongs(context, playlist),
            ),
          ),
        if (!isSmartPlaylist) const SizedBox(width: 10),
        Expanded(
          child: _PlaylistCommandButton(
            icon: Icons.play_arrow_rounded,
            label: 'Reproducir',
            onPressed: items.isEmpty ? null : () => _play(items, 0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlaylistCommandButton(
            icon: Icons.shuffle_rounded,
            label: 'Aleatorio',
            onPressed: items.isEmpty ? null : () => _playShuffled(items),
          ),
        ),
      ],
    );
  }

  Widget _tracksHeader(ThemeData theme, int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count canciones',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          tooltip: controller.detailGridView.value
              ? 'Vista de cuadrícula'
              : 'Vista de lista',
          onPressed: controller.toggleDetailGridView,
          icon: Icon(
            controller.detailGridView.value
                ? Icons.grid_view_rounded
                : Icons.view_list_rounded,
          ),
        ),
      ],
    );
  }

  Widget _trackTile(
    BuildContext context,
    ThemeData theme,
    MediaItem item,
    int index,
    List<MediaItem> queue,
    Playlist? playlist,
    bool isSmartPlaylist,
    MediaActionsController actions,
  ) {
    final scheme = theme.colorScheme;
    final thumb = item.effectiveThumbnail;
    ImageProvider? provider;
    if (thumb != null && thumb.isNotEmpty) {
      provider = thumb.startsWith('http')
          ? NetworkImage(thumb)
          : FileImage(File(thumb));
    }

    final canRemoveFromPlaylist = !isSmartPlaylist && playlist != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _play(queue, index),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.32),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: scheme.surfaceContainerHighest,
                    child: provider != null
                        ? Image(image: provider, fit: BoxFit.cover)
                        : Icon(
                            Icons.music_note_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.displaySubtitle.trim().isEmpty
                            ? 'Audio'
                            : item.displaySubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  tooltip: 'Acciones',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  splashRadius: 18,
                  onPressed: () => _openTrackActionSheet(
                    context: context,
                    item: item,
                    queue: queue,
                    playlist: playlist,
                    isSmartPlaylist: isSmartPlaylist,
                    actions: actions,
                    canRemoveFromPlaylist: canRemoveFromPlaylist,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTrackActionSheet({
    required BuildContext context,
    required MediaItem item,
    required List<MediaItem> queue,
    required Playlist? playlist,
    required bool isSmartPlaylist,
    required MediaActionsController actions,
    required bool canRemoveFromPlaylist,
  }) async {
    final action = await showModalBottomSheet<_TrackAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canRemoveFromPlaylist)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline_rounded),
                  title: const Text('Quitar de esta playlist'),
                  onTap: () =>
                      Navigator.of(ctx).pop(_TrackAction.removeFromPlaylist),
                ),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Más acciones'),
                onTap: () => Navigator.of(ctx).pop(_TrackAction.moreActions),
              ),
            ],
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;
    await _handleTrackAction(
      context: context,
      action: action,
      item: item,
      queue: queue,
      playlist: playlist,
      isSmartPlaylist: isSmartPlaylist,
      actions: actions,
    );
  }

  Future<void> _handleTrackAction({
    required BuildContext context,
    required _TrackAction action,
    required MediaItem item,
    required List<MediaItem> queue,
    required Playlist? playlist,
    required bool isSmartPlaylist,
    required MediaActionsController actions,
  }) async {
    switch (action) {
      case _TrackAction.removeFromPlaylist:
        if (playlist == null) return;
        await controller.removeItemFromPlaylist(playlist.id, item);
        if (context.mounted) {
          Get.snackbar(
            'Playlist',
            'Canción eliminada de la lista',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        break;
      case _TrackAction.moreActions:
        await actions.showItemActions(
          context,
          item,
          onChanged: controller.load,
          onStartMultiSelect: () {
            Get.toNamed(
              AppRoutes.homeSectionList,
              arguments: {
                'title': isSmartPlaylist
                    ? 'Playlist inteligente'
                    : (playlist?.name ?? 'Playlist'),
                'items': queue,
                'onItemTap': (MediaItem tapped, int tapIndex) =>
                    _play(queue, tapIndex < 0 ? 0 : tapIndex),
                'onItemLongPress':
                    (
                      MediaItem target,
                      int _, {
                      VoidCallback? onStartMultiSelect,
                    }) => actions.showItemActions(
                      context,
                      target,
                      onChanged: controller.load,
                      onStartMultiSelect: onStartMultiSelect,
                    ),
                'onDeleteSelected': (List<MediaItem> selected) async {
                  await actions.confirmDeleteMultiple(
                    context,
                    selected,
                    onChanged: controller.load,
                  );
                },
                'startInSelectionMode': true,
                'initialSelectionItemId': item.id,
              },
            );
          },
        );
        break;
    }
  }

  void _play(List<MediaItem> queue, int index) {
    if (queue.isEmpty) return;
    Get.toNamed(
      AppRoutes.audioPlayer,
      arguments: {'queue': queue, 'index': index},
    );
  }

  void _playShuffled(List<MediaItem> items) {
    if (items.isEmpty) return;
    final shuffled = List<MediaItem>.from(items)..shuffle();
    _play(shuffled, 0);
  }

  ImageProvider? _resolveCover(Playlist? playlist, List<MediaItem> items) {
    if (playlist != null) {
      final local = playlist.coverLocalPath?.trim();
      if (local != null && local.isNotEmpty && File(local).existsSync()) {
        return FileImage(File(local));
      }
      final url = playlist.coverUrl?.trim();
      if (url != null && url.isNotEmpty) {
        return NetworkImage(url);
      }
      if (playlist.coverCleared) {
        return null;
      }
    }
    final thumb = items.isNotEmpty ? items.first.effectiveThumbnail : null;
    if (thumb != null && thumb.isNotEmpty) {
      return thumb.startsWith('http')
          ? NetworkImage(thumb)
          : FileImage(File(thumb));
    }
    return null;
  }

  Future<void> _openAddSongs(BuildContext context, Playlist? playlist) async {
    if (playlist == null) return;
    final existing = playlist.itemIds.toSet();
    final allItems = controller.libraryAudio.where((item) {
      final key = item.publicId.trim().isNotEmpty
          ? item.publicId.trim()
          : item.id.trim();
      return !existing.contains(key);
    }).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return _AddSongsSheet(
          playlist: playlist,
          allItems: allItems,
          controller: controller,
        );
      },
    );
  }
}

class _PlaylistCommandButton extends StatelessWidget {
  const _PlaylistCommandButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: enabled
                ? scheme.primaryContainer.withValues(alpha: 0.32)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? scheme.primary.withValues(alpha: 0.34)
                  : scheme.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: enabled ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TrackAction { removeFromPlaylist, moreActions }

class _AddSongsSheet extends StatefulWidget {
  const _AddSongsSheet({
    required this.playlist,
    required this.allItems,
    required this.controller,
  });

  final Playlist playlist;
  final List<MediaItem> allItems;
  final PlaylistsController controller;

  @override
  State<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends State<_AddSongsSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selected = <String>{};
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _keyFor(MediaItem item) {
    final publicId = item.publicId.trim();
    return publicId.isNotEmpty ? publicId : item.id.trim();
  }

  List<MediaItem> get _filteredItems {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return widget.allItems;
    return widget.allItems
        .where((item) {
          return item.title.toLowerCase().contains(normalizedQuery) ||
              item.displaySubtitle.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final items = _filteredItems;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.playlist_add_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Agregar canciones',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (value) {
                      setState(() => _query = value);
                    },
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                      hintText: 'Buscar por cancion o artista',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(
                          Icons.library_music_rounded,
                          size: 18,
                        ),
                        label: Text('${widget.allItems.length} disponibles'),
                      ),
                      Chip(
                        avatar: const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                        ),
                        label: Text('${_selected.length} seleccionadas'),
                      ),
                      if (normalizedQuery.isNotEmpty)
                        Chip(
                          avatar: const Icon(
                            Icons.filter_alt_rounded,
                            size: 18,
                          ),
                          label: Text('${items.length} resultados'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          normalizedQuery.isEmpty
                              ? 'No hay canciones nuevas para agregar.'
                              : 'No se encontraron canciones.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _songTile(ctx, items[i]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty ? null : _addSelected,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    _selected.isEmpty
                        ? 'Selecciona canciones'
                        : 'Agregar ${_selected.length} seleccionadas',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _songTile(BuildContext context, MediaItem item) {
    final key = _keyFor(item);
    final checked = _selected.contains(key);
    final thumb = item.effectiveThumbnail;

    return Material(
      color: checked
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.5)
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: checked
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _toggle(key, checked),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: thumb == null || thumb.isEmpty
                ? ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.music_note_rounded),
                  )
                : Image(
                    image: thumb.startsWith('http')
                        ? NetworkImage(thumb)
                        : FileImage(File(thumb)) as ImageProvider,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          item.displaySubtitle.isEmpty
              ? 'Artista desconocido'
              : item.displaySubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Checkbox(
          value: checked,
          onChanged: (v) => _toggle(key, checked),
        ),
      ),
    );
  }

  void _toggle(String key, bool checked) {
    setState(() {
      if (checked) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  Future<void> _addSelected() async {
    final toAdd = widget.allItems.where((item) {
      return _selected.contains(_keyFor(item));
    }).toList();
    await widget.controller.addItemsToPlaylist(widget.playlist.id, toAdd);
    if (mounted) Navigator.of(context).pop();
  }
}

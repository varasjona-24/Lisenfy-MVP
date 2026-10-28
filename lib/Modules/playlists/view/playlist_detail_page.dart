import '../../../app/ui/widgets/navigation/app_navigation_scaffold.dart';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/dialogs/sort_options_sheet.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/media/app_media_items_view.dart';
import '../../../app/models/media_item.dart';
import '../controller/playlists_controller.dart';
import '../domain/playlist.dart';
import 'widgets/playlist_song_picker_sheet.dart';
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
          ? controller.sortTrackItems(smart?.items ?? const <MediaItem>[])
          : (playlist != null
                ? controller.resolvePlaylistItems(playlist)
                : const <MediaItem>[]);

      final cover = _resolveCover(playlist, items);
      final totalBytes = _totalBytes(items);

      return AppNavigationScaffold(
        navigationIndex: 1,
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
                else
                  AppMediaItemsSliver(
                    expandedDesktopRows: true,
                    desktopGridHorizontalInset: 12,
                    desktopListHorizontalInset: 12,
                    items: items,
                    gridView: controller.detailGridView.value,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    onTap: (item, index) => _play(items, index),
                    onLongPress: (item, index) => _openTrackActionSheet(
                      context: context,
                      item: item,
                      queue: items,
                      playlist: playlist,
                      isSmartPlaylist: isSmart,
                      actions: actions,
                      canRemoveFromPlaylist:
                          !isSmart && playlist != null && !playlist.isTemporary,
                    ),
                    compactListCard: true,
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
                title ?? tr('edit.entity_type.list'),
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
        if (!isSmartPlaylist && playlist?.isTemporary != true)
          Expanded(
            child: _PlaylistCommandButton(
              icon: Icons.add_rounded,
              label: tr('common.add'),
              onPressed: () => _openAddSongs(context, playlist),
            ),
          ),
        if (!isSmartPlaylist && playlist?.isTemporary != true)
          const SizedBox(width: 10),
        Expanded(
          child: _PlaylistCommandButton(
            icon: Icons.play_arrow_rounded,
            label: tr('player.play'),
            onPressed: items.isEmpty ? null : () => _play(items, 0),
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
            tr('playlists.detail.songs_count', args: ['$count']),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          tooltip: tr('common.options'),
          onPressed: () => _openSortSheet(Get.context!),
          icon: const Icon(Icons.sort_rounded),
        ),
        IconButton(
          tooltip: controller.detailGridView.value
              ? tr('home.section.grid_view')
              : tr('home.section.list_view'),
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

  Future<void> _openSortSheet(BuildContext context) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nav = Get.isRegistered<NavigationController>()
        ? Get.find<NavigationController>()
        : null;
    nav?.setOverlayOpen(true);
    await showAdaptiveSortMenu<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return Obx(() {
          final sort = controller.trackSort.value;
          final asc = controller.trackSortAscending.value;
          void pickSort(PlaylistTrackSort next) {
            if (sort == next) {
              controller.setTrackSortAscending(!asc);
              return;
            }
            controller.setTrackSort(next);
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('playlists.detail.sort_by'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PlaylistSortOption(
                      icon: Icons.playlist_add_check_rounded,
                      label: tr('playlists.detail.sort_added'),
                      sublabel: _playlistSortDirectionLabel(
                        PlaylistTrackSort.addedAt,
                        ascending: sort == PlaylistTrackSort.addedAt
                            ? asc
                            : false,
                      ),
                      selected: sort == PlaylistTrackSort.addedAt,
                      ascending: sort == PlaylistTrackSort.addedAt ? asc : null,
                      onTap: () => pickSort(PlaylistTrackSort.addedAt),
                    ),
                    const SizedBox(height: 6),
                    _PlaylistSortOption(
                      icon: Icons.title_rounded,
                      label: tr('playlists.detail.sort_title'),
                      sublabel: _playlistSortDirectionLabel(
                        PlaylistTrackSort.title,
                        ascending: sort == PlaylistTrackSort.title ? asc : true,
                      ),
                      selected: sort == PlaylistTrackSort.title,
                      ascending: sort == PlaylistTrackSort.title ? asc : null,
                      onTap: () => pickSort(PlaylistTrackSort.title),
                    ),
                    const SizedBox(height: 6),
                    _PlaylistSortOption(
                      icon: Icons.person_rounded,
                      label: tr('playlists.detail.sort_artist'),
                      sublabel: _playlistSortDirectionLabel(
                        PlaylistTrackSort.artist,
                        ascending: sort == PlaylistTrackSort.artist
                            ? asc
                            : true,
                      ),
                      selected: sort == PlaylistTrackSort.artist,
                      ascending: sort == PlaylistTrackSort.artist ? asc : null,
                      onTap: () => pickSort(PlaylistTrackSort.artist),
                    ),
                    const SizedBox(height: 6),
                    _PlaylistSortOption(
                      icon: Icons.sd_storage_rounded,
                      label: tr('playlists.detail.sort_size'),
                      sublabel: _playlistSortDirectionLabel(
                        PlaylistTrackSort.size,
                        ascending: sort == PlaylistTrackSort.size ? asc : false,
                      ),
                      selected: sort == PlaylistTrackSort.size,
                      ascending: sort == PlaylistTrackSort.size ? asc : null,
                      onTap: () => pickSort(PlaylistTrackSort.size),
                    ),
                    const SizedBox(height: 6),
                    _PlaylistSortOption(
                      icon: Icons.equalizer_rounded,
                      label: tr('playlists.detail.sort_plays'),
                      sublabel: _playlistSortDirectionLabel(
                        PlaylistTrackSort.plays,
                        ascending: sort == PlaylistTrackSort.plays
                            ? asc
                            : false,
                      ),
                      selected: sort == PlaylistTrackSort.plays,
                      ascending: sort == PlaylistTrackSort.plays ? asc : null,
                      onTap: () => pickSort(PlaylistTrackSort.plays),
                    ),
                    const SizedBox(height: 6),
                    _PlaylistSortOption(
                      icon: Icons.timer_rounded,
                      label: tr('playlists.detail.sort_duration'),
                      sublabel: _playlistSortDirectionLabel(
                        PlaylistTrackSort.duration,
                        ascending: sort == PlaylistTrackSort.duration
                            ? asc
                            : false,
                      ),
                      selected: sort == PlaylistTrackSort.duration,
                      ascending: sort == PlaylistTrackSort.duration
                          ? asc
                          : null,
                      onTap: () => pickSort(PlaylistTrackSort.duration),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          tr('common.accept'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    ).whenComplete(() => nav?.setOverlayOpen(false));
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
    final nav = Get.isRegistered<NavigationController>()
        ? Get.find<NavigationController>()
        : null;
    nav?.setOverlayOpen(true);
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
                  title: Text(tr('playlists.detail.remove_from_playlist')),
                  onTap: () =>
                      Navigator.of(ctx).pop(_TrackAction.removeFromPlaylist),
                ),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: Text(tr('playlists.detail.more_actions')),
                onTap: () => Navigator.of(ctx).pop(_TrackAction.moreActions),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => nav?.setOverlayOpen(false));
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

  String _playlistSortDirectionLabel(
    PlaylistTrackSort sort, {
    required bool ascending,
  }) {
    return switch (sort) {
      PlaylistTrackSort.title ||
      PlaylistTrackSort.artist => ascending ? 'A-Z' : 'Z-A',
      PlaylistTrackSort.addedAt =>
        ascending
            ? tr('playlists.detail.asc_oldest')
            : tr('playlists.detail.desc_recent'),
      PlaylistTrackSort.size ||
      PlaylistTrackSort.plays ||
      PlaylistTrackSort.duration =>
        ascending
            ? tr('home.section.low_to_high')
            : tr('home.section.high_to_low'),
    };
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
            tr('edit.entity_type.playlist'),
            tr('playlists.detail.removed'),
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        break;
      case _TrackAction.moreActions:
        await actions.showItemActions(
          context,
          item,
          onChanged: controller.load,
          queueContext: queue,
          queueContextIndex: queue.indexWhere((entry) => entry.id == item.id),
          onStartMultiSelect: () {
            Get.toNamed(
              AppRoutes.homeSectionList,
              arguments: {
                'title': isSmartPlaylist
                    ? tr('playlists.smart_playlist')
                    : (playlist?.name ?? tr('edit.entity_type.playlist')),
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
                      queueContext: queue,
                      queueContextIndex: queue.indexWhere(
                        (entry) => entry.id == target.id,
                      ),
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

  ImageProvider? _resolveCover(Playlist? playlist, List<MediaItem> items) {
    if (playlist != null) {
      final local = playlist.coverLocalPath?.trim();
      if (local != null && local.isNotEmpty) {
        if (local.startsWith('assets/')) return AssetImage(local);
        if (File(local).existsSync()) return FileImage(File(local));
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
    final nav = Get.isRegistered<NavigationController>()
        ? Get.find<NavigationController>()
        : null;
    final existing = playlist.itemIds.toSet();
    final allItems = controller.libraryAudio.where((item) {
      final key = item.publicId.trim().isNotEmpty
          ? item.publicId.trim()
          : item.id.trim();
      return !existing.contains(key);
    }).toList();

    nav?.setOverlayOpen(true);
    final selected = await showModalBottomSheet<List<MediaItem>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return PlaylistSongPickerSheet(
          title: tr('playlists.detail.add_songs'),
          allItems: allItems,
          submitLabelBuilder: (count) =>
              tr('playlists.detail.add_selected', args: ['$count']),
        );
      },
    ).whenComplete(() => nav?.setOverlayOpen(false));
    if (selected == null || selected.isEmpty) return;
    await controller.addItemsToPlaylist(playlist.id, selected);
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

class _PlaylistSortOption extends StatelessWidget {
  const _PlaylistSortOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
    this.ascending,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;
  final bool? ascending;

  @override
  Widget build(BuildContext context) {
    return SortOptionTile(
      icon: icon,
      label: label,
      sublabel: sublabel,
      selected: selected,
      ascending: ascending,
      onTap: onTap,
    );
  }
}

enum _TrackAction { removeFromPlaylist, moreActions }

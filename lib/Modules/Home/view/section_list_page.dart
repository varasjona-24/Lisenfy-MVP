import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/models/media_item.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/themes/app_grid_theme.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/media/media_item_grid.dart';
import '../controller/home_controller.dart';

class SectionListPage extends StatefulWidget {
  const SectionListPage({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
    required this.onItemLongPress,
    this.onShuffle,
    this.itemHintBuilder,
    this.itemTrailingBuilder,
    this.onInterested,
    this.onHideTrack,
    this.onHideArtist,
    this.onDeleteSelected,
    this.itemsRefreshBuilder,
    this.sourceId,
    this.startInSelectionMode = false,
    this.initialSelectionItemId,
    this.forceGrid = false,
    this.rectangularGrid = false,
  });

  final String title;
  final List<MediaItem> items;
  final FutureOr<void> Function(MediaItem item, int index) onItemTap;
  final FutureOr<void> Function(
    MediaItem item,
    int index, {
    VoidCallback? onStartMultiSelect,
  })
  onItemLongPress;
  final void Function(List<MediaItem> queue)? onShuffle;
  final String? Function(MediaItem item, int index)? itemHintBuilder;
  final Widget? Function(MediaItem item, int index)? itemTrailingBuilder;
  final FutureOr<void> Function(MediaItem item, int index)? onInterested;
  final FutureOr<void> Function(MediaItem item, int index)? onHideTrack;
  final FutureOr<void> Function(MediaItem item, int index)? onHideArtist;
  final FutureOr<void> Function(List<MediaItem> items)? onDeleteSelected;
  final FutureOr<List<MediaItem>> Function()? itemsRefreshBuilder;
  final HomeWidgetId? sourceId;
  final bool startInSelectionMode;
  final String? initialSelectionItemId;
  final bool forceGrid;
  final bool rectangularGrid;

  @override
  State<SectionListPage> createState() => _SectionListPageState();
}

class _SectionListPageState extends State<SectionListPage> {
  late List<MediaItem> _items;
  bool _selectionMode = false;
  bool _gridMode = false;
  final GetStorage _storage = GetStorage();
  final LocalLibraryStore _libraryStore = Get.find<LocalLibraryStore>();
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _gridMode = widget.forceGrid
        ? true
        : (_storage.read('section_list_grid_view') ?? false);
    _items = List<MediaItem>.from(widget.items);
    if (widget.startInSelectionMode) {
      _selectionMode = true;
      final initialId = widget.initialSelectionItemId?.trim();
      if (initialId != null && initialId.isNotEmpty) {
        MediaItem? initialItem;
        for (final item in _items) {
          if (item.id == initialId) {
            initialItem = item;
            break;
          }
        }
        if (initialItem != null && _canSelect(initialItem)) {
          _selectedIds.add(initialId);
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant SectionListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _items = List<MediaItem>.from(widget.items);
      _selectedIds.removeWhere((id) => !_items.any((item) => item.id == id));
    }
  }

  bool get _hasFeedbackActions =>
      widget.onInterested != null ||
      widget.onHideTrack != null ||
      widget.onHideArtist != null;

  Future<void> _handleInterested(MediaItem item, int index) async {
    await widget.onInterested?.call(item, index);
    if (mounted) setState(() {});
  }

  Future<void> _handleHideTrack(MediaItem item, int index) async {
    await widget.onHideTrack?.call(item, index);
    if (!mounted) return;
    setState(() {
      _items.removeWhere((entry) => entry.id == item.id);
    });
  }

  Future<void> _handleHideArtist(MediaItem item, int index) async {
    await widget.onHideArtist?.call(item, index);
    if (!mounted) return;
    final artistKey = _artistKeyFromItem(item);
    setState(() {
      _items.removeWhere((entry) => _artistKeyFromItem(entry) == artistKey);
    });
  }

  String _artistKeyFromItem(MediaItem item) {
    final raw = item.displaySubtitle.trim();
    if (raw.isEmpty) return item.title.trim().toLowerCase();
    final normalized = raw
        .split('·')
        .first
        .split(',')
        .first
        .split(' - ')
        .first
        .trim()
        .toLowerCase();
    return normalized.isEmpty ? item.title.trim().toLowerCase() : normalized;
  }

  int get _selectedCount => _selectedIds.length;

  List<MediaItem> get _selectedItems => _items
      .where((item) => _selectedIds.contains(item.id))
      .toList(growable: false);

  bool _canSelect(MediaItem item) => item.isOfflineStored;

  HomeController? get _homeController =>
      Get.isRegistered<HomeController>() ? Get.find<HomeController>() : null;

  bool get _canSortSource {
    final sourceId = widget.sourceId;
    final home = _homeController;
    return sourceId != null &&
        home != null &&
        home.sortOptionsForHomeWidget(sourceId).isNotEmpty;
  }

  void _refreshFromSourceSort() {
    final sourceId = widget.sourceId;
    final home = _homeController;
    if (sourceId == null || home == null) return;
    setState(() {
      _items = home.fullItemsForHomeWidget(sourceId);
      _selectedIds.removeWhere((id) => !_items.any((item) => item.id == id));
    });
  }

  Future<void> _refreshItemsFromStore() async {
    final builder = widget.itemsRefreshBuilder;
    if (builder != null) {
      final refreshed = await builder();
      if (!mounted) return;
      setState(() {
        _items = List<MediaItem>.from(refreshed);
        _selectedIds.removeWhere((id) => !_items.any((item) => item.id == id));
      });
      return;
    }

    final current = List<MediaItem>.from(_items);
    if (current.isEmpty) return;

    final all = await _libraryStore.readAll();
    if (all.isEmpty) return;

    MediaItem? resolve(MediaItem item) {
      for (final candidate in all) {
        if (candidate.id == item.id) return candidate;
      }

      final publicId = item.publicId.trim();
      if (publicId.isEmpty) return null;

      for (final candidate in all) {
        if (candidate.publicId.trim() == publicId) return candidate;
      }

      return null;
    }

    final refreshed = current
        .map(resolve)
        .whereType<MediaItem>()
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _items = refreshed;
      _selectedIds.removeWhere((id) => !_items.any((item) => item.id == id));
    });
  }

  void _toggleSelectionMode([bool? enabled]) {
    setState(() {
      _selectionMode = enabled ?? !_selectionMode;
      if (!_selectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleItemSelection(MediaItem item) {
    if (!_canSelect(item)) {
      Get.snackbar(
        'Selección',
        'Este item no tiene archivo local para borrar.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  void _startMultiSelectFromItem(MediaItem item) {
    if (!_canSelect(item)) {
      Get.snackbar(
        'Selección',
        'Este item no tiene archivo local para borrar.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    setState(() {
      _selectionMode = true;
      _selectedIds.add(item.id);
    });
  }

  Future<void> _deleteSelectedItems() async {
    final selectedItems = _selectedItems;
    final selectedIds = selectedItems.map((e) => e.id).toSet();
    if (selectedItems.isEmpty) {
      Get.snackbar(
        'Selección',
        'No hay items seleccionados.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (widget.onDeleteSelected != null) {
      await widget.onDeleteSelected!.call(selectedItems);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((item) => selectedIds.contains(item.id));
        _selectedIds.removeWhere((id) => selectedIds.contains(id));
        _selectionMode = false;
      });
      return;
    }

    final actions = Get.find<MediaActionsController>();

    await actions.confirmDeleteMultiple(
      context,
      selectedItems,
      onChanged: () async {
        if (!mounted) return;
        setState(() {
          _items.removeWhere((item) => selectedIds.contains(item.id));
          _selectedIds.removeWhere((id) => selectedIds.contains(id));
          _selectionMode = false;
        });
        if (Get.isRegistered<HomeController>()) {
          await Get.find<HomeController>().loadHome();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: _selectionMode
            ? Text(
                'Seleccionados: $_selectedCount',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              )
            : ListenfyLogo(size: 28, color: scheme.primary),
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        actions: _selectionMode
            ? [
                IconButton(
                  tooltip: 'Borrar seleccionados',
                  onPressed: _selectedCount == 0 ? null : _deleteSelectedItems,
                  icon: const Icon(Icons.delete_sweep_rounded),
                ),
                IconButton(
                  tooltip: 'Cancelar selección',
                  onPressed: () => _toggleSelectionMode(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]
            : [
                if (!widget.forceGrid)
                  IconButton(
                    tooltip: _gridMode
                        ? 'Vista de cuadrícula'
                        : 'Vista de lista',
                    onPressed: () {
                      setState(() {
                        _gridMode = !_gridMode;
                        _storage.write('section_list_grid_view', _gridMode);
                      });
                    },
                    icon: Icon(
                      _gridMode
                          ? Icons.grid_view_rounded
                          : Icons.view_list_rounded,
                    ),
                  ),
                if (_canSortSource)
                  IconButton(
                    tooltip: 'Ordenar',
                    onPressed: () => _openSortSheet(context),
                    icon: const Icon(Icons.sort_rounded),
                  ),
                IconButton(
                  tooltip: 'Seleccionar varios',
                  onPressed: _items.any(_canSelect)
                      ? () => _toggleSelectionMode(true)
                      : null,
                  icon: const Icon(Icons.checklist_rounded),
                ),
              ],
      ),
      body: AppGradientBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_selectionMode) {
              return _buildIconSelectionView(theme, constraints.maxWidth);
            }
            if (_gridMode) {
              return _buildDefaultGridView(theme, constraints.maxWidth);
            }
            return _buildDefaultListView(theme);
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (widget.onShuffle != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final queue = List<MediaItem>.from(_items);
                queue.shuffle(Random());
                if (queue.isEmpty) return;
                widget.onShuffle?.call(queue);
              },
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Reproducción aleatoria'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Future<void> _openSortSheet(BuildContext context) async {
    final sourceId = widget.sourceId;
    final home = _homeController;
    if (sourceId == null || home == null) return;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nav = Get.isRegistered<NavigationController>()
        ? Get.find<NavigationController>()
        : null;
    nav?.setOverlayOpen(true);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Obx(() {
          final selected = home.sortForHomeWidget(sourceId);
          final asc = home.sortAscendingForHomeWidget(sourceId);
          final options = home.sortOptionsForHomeWidget(sourceId);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ordenar',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final option in options)
                    _SortOption(
                      icon: option.icon,
                      label: option.label,
                      selected: selected == option,
                      onTap: () {
                        home.setHomeWidgetSort(sourceId, option);
                        _refreshFromSourceSort();
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  _SortOption(
                    icon: Icons.south_rounded,
                    label: _directionLabel(home, sourceId, ascending: false),
                    selected: !asc,
                    onTap: () {
                      home.setHomeWidgetSortAscending(sourceId, false);
                      _refreshFromSourceSort();
                    },
                  ),
                  _SortOption(
                    icon: Icons.north_rounded,
                    label: _directionLabel(home, sourceId, ascending: true),
                    selected: asc,
                    onTap: () {
                      home.setHomeWidgetSortAscending(sourceId, true);
                      _refreshFromSourceSort();
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Aceptar'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    ).whenComplete(() => nav?.setOverlayOpen(false));
  }

  String _directionLabel(
    HomeController home,
    HomeWidgetId sourceId, {
    required bool ascending,
  }) {
    final sort = home.sortForHomeWidget(sourceId);
    return switch (sort) {
      HomeMediaSort.title || HomeMediaSort.artist => ascending ? 'A-Z' : 'Z-A',
      HomeMediaSort.importedAt || HomeMediaSort.recent =>
        ascending ? 'Más antiguo primero' : 'Más reciente primero',
      HomeMediaSort.plays ||
      HomeMediaSort.size ||
      HomeMediaSort.duration => ascending ? 'Menor a mayor' : 'Mayor a menor',
    };
  }

  Future<void> _openItem(MediaItem item, int index) async {
    final sourceId = widget.sourceId;
    final home = _homeController;
    if (sourceId != null && home != null) {
      await home.openMedia(item, index, _items);
      return;
    }
    await widget.onItemTap(item, index);
  }

  Widget _buildDefaultListView(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      itemCount: _items.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSectionHeader(theme);
        }

        final item = _items[index - 1];
        final itemIndex = index - 1;
        return _MediaRow(
          item: item,
          videoStyle: widget.rectangularGrid,
          hintText: widget.itemHintBuilder?.call(item, itemIndex),
          trailing: widget.itemTrailingBuilder?.call(item, itemIndex),
          selectionMode: _selectionMode,
          selected: _selectedIds.contains(item.id),
          selectable: _canSelect(item),
          onToggleSelection: () => _toggleItemSelection(item),
          onTap: () async {
            if (_selectionMode) {
              _toggleItemSelection(item);
              return;
            }
            await _openItem(item, itemIndex);
            if (mounted) setState(() {});
          },
          onLongPress: () async {
            if (_selectionMode) {
              _toggleItemSelection(item);
              return;
            }
            await widget.onItemLongPress(
              item,
              itemIndex,
              onStartMultiSelect: () => _startMultiSelectFromItem(item),
            );
            await _refreshItemsFromStore();
          },
          showFeedbackActions: _hasFeedbackActions,
          onInterested: widget.onInterested == null
              ? null
              : () => _handleInterested(item, itemIndex),
          onHideTrack: widget.onHideTrack == null
              ? null
              : () => _handleHideTrack(item, itemIndex),
          onHideArtist: widget.onHideArtist == null
              ? null
              : () => _handleHideArtist(item, itemIndex),
          onSelectMultiple: _canSelect(item)
              ? () => _startMultiSelectFromItem(item)
              : null,
        );
      },
    );
  }

  Widget _buildDefaultGridView(ThemeData theme, double maxWidth) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(child: _buildSectionHeader(theme)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          sliver: MediaItemSliverGrid(
            items: _items,
            childAspectRatio: widget.rectangularGrid
                ? AppGridTheme.videoChildAspectRatio
                : AppGridTheme.childAspectRatio,
            coverAspectRatio: widget.rectangularGrid ? 16 / 9 : 1,
            crossAxisCount: null,
            fallbackIcon: widget.rectangularGrid
                ? Icons.videocam_rounded
                : Icons.music_note_rounded,
            hintBuilder: widget.itemHintBuilder,
            coverOverlayBuilder: widget.sourceId == HomeWidgetId.mostPlayed
                ? (item, index) => _PlayCountCoverBadge(item: item)
                : null,
            onTap: (item, index) async {
              await _openItem(item, index);
              if (mounted) setState(() {});
            },
            onLongPress: (item, index) async {
              await widget.onItemLongPress(
                item,
                index,
                onStartMultiSelect: () => _startMultiSelectFromItem(item),
              );
              await _refreshItemsFromStore();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIconSelectionView(ThemeData theme, double maxWidth) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(child: _buildSectionHeader(theme)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          sliver: MediaItemSliverGrid(
            items: _items,
            childAspectRatio: widget.rectangularGrid
                ? AppGridTheme.videoChildAspectRatio
                : AppGridTheme.childAspectRatio,
            coverAspectRatio: widget.rectangularGrid ? 16 / 9 : 1,
            crossAxisCount: null,
            fallbackIcon: widget.rectangularGrid
                ? Icons.videocam_rounded
                : Icons.music_note_rounded,
            selectionMode: true,
            selectedBuilder: (item, index) => _selectedIds.contains(item.id),
            selectableBuilder: (item, index) => _canSelect(item),
            onTap: (item, index) => _toggleItemSelection(item),
            onSelectionTap: (item, index) => _toggleItemSelection(item),
          ),
        ),
      ],
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.item,
    required this.videoStyle,
    required this.hintText,
    required this.trailing,
    required this.onTap,
    required this.onLongPress,
    required this.showFeedbackActions,
    required this.selectionMode,
    required this.selected,
    required this.selectable,
    required this.onToggleSelection,
    this.onInterested,
    this.onHideTrack,
    this.onHideArtist,
    this.onSelectMultiple,
  });

  final MediaItem item;
  final bool videoStyle;
  final String? hintText;
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool showFeedbackActions;
  final bool selectionMode;
  final bool selected;
  final bool selectable;
  final VoidCallback onToggleSelection;
  final FutureOr<void> Function()? onInterested;
  final FutureOr<void> Function()? onHideTrack;
  final FutureOr<void> Function()? onHideArtist;
  final FutureOr<void> Function()? onSelectMultiple;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(videoStyle ? 12 : 16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.all(videoStyle ? 0 : 10),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : (videoStyle ? Colors.transparent : scheme.surfaceContainerHigh),
          borderRadius: BorderRadius.circular(videoStyle ? 12 : 16),
          border: selected
              ? Border.all(
                  color: scheme.primary.withValues(alpha: 0.55),
                  width: 1.2,
                )
              : null,
        ),
        child: Row(
          children: [
            _Thumb(
              thumb: item.effectiveThumbnail,
              videoStyle: videoStyle,
              durationSeconds: item.effectiveDurationSeconds,
            ),
            SizedBox(width: videoStyle ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: videoStyle
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  if (videoStyle) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if ((item.localVideoVariant?.format ?? '')
                            .trim()
                            .isNotEmpty)
                          _VideoMetaChip(
                            label: item.localVideoVariant!.format
                                .trim()
                                .toUpperCase(),
                          ),
                        if ((item.localVideoVariant?.size ?? 0) > 0)
                          _VideoMetaChip(
                            label: _formatVideoSize(
                              item.localVideoVariant!.size!,
                            ),
                          ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      item.displaySubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if ((hintText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        hintText!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (selectionMode)
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: selectable ? onToggleSelection : null,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : (selectable
                              ? Icons.radio_button_unchecked_rounded
                              : Icons.block_rounded),
                    color: selected
                        ? scheme.primary
                        : (selectable
                              ? scheme.onSurfaceVariant
                              : scheme.outline),
                    size: 22,
                  ),
                ),
              )
            else if (showFeedbackActions && !videoStyle)
              PopupMenuButton<_FeedbackAction>(
                tooltip: 'Feedback',
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (value) async {
                  switch (value) {
                    case _FeedbackAction.selectMultiple:
                      await onSelectMultiple?.call();
                      break;
                    case _FeedbackAction.interested:
                      await onInterested?.call();
                      break;
                    case _FeedbackAction.hideTrack:
                      await onHideTrack?.call();
                      break;
                    case _FeedbackAction.hideArtist:
                      await onHideArtist?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (onSelectMultiple != null)
                    PopupMenuItem(
                      value: _FeedbackAction.selectMultiple,
                      child: Row(
                        children: [
                          Icon(
                            Icons.checklist_rounded,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 10),
                          const Text('Seleccionar varios'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: _FeedbackAction.interested,
                    child: Row(
                      children: [
                        Icon(
                          Icons.thumb_up_alt_outlined,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 10),
                        const Text('Me interesa'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _FeedbackAction.hideTrack,
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 18,
                          color: scheme.error,
                        ),
                        const SizedBox(width: 10),
                        const Text('Ocultar canción'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _FeedbackAction.hideArtist,
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 18,
                          color: scheme.tertiary,
                        ),
                        const SizedBox(width: 10),
                        const Text('Ocultar artista'),
                      ],
                    ),
                  ),
                ],
              ),
            if (showFeedbackActions && !videoStyle) const SizedBox(width: 4),
            trailing ??
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: scheme.primary),
                ),
          ],
        ),
      ),
    );
  }

  String _formatVideoSize(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final text = value >= 10 || unitIndex == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text ${units[unitIndex]}';
  }
}

enum _FeedbackAction { selectMultiple, interested, hideTrack, hideArtist }

class _PlayCountCoverBadge extends StatelessWidget {
  const _PlayCountCoverBadge({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: scheme.scrim.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.38)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.remove_red_eye_rounded, size: 13, color: scheme.primary),
          Text(
            '${item.playCount}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w900,
              height: 0.95,
            ),
          ),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.thumb,
    required this.videoStyle,
    required this.durationSeconds,
  });

  final String? thumb;
  final bool videoStyle;
  final int? durationSeconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (thumb != null && thumb!.isNotEmpty) {
      final provider = thumb!.startsWith('http')
          ? NetworkImage(thumb!)
          : FileImage(File(thumb!)) as ImageProvider;
      return ClipRRect(
        borderRadius: BorderRadius.circular(videoStyle ? 14 : 12),
        child: Stack(
          children: [
            Image(
              key: ValueKey<String>(thumb!),
              image: provider,
              width: videoStyle ? 148 : 56,
              height: videoStyle ? 84 : 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: videoStyle ? 148 : 56,
                height: videoStyle ? 84 : 56,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(videoStyle ? 14 : 12),
                ),
                child: Icon(
                  videoStyle ? Icons.videocam_rounded : Icons.music_note,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (videoStyle)
              Positioned(
                left: 8,
                bottom: 7,
                child: _DurationBadge(seconds: durationSeconds),
              ),
          ],
        ),
      );
    }
    return Container(
      width: videoStyle ? 148 : 56,
      height: videoStyle ? 84 : 56,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(videoStyle ? 14 : 12),
      ),
      child: Icon(
        videoStyle ? Icons.videocam_rounded : Icons.music_note,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _VideoMetaChip extends StatelessWidget {
  const _VideoMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.seconds});

  final int? seconds;

  @override
  Widget build(BuildContext context) {
    final label = _formatDuration(seconds);
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static String? _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

import 'dart:async';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/models/media_item.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/media/app_media_items_view.dart';
import '../../../app/utils/format_bytes.dart';
import '../Controller/home_controller.dart';

class SectionListRouteData {
  const SectionListRouteData({
    required this.title,
    required this.items,
    required this.onItemTap,
    required this.onItemLongPress,
    this.onShuffle,
    this.itemHintBuilder,
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
}

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

  SectionListPage.fromRouteData(SectionListRouteData data, {super.key})
    : title = data.title,
      items = data.items,
      onItemTap = data.onItemTap,
      onItemLongPress = data.onItemLongPress,
      onShuffle = data.onShuffle,
      itemHintBuilder = data.itemHintBuilder,
      itemTrailingBuilder = null,
      onInterested = null,
      onHideTrack = null,
      onHideArtist = null,
      onDeleteSelected = null,
      itemsRefreshBuilder = null,
      sourceId = null,
      startInSelectionMode = false,
      initialSelectionItemId = null,
      forceGrid = false,
      rectangularGrid = false;

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
        'dialogs.selection.title'.tr,
        'dialogs.selection.no_local_file'.tr,
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
        'dialogs.selection.title'.tr,
        'dialogs.selection.no_local_file'.tr,
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
        'dialogs.selection.title'.tr,
        'dialogs.selection.no_items_selected'.tr,
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

  Future<void> _shareSelectedExternally() async {
    final selectedItems = _selectedItems;
    if (selectedItems.isEmpty) {
      Get.snackbar(
        'dialogs.sharing.title'.tr,
        'dialogs.sharing.no_items'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final actions = Get.find<MediaActionsController>();
    await actions.shareMediaExternallyMultiple(selectedItems);
  }

  Future<void> _transferSelectedInternally() async {
    final selectedItems = _selectedItems;
    if (selectedItems.isEmpty) {
      Get.snackbar(
        'dialogs.connect.title'.tr,
        'dialogs.connect.no_items'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final actions = Get.find<MediaActionsController>();
    await actions.transferMediaInternallyMultiple(selectedItems);
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
                tr('home.section.selected', args: ['$_selectedCount']),
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
                  tooltip: tr('home.section.share_external'),
                  onPressed: _selectedCount == 0
                      ? null
                      : _shareSelectedExternally,
                  icon: const Icon(Icons.ios_share_rounded),
                ),
                IconButton(
                  tooltip: tr('home.section.connect_transfer'),
                  onPressed: _selectedCount == 0
                      ? null
                      : _transferSelectedInternally,
                  icon: const Icon(Icons.wifi_tethering_rounded),
                ),
                IconButton(
                  tooltip: tr('home.section.delete_selected'),
                  onPressed: _selectedCount == 0 ? null : _deleteSelectedItems,
                  icon: const Icon(Icons.delete_sweep_rounded),
                ),
                IconButton(
                  tooltip: tr('home.section.cancel_selection'),
                  onPressed: () => _toggleSelectionMode(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]
            : [
                if (!widget.forceGrid)
                  IconButton(
                    tooltip: _gridMode
                        ? tr('home.section.grid_view')
                        : tr('home.section.list_view'),
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
                    tooltip: tr('sources.sort'),
                    onPressed: () => _openSortSheet(context),
                    icon: const Icon(Icons.sort_rounded),
                  ),
                IconButton(
                  tooltip: tr('media_actions.multi_select'),
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
    final selectedItems = _selectedItems;
    final selectedBytes = selectedItems.fold<int>(0, (total, item) {
      final variant = item.localAudioVariant ?? item.localVideoVariant;
      return total + (variant?.size ?? 0);
    });

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
              label: Text(tr('home.section.shuffle')),
            ),
          ),
        ],
        if (_selectionMode) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SelectionInfoChip(
                icon: Icons.check_circle_rounded,
                label: tr(
                  'home.section.selected_count',
                  args: ['$_selectedCount'],
                ),
              ),
              _SelectionInfoChip(
                icon: Icons.sd_storage_rounded,
                label: selectedBytes > 0
                    ? formatBytes(selectedBytes)
                    : tr('home.section.calculating_size'),
              ),
            ],
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
                      child: Text(tr('common.accept')),
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
        ascending
            ? tr('home.section.oldest_first')
            : tr('home.section.newest_first'),
      HomeMediaSort.plays || HomeMediaSort.size || HomeMediaSort.duration =>
        ascending
            ? tr('home.section.low_to_high')
            : tr('home.section.high_to_low'),
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
        return AppMediaActionListTile(
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
        AppMediaItemsSliver(
          items: _items,
          gridView: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          videoStyle: widget.rectangularGrid,
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
        AppMediaItemsSliver(
          items: _items,
          gridView: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          videoStyle: widget.rectangularGrid,
          selectionMode: true,
          selectedBuilder: (item, index) => _selectedIds.contains(item.id),
          selectableBuilder: (item, index) => _canSelect(item),
          onTap: (item, index) => _toggleItemSelection(item),
          onSelectionTap: (item, index) => _toggleItemSelection(item),
        ),
      ],
    );
  }
}

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

class _SelectionInfoChip extends StatelessWidget {
  const _SelectionInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
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

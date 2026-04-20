import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/models/media_item.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/ui/themes/app_spacing.dart';
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
    this.startInSelectionMode = false,
    this.initialSelectionItemId,
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
  final bool startInSelectionMode;
  final String? initialSelectionItemId;

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
    _gridMode = _storage.read('section_list_grid_view') ?? false;
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

  Future<void> _refreshItemsFromStore() async {
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
        .map((item) => resolve(item) ?? item)
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
                IconButton(
                  tooltip: _gridMode ? 'Vista de cuadrícula' : 'Vista de lista',
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
            await widget.onItemTap(item, itemIndex);
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
            hintBuilder: widget.itemHintBuilder,
            onTap: (item, index) async {
              await widget.onItemTap(item, index);
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
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(
                  color: scheme.primary.withValues(alpha: 0.55),
                  width: 1.2,
                )
              : null,
        ),
        child: Row(
          children: [
            _Thumb(thumb: item.effectiveThumbnail),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
            else if (showFeedbackActions)
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
            if (showFeedbackActions) const SizedBox(width: 4),
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
}

enum _FeedbackAction { selectMultiple, interested, hideTrack, hideArtist }

class _Thumb extends StatelessWidget {
  const _Thumb({required this.thumb});

  final String? thumb;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (thumb != null && thumb!.isNotEmpty) {
      final provider = thumb!.startsWith('http')
          ? NetworkImage(thumb!)
          : FileImage(File(thumb!)) as ImageProvider;
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          key: ValueKey<String>(thumb!),
          image: provider,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.music_note, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.music_note, color: scheme.onSurfaceVariant),
    );
  }
}

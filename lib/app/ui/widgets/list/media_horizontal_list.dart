import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../themes/app_spacing.dart';
import '../cards/media_card.dart';
import '../cards/media_cart_skeletton.dart';

class MediaHorizontalList extends StatefulWidget {
  final String title;
  final List<MediaItem> items;
  final bool isLoading;
  final void Function(MediaItem item, int index) onItemTap;
  final FutureOr<void> Function(
    MediaItem item,
    int index, {
    VoidCallback? onStartMultiSelect,
  })?
  onItemLongPress;
  final FutureOr<void> Function(List<MediaItem> items)? onDeleteSelected;
  final VoidCallback? onHeaderTap;
  final Widget? headerTrailing;
  final String? Function(MediaItem item, int index)? itemHintBuilder;

  const MediaHorizontalList({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
    this.onItemLongPress,
    this.onDeleteSelected,
    this.isLoading = false,
    this.onHeaderTap,
    this.headerTrailing,
    this.itemHintBuilder,
  });

  @override
  State<MediaHorizontalList> createState() => _MediaHorizontalListState();
}

class _MediaHorizontalListState extends State<MediaHorizontalList> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

  bool _canSelect(MediaItem item) => item.isOfflineStored;

  int get _selectedCount => _selectedIds.length;

  List<MediaItem> get _selectedItems => widget.items
      .where((item) => _selectedIds.contains(item.id))
      .toList(growable: false);

  @override
  void didUpdateWidget(covariant MediaHorizontalList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _selectedIds.removeWhere((id) => !widget.items.any((it) => it.id == id));
      if (_selectionMode && _selectedIds.isEmpty) {
        _selectionMode = false;
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  void _startMultiSelectFromItem(MediaItem item) {
    if (!_canSelect(item)) {
      _showMessage('Este item no tiene archivo local para borrar.');
      return;
    }
    setState(() {
      _selectionMode = true;
      _selectedIds.add(item.id);
    });
  }

  void _toggleSelection(MediaItem item) {
    if (!_canSelect(item)) {
      _showMessage('Este item no tiene archivo local para borrar.');
      return;
    }
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
      if (_selectionMode && _selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (widget.onDeleteSelected == null) return;
    final selectedItems = _selectedItems;
    if (selectedItems.isEmpty) {
      _showMessage('No hay items seleccionados.');
      return;
    }
    await widget.onDeleteSelected!(selectedItems);
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
    );

    Widget header() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _selectionMode ? null : widget.onHeaderTap,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectionMode
                          ? '${widget.title} · $_selectedCount seleccionados'
                          : widget.title,
                      style: titleStyle,
                    ),
                  ),
                  if (!_selectionMode)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
          if (_selectionMode) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Borrar seleccionados',
              onPressed: _selectedCount == 0 || widget.onDeleteSelected == null
                  ? null
                  : _deleteSelected,
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
            IconButton(
              tooltip: 'Cancelar selección',
              onPressed: () {
                setState(() {
                  _selectionMode = false;
                  _selectedIds.clear();
                });
              },
              icon: const Icon(Icons.close_rounded),
            ),
          ] else if (widget.headerTrailing != null) ...[
            const SizedBox(width: 8),
            widget.headerTrailing!,
          ],
        ],
      ),
    );

    if (widget.isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header(),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, __) => const MediaCardSkeleton(),
            ),
          ),
        ],
      );
    }

    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header(),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: widget.itemHintBuilder == null ? 200 : 216,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            scrollDirection: Axis.horizontal,
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final selected = _selectedIds.contains(item.id);
              final selectable = _canSelect(item);

              final card = MediaCard(
                item: item,
                width: 120,
                showPlayBadge: !_selectionMode,
                hintText: widget.itemHintBuilder?.call(item, index),
                onTap: () {
                  if (_selectionMode) {
                    _toggleSelection(item);
                    return;
                  }
                  widget.onItemTap(item, index);
                },
                onLongPress: widget.onItemLongPress == null
                    ? null
                    : () {
                        if (_selectionMode) {
                          _toggleSelection(item);
                          return;
                        }
                        widget.onItemLongPress!(
                          item,
                          index,
                          onStartMultiSelect: () =>
                              _startMultiSelectFromItem(item),
                        );
                      },
              );

              if (!_selectionMode) return card;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: selected
                          ? Border.all(
                              color: scheme.primary.withValues(alpha: 0.72),
                              width: 2,
                            )
                          : null,
                    ),
                    child: Opacity(opacity: selectable ? 1 : 0.6, child: card),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : (selectable
                                ? Icons.radio_button_unchecked_rounded
                                : Icons.block_rounded),
                      size: 22,
                      color: selected
                          ? scheme.primary
                          : (selectable ? scheme.onSurface : scheme.outline),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

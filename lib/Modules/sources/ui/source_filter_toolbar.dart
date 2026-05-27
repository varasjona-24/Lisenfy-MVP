import 'package:flutter/material.dart';

class SourceFilterToolbar extends StatelessWidget {
  const SourceFilterToolbar({
    super.key,
    required this.controller,
    required this.query,
    required this.hintText,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onSort,
    this.gridView,
    this.onToggleGridView,
    this.gridTooltip,
    this.listTooltip,
  });

  final TextEditingController controller;
  final String query;
  final String hintText;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final VoidCallback onSort;
  final bool? gridView;
  final VoidCallback? onToggleGridView;
  final String? gridTooltip;
  final String? listTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showViewToggle = gridView != null && onToggleGridView != null;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: controller,
              onChanged: onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        onPressed: onClearQuery,
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
        IconButton(
          tooltip: 'Ordenar',
          onPressed: onSort,
          icon: const Icon(Icons.sort_rounded),
        ),
        if (showViewToggle) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: gridView!
                ? (listTooltip ?? 'Ver como lista')
                : (gridTooltip ?? 'Ver como grid'),
            onPressed: onToggleGridView,
            icon: Icon(
              gridView! ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

import '../domain/capture_gallery_sort.dart';

class CaptureSortSheet extends StatelessWidget {
  const CaptureSortSheet({
    super.key,
    required this.currentSort,
    required this.ascending,
    required this.directionLabel,
    required this.onPick,
  });

  final CaptureSort currentSort;
  final bool ascending;
  final String Function(CaptureSort sort) directionLabel;
  final ValueChanged<CaptureSort> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('captures.cover.sort_title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            _SortOption(
              icon: Icons.access_time_rounded,
              label: tr('captures.tags.age'),
              sublabel: directionLabel(CaptureSort.date),
              selected: currentSort == CaptureSort.date,
              ascending: currentSort == CaptureSort.date ? ascending : null,
              onTap: () => onPick(CaptureSort.date),
            ),
            const SizedBox(height: 6),
            _SortOption(
              icon: Icons.data_usage_rounded,
              label: tr('edit.weight'),
              sublabel: directionLabel(CaptureSort.size),
              selected: currentSort == CaptureSort.size,
              ascending: currentSort == CaptureSort.size ? ascending : null,
              onTap: () => onPick(CaptureSort.size),
            ),
            const SizedBox(height: 6),
            _SortOption(
              icon: Icons.sort_by_alpha_rounded,
              label: tr('captures.tags.name'),
              sublabel: directionLabel(CaptureSort.name),
              selected: currentSort == CaptureSort.name,
              ascending: currentSort == CaptureSort.name ? ascending : null,
              onTap: () => onPick(CaptureSort.name),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('common.accept')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
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
  final bool? ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                ascending == true
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 18,
                color: scheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

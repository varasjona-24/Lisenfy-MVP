import 'package:flutter/material.dart';

import '../../domain/entities/download_history_filter.dart';

class DownloadHistoryFilterRow extends StatelessWidget {
  const DownloadHistoryFilterRow({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final DownloadHistoryFilter selected;
  final ValueChanged<DownloadHistoryFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'Música',
          icon: Icons.music_note_rounded,
          isSelected: selected == DownloadHistoryFilter.audio,
          onTap: () => onSelect(DownloadHistoryFilter.audio),
        ),
        const SizedBox(width: 12),
        _FilterChip(
          label: 'Videos',
          icon: Icons.videocam_rounded,
          isSelected: selected == DownloadHistoryFilter.video,
          onTap: () => onSelect(DownloadHistoryFilter.video),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? scheme.primary : scheme.surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

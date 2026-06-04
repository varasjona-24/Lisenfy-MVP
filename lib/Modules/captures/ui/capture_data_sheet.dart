import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/capture_item.dart';

class CaptureDataSheet extends StatelessWidget {
  const CaptureDataSheet({
    super.key,
    required this.capture,
    required this.onRename,
    required this.onEditTags,
  });

  final CaptureItem capture;
  final VoidCallback onRename;
  final VoidCallback onEditTags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(capture.path),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: const SizedBox(
                        width: 72,
                        height: 72,
                        child: Icon(Icons.image_not_supported_rounded),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capture.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Captura de video',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DataRow(
              icon: Icons.badge_outlined,
              label: 'Nombre',
              value: capture.name,
              onTap: onRename,
            ),
            _DataRow(
              icon: Icons.storage_rounded,
              label: 'Peso',
              value: _formatBytes(capture.size),
            ),
            _DataRow(
              icon: Icons.calendar_month_rounded,
              label: 'Fecha de captura',
              value: _formatDate(capture.modifiedAt),
            ),
            _DataRow(
              icon: Icons.sell_outlined,
              label: 'Etiqueta',
              value: capture.tags.isEmpty
                  ? 'Sin etiqueta'
                  : capture.tags.map((tag) => '#$tag').join(', '),
              onTap: onEditTags,
            ),
            _DataRow(
              icon: Icons.movie_filter_rounded,
              label: 'Fuente',
              value: capture.sourceTitle?.isNotEmpty == true
                  ? capture.sourceTitle!
                  : 'Fuente no registrada',
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final decimals = unit == 0 || value >= 100 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
  }

  static String _formatDate(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: scheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

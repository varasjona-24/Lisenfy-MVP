import 'package:flutter/material.dart';

import '../domain/capture_item.dart';

class CaptureActionSheet extends StatelessWidget {
  const CaptureActionSheet({
    super.key,
    required this.capture,
    required this.onShare,
    required this.onUseAsCover,
    required this.onEditTags,
    required this.onRename,
    required this.onDelete,
  });

  final CaptureItem capture;
  final VoidCallback onShare;
  final VoidCallback onUseAsCover;
  final VoidCallback onEditTags;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              capture.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _BottomSheetOption(
              icon: Icons.bluetooth_searching_rounded,
              label: 'Compartir externo',
              onTap: onShare,
            ),
            const SizedBox(height: 8),
            _BottomSheetOption(
              icon: Icons.image_rounded,
              label: 'Usar como portada',
              onTap: onUseAsCover,
            ),
            const SizedBox(height: 8),
            _BottomSheetOption(
              icon: Icons.sell_outlined,
              label: 'Editar etiquetas',
              onTap: onEditTags,
            ),
            const SizedBox(height: 8),
            _BottomSheetOption(
              icon: Icons.drive_file_rename_outline_rounded,
              label: 'Renombrar',
              onTap: onRename,
            ),
            const SizedBox(height: 8),
            _BottomSheetOption(
              icon: Icons.delete_outline_rounded,
              label: 'Eliminar',
              destructive: true,
              onTap: onDelete,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetOption extends StatelessWidget {
  const _BottomSheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = destructive ? scheme.error : scheme.onSurface;
    final bg = destructive
        ? scheme.errorContainer.withValues(alpha: .18)
        : scheme.surfaceContainerHighest.withValues(alpha: .55);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (destructive ? scheme.error : scheme.outlineVariant)
                .withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

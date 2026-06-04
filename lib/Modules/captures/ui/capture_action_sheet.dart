import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/capture_item.dart';

class CaptureActionSheet extends StatelessWidget {
  const CaptureActionSheet({
    super.key,
    required this.capture,
    required this.onShare,
    required this.onData,
    required this.onUseAsCover,
    required this.onEditTags,
    required this.onRename,
    required this.onDelete,
  });

  final CaptureItem capture;
  final VoidCallback onShare;
  final VoidCallback onData;
  final VoidCallback onUseAsCover;
  final VoidCallback onEditTags;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: Image.file(
                          File(capture.path),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: const Icon(Icons.image_rounded),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            capture.sourceTitle?.isNotEmpty == true
                                ? 'Fuente: ${capture.sourceTitle}'
                                : 'Captura de video',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _BottomSheetOption(
                icon: Icons.info_outline_rounded,
                label: 'Datos de captura',
                onTap: onData,
              ),
              _BottomSheetOption(
                icon: Icons.drive_file_rename_outline_rounded,
                label: 'Cambiar nombre',
                onTap: onRename,
              ),
              _BottomSheetOption(
                icon: Icons.sell_outlined,
                label: 'Editar etiqueta',
                onTap: onEditTags,
              ),
              _BottomSheetOption(
                icon: Icons.ios_share_rounded,
                label: 'Compartir externo',
                onTap: onShare,
              ),
              _BottomSheetOption(
                icon: Icons.image_rounded,
                label: 'Usar como portada',
                onTap: onUseAsCover,
              ),
              _BottomSheetOption(
                icon: Icons.delete_outline_rounded,
                label: 'Eliminar',
                destructive: true,
                onTap: onDelete,
              ),
              const SizedBox(height: 12),
            ],
          ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (destructive ? scheme.error : scheme.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: destructive ? scheme.error : scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.outlineVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

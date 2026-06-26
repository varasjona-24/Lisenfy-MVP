import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/navigation_controller.dart';

class SourceCollectionCard extends StatefulWidget {
  const SourceCollectionCard({
    super.key,
    required this.name,
    required this.itemCount,
    required this.childCollectionCount,
    required this.baseColor,
    this.coverLocalPath,
    this.coverUrl,
    this.gridStyle = false,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    this.completedCount,
  });

  final String name;
  final int itemCount;
  final int childCollectionCount;
  final Color baseColor;
  final String? coverLocalPath;
  final String? coverUrl;
  final bool gridStyle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int? completedCount;

  @override
  State<SourceCollectionCard> createState() => _SourceCollectionCardState();
}

class _SourceCollectionCardState extends State<SourceCollectionCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = widget.baseColor;
    final scale = _isPressed ? 0.97 : (_isHovered ? 1.01 : 1.0);
    final onTint = scheme.onSurface;
    final provider = _imageProvider();

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onOpen();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: Colors.transparent,
              child: widget.gridStyle
                  ? _buildGridCard(theme, scheme, base, onTint, provider)
                  : _buildListCard(theme, scheme, base, onTint, provider),
            ),
          ),
        ),
      ),
    );
  }

  ImageProvider? _imageProvider() {
    final path = widget.coverLocalPath?.trim();
    final url = widget.coverUrl?.trim();
    if (path != null && path.isNotEmpty) {
      return FileImage(File(path));
    }
    if (url != null && url.isNotEmpty) {
      return NetworkImage(url);
    }
    return null;
  }

  Widget _buildGridCard(
    ThemeData theme,
    ColorScheme scheme,
    Color base,
    Color onTint,
    ImageProvider? provider,
  ) {
    final isAllCompleted =
        widget.completedCount != null &&
        widget.itemCount > 0 &&
        widget.completedCount == widget.itemCount;

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          base.withValues(alpha: 0.36),
          scheme.surfaceContainerHighest,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isHovered
              ? base.withValues(alpha: 0.85)
              : base.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: _buildCoverStack(
                width: double.infinity,
                height: double.infinity,
                base: base,
                onTint: onTint,
                provider: provider,
                isAllCompleted: isAllCompleted,
                scheme: scheme,
                theme: theme,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onTint,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: _actionsButton(onTint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _metrics(onTint),
                  _buildProgressBar(theme, scheme, onTint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(
    ThemeData theme,
    ColorScheme scheme,
    Color base,
    Color onTint,
    ImageProvider? provider,
  ) {
    final isAllCompleted =
        widget.completedCount != null &&
        widget.itemCount > 0 &&
        widget.completedCount == widget.itemCount;

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          base.withValues(alpha: 0.34),
          scheme.surfaceContainerHighest,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isHovered
              ? base.withValues(alpha: 0.85)
              : base.withValues(alpha: 0.48),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 116,
                height: 65,
                child: _buildCoverStack(
                  width: 116,
                  height: 65,
                  base: base,
                  onTint: onTint,
                  provider: provider,
                  isAllCompleted: isAllCompleted,
                  scheme: scheme,
                  theme: theme,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onTint,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _metrics(onTint),
                  _buildProgressBar(theme, scheme, onTint),
                ],
              ),
            ),
            _actionsButton(onTint),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverStack({
    required double width,
    required double height,
    required Color base,
    required Color onTint,
    required ImageProvider? provider,
    required bool isAllCompleted,
    required ColorScheme scheme,
    required ThemeData theme,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: base.withValues(alpha: 0.16),
            child: provider != null
                ? Image(image: provider, fit: BoxFit.cover)
                : Icon(
                    Icons.folder_rounded,
                    color: onTint,
                    size: width > 110 ? 34 : 32,
                  ),
          ),
        ),
        if (isAllCompleted)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 8,
                    color: scheme.onPrimary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'COMPLETADO',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 7.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar(ThemeData theme, ColorScheme scheme, Color onTint) {
    if (widget.completedCount == null || widget.itemCount <= 0) {
      return const SizedBox.shrink();
    }
    final completed = widget.completedCount!;
    final total = widget.itemCount;
    final percentage = (completed / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 3.5,
                  backgroundColor: onTint.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completed == total
                        ? scheme.primary
                        : scheme.primary.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              tr('sources.completed_count', args: ['$completed', '$total']),
              style: theme.textTheme.labelSmall?.copyWith(
                color: onTint.withValues(alpha: 0.7),
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metrics(Color onTint) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _SourceCollectionMetricChip(
          icon: Icons.library_music_rounded,
          label: '${widget.itemCount}',
          color: onTint,
        ),
        if (widget.childCollectionCount > 0)
          _SourceCollectionMetricChip(
            icon: Icons.folder_copy_rounded,
            label: '${widget.childCollectionCount}',
            color: onTint,
          ),
      ],
    );
  }

  Widget _actionsButton(Color onTint) {
    return IconButton(
      tooltip: tr('sources.options'),
      onPressed: _openActionsSheet,
      icon: Icon(Icons.more_vert_rounded, color: onTint.withValues(alpha: 0.9)),
    );
  }

  Future<void> _openActionsSheet() async {
    _setOverlayOpen(true);
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(tr('sources.edit')),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onEdit();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: scheme.error,
                ),
                title: Text(
                  tr('common.delete'),
                  style: TextStyle(color: scheme.error),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onDelete();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).whenComplete(() => _setOverlayOpen(false));
  }
}

void _setOverlayOpen(bool value) {
  if (!Get.isRegistered<NavigationController>()) return;
  Get.find<NavigationController>().setOverlayOpen(value);
}

class _SourceCollectionMetricChip extends StatelessWidget {
  const _SourceCollectionMetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.88)),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

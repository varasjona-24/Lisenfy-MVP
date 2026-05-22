import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/navigation_controller.dart';
import '../domain/source_theme.dart';
import '../domain/source_theme_topic_playlist.dart';

// ============================
// 🧱 UI: CARD DE PLAYLIST
// ============================
class SourcePlaylistCard extends StatefulWidget {
  const SourcePlaylistCard({
    super.key,
    required this.theme,
    required this.playlist,
    this.childListCount = 0,
    this.gridStyle = false,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final SourceTheme theme;
  final SourceThemeTopicPlaylist playlist;
  final int childListCount;
  final bool gridStyle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<SourcePlaylistCard> createState() => _SourcePlaylistCardState();
}

class _SourcePlaylistCardState extends State<SourcePlaylistCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final playlist = widget.playlist;
    final base = playlist.colorValue != null
        ? Color(playlist.colorValue!)
        : widget.theme.colors.first;
    final scheme = t.colorScheme;
    final scale = _isPressed ? 0.97 : (_isHovered ? 1.01 : 1.0);
    final onTint = _foregroundFor(base, scheme);

    ImageProvider? provider;
    final path = playlist.coverLocalPath?.trim();
    final url = playlist.coverUrl?.trim();
    if (path != null && path.isNotEmpty) {
      provider = FileImage(File(path));
    } else if (url != null && url.isNotEmpty) {
      provider = NetworkImage(url);
    }

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
                  ? _buildGridCard(
                      context: context,
                      theme: t,
                      scheme: scheme,
                      base: base,
                      onTint: onTint,
                      provider: provider,
                      playlist: playlist,
                    )
                  : _buildListCard(
                      theme: t,
                      scheme: scheme,
                      base: base,
                      onTint: onTint,
                      provider: provider,
                      playlist: playlist,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard({
    required BuildContext context,
    required ThemeData theme,
    required ColorScheme scheme,
    required Color base,
    required Color onTint,
    required ImageProvider? provider,
    required SourceThemeTopicPlaylist playlist,
  }) {
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
              child: Container(
                color: base.withValues(alpha: 0.16),
                child: provider != null
                    ? Image(image: provider, fit: BoxFit.cover)
                    : Icon(Icons.folder_rounded, color: onTint, size: 34),
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
                          playlist.name,
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
                        child: _playlistMenu(theme, scheme, onTint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _SourcePlaylistMetricChip(
                        icon: Icons.library_music_rounded,
                        label: '${playlist.itemIds.length}',
                        color: onTint,
                      ),
                      if (widget.childListCount > 0)
                        _SourcePlaylistMetricChip(
                          icon: Icons.folder_copy_rounded,
                          label: '${widget.childListCount}',
                          color: onTint,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard({
    required ThemeData theme,
    required ColorScheme scheme,
    required Color base,
    required Color onTint,
    required ImageProvider? provider,
    required SourceThemeTopicPlaylist playlist,
  }) {
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
              child: Container(
                width: 116,
                height: 65,
                color: base.withValues(alpha: 0.22),
                child: provider != null
                    ? Image(image: provider, fit: BoxFit.cover)
                    : Icon(Icons.folder_rounded, color: onTint, size: 32),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onTint,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _SourcePlaylistMetricChip(
                        icon: Icons.library_music_rounded,
                        label: '${playlist.itemIds.length}',
                        color: onTint,
                      ),
                      if (widget.childListCount > 0)
                        _SourcePlaylistMetricChip(
                          icon: Icons.folder_copy_rounded,
                          label: '${widget.childListCount}',
                          color: onTint,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _playlistMenu(theme, scheme, onTint),
          ],
        ),
      ),
    );
  }

  Widget _playlistMenu(ThemeData theme, ColorScheme scheme, Color onTint) {
    return IconButton(
      tooltip: 'Opciones',
      onPressed: _openActionsSheet,
      icon: Icon(Icons.more_vert_rounded, color: onTint.withValues(alpha: 0.9)),
    );
  }

  Future<void> _openActionsSheet() async {
    _setOverlayOpen(true);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                title: const Text('Editar'),
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
                title: Text('Eliminar', style: TextStyle(color: scheme.error)),
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

  Color _foregroundFor(Color base, ColorScheme scheme) {
    final brightness = ThemeData.estimateBrightnessForColor(base);
    final raw = brightness == Brightness.dark ? Colors.white : Colors.black;
    return Color.alphaBlend(raw.withValues(alpha: 0.9), scheme.onSurface);
  }
}

void _setOverlayOpen(bool value) {
  if (!Get.isRegistered<NavigationController>()) return;
  Get.find<NavigationController>().setOverlayOpen(value);
}

class _SourcePlaylistMetricChip extends StatelessWidget {
  const _SourcePlaylistMetricChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg.withValues(alpha: 0.88)),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

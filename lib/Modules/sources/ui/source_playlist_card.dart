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
                      provider: provider,
                      playlist: playlist,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.58,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isHovered
                              ? base.withValues(alpha: 0.65)
                              : scheme.outlineVariant.withValues(alpha: 0.48),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Container(width: 4, color: base),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: base.withValues(alpha: 0.16),
                                      border: Border.all(
                                        color: base.withValues(alpha: 0.22),
                                        width: 1,
                                      ),
                                    ),
                                    child: provider != null
                                        ? Image(
                                            image: provider,
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(
                                            Icons.queue_music_rounded,
                                            color: base,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        playlist.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.textTheme.titleMedium
                                            ?.copyWith(
                                              color: scheme.onSurface,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          _SourcePlaylistMetricChip(
                                            icon: Icons.library_music_rounded,
                                            label: '${playlist.itemIds.length}',
                                          ),
                                          if (widget.childListCount > 0)
                                            _SourcePlaylistMetricChip(
                                              icon: Icons.folder_copy_rounded,
                                              label: '${widget.childListCount}',
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                _playlistMenu(t, scheme),
                              ],
                            ),
                          ),
                        ],
                      ),
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
    required ImageProvider? provider,
    required SourceThemeTopicPlaylist playlist,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isHovered
              ? base.withValues(alpha: 0.65)
              : scheme.outlineVariant.withValues(alpha: 0.42),
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
                    : Icon(Icons.folder_rounded, color: base, size: 34),
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
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: _playlistMenu(theme, scheme),
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
                      ),
                      if (widget.childListCount > 0)
                        _SourcePlaylistMetricChip(
                          icon: Icons.folder_copy_rounded,
                          label: '${widget.childListCount}',
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

  PopupMenuButton<_SourcePlaylistAction> _playlistMenu(
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return PopupMenuButton<_SourcePlaylistAction>(
      onOpened: () => _setOverlayOpen(true),
      onCanceled: () => _setOverlayOpen(false),
      onSelected: (value) {
        _setOverlayOpen(false);
        if (value == _SourcePlaylistAction.edit) {
          widget.onEdit();
        }
        if (value == _SourcePlaylistAction.delete) {
          widget.onDelete();
        }
      },
      icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: _SourcePlaylistAction.edit, child: Text('Editar')),
        PopupMenuItem(
          value: _SourcePlaylistAction.delete,
          child: Text('Eliminar'),
        ),
      ],
    );
  }
}

enum _SourcePlaylistAction { edit, delete }

void _setOverlayOpen(bool value) {
  if (!Get.isRegistered<NavigationController>()) return;
  Get.find<NavigationController>().setOverlayOpen(value);
}

class _SourcePlaylistMetricChip extends StatelessWidget {
  const _SourcePlaylistMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

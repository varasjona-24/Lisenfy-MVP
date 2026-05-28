import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../../utils/media_item_status_helper.dart';
import '../../themes/app_spacing.dart';

class MediaCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;
  final double thumbnailAspectRatio;
  final bool showPlayBadge;
  final String? hintText;

  const MediaCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.width = 130,
    this.thumbnailAspectRatio = 1,
    this.showPlayBadge = true,
    this.hintText,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  Timer? _holdTimer;
  bool _fired = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    if (widget.onLongPress == null) return;
    _holdTimer?.cancel();
    _fired = false;
    _holdTimer = Timer(const Duration(seconds: 2), () {
      _fired = true;
      widget.onLongPress?.call();
    });
  }

  void _cancelHold() {
    if (_fired) return;
    _holdTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final audioFormat = _audioFormat();
    final cardBg = colors.surfaceContainerHighest;
    final cardStroke = colors.onSurface.withOpacity(0.08);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: _cancelHold,
      onPanStart: (_) => _cancelHold(),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.onTap,
        splashColor: colors.primary.withOpacity(0.12),
        highlightColor: colors.primary.withOpacity(0.06),
        child: SizedBox(
          width: widget.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🎨 THUMBNAIL / COVER
              AspectRatio(
                aspectRatio: widget.thumbnailAspectRatio,
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cardStroke),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildThumbnail(context),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: VideoBadgesOverlay(item: widget.item),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  colors.shadow.withOpacity(0.55),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (widget.showPlayBadge)
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colors.surface.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadow.withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                size: 18,
                                color: colors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              // 🏷 TITLE
              Text(
                widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              // 🏷 SUBTITLE
              Text(
                widget.item.displaySubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              if ((widget.hintText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.hintText!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              if (audioFormat != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    audioFormat.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _audioFormat() {
    if (!widget.item.hasAudioLocal && widget.item.localAudioVariant == null) {
      return null;
    }
    final local = widget.item.localAudioVariant?.format.trim();
    if (local != null && local.isNotEmpty) return local;
    final any = widget.item.variants
        .firstWhere((v) => v.kind == MediaVariantKind.audio)
        .format
        .trim();
    return any.isNotEmpty ? any : null;
  }

  Widget _buildThumbnail(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // 1) ✅ Preferir thumbnail local si existe
    final local = widget.item.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) {
      return Image.file(
        File(local),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallbackIcon(colors),
      );
    }

    // 2) 🌐 Fallback a thumbnail remoto
    final remote = widget.item.thumbnail?.trim();
    if (remote != null && remote.isNotEmpty) {
      return Image.network(
        remote,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallbackIcon(colors),
      );
    }

    // 3) 🎵 Placeholder
    return _fallbackIcon(colors);
  }

  Widget _fallbackIcon(ColorScheme colors) {
    final isVideo =
        widget.item.hasVideoLocal || widget.item.localVideoVariant != null;

    return Container(
      decoration: BoxDecoration(color: colors.surfaceContainerHigh),
      alignment: Alignment.center,
      child: Icon(
        isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
        size: 42,
        color: colors.onSurface.withOpacity(0.6),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

// ============================
// 🖼️ MINIATURA DE MEDIA
// ============================
class MediaThumb extends StatelessWidget {
  const MediaThumb({
    super.key,
    this.path,
    this.url,
    this.fallbackIcon = Icons.music_note_rounded,
    this.size = 54,
    this.borderRadius = 12,
  });

  final String? path;
  final String? url;
  final IconData fallbackIcon;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLocal = path != null && path!.trim().isNotEmpty;
    final hasUrl = url != null && url!.trim().isNotEmpty;

    ImageProvider? provider;
    if (hasLocal) {
      provider = FileImage(File(path!.trim()));
    } else if (hasUrl) {
      provider = NetworkImage(url!.trim());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHigh,
        child: provider != null
            ? Image(image: provider, fit: BoxFit.cover)
            : Icon(fallbackIcon, color: scheme.primary),
      ),
    );
  }
}

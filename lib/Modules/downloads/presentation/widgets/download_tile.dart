import 'package:flutter/material.dart';

import '../../../../app/models/media_item.dart';

// ============================================================================
// 🎵 TILE: ITEM IMPORTADO
// ============================================================================
class DownloadTile extends StatelessWidget {
  const DownloadTile({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onHold,
  });

  final MediaItem item;
  final void Function(MediaItem item) onPlay;
  final void Function(MediaItem item) onHold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variant = item.variants.isNotEmpty ? item.variants.first : null;
    final isVideo = variant?.kind == MediaVariantKind.video;
    final icon = isVideo ? Icons.videocam_rounded : Icons.music_note_rounded;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => onPlay(item),
        leading: Icon(icon),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          item.displaySubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'Más opciones',
          onPressed: () => onHold(item),
        ),
      ),
    );
  }
}

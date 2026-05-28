import 'package:flutter/material.dart';

import '../domain/source_theme.dart';
import '../domain/source_theme_topic_playlist.dart';
import 'source_collection_card.dart';

class SourcePlaylistCard extends StatelessWidget {
  const SourcePlaylistCard({
    super.key,
    required this.theme,
    required this.playlist,
    this.childListCount = 0,
    this.gridStyle = false,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    this.completedCount,
  });

  final SourceTheme theme;
  final SourceThemeTopicPlaylist playlist;
  final int childListCount;
  final bool gridStyle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int? completedCount;

  @override
  Widget build(BuildContext context) {
    return SourceCollectionCard(
      name: playlist.name,
      itemCount: playlist.itemIds.length,
      childCollectionCount: childListCount,
      baseColor: playlist.colorValue != null
          ? Color(playlist.colorValue!)
          : theme.colors.first,
      coverLocalPath: playlist.coverLocalPath,
      coverUrl: playlist.coverUrl,
      gridStyle: gridStyle,
      onOpen: onOpen,
      onEdit: onEdit,
      onDelete: onDelete,
      completedCount: completedCount,
    );
  }
}

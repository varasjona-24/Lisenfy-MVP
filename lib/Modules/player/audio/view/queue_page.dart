import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../audio/controller/audio_player_controller.dart';
import '../../../../app/models/media_item.dart';

class QueuePage extends GetView<AudioPlayerController> {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(tr('player.queue_title')), centerTitle: true),
      body: Obx(() {
        final queue = controller.queue; // RxList
        final idx = controller.currentIndex.value;

        if (queue.isEmpty) {
          return Center(child: Text(tr('player.queue_empty')));
        }

        final totalSeconds = queue.fold<int>(
          0,
          (s, it) => s + (it.effectiveDurationSeconds ?? 0),
        );

        return Column(
          children: [
            _header(
              theme: theme,
              count: queue.length,
              totalSeconds: totalSeconds,
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: queue.length,
                onReorder: (oldIndex, newIndex) async {
                  await controller.reorderQueue(oldIndex, newIndex);
                },
                buildDefaultDragHandles: false,
                itemBuilder: (context, i) {
                  final it = queue[i];
                  final selected = i == idx;

                  final durText = _fmtDurationShort(
                    it.effectiveDurationSeconds,
                  );

                  return ListTile(
                    key: ValueKey(it.id),
                    selected: selected,
                    contentPadding: const EdgeInsets.only(left: 8, right: 4),
                    leading: _thumb(theme: theme, item: it, selected: selected),
                    title: Text(
                      it.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: it.subtitle.isNotEmpty ? Text(it.subtitle) : null,
                    onTap: () async {
                      await controller.playAt(i);
                      Get.back();
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (durText.isNotEmpty)
                              Text(durText, style: theme.textTheme.bodySmall),
                            if (selected) const Text('Reproduciendo'),
                          ],
                        ),
                        const SizedBox(width: 4),
                        ReorderableDragStartListener(
                          index: i,
                          child: Icon(
                            Icons.drag_handle,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  Widget _header({
    required ThemeData theme,
    required int count,
    required int totalSeconds,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count pistas • Total: ${_fmtDurationTotal(totalSeconds)}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            'Arrastra para mover',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb({
    required ThemeData theme,
    required MediaItem item,
    required bool selected,
  }) {
    final thumb = item.effectiveThumbnail?.trim();

    Widget image;
    if (thumb != null && thumb.isNotEmpty) {
      // Si es un path local, lo renderizamos con Image.file
      final looksLikeUrl =
          thumb.startsWith('http://') || thumb.startsWith('https://');
      if (looksLikeUrl) {
        image = Image.network(
          thumb,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _thumbFallback(theme),
        );
      } else {
        image = Image.file(
          File(thumb),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _thumbFallback(theme),
        );
      }
    } else {
      image = _thumbFallback(theme);
    }

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(6), child: image),
          if (selected)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.play_arrow,
                  size: 12,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumbFallback(ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.music_note, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _fmtDurationTotal(int s) {
    if (s <= 0) return '0:00';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  String _fmtDurationShort(int? s) {
    if (s == null || s <= 0) return '';
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

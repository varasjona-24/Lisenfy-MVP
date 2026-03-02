import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/video_player_controller.dart';
import '../../../../app/models/media_item.dart';

class VideoQueuePage extends StatefulWidget {
  const VideoQueuePage({super.key});

  @override
  State<VideoQueuePage> createState() => _VideoQueuePageState();
}

class _VideoQueuePageState extends State<VideoQueuePage>
    with WidgetsBindingObserver {
  late final VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<VideoPlayerController>();
    controller.isQueueOpen.value = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.isQueueOpen.value = false;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(controller.videoService.pause());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cola de reproducción'),
        centerTitle: true,
      ),
      body: Obx(() {
        final queue = controller.queue;
        final idx = controller.currentIndex.value;

        if (queue.isEmpty) {
          return const Center(child: Text('La cola está vacía'));
        }

        final totalSeconds = queue.fold<int>(
          0,
          (sum, item) => sum + (item.effectiveDurationSeconds ?? 0),
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
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) async {
                  await controller.reorderQueue(oldIndex, newIndex);
                },
                itemBuilder: (context, i) {
                  final it = queue[i];
                  final selected = i == idx;
                  final durText = _fmtDurationShort(
                    it.effectiveDurationSeconds,
                  );

                  return ListTile(
                    key: ObjectKey(it),
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
              '$count videos • Total: ${_fmtDurationTotal(totalSeconds)}',
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
      child: Icon(Icons.videocam, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  String _fmtDurationTotal(int seconds) {
    if (seconds <= 0) return '0:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _fmtDurationShort(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

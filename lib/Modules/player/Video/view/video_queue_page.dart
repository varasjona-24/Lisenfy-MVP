import '../../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
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
    final desktop = AppBottomNav.desktopSidebarEnabled;

    return Scaffold(
      appBar: AppBar(title: Text(tr('player.queue_title')), centerTitle: true),
      body: Obx(() {
        final queue = controller.queue;
        final idx = controller.currentIndex.value;

        if (queue.isEmpty) {
          return Center(child: Text(tr('player.queue_empty')));
        }

        final totalSeconds = queue.fold<int>(
          0,
          (sum, item) => sum + (item.effectiveDurationSeconds ?? 0),
        );

        if (desktop) return AppGradientBackground(child: _desktopQueue(theme));
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
                onReorderItem: _reorder,

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
                            if (selected) Text(tr('player.now_playing')),
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

  Future<void> _reorder(int from, int to) =>
      controller.reorderQueue(from, to > from ? to + 1 : to);

  Widget _desktopQueue(ThemeData theme) {
    final scheme = theme.colorScheme;
    final queue = controller.queue;
    final current = controller.currentIndex.value;
    final playing = current >= 0 && current < queue.length
        ? queue[current]
        : null;
    final occurrences = <String, int>{};
    final keys = [
      for (final item in queue)
        ValueKey(
          'video-queue-${item.id}-${occurrences.update(item.id, (count) => count + 1, ifAbsent: () => 0)}',
        ),
    ];
    Widget overview({bool compact = false}) {
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('player.now_playing'),
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 12),
          if (playing != null) ...[
            Text(
              playing.title,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (playing.subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                playing.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
          ],
          Text(
            tr(
              'player.queue_video_summary',
              args: [
                '${queue.length}',
                _fmtDurationTotal(
                  queue.fold<int>(
                    0,
                    (sum, item) => sum + (item.effectiveDurationSeconds ?? 0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('player.queue_drag_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
      return Container(
        key: const ValueKey('desktop-video-queue-overview'),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .35),
          ),
        ),
        child: compact
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (playing != null) ...[
                    _thumb(
                      theme: theme,
                      item: playing,
                      selected: false,
                      width: 144,
                    ),
                    const SizedBox(width: 20),
                  ],
                  Expanded(child: details),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (playing != null) ...[
                    LayoutBuilder(
                      builder: (context, box) => _thumb(
                        theme: theme,
                        item: playing,
                        selected: false,
                        width: box.maxWidth,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  details,
                ],
              ),
      );
    }

    Widget rows() => ReorderableListView.builder(
      key: const ValueKey('desktop-video-queue-list'),
      padding: EdgeInsets.zero,
      buildDefaultDragHandles: false,
      itemCount: queue.length,
      onReorderItem: _reorder,
      itemBuilder: (context, index) {
        final item = queue[index];
        final selected = index == current;
        return Padding(
          key: keys[index],
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: .35)
                : scheme.surfaceContainer.withValues(alpha: .75),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: selected
                    ? scheme.primary.withValues(alpha: .55)
                    : scheme.outlineVariant.withValues(alpha: .25),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => controller.playAt(index),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _thumb(
                      theme: theme,
                      item: item,
                      selected: selected,
                      width: 104,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _fmtDurationShort(item.effectiveDurationSeconds),
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(width: 16),
                    MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= 1000) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 300,
                  child: SingleChildScrollView(child: overview()),
                ),
                const SizedBox(width: 24),
                Expanded(child: rows()),
              ],
            );
          }
          return Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: box.maxHeight * .4),
                child: SingleChildScrollView(
                  child: overview(compact: box.maxWidth >= 500),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: rows()),
            ],
          );
        },
      ),
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
              tr(
                'player.queue_video_summary',
                args: ['$count', _fmtDurationTotal(totalSeconds)],
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            tr('player.queue_drag_hint'),
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
    double width = 64,
  }) {
    final thumb = item.effectiveThumbnail?.trim();

    Widget image;
    if (thumb != null && thumb.isNotEmpty) {
      final looksLikeUrl =
          thumb.startsWith('http://') || thumb.startsWith('https://');
      if (looksLikeUrl) {
        image = Image.network(
          thumb,
          width: width,
          height: width * 9 / 16,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _thumbFallback(theme, width: width),
        );
      } else {
        image = Image.file(
          File(thumb),
          width: width,
          height: width * 9 / 16,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _thumbFallback(theme, width: width),
        );
      }
    } else {
      image = _thumbFallback(theme, width: width);
    }

    return SizedBox(
      width: width,
      height: width * 9 / 16 + 6,
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

  Widget _thumbFallback(ThemeData theme, {double width = 64}) {
    return Container(
      width: width,
      height: width * 9 / 16,
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

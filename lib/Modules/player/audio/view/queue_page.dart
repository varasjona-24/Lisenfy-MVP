import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../audio/controller/audio_player_controller.dart';
import '../../../../app/models/media_item.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../../app/ui/widgets/dialogs/sort_options_sheet.dart';
import 'desktop_audio_player_view.dart';

class QueuePage extends StatefulWidget {
  const QueuePage({super.key});
  @override
  State<QueuePage> createState() => _QueuePageState();
}

enum _QueueFilter { all, upcoming, previous }

class _QueueMatchIntent extends Intent {
  const _QueueMatchIntent(this.direction);
  final int direction;
}

class _QueuePageState extends State<QueuePage> {
  AudioPlayerController get controller => Get.find<AudioPlayerController>();
  final _search = TextEditingController();
  final _queueScroll = ScrollController();
  int _matchCursor = 0;
  double _rowExtent = 92;
  bool _searchOpen = false;
  _QueueFilter _filter = _QueueFilter.all;
  @override
  void dispose() {
    _search.dispose();
    _queueScroll.dispose();
    super.dispose();
  }

  List<int> _matches() {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return [];
    return [
      for (var i = 0; i < controller.queue.length; i++)
        if (controller.queue[i].title.toLowerCase().contains(query) ||
            controller.queue[i].displaySubtitle.toLowerCase().contains(query))
          i,
    ];
  }

  void _changeSearch() {
    setState(() {
      _matchCursor = 0;
      if (_search.text.trim().isNotEmpty) _filter = _QueueFilter.all;
    });
    _scrollToMatch();
  }

  void _moveMatch(int direction) {
    final matches = _matches();
    if (matches.isEmpty) return;
    setState(() => _matchCursor = (_matchCursor + direction) % matches.length);
    _scrollToMatch();
  }

  void _scrollToMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_queueScroll.hasClients) return;
      final matches = _matches();
      if (matches.isEmpty) return;
      final index = matches[_matchCursor % matches.length];
      final position = _queueScroll.position;
      final offset = (index * _rowExtent - position.viewportDimension * .35)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      _queueScroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  static const List<String> _temporaryQueueCoverAssets = <String>[
    'assets/ui/ListasTemp/WhatsApp Image 2026-08-11 at 11.47.46 AM (1).jpeg',
    'assets/ui/ListasTemp/WhatsApp Image 2026-08-11 at 11.47.46 AM.jpeg',
    'assets/ui/ListasTemp/WhatsApp Image 2026-08-11 at 11.47.47 AM (1).jpeg',
    'assets/ui/ListasTemp/WhatsApp Image 2026-08-11 at 11.47.47 AM (2).jpeg',
    'assets/ui/ListasTemp/WhatsApp Image 2026-08-11 at 11.47.47 AM (3).jpeg',
    'assets/ui/ListasTemp/WhatsApp Image 2026-08-11 at 11.47.47 AM.jpeg',
    'assets/ui/ListasTemp/WhatsApp Image 2026-08-11 at 11.47.48 AM (1).jpeg',
    'assets/ui/ListasTemp/WhatsApp Image 2026-08-11 at 11.47.48 AM.jpeg',
    'assets/ui/ListasTemp/WhatsApp Image 2026-08-11 at 11.49.28 AM.jpeg',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = usesDesktopAudioPlayer(defaultTargetPlatform);

    return Scaffold(
      backgroundColor: desktop ? Colors.transparent : null,
      appBar: AppBar(
        toolbarHeight: desktop ? 96 : null,
        backgroundColor: desktop
            ? theme.colorScheme.surface.withValues(alpha: .96)
            : null,
        title: desktop
            ? Obx(
                () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('player.queue_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        'player.queue_desktop.summary',
                        args: [
                          '${controller.queue.length}',
                          _desktopDuration(
                            controller.queue.fold<int>(
                              0,
                              (sum, item) =>
                                  sum + (item.effectiveDurationSeconds ?? 0),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : Text(tr('player.queue_title')),
        centerTitle: !desktop,
        actions: [
          if (desktop) ...[
            IconButton(
              tooltip: tr('player.queue_desktop.search'),
              icon: Icon(
                _searchOpen ? Icons.search_off_rounded : Icons.search_rounded,
              ),
              onPressed: () => setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) _search.clear();
              }),
            ),
            IconButton(
              tooltip: tr('player.queue_desktop.filter'),
              icon: Icon(
                Icons.filter_alt_outlined,
                color: _filter == _QueueFilter.all
                    ? null
                    : theme.colorScheme.primary,
              ),
              onPressed: _search.text.trim().isEmpty ? _chooseFilter : null,
            ),
            Obx(
              () => PopupMenuButton<_QueueSaveAction>(
                tooltip: tr('player.desktop.more'),
                enabled: controller.queue.isNotEmpty,
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (action) {
                  if (action == _QueueSaveAction.temporary) {
                    _saveTemporaryQueue(context);
                  } else {
                    _savePermanentQueue(context);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _QueueSaveAction.permanent,
                    child: Text(tr('player.queue_save_permanent')),
                  ),
                  PopupMenuItem(
                    value: _QueueSaveAction.temporary,
                    child: Text(tr('player.queue_save_temporary')),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ] else
            Obx(
              () => IconButton(
                tooltip: tr('player.queue_save_tooltip'),
                icon: const Icon(Icons.save_alt_rounded),
                onPressed: controller.queue.isEmpty
                    ? null
                    : () => _showSaveQueueOptions(context),
              ),
            ),
        ],
      ),
      body: desktop
          ? AppGradientBackground(
              child: Material(
                color: theme.colorScheme.surface.withValues(alpha: .96),
                child: Obx(() => _desktopQueue(theme)),
              ),
            )
          : Obx(() {
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
                      onReorderItem: (oldIndex, newIndex) async {
                        await controller.reorderQueueItem(oldIndex, newIndex);
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
                          contentPadding: const EdgeInsets.only(
                            left: 8,
                            right: 4,
                          ),
                          leading: _thumb(
                            theme: theme,
                            item: it,
                            selected: selected,
                          ),
                          title: Text(
                            it.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: it.subtitle.isNotEmpty
                              ? Text(it.subtitle)
                              : null,
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
                                    Text(
                                      durText,
                                      style: theme.textTheme.bodySmall,
                                    ),
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

  String _desktopDuration(int seconds) {
    if (seconds <= 0) return '—';
    final hours = seconds ~/ 3600, minutes = (seconds % 3600) ~/ 60;
    return hours > 0
        ? tr('player.queue_desktop.hours_minutes', args: ['$hours', '$minutes'])
        : tr(
            'player.queue_desktop.minutes',
            args: ['${(seconds / 60).ceil()}'],
          );
  }

  Future<void> _chooseFilter() async {
    final selected = await showModalBottomSheet<_QueueFilter>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('player.queue_desktop.filter'),
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              for (final filter in _QueueFilter.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SortOptionTile(
                    label: tr('player.queue_desktop.${filter.name}'),
                    selected: _filter == filter,
                    icon: Icons.queue_music_rounded,
                    onTap: () => Navigator.of(ctx).pop(filter),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && selected != null) setState(() => _filter = selected);
  }

  Widget _desktopQueue(ThemeData theme) {
    final queue = controller.queue;
    final current = controller.currentIndex.value;
    final playing = controller.audioService.isPlaying.value;
    final query = _search.text.trim().toLowerCase();
    final matches = _matches();
    final matchSet = matches.toSet();
    final activeMatch = matches.isEmpty
        ? -1
        : matches[_matchCursor % matches.length];
    final visible = <int>[
      for (var i = 0; i < queue.length; i++)
        if (_filter == _QueueFilter.all ||
            (_filter == _QueueFilter.upcoming ? i > current : i < current))
          i,
    ];
    final canReorder = _filter == _QueueFilter.all;
    final occurrences = <String, int>{};
    final keys = [
      for (final item in queue)
        ValueKey(
          'queue-${item.id}-${occurrences.update(item.id, (n) => n + 1, ifAbsent: () => 0)}',
        ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 780;
        final scaler = MediaQuery.textScalerOf(context);
        final titleHeight =
            scaler.scale(theme.textTheme.bodyLarge?.fontSize ?? 16) * 1.5;
        final subtitleHeight =
            scaler.scale(theme.textTheme.bodySmall?.fontSize ?? 12) * 1.5;
        _rowExtent = math.max(
          wide ? 92.0 : 84.0,
          (wide ? titleHeight : titleHeight + subtitleHeight) + 36,
        );
        return Column(
          children: [
            if (_searchOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Shortcuts(
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.arrowDown):
                        _QueueMatchIntent(1),
                    SingleActivator(LogicalKeyboardKey.arrowUp):
                        _QueueMatchIntent(-1),
                    SingleActivator(LogicalKeyboardKey.enter, shift: true):
                        _QueueMatchIntent(-1),
                  },
                  child: Actions(
                    actions: {
                      _QueueMatchIntent: CallbackAction<_QueueMatchIntent>(
                        onInvoke: (intent) {
                          _moveMatch(intent.direction);
                          return null;
                        },
                      ),
                    },
                    child: TextField(
                      key: const ValueKey('desktop-queue-search'),
                      controller: _search,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: tr('player.queue_desktop.search_hint'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: tr('common.clear'),
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _search.clear();
                                  _changeSearch();
                                },
                              ),
                      ),
                      onChanged: (_) => _changeSearch(),
                      onSubmitted: (_) => _moveMatch(1),
                    ),
                  ),
                ),
              ),
            if (_searchOpen && query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          matches.isEmpty
                              ? tr('player.queue_desktop.no_results')
                              : tr(
                                  'player.queue_desktop.match_position',
                                  args: [
                                    '${_matchCursor % matches.length + 1}',
                                    '${matches.length}',
                                  ],
                                ),
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('queue-match-previous'),
                      tooltip: tr('player.queue_desktop.previous_match'),
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      onPressed: matches.isEmpty ? null : () => _moveMatch(-1),
                    ),
                    IconButton(
                      key: const ValueKey('queue-match-next'),
                      tooltip: tr('player.queue_desktop.next_match'),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      onPressed: matches.isEmpty ? null : () => _moveMatch(1),
                    ),
                  ],
                ),
              ),
            if (!canReorder)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(
                          'player.queue_desktop.filtered',
                          args: ['${visible.length}'],
                        ),
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        tr('player.queue_desktop.reorder_filtered'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 12),
              child: _desktopColumns(
                wide: wide,
                number: Text('#', style: theme.textTheme.labelLarge),
                title: Text(
                  tr('player.queue_desktop.title'),
                  style: theme.textTheme.labelLarge,
                ),
                artist: Text(
                  tr('player.queue_desktop.artist'),
                  style: theme.textTheme.labelLarge,
                ),
                duration: Tooltip(
                  message: tr('player.queue_desktop.duration'),
                  child: wide
                      ? Text(
                          tr('player.queue_desktop.duration'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge,
                        )
                      : const Icon(Icons.schedule_rounded, size: 18),
                ),
                handle: const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        tr(
                          queue.isEmpty
                              ? 'player.queue_empty'
                              : 'player.queue_desktop.no_results',
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      key: const ValueKey('desktop-queue-list'),
                      scrollController: _queueScroll,
                      itemExtent: _rowExtent,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      buildDefaultDragHandles: false,
                      itemCount: visible.length,
                      onReorderItem: (from, to) async {
                        if (canReorder) {
                          await controller.reorderQueueItem(from, to);
                        }
                      },
                      itemBuilder: (context, index) {
                        final sourceIndex = visible[index],
                            item = queue[sourceIndex];
                        final selected = sourceIndex == current;
                        final duration = _fmtDurationShort(
                          item.effectiveDurationSeconds,
                        );
                        return Padding(
                          key: keys[sourceIndex],
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            key: sourceIndex == activeMatch
                                ? const ValueKey('queue-active-match')
                                : ValueKey('queue-row-$sourceIndex'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                width: sourceIndex == activeMatch ? 2 : 1,
                                color: sourceIndex == activeMatch
                                    ? theme.colorScheme.primary
                                    : matchSet.contains(sourceIndex)
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: .4,
                                      )
                                    : Colors.transparent,
                              ),
                            ),
                            color: selected
                                ? theme.colorScheme.primaryContainer.withValues(
                                    alpha: .65,
                                  )
                                : sourceIndex == activeMatch
                                ? theme.colorScheme.secondaryContainer
                                      .withValues(alpha: .45)
                                : index.isOdd
                                ? theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: .3)
                                : Colors.transparent,
                            clipBehavior: Clip.antiAlias,
                            child: Semantics(
                              selected: selected,
                              child: InkWell(
                                onTap: () => controller.playAt(sourceIndex),
                                hoverColor: theme.colorScheme.primary
                                    .withValues(alpha: .07),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: _desktopColumns(
                                    wide: wide,
                                    number: selected
                                        ? Tooltip(
                                            message: tr('player.now_playing'),
                                            child: Icon(
                                              playing
                                                  ? Icons.graphic_eq_rounded
                                                  : Icons
                                                        .pause_circle_outline_rounded,
                                              color: theme.colorScheme.primary,
                                              size: 21,
                                            ),
                                          )
                                        : Text(
                                            '${sourceIndex + 1}'.padLeft(
                                              2,
                                              '0',
                                            ),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                    title: Row(
                                      children: [
                                        SizedBox.square(
                                          dimension: wide ? 56 : 40,
                                          child: FittedBox(
                                            child: _thumb(
                                              theme: theme,
                                              item: item,
                                              selected: false,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: wide ? 16 : 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                item.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                      fontWeight: selected
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                      color: selected
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                          : null,
                                                    ),
                                              ),
                                              if (!wide &&
                                                  item
                                                      .displaySubtitle
                                                      .isNotEmpty)
                                                Text(
                                                  item.displaySubtitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    artist: Text(
                                      item.displaySubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    duration: Text(
                                      duration.isEmpty ? '—' : duration,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    handle: canReorder
                                        ? Tooltip(
                                            message: tr(
                                              'player.queue_desktop.drag_hint',
                                            ),
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors.grab,
                                              child: ReorderableDragStartListener(
                                                index: index,
                                                child: const SizedBox(
                                                  width: 40,
                                                  height: 48,
                                                  child: Icon(
                                                    Icons
                                                        .drag_indicator_rounded,
                                                    size: 22,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _desktopColumns({
    required bool wide,
    required Widget number,
    required Widget title,
    required Widget artist,
    required Widget duration,
    required Widget handle,
  }) => Row(
    children: [
      SizedBox(width: wide ? 48 : 32, child: number),
      SizedBox(width: wide ? 16 : 8),
      Expanded(flex: 6, child: title),
      if (wide) ...[
        const SizedBox(width: 24),
        Expanded(flex: 3, child: artist),
      ],
      SizedBox(width: wide ? 20 : 8),
      SizedBox(width: wide ? 88 : 52, child: duration),
      SizedBox(width: wide ? 48 : 32, child: handle),
    ],
  );

  // ===========================================================================
  // UI
  // ===========================================================================

  Future<void> _showSaveQueueOptions(BuildContext context) async {
    final action = await showModalBottomSheet<_QueueSaveAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _QueueSaveOptionsSheet(),
    );
    if (action == null) return;
    if (!context.mounted) return;
    switch (action) {
      case _QueueSaveAction.temporary:
        await _saveTemporaryQueue(context);
        return;
      case _QueueSaveAction.permanent:
        await _savePermanentQueue(context);
        return;
    }
  }

  Future<void> _saveTemporaryQueue(BuildContext context) async {
    final setup = await _requestTemporaryQueueSetup(context);
    if (setup == null) return;

    final result = await controller.saveCurrentQueueAsTemporaryPlaylist(
      name: setup.name,
      coverLocalPath: setup.coverAsset,
    );
    final message = switch (result) {
      TemporaryQueueSaveResult.created => tr('player.temporary_queue_created'),
      TemporaryQueueSaveResult.duplicate => tr(
        'player.temporary_queue_already_saved',
      ),
      TemporaryQueueSaveResult.dailyLimitReached => tr(
        'player.temporary_queue_daily_limit',
      ),
      TemporaryQueueSaveResult.empty => tr('player.queue_empty'),
      TemporaryQueueSaveResult.unavailable => tr('common.error'),
    };
    Get.snackbar(
      tr('player.queue_title'),
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<_TemporaryQueueSetup?> _requestTemporaryQueueSetup(
    BuildContext context,
  ) async {
    return showDialog<_TemporaryQueueSetup>(
      context: context,
      builder: (_) => const _TemporaryQueueSetupDialog(),
    );
  }

  Future<void> _savePermanentQueue(BuildContext context) async {
    final name = await _requestPermanentQueueName(context);
    if (name == null) return;

    final result = await controller.saveCurrentQueueAsPlaylist(name: name);
    final message = switch (result) {
      PermanentQueueSaveResult.created => tr('player.queue_playlist_created'),
      PermanentQueueSaveResult.duplicate => tr(
        'player.queue_playlist_already_saved',
      ),
      PermanentQueueSaveResult.empty => tr('player.queue_empty'),
      PermanentQueueSaveResult.unavailable => tr('common.error'),
    };
    Get.snackbar(
      tr('player.queue_title'),
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<String?> _requestPermanentQueueName(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _PermanentQueueNameDialog(),
    );
    final trimmed = result?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
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
                'player.queue_audio_summary',
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

enum _QueueSaveAction { temporary, permanent }

class _QueueSaveOptionsSheet extends StatelessWidget {
  const _QueueSaveOptionsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                tr('player.queue_save_title'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr('player.queue_save_sheet_subtitle'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              _QueueSaveOptionTile(
                action: _QueueSaveAction.temporary,
                icon: Icons.schedule_rounded,
                title: tr('player.queue_save_temporary'),
                badge: tr('player.queue_save_badge_temporary'),
                subtitle: tr('player.queue_save_temporary_hint'),
              ),
              const SizedBox(height: 10),
              _QueueSaveOptionTile(
                action: _QueueSaveAction.permanent,
                icon: Icons.playlist_add_check_rounded,
                title: tr('player.queue_save_permanent'),
                badge: tr('player.queue_save_badge_permanent'),
                subtitle: tr('player.queue_save_permanent_hint'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueSaveOptionTile extends StatelessWidget {
  const _QueueSaveOptionTile({
    required this.action,
    required this.icon,
    required this.title,
    required this.badge,
    required this.subtitle,
  });

  final _QueueSaveAction action;
  final IconData icon;
  final String title;
  final String badge;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isTemporary = action == _QueueSaveAction.temporary;
    final accent = isTemporary ? scheme.tertiary : scheme.primary;
    final badgeBg = isTemporary
        ? scheme.tertiaryContainer.withValues(alpha: 0.62)
        : scheme.primaryContainer.withValues(alpha: 0.62);
    final badgeFg = isTemporary
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(action),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          child: Text(
                            badge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: badgeFg,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.outline,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemporaryQueueSetup {
  const _TemporaryQueueSetup({required this.name, required this.coverAsset});

  final String name;
  final String coverAsset;
}

class _TemporaryQueueSetupDialog extends StatefulWidget {
  const _TemporaryQueueSetupDialog();

  @override
  State<_TemporaryQueueSetupDialog> createState() =>
      _TemporaryQueueSetupDialogState();
}

class _TemporaryQueueSetupDialogState
    extends State<_TemporaryQueueSetupDialog> {
  late final TextEditingController _nameController;
  late String _selectedCover;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: tr('player.temporary_queue_name'),
    );
    _selectedCover = _QueuePageState._temporaryQueueCoverAssets.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(
      context,
    ).pop(_TemporaryQueueSetup(name: name, coverAsset: _selectedCover));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: Text(tr('player.temporary_queue_customize_title')),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: tr('player.temporary_queue_name_label'),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Text(
              tr('player.temporary_queue_cover_label'),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 124,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _QueuePageState._temporaryQueueCoverAssets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final asset =
                      _QueuePageState._temporaryQueueCoverAssets[index];
                  final selected = asset == _selectedCover;
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setState(() => _selectedCover = asset),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: selected ? 3 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(asset, fit: BoxFit.cover),
                            if (selected)
                              Align(
                                alignment: Alignment.topRight,
                                child: Container(
                                  margin: const EdgeInsets.all(6),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: scheme.onPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('common.cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(tr('player.queue_save_confirm')),
        ),
      ],
    );
  }
}

class _PermanentQueueNameDialog extends StatefulWidget {
  const _PermanentQueueNameDialog();

  @override
  State<_PermanentQueueNameDialog> createState() =>
      _PermanentQueueNameDialogState();
}

class _PermanentQueueNameDialogState extends State<_PermanentQueueNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: tr('player.queue_playlist_default_name'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('player.queue_playlist_name_title')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: tr('player.queue_playlist_name_label'),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('common.cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(tr('common.save'))),
      ],
    );
  }
}

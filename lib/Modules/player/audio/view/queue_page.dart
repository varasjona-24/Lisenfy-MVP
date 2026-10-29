import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../audio/controller/audio_player_controller.dart';
import '../../../../app/models/media_item.dart';

class QueuePage extends StatefulWidget {
  const QueuePage({super.key});
  @override
  State<QueuePage> createState() => _QueuePageState();
}

enum _QueueFilter { all, upcoming, previous }

class _QueuePageState extends State<QueuePage> {
  AudioPlayerController get controller => Get.find<AudioPlayerController>();
  final _search = TextEditingController();
  bool _searchOpen = false;
  _QueueFilter _filter = _QueueFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('player.queue_title')),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: tr('player.queue_controls.search'),
            icon: Icon(
              _searchOpen ? Icons.search_off_rounded : Icons.search_rounded,
            ),
            onPressed: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) _search.clear();
            }),
          ),
          PopupMenuButton<_QueueFilter>(
            tooltip: tr('player.queue_controls.filter'),
            icon: Icon(
              Icons.filter_alt_outlined,
              color: _filter == _QueueFilter.all
                  ? null
                  : theme.colorScheme.primary,
            ),
            initialValue: _filter,
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (_) => [
              for (final filter in _QueueFilter.values)
                CheckedPopupMenuItem(
                  value: filter,
                  checked: filter == _filter,
                  child: Text(tr('player.queue_controls.${filter.name}')),
                ),
            ],
          ),
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
      body: Obx(() {
        final queue = controller.queue; // RxList
        final idx = controller.currentIndex.value;
        final query = _search.text.trim().toLowerCase();
        final indices = [
          for (var i = 0; i < queue.length; i++)
            if ((_filter == _QueueFilter.all ||
                    (_filter == _QueueFilter.upcoming && i > idx) ||
                    (_filter == _QueueFilter.previous && i < idx)) &&
                (query.isEmpty ||
                    queue[i].title.toLowerCase().contains(query) ||
                    queue[i].displaySubtitle.toLowerCase().contains(query)))
              i,
        ];
        final canReorder = query.isEmpty && _filter == _QueueFilter.all;

        if (queue.isEmpty) {
          return Center(child: Text(tr('player.queue_empty')));
        }

        final totalSeconds = queue.fold<int>(
          0,
          (s, it) => s + (it.effectiveDurationSeconds ?? 0),
        );

        return Column(
          children: [
            if (_searchOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: tr('player.queue_controls.search'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _search.clear()),
                    ),
                  ),
                ),
              ),
            _header(
              theme: theme,
              count: queue.length,
              totalSeconds: totalSeconds,
            ),
            Expanded(
              child: indices.isEmpty
                  ? Center(child: Text(tr('player.queue_controls.no_results')))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: indices.length,
                      onReorderItem: (oldIndex, newIndex) async {
                        if (canReorder) {
                          await controller.reorderQueueItem(oldIndex, newIndex);
                        }
                      },
                      buildDefaultDragHandles: false,
                      itemBuilder: (context, visibleIndex) {
                        final i = indices[visibleIndex];
                        final it = queue[i];
                        final selected = i == idx;

                        final durText = _fmtDurationShort(
                          it.effectiveDurationSeconds,
                        );

                        return ListTile(
                          key: ValueKey('${it.id}:$i'),
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
                              if (canReorder)
                                ReorderableDragStartListener(
                                  index: visibleIndex,
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

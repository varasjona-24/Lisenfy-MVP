import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/data/local/local_library_store.dart';
import '../../../../app/data/playback/playback_repository.dart';
import '../../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../recommendations/data/listening_event_store.dart';
import '../../../artists/domain/artist_profile.dart';
import '../../application/weekly_collage_summary.dart';
import '../../application/weekly_collage_activity.dart';
import '../../application/weekly_collage_weeks.dart';
import '../widgets/weekly_activity_chart.dart';

class WeeklyCollagePage extends StatefulWidget {
  const WeeklyCollagePage({
    super.key,
    this.summaryLoader,
    this.activity,
    this.weekLoader,
    this.availableWeeksLoader,
    this.now,
  });
  final Future<WeeklyCollageSummary> Function()? summaryLoader;
  final WeeklyCollageActivity? activity;
  final Future<WeeklyCollageSummary> Function(DateTime start)? weekLoader;
  final Future<List<DateTime>> Function()? availableWeeksLoader;
  final DateTime? now;
  @override
  State<WeeklyCollagePage> createState() => _WeeklyCollagePageState();
}

class _WeeklyCollagePageState extends State<WeeklyCollagePage> {
  final _imageKeys = [GlobalKey(), GlobalKey()];
  late Future<WeeklyCollageSummary> _summary;
  late final Future<List<DateTime>> _weeks;
  late DateTime _selectedWeek;
  DateTime get _now => widget.now ?? DateTime.now();
  bool _exporting = false;
  WeeklyCollageActivity? _activity;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    _selectedWeek = WeeklyCollageSummary.previousWeek(_now).$1;
    _weeks = _loadWeeks();
    _summary = _load(_selectedWeek);
  }

  Future<List<DateTime>> _loadWeeks() async {
    final injected = widget.availableWeeksLoader;
    if (injected != null) {
      final dates = await injected();
      return weeklyCollageWeeks(
        dates.map(
          (date) => (date.millisecondsSinceEpoch, date.millisecondsSinceEpoch),
        ),
        _now,
      );
    }
    if (widget.summaryLoader != null || widget.weekLoader != null) {
      return [_selectedWeek];
    }
    if (Get.isRegistered<PlaybackRepository>()) {
      return weeklyCollageWeeks(
        await Get.find<PlaybackRepository>().queryWeeklyActivityRanges(),
        _now,
      );
    }
    final events = await Get.find<ListeningEventStore>().readAsync();
    return weeklyCollageWeeks(
      events.map((e) => (e.occurredAt, e.occurredAt)),
      _now,
    );
  }

  Future<WeeklyCollageSummary> _load(DateTime start) async {
    if (widget.weekLoader != null) return widget.weekLoader!(start);
    if (widget.summaryLoader != null) return widget.summaryLoader!();
    final library = await Get.find<LocalLibraryStore>().readAll();
    final end = DateTime(start.year, start.month, start.day + 7);
    if (Get.isRegistered<PlaybackRepository>()) {
      final repository = Get.find<PlaybackRepository>();
      final previous = DateTime(start.year, start.month, start.day - 7);
      final activity = WeeklyCollageActivity.build(
        await repository.queryWeeklyIntervals(
          previous.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ),
        start,
        end,
        coverageStart: await repository.weeklyComparisonCoverageStart(),
      );
      if (_selectedWeek == start) _activity = activity;
    }
    return WeeklyCollageSummary.build(
      library,
      await Get.find<ListeningEventStore>().readAsync(
        startUtcMs: start.millisecondsSinceEpoch,
        endUtcMs: end.millisecondsSinceEpoch,
      ),
      _now,
      weekStart: start,
    );
  }

  void _selectWeek(DateTime? week) {
    if (week == null || week == _selectedWeek || _exporting) return;
    setState(() {
      _selectedWeek = week;
      _activity = widget.activity;
      _summary = _load(week);
    });
  }

  Widget _weekSelector() => FutureBuilder<List<DateTime>>(
    future: _weeks,
    builder: (context, snapshot) {
      final weeks = snapshot.data ?? [_selectedWeek];
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            constraints: const BoxConstraints(minHeight: 48),
            labelText: tr('weekly_collage.select_week'),
            prefixIcon: const Icon(Icons.date_range_rounded, size: 18),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: snapshot.hasError
                ? tr('weekly_collage.weeks_error')
                : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DateTime>(
              key: const ValueKey('weekly-week-selector'),
              value: _selectedWeek,
              isDense: true,
              iconSize: 20,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              isExpanded: true,
              onChanged: _exporting || !snapshot.hasData ? null : _selectWeek,
              items: [
                for (final start in weeks)
                  DropdownMenuItem(
                    value: start,
                    child: Text(
                      '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(start)} — ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(DateTime(start.year, start.month, start.day + 6))}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final summary = await _summary;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final files = <XFile>[];
      final names = <String>[];
      for (var index = 0; index < _imageKeys.length; index++) {
        final boundary =
            _imageKeys[index].currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(
          pixelRatio: 2160 / boundary.size.width,
        );
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) throw StateError('PNG encoding failed');
          final name =
              'listenfy-weekly-${DateFormat('yyyy-MM-dd').format(summary.start)}-${index + 1}.png';
          names.add(name);
          files.add(
            XFile.fromData(
              data.buffer.asUint8List(),
              mimeType: 'image/png',
              name: name,
            ),
          );
        } finally {
          image.dispose();
        }
      }
      if (!mounted) return;
      final box = context.findRenderObject()! as RenderBox;
      await Share.shareXFiles(
        files,
        fileNameOverrides: names,
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('weekly_collage.export_error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('weekly_collage.title'))),
    body: AppGradientBackground(
      child: Column(
        children: [
          _weekSelector(),
          Expanded(
            child: FutureBuilder<WeeklyCollageSummary>(
              future: _summary,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(tr('weekly_collage.load_error')));
                }
                final summary = snapshot.data;
                if (summary == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (summary.entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        tr('weekly_collage.empty'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      for (var part = 0; part < 2; part++) ...[
                        if (part > 0) const SizedBox(height: 20),
                        RepaintBoundary(
                          key: _imageKeys[part],
                          child: _collage(summary, part: part),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _exporting ? null : _export,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(
                          _exporting
                              ? tr('weekly_collage.exporting')
                              : tr('weekly_collage.export'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _collage(WeeklyCollageSummary summary, {required int part}) {
    final scheme = Theme.of(context).colorScheme;
    final top = summary.entries.first;
    final audio = summary.entries
        .where((e) => !e.video && !identical(e, top))
        .take(top.video ? 5 : 4)
        .toList();
    final videos = summary.entries
        .where((e) => e.video && !identical(e, top))
        .take(2)
        .toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              scheme.primary.withValues(alpha: .12),
              scheme.surface,
            ),
            scheme.surface,
            Color.alphaBlend(
              scheme.secondary.withValues(alpha: .09),
              scheme.surface,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: ListenfyLogo(size: 36, color: scheme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            tr('weekly_collage.headline'),
            style: TextStyle(
              fontSize: 32,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat.MMMMd(Localizations.localeOf(context).toString()).format(summary.start)} — ${DateFormat.MMMMd(Localizations.localeOf(context).toString()).format(DateTime(summary.end.year, summary.end.month, summary.end.day - 1))}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          if (part == 0) ...[
            _cover(top, protagonist: true),
            if (audio.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionTitle(
                Icons.music_note_rounded,
                tr('weekly_collage.other_audio'),
                scheme.primary,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    for (final entry in audio)
                      SizedBox(
                        width: (constraints.maxWidth - 10) / 2,
                        child: _cover(entry),
                      ),
                  ],
                ),
              ),
            ],
            if (videos.isNotEmpty) ...[
              const SizedBox(height: 20),
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(
                      Icons.movie_rounded,
                      tr('weekly_collage.video_highlights'),
                      scheme.tertiary,
                    ),
                    const SizedBox(height: 12),
                    for (final entry in videos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _cover(entry),
                      ),
                  ],
                ),
              ),
            ],
          ],
          if (part == 1) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (summary.plays(false) > 0)
                  _metric(
                    Icons.music_note_rounded,
                    '${summary.plays(false)}',
                    tr('weekly_collage.audio_plays'),
                  ),
                if (summary.plays(true) > 0)
                  _metric(
                    Icons.movie_rounded,
                    '${summary.plays(true)}',
                    tr('weekly_collage.video_plays'),
                    video: true,
                  ),
                if ((_activity?.videoTotalMs ?? 0) > 0)
                  _metric(
                    Icons.ondemand_video_rounded,
                    _minutes(_activity!.videoTotalMs),
                    tr('weekly_collage.watched_time'),
                    video: true,
                  ),
                if ((_activity?.totalMs ?? 0) > 0)
                  _metric(
                    Icons.schedule_rounded,
                    tr(
                      'weekly_collage.minutes',
                      args: [('${(_activity!.totalMs / 60000).round()}')],
                    ),
                    tr('weekly_collage.active_time'),
                  ),
              ],
            ),
            if (_activity != null && _activity!.totalMs > 0) ...[
              const SizedBox(height: 22),
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('weekly_collage.activity'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    WeeklyActivityChart(
                      activity: _activity!,
                      labels: List.generate(
                        7,
                        (i) =>
                            DateFormat.E(
                              Localizations.localeOf(context).toString(),
                            ).format(
                              DateTime(
                                summary.start.year,
                                summary.start.month,
                                summary.start.day + i,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        _legend(
                          scheme.primary,
                          tr('weekly_collage.audio'),
                          Icons.music_note_rounded,
                        ),
                        if (_activity!.videoMs.any((v) => v > 0))
                          _legend(
                            scheme.tertiary,
                            tr('weekly_collage.video'),
                            Icons.movie_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr(
                        _activity!.closingDayMs > 0
                            ? 'weekly_collage.week_closing'
                            : 'weekly_collage.week_closing_empty',
                        args: [
                          _minutes(_activity!.closingDayMs),
                          NumberFormat.decimalPercentPattern(
                            locale: Localizations.localeOf(context).toString(),
                            decimalDigits: 1,
                          ).format(_activity!.closingDayShare),
                        ],
                      ),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (_activity!.changePercent != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    tr(
                      _activity!.changePercent!.abs() < .5
                          ? 'weekly_collage.same_time'
                          : _activity!.changePercent! >= 0
                          ? 'weekly_collage.more_time'
                          : 'weekly_collage.less_time',
                      args: [
                        _activity!.changePercent!.abs().round().toString(),
                      ],
                    ),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
            if (_activity?.regionsMs.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('weekly_collage.regions'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final region
                            in (_activity!.regionsMs.entries.toList()
                                  ..sort((a, b) => b.value.compareTo(a.value)))
                                .take(3))
                          Chip(
                            label: Text(
                              tr(
                                'weekly_collage.stat',
                                args: [
                                  ArtistMainRegionX.fromRaw(
                                    region.key,
                                  ).simpleLabel,
                                  region.value < 60000
                                      ? tr('weekly_collage.under_one_minute')
                                      : tr(
                                          'weekly_collage.minutes',
                                          args: [
                                            '${(region.value / 60000).round()}',
                                          ],
                                        ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              tr(
                top.plays >= 3 && top.plays * 2 >= summary.plays(top.video)
                    ? 'weekly_collage.habit_repeat'
                    : summary.entries.length >= 4
                    ? 'weekly_collage.habit_varied'
                    : 'weekly_collage.habit_yours',
              ),
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('weekly_collage.footer'),
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('weekly_collage.footer_story'),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .5),
      ),
    ),
    child: child,
  );
  String _minutes(double ms) => ms > 0 && ms < 60000
      ? tr('weekly_collage.under_one_minute')
      : tr('weekly_collage.minutes', args: ['${(ms / 60000).round()}']);
  Widget _sectionTitle(IconData icon, String label, Color color) => Row(
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    ],
  );
  Widget _legend(Color color, String label, IconData icon) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
  Widget _metric(
    IconData icon,
    String value,
    String label, {
    bool video = false,
  }) => Container(
    constraints: const BoxConstraints(minWidth: 110),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: video
          ? Color.alphaBlend(
              Theme.of(context).colorScheme.tertiary.withValues(alpha: .08),
              Theme.of(context).colorScheme.surfaceContainerHigh,
            )
          : Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color:
            (video
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.primary)
                .withValues(alpha: .25),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: video
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _cover(WeeklyCollageEntry entry, {bool protagonist = false}) {
    final item = entry.item;
    final overlay =
        protagonist &&
        !entry.video &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    final local = item.thumbnailLocalPath;
    final remote = item.thumbnail;
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Center(
        child: Icon(
          entry.video ? Icons.movie_rounded : Icons.music_note_rounded,
          size: 48,
        ),
      ),
    );
    final Widget image = local != null && File(local).existsSync()
        ? Image.file(
            File(local),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : remote != null && remote.isNotEmpty
        ? Image.network(
            remote,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              (entry.video
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.primary)
                  .withValues(alpha: .25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (protagonist)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr('weekly_collage.protagonist'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: entry.video ? 16 / 9 : 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  if (overlay) ...[
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xE6000000)],
                            stops: [.35, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: _coverText(entry, true, color: Colors.white),
                    ),
                  ],
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              entry.video
                                  ? Icons.movie_rounded
                                  : Icons.music_note_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                tr(
                                  entry.video
                                      ? 'weekly_collage.video'
                                      : 'weekly_collage.audio',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!overlay) ...[
            const SizedBox(height: 7),
            _coverText(entry, protagonist),
          ],
        ],
      ),
    );
  }

  Widget _coverText(
    WeeklyCollageEntry entry,
    bool protagonist, {
    Color? color,
  }) {
    final item = entry.item;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: protagonist ? 20 : 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        if (protagonist && item.displaySubtitle.isNotEmpty)
          Text(
            item.displaySubtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color),
          ),
        Text(
          tr(
            'weekly_collage.cover_caption',
            args: [
              tr(entry.video ? 'weekly_collage.video' : 'weekly_collage.audio'),
              '${entry.plays}',
            ],
          ),
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}

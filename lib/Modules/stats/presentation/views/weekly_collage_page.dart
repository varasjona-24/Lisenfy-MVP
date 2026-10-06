import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/data/local/local_library_store.dart';
import '../../../recommendations/data/listening_event_store.dart';
import '../../application/weekly_collage_summary.dart';

class WeeklyCollagePage extends StatefulWidget {
  const WeeklyCollagePage({super.key});
  @override
  State<WeeklyCollagePage> createState() => _WeeklyCollagePageState();
}

class _WeeklyCollagePageState extends State<WeeklyCollagePage> {
  final _imageKey = GlobalKey();
  late final Future<WeeklyCollageSummary> _summary;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _summary = _load();
  }

  Future<WeeklyCollageSummary> _load() async {
    final library = await Get.find<LocalLibraryStore>().readAll();
    final now = DateTime.now();
    final (start, end) = WeeklyCollageSummary.previousWeek(now);
    return WeeklyCollageSummary.build(
      library,
      await Get.find<ListeningEventStore>().readAsync(
        startUtcMs: start.millisecondsSinceEpoch,
        endUtcMs: end.millisecondsSinceEpoch,
      ),
      now,
    );
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    ui.Image? image;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _imageKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || !mounted) return;
      final box = context.findRenderObject()! as RenderBox;
      await Share.shareXFiles(
        [
          XFile.fromData(
            data.buffer.asUint8List(),
            mimeType: 'image/png',
            name: 'listenfy-weekly.png',
          ),
        ],
        fileNameOverrides: ['listenfy-weekly.png'],
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('weekly_collage.export_error'))),
        );
      }
    } finally {
      image?.dispose();
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('weekly_collage.title'))),
    body: FutureBuilder<WeeklyCollageSummary>(
      future: _summary,
      builder: (context, snapshot) {
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
              RepaintBoundary(key: _imageKey, child: _collage(summary)),
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
  );

  Widget _collage(WeeklyCollageSummary summary) {
    final scheme = Theme.of(context).colorScheme;
    final featured = summary.entries.take(4).toList();
    final videos = summary.entries.where((e) => e.video);
    if (videos.isNotEmpty && !featured.any((e) => e.video)) {
      if (featured.length == 4) featured.removeLast();
      featured.add(videos.first);
    }
    final top = summary.entries.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.surface,
            scheme.secondaryContainer,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('weekly_collage.brand'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: scheme.primary,
            ),
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
            '${DateFormat.MMMMd(context.locale.toString()).format(summary.start)} — ${DateFormat.MMMMd(context.locale.toString()).format(DateTime(summary.end.year, summary.end.month, summary.end.day - 1))}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              for (var i = 0; i < featured.length; i++)
                FractionallySizedBox(
                  widthFactor: featured.length == 1 ? 1 : .47,
                  child: Transform.rotate(
                    angle: i.isEven ? -.035 : .035,
                    child: _cover(featured[i]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (summary.plays(false) > 0)
            _stat('${summary.plays(false)}', tr('weekly_collage.audio_plays')),
          if (summary.plays(true) > 0)
            _stat('${summary.plays(true)}', tr('weekly_collage.video_plays')),
          if (summary.minutes(false) > 0)
            _stat(
              tr('weekly_collage.minutes', args: ['${summary.minutes(false)}']),
              tr('weekly_collage.listened_estimated'),
            ),
          if (summary.minutes(true) > 0)
            _stat(
              tr('weekly_collage.minutes', args: ['${summary.minutes(true)}']),
              tr('weekly_collage.watched_estimated'),
            ),
          const SizedBox(height: 16),
          Text(
            tr('weekly_collage.headliner', args: [top.item.title]),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          Text(
            tr('weekly_collage.last_week_plays', args: ['${top.plays}']),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            tr('weekly_collage.footer'),
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      tr('weekly_collage.stat', args: [value, label]),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _cover(WeeklyCollageEntry entry) {
    final item = entry.item;
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
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: entry.video ? 16 / 10 : 1, child: image),
          const SizedBox(height: 7),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          Text(
            tr(
              'weekly_collage.cover_caption',
              args: [
                tr(
                  entry.video ? 'weekly_collage.video' : 'weekly_collage.audio',
                ),
                '${entry.plays}',
              ],
            ),
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

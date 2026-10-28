import '../../../app/models/media_item.dart';
import '../../recommendations/data/listening_event_store.dart';
import '../../recommendations/domain/recommendation_models.dart';

class WeeklyCollageEntry {
  WeeklyCollageEntry(this.item, this.video, {MediaItem? artworkItem})
    : artworkItem = artworkItem ?? item;
  final MediaItem item;
  final MediaItem artworkItem;
  final bool video;
  int plays = 0;
  int seconds = 0;
}

class WeeklyCollageSummary {
  static (DateTime, DateTime) previousWeek(DateTime now) {
    final end = DateTime(now.year, now.month, now.day - now.weekday + 1);
    return (DateTime(end.year, end.month, end.day - 7), end);
  }

  WeeklyCollageSummary({
    required this.start,
    required this.end,
    required this.entries,
  });
  final DateTime start;
  final DateTime end;
  final List<WeeklyCollageEntry> entries;
  int minutes(bool video) =>
      (entries
                  .where((e) => e.video == video)
                  .fold<int>(0, (sum, e) => sum + e.seconds) /
              60)
          .round();
  int plays(bool video) => entries
      .where((e) => e.video == video)
      .fold<int>(0, (sum, e) => sum + e.plays);

  static WeeklyCollageSummary build(
    List<MediaItem> library,
    List<ListeningEvent> events,
    DateTime now, {
    DateTime? weekStart,
  }) {
    // Local calendar boundaries: the previous Monday through this Monday,
    // exclusive. Calendar arithmetic also handles daylight-saving changes.
    final latest = previousWeek(now).$1;
    final start = weekStart == null
        ? latest
        : DateTime(
            weekStart.year,
            weekStart.month,
            weekStart.day - weekStart.weekday + 1,
          );
    if (start.isAfter(latest)) {
      throw ArgumentError('Only complete weeks can be summarized');
    }
    final end = DateTime(start.year, start.month, start.day + 7);
    final items = <String, List<MediaItem>>{};
    for (final item in library) {
      final id = item.id.trim();
      final publicId = item.publicId.trim();
      final aliases = <String>{
        if (id.isNotEmpty) ...[id, 'i:$id'],
        if (publicId.isNotEmpty) ...[publicId, 'p:$publicId'],
      };
      for (final alias in aliases) {
        items.putIfAbsent(alias, () => []).add(item);
      }
    }
    final ranked = <String, WeeklyCollageEntry>{};
    for (final event in events) {
      if (event.occurredAt < start.millisecondsSinceEpoch ||
          event.occurredAt >= end.millisecondsSinceEpoch) {
        continue;
      }
      final snapshot = event.mediaSnapshot;
      final candidates =
          items[event.trackKey.trim()] ??
          (snapshot == null || snapshot.publicId.trim().isEmpty
              ? null
              : items['p:${snapshot.publicId.trim()}']) ??
          (snapshot == null ? null : items['i:${snapshot.id.trim()}']);
      if ((candidates == null || candidates.isEmpty) &&
          event.mediaSnapshot == null) {
        continue;
      }
      final hasAudio =
          candidates?.any(
            (item) =>
                item.variants.any((v) => v.kind == MediaVariantKind.audio),
          ) ??
          false;
      final hasVideo =
          candidates?.any(
            (item) =>
                item.variants.any((v) => v.kind == MediaVariantKind.video),
          ) ??
          false;
      if (event.mode == null && hasAudio == hasVideo) continue;
      final video =
          event.mode == RecommendationMode.video ||
          (event.mode == null && hasVideo);
      final kind = video ? MediaVariantKind.video : MediaVariantKind.audio;
      final currentItem = candidates == null || candidates.isEmpty
          ? null
          : candidates.firstWhere(
              (candidate) => candidate.variants.any((v) => v.kind == kind),
              orElse: () => candidates.first,
            );
      final item =
          event.mediaSnapshot ??
          candidates!.firstWhere(
            (candidate) => candidate.variants.any((v) => v.kind == kind),
            orElse: () => candidates.first,
          );
      final publicId = item.publicId.trim();
      final canonicalKey = publicId.isNotEmpty
          ? 'p:$publicId'
          : 'i:${item.id.trim()}';
      final entry = ranked.putIfAbsent(
        '$canonicalKey:$video',
        () => WeeklyCollageEntry(item, video, artworkItem: currentItem),
      );
      if (event.countsAsPlay) entry.plays++;
      final durations = item.variants.where(
        (v) => v.kind == kind && (v.durationSeconds ?? 0) > 0,
      );
      final seconds = durations.isEmpty
          ? (item.durationSeconds ?? 0)
          : durations.first.durationSeconds!;
      entry.seconds +=
          event.playedSeconds?.round() ??
          (seconds * event.progress.clamp(0, 1)).round();
    }
    final entries = ranked.values.toList()
      ..sort((a, b) {
        final count = b.plays.compareTo(a.plays);
        return count != 0 ? count : a.item.title.compareTo(b.item.title);
      });
    return WeeklyCollageSummary(start: start, end: end, entries: entries);
  }
}

import '../../../app/models/media_item.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../../recommendations/data/listening_event_store.dart';

class WeeklyListeningSummary {
  const WeeklyListeningSummary({
    required this.periodKey,
    required this.sessionCount,
    required this.uniqueTrackCount,
    required this.listenedSeconds,
    required this.topArtistName,
  });

  final String periodKey;
  final int sessionCount;
  final int uniqueTrackCount;
  final int listenedSeconds;
  final String? topArtistName;

  int get listenedMinutes => listenedSeconds <= 0
      ? 0
      : (listenedSeconds / Duration.secondsPerMinute).ceil();
}

typedef WeeklyListeningSummaryLoader =
    Future<WeeklyListeningSummary?> Function(DateTime now);

/// Builds a local-only weekly snapshot from playback events. The period begins
/// on Monday; on Monday morning it resolves the preceding completed week so a
/// delayed app launch can still publish the same Sunday summary once.
class WeeklyListeningSummaryBuilder {
  WeeklyListeningSummaryBuilder({
    required ListeningEventStore listeningEventStore,
    required Future<List<MediaItem>> Function() libraryLoader,
  }) : _listeningEventStore = listeningEventStore,
       _libraryLoader = libraryLoader;

  final ListeningEventStore _listeningEventStore;
  final Future<List<MediaItem>> Function() _libraryLoader;

  Future<WeeklyListeningSummary?> build(DateTime now) async {
    final window = _WeeklySummaryWindow.forNow(now);
    final library = await _libraryLoader();
    final itemsByKey = <String, MediaItem>{
      for (final item in library) _stableKeyOf(item): item,
    };
    final events = _listeningEventStore.readAll().where((event) {
      return event.occurredAt >= window.start.millisecondsSinceEpoch &&
          event.occurredAt < window.end.millisecondsSinceEpoch;
    });

    var sessionCount = 0;
    var listenedSeconds = 0;
    final trackKeys = <String>{};
    final artistWeights = <String, int>{};
    final artistNames = <String, String>{};

    for (final event in events) {
      final item = itemsByKey[event.trackKey];
      if (item == null) continue;

      sessionCount++;
      trackKeys.add(event.trackKey);
      final playedSeconds = _playedSeconds(item, event.progress);
      listenedSeconds += playedSeconds;
      final artist = _primaryArtist(item);
      if (artist == null) continue;
      final artistKey = ArtistCreditParser.normalizeKey(artist);
      if (artistKey.isEmpty || artistKey == 'unknown') continue;
      artistNames[artistKey] = artist;
      artistWeights[artistKey] =
          (artistWeights[artistKey] ?? 0) +
          (playedSeconds > 0 ? playedSeconds : 1);
    }

    if (sessionCount == 0) return null;
    final topArtistKey = artistWeights.entries.fold<String?>(null, (
      current,
      entry,
    ) {
      if (current == null) return entry.key;
      return entry.value > (artistWeights[current] ?? 0) ? entry.key : current;
    });

    return WeeklyListeningSummary(
      periodKey: window.periodKey,
      sessionCount: sessionCount,
      uniqueTrackCount: trackKeys.length,
      listenedSeconds: listenedSeconds,
      topArtistName: topArtistKey == null ? null : artistNames[topArtistKey],
    );
  }

  String _stableKeyOf(MediaItem item) {
    final publicId = item.publicId.trim();
    return publicId.isNotEmpty ? 'p:$publicId' : 'i:${item.id.trim()}';
  }

  int _playedSeconds(MediaItem item, double progress) {
    final duration = item.effectiveDurationSeconds ?? 0;
    if (duration <= 0) return 0;
    return (duration * progress.clamp(0, 1)).round();
  }

  String? _primaryArtist(MediaItem item) {
    final parsed = ArtistCreditParser.parse(item.displaySubtitle);
    final primary = ArtistCreditParser.cleanName(parsed.primaryArtist);
    if (primary.isNotEmpty) return primary;
    final fallback = ArtistCreditParser.cleanName(item.displaySubtitle);
    return fallback.isEmpty ? null : fallback;
  }
}

class _WeeklySummaryWindow {
  const _WeeklySummaryWindow({
    required this.start,
    required this.end,
    required this.periodKey,
  });

  final DateTime start;
  final DateTime end;
  final String periodKey;

  factory _WeeklySummaryWindow.forNow(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    final currentMonday = day.subtract(Duration(days: day.weekday - 1));
    final isSundayEvening = now.weekday == DateTime.sunday && now.hour >= 19;
    final isMondayMorning = now.weekday == DateTime.monday && now.hour < 12;
    final start = isSundayEvening
        ? currentMonday
        : isMondayMorning
        ? currentMonday.subtract(const Duration(days: 7))
        : currentMonday;
    final end = isSundayEvening
        ? now
        : isMondayMorning
        ? currentMonday
        : now;
    return _WeeklySummaryWindow(
      start: start,
      end: end,
      periodKey: _dateKey(start),
    );
  }

  static String _dateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

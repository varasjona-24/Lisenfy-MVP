import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/stats/application/weekly_collage_summary.dart';
import 'package:listenfy/Modules/stats/application/weekly_collage_weeks.dart';
import 'package:listenfy/Modules/recommendations/data/listening_event_store.dart';
import 'package:listenfy/app/models/media_item.dart';

void main() {
  final now = DateTime(2026, 10, 19, 12);
  (int, int) point(DateTime date) =>
      (date.millisecondsSinceEpoch, date.millisecondsSinceEpoch);
  test(
    'defaults to last complete week and excludes current and future weeks',
    () {
      expect(weeklyCollageWeeks([], now), [DateTime(2026, 10, 12)]);
      final weeks = weeklyCollageWeeks([
        point(DateTime(2026, 10, 1)),
        point(DateTime(2026, 10, 2)),
        point(DateTime(2026, 10, 19)),
        point(DateTime(2026, 11, 1)),
        point(DateTime(2026, 10, 6)),
      ], now);
      expect(weeks, [
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 5),
        DateTime(2026, 9, 28),
      ]);
    },
  );
  test(
    'interval crossing Monday includes both complete weeks but not a gap',
    () {
      final weeks = weeklyCollageWeeks([
        (
          DateTime(2026, 9, 27, 23, 59).millisecondsSinceEpoch,
          DateTime(2026, 9, 28, 0, 1).millisecondsSinceEpoch,
        ),
      ], now);
      expect(weeks, [
        DateTime(2026, 10, 12),
        DateTime(2026, 9, 28),
        DateTime(2026, 9, 21),
      ]);
    },
  );
  test('calendar arithmetic crosses years and switches only on Monday', () {
    expect(
      weeklyCollageWeeks([], DateTime(2027, 1, 3)).single,
      DateTime(2026, 12, 21),
    );
    expect(
      weeklyCollageWeeks([], DateTime(2027, 1, 4)).single,
      DateTime(2026, 12, 28),
    );
  });
  test('selected summary uses its exact Monday to Monday range', () {
    final item = MediaItem.fromJson({
      'id': 'a',
      'publicId': 'a',
      'title': 'A',
      'variants': [
        {'kind': 'audio', 'fileName': 'a.mp3', 'format': 'mp3'},
      ],
    });
    final events = [
      for (final day in [27, 28])
        ListeningEvent.fromJson({
          'trackKey': 'a',
          'mode': 'audio',
          'progress': 1,
          'occurredAt': DateTime(2026, 9, day, 12).millisecondsSinceEpoch,
        }),
      ListeningEvent.fromJson({
        'trackKey': 'a',
        'mode': 'audio',
        'progress': 1,
        'occurredAt': DateTime(2026, 10, 5).millisecondsSinceEpoch,
      }),
    ];
    final summary = WeeklyCollageSummary.build(
      [item],
      events,
      now,
      weekStart: DateTime(2026, 9, 30),
    );
    expect(summary.start, DateTime(2026, 9, 28));
    expect(summary.end, DateTime(2026, 10, 5));
    expect(summary.plays(false), 1);
    expect(
      () => WeeklyCollageSummary.build(
        [],
        [],
        now,
        weekStart: DateTime(2026, 10, 19),
      ),
      throwsArgumentError,
    );
  });
}

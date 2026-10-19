import 'weekly_collage_summary.dart';

/// Calendar weeks, newest first. Keep the last complete week as the default,
/// even without activity. Intervals crossing a Monday include both weeks.
List<DateTime> weeklyCollageWeeks(Iterable<(int, int)> ranges, DateTime now) {
  final latest = WeeklyCollageSummary.previousWeek(now).$1;
  final starts = <DateTime>{latest};
  for (final (from, to) in ranges) {
    if (to < from) continue;
    final date = DateTime.fromMillisecondsSinceEpoch(from);
    var week = DateTime(date.year, date.month, date.day - date.weekday + 1);
    while (!week.isAfter(latest) && week.millisecondsSinceEpoch <= to) {
      starts.add(week);
      week = DateTime(week.year, week.month, week.day + 7);
    }
  }
  return starts.toList()..sort((a, b) => b.compareTo(a));
}

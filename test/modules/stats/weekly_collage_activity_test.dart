import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/stats/application/weekly_collage_activity.dart';
import 'package:listenfy/Modules/stats/presentation/widgets/weekly_activity_chart.dart';

void main() {
  final start = DateTime(2026, 10, 5), end = DateTime(2026, 10, 12);
  Map<String, dynamic> interval(
    DateTime from,
    DateTime to, {
    bool video = false,
    String? country,
    double? wall,
  }) => {
    'start': from.millisecondsSinceEpoch,
    'end': to.millisecondsSinceEpoch,
    'wallMs': wall ?? to.difference(from).inMilliseconds,
    'video': video,
    'country': country,
  };
  test('splits midnight, week edges and modes without inventing regions', () {
    final activity = WeeklyCollageActivity.build(
      [
        interval(
          DateTime(2026, 10, 4, 23, 59),
          DateTime(2026, 10, 5, 0, 1),
          country: 'JP',
        ),
        interval(
          DateTime(2026, 10, 5, 23, 59),
          DateTime(2026, 10, 6, 0, 1),
          video: true,
        ),
        interval(
          DateTime(2026, 10, 11, 23, 59),
          DateTime(2026, 10, 12, 0, 1),
          country: '???',
        ),
      ],
      start,
      end,
    );
    expect(activity.audioMs[0], 60000);
    expect(activity.audioMs[6], 60000);
    expect(activity.videoMs[0], 60000);
    expect(activity.videoMs[1], 60000);
    expect(activity.totalMs, 240000);
    expect(activity.previousMs, 60000);
    expect(activity.regionsMs, {'asiatico': 60000});
    expect(activity.changePercent, isNull);
  });
  test('uses wall time rather than media advance and guards comparison', () {
    final rows = [
      interval(DateTime(2026, 9, 28), DateTime(2026, 9, 28, 0, 2)),
      interval(start, DateTime(2026, 10, 5, 0, 4), wall: 180000),
    ];
    final full = WeeklyCollageActivity.build(
      rows,
      start,
      end,
      coverageStart: DateTime(2026, 9, 28).millisecondsSinceEpoch,
    );
    expect(full.totalMs, 180000);
    expect(full.changePercent, 50);
    final partial = WeeklyCollageActivity.build(
      rows,
      start,
      end,
      coverageStart: DateTime(2026, 9, 29).millisecondsSinceEpoch,
    );
    expect(partial.changePercent, isNull);
    expect(
      WeeklyCollageActivity.build(
        [],
        start,
        end,
        coverageStart: 0,
      ).changePercent,
      isNull,
    );
  });
  testWidgets('seven bars fit narrow layouts and larger text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SizedBox(
              width: 280,
              child: WeeklyActivityChart(
                activity: WeeklyCollageActivity(
                  List.filled(7, 60000),
                  List.filled(7, 30000),
                  {},
                  0,
                  false,
                ),
                labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

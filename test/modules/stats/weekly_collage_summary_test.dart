import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/recommendations/data/listening_event_store.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/Modules/stats/application/weekly_collage_summary.dart';
import 'package:listenfy/app/models/media_item.dart';

void main() {
  test(
    'separa audio y video del mismo item y excluye otras semanas y eventos futuros',
    () {
      final now = DateTime(2026, 10, 7, 12);
      final item = MediaItem(
        id: 'a',
        publicId: 'a',
        title: 'A',
        subtitle: 'Artist',
        source: MediaSource.local,
        origin: SourceOrigin.device,
        variants: [
          MediaVariant(
            kind: MediaVariantKind.audio,
            format: 'mp3',
            fileName: 'a.mp3',
            durationSeconds: 120,
            createdAt: 1,
          ),
          MediaVariant(
            kind: MediaVariantKind.video,
            format: 'mp4',
            fileName: 'a.mp4',
            durationSeconds: 120,
            createdAt: 1,
          ),
        ],
      );
      ListeningEvent event(DateTime at, String? mode, double progress) =>
          ListeningEvent.fromJson({
            'trackKey': mode == 'video'
                ? 'a'
                : mode == null
                ? 'i:a'
                : 'p:a',
            'occurredAt': at.millisecondsSinceEpoch,
            'progress': progress,
            'mode': mode,
          });
      final summary = WeeklyCollageSummary.build(
        [item],
        [
          event(DateTime(2026, 9, 28, 0), 'audio', 1),
          event(DateTime(2026, 10, 4, 23, 59), 'video', .5),
          event(DateTime(2026, 10, 2), null, .5),
          event(DateTime(2026, 9, 27, 23, 59), 'audio', 1),
          event(DateTime(2026, 10, 5, 0), 'audio', 1),
          event(DateTime(2026, 10, 8), 'audio', 1),
        ],
        now,
      );
      expect(summary.start, DateTime(2026, 9, 28));
      expect(summary.end, DateTime(2026, 10, 5));
      expect(summary.plays(false), 1);
      expect(summary.plays(true), 1);
      expect(summary.minutes(false), 2);
      expect(summary.minutes(true), 1);
      expect(summary.entries.first.video, isFalse);
    },
  );

  test('sin actividad no inventa datos', () {
    final summary = WeeklyCollageSummary.build([], [], DateTime(2026, 10, 7));
    expect(summary.entries, isEmpty);
    expect(summary.plays(true), 0);
    expect(summary.minutes(false), 0);
  });

  test(
    'el periodo se conserva hasta el domingo y cambia el lunes a medianoche',
    () {
      final monday = WeeklyCollageSummary.build([], [], DateTime(2026, 10, 5));
      final sunday = WeeklyCollageSummary.build(
        [],
        [],
        DateTime(2026, 10, 11, 23, 59),
      );
      final nextMonday = WeeklyCollageSummary.build(
        [],
        [],
        DateTime(2026, 10, 12),
      );
      expect(sunday.start, monday.start);
      expect(sunday.end, monday.end);
      expect(nextMonday.start, monday.end);
      expect(nextMonday.end, DateTime(2026, 10, 12));
    },
  );
}

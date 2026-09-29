import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/recommendations/data/listening_event_store.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/Modules/stats/application/weekly_listening_summary.dart';
import 'package:listenfy/app/models/media_item.dart';

void main() {
  test(
    'resume los eventos reales de la semana y pondera el artista por tiempo',
    () async {
      final now = DateTime(2026, 9, 27, 20);
      final store = ListeningEventStore.memory([
        _event('p:a', now.subtract(const Duration(hours: 2)), .5),
        _event('p:b', now.subtract(const Duration(hours: 1)), 1),
        _event('p:a', now.subtract(const Duration(minutes: 30)), 1),
        _event('p:old', now.subtract(const Duration(days: 8)), 1),
      ]);
      final builder = WeeklyListeningSummaryBuilder(
        listeningEventStore: store,
        libraryLoader: () async => [
          _item('a', 'Artista A', 120),
          _item('b', 'Artista B', 30),
        ],
      );

      final summary = await builder.build(now);

      expect(summary, isNotNull);
      expect(summary!.periodKey, '2026-09-21');
      expect(summary.sessionCount, 3);
      expect(summary.uniqueTrackCount, 2);
      expect(summary.listenedSeconds, 210);
      expect(summary.listenedMinutes, 4);
      expect(summary.topArtistName, 'Artista A');
    },
  );

  test(
    'el lunes por la mañana conserva la misma semana recién finalizada',
    () async {
      final monday = DateTime(2026, 9, 28, 9);
      final store = ListeningEventStore.memory([
        _event('p:a', monday.subtract(const Duration(hours: 10)), 1),
      ]);
      final builder = WeeklyListeningSummaryBuilder(
        listeningEventStore: store,
        libraryLoader: () async => [_item('a', 'Artista A', 60)],
      );

      final summary = await builder.build(monday);

      expect(summary?.periodKey, '2026-09-21');
      expect(summary?.sessionCount, 1);
    },
  );
}

Map<String, dynamic> _event(String trackKey, DateTime at, double progress) => {
  'trackKey': trackKey,
  'occurredAt': at.millisecondsSinceEpoch,
  'progress': progress,
  'completed': progress >= 1,
  'skipped': false,
  'mode': 'audio',
};

MediaItem _item(String id, String artist, int seconds) => MediaItem(
  id: id,
  publicId: id,
  title: 'Canción $id',
  subtitle: artist,
  source: MediaSource.local,
  variants: [
    MediaVariant(
      kind: MediaVariantKind.audio,
      format: 'mp3',
      fileName: '$id.mp3',
      localPath: '/tmp/$id.mp3',
      durationSeconds: seconds,
      createdAt: 1,
    ),
  ],
  origin: SourceOrigin.device,
);

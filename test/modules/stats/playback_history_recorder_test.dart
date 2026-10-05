import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/services/playback_history_recorder.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/Modules/recommendations/data/listening_event_store.dart';
import 'package:listenfy/Modules/recommendations/domain/recommendation_models.dart';
import 'package:listenfy/Modules/stats/application/weekly_collage_summary.dart';

MediaItem item(String id) => MediaItem(
  id: id,
  publicId: id,
  title: id,
  subtitle: '',
  source: MediaSource.local,
  origin: SourceOrigin.device,
  variants: const [],
);

void main() {
  test(
    'motor registra cola sin controller, actualiza una sesión y conserva items eliminados',
    () async {
      final store = ListeningEventStore.memory();
      var now = DateTime(2026, 9, 29, 12);
      final recorder = PlaybackHistoryRecorder(
        events: store,
        mode: RecommendationMode.audio,
        clock: () => now,
      );
      void tick(int position) {
        now = now.add(const Duration(seconds: 1));
        recorder.update(
          position: Duration(seconds: position),
          duration: const Duration(seconds: 60),
          playing: true,
        );
      }

      recorder.select(item('a'));
      for (var i = 0; i <= 12; i++) {
        tick(i);
      }
      await recorder.flush();
      expect(store.readAll(), hasLength(1));
      expect(store.readAll().single.playedSeconds, 12);
      recorder.select(item('b'));
      for (var i = 0; i <= 8; i++) {
        tick(i);
      }
      await recorder.flush();
      expect(store.readAll(), hasLength(2));
      final summary = WeeklyCollageSummary.build(
        [],
        store.readAll(),
        DateTime(2026, 10, 5),
      );
      expect(summary.plays(false), 2);
      expect(summary.entries.fold<int>(0, (sum, e) => sum + e.seconds), 20);
    },
  );

  test('seek y pausa no inventan minutos ni nuevas reproducciones', () async {
    final store = ListeningEventStore.memory();
    var now = DateTime(2026, 9, 29);
    final recorder = PlaybackHistoryRecorder(
      events: store,
      mode: RecommendationMode.video,
      clock: () => now,
    );
    recorder.select(item('v'));
    void tick(int p, bool playing) {
      now = now.add(const Duration(seconds: 1));
      recorder.update(
        position: Duration(seconds: p),
        duration: const Duration(seconds: 120),
        playing: playing,
      );
    }

    for (var i = 0; i <= 6; i++) {
      tick(i, true);
    }
    recorder.beforeSeek();
    tick(100, true);
    tick(101, true);
    tick(101, false);
    now = now.add(const Duration(minutes: 10));
    tick(101, false);
    await recorder.flush();
    expect(store.readAll(), hasLength(1));
    expect(store.readAll().single.playedSeconds, 7);
  });

  test('repetir una pista completa crea otra sesión', () async {
    final store = ListeningEventStore.memory();
    var now = DateTime(2026, 9, 29);
    final recorder = PlaybackHistoryRecorder(
      events: store,
      mode: RecommendationMode.audio,
      clock: () => now,
    );
    recorder.select(item('loop'));
    for (var replay = 0; replay < 2; replay++) {
      for (var p = 0; p <= 10; p++) {
        now = now.add(const Duration(seconds: 1));
        recorder.update(
          position: Duration(seconds: p),
          duration: const Duration(seconds: 10),
          playing: true,
        );
      }
    }
    await recorder.flush();
    expect(store.readAll(), hasLength(2));
    expect(store.readAll().every((e) => e.completed), isTrue);
  });

  test(
    'backup conserva snapshots y sesiones sin duplicarlas al restaurar dos veces',
    () async {
      final source = ListeningEventStore.memory();
      await source.add(
        ListeningEvent(
          trackKey: 'p:a',
          occurredAt: DateTime.now().millisecondsSinceEpoch,
          progress: .5,
          completed: false,
          skipped: false,
          mode: RecommendationMode.audio,
          sessionId: 'session',
          playedSeconds: 30,
          mediaSnapshot: item('a'),
        ),
      );
      final restored = ListeningEventStore.memory();
      await restored.restoreBackupPayload(source.exportBackupPayload());
      await restored.restoreBackupPayload(source.exportBackupPayload());
      expect(restored.readAll(), hasLength(1));
      expect(restored.readAll().single.mediaSnapshot?.title, 'a');
      expect(restored.readAll().single.playedSeconds, 30);
    },
  );
}

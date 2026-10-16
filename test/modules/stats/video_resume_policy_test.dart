import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/app/services/video_resume_policy.dart';
import 'package:listenfy/app/models/media_item.dart';

class _Memory implements GetStorage {
  final values = <String, dynamic>{};
  @override
  T? read<T>(String key) => values[key] as T?;
  @override
  Future<void> write(String key, dynamic value) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

void main() {
  final item = MediaItem.fromJson({
    'id': 'video',
    'title': 'Video',
    'variants': [],
    'durationSeconds': 300,
  });
  test(
    'engine policy persists eligible watching without a route controller',
    () {
      var now = 0;
      final memory = _Memory();
      final policy = VideoResumePolicy(memory, monotonicMs: () => now);
      for (var i = 0; i <= 10; i++) {
        now = i * 1000;
        policy.observe(
          item,
          Duration(seconds: 20 + i),
          const Duration(seconds: 300),
          true,
        );
      }
      expect((memory.values['video_resume_positions'] as Map)['video'], 30000);
      expect((memory.values['video_resume_watch_ms'] as Map)['video'], 10000);
    },
  );
  test('seek and paused time never qualify as trusted watch', () {
    var now = 0;
    final memory = _Memory();
    final policy = VideoResumePolicy(memory, monotonicMs: () => now);
    policy.observe(item, Duration.zero, const Duration(seconds: 300), true);
    now = 1000;
    policy.discontinuity();
    policy.observe(
      item,
      const Duration(seconds: 100),
      const Duration(seconds: 300),
      true,
    );
    now = 12000;
    policy.observe(
      item,
      const Duration(seconds: 100),
      const Duration(seconds: 300),
      false,
    );
    policy.persist(
      item,
      const Duration(seconds: 100),
      const Duration(seconds: 300),
    );
    expect(memory.values['video_resume_positions'], isEmpty);
  });
}

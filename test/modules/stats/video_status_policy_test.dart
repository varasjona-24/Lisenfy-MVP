import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/utils/media_item_status_helper.dart';

void main() {
  test('seen persists during a new partial playback', () {
    expect(
      resolveVideoProgress(seen: true, started: true, resumable: true),
      VideoProgressStatus.completado,
    );
  });
  test('resume and progress are distinct from pending', () {
    expect(
      resolveVideoProgress(seen: false, started: true, resumable: true),
      VideoProgressStatus.viendo,
    );
    expect(
      resolveVideoProgress(seen: false, started: true, resumable: false),
      VideoProgressStatus.enProgreso,
    );
    expect(
      resolveVideoProgress(seen: false, started: false, resumable: false),
      VideoProgressStatus.pendiente,
    );
  });
  test('duration boundaries include reels, 2:30 and 13 minutes', () {
    MediaItem item(int seconds) => MediaItem.fromJson({
      'id': 'v',
      'title': 'Video',
      'durationSeconds': seconds,
      'variants': [],
    });
    expect(item(10).isShortVideoForResume, isTrue);
    expect(item(149).isShortVideoForResume, isTrue);
    expect(item(150).isShortVideoForResume, isFalse);
    expect(item(150).usesSeenLabel, isTrue);
    expect(item(780).usesSeenLabel, isTrue);
    expect(item(781).usesSeenLabel, isFalse);
  });
}

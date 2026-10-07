import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/services/video_service.dart';
import 'package:listenfy/app/ui/widgets/player/continue_video_card.dart';

class _Video extends VideoService {
  // Avoid native player initialization in this presentation test.
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onClose() {}
}

void main() {
  tearDown(() => Get.reset());

  testWidgets('no session service renders no resume action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ContinueVideoCard(header: Text('Section title'))),
      ),
    );
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Section title'), findsNothing);
  });

  testWidgets('card follows the current video without mutating playback', (
    tester,
  ) async {
    final video = (await tester.runAsync(
      () async => Get.put<VideoService>(_Video()),
    ))!;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ContinueVideoCard(header: Text('Section title'))),
      ),
    );
    expect(find.byType(InkWell), findsNothing);
    video.currentItem.value = MediaItem.fromJson({
      'id': 'video',
      'title': 'Saved video',
      'source': 'local',
      'origin': 'device',
      'variants': [],
    });
    await tester.pump();
    expect(find.text('Saved video'), findsOneWidget);
    expect(find.text('Section title'), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);
    expect(video.isPlaying.value, isFalse);
    video.currentItem.value = null;
    await tester.pump();
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Section title'), findsNothing);
  });
}

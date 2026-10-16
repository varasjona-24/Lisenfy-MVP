import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:listenfy/app/services/audio_service.dart';
import 'package:listenfy/app/controllers/navigation_controller.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/ui/widgets/player/mini_player_bar.dart';
import 'package:listenfy/app/ui/widgets/motion/app_motion.dart';
import 'package:listenfy/app/utils/media_item_status_helper.dart';

class _Audio extends AudioService {
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}
  @override
  void onClose() {}
}

void main() {
  tearDown(() => Get.reset());
  MediaItem item(bool favorite) => MediaItem.fromJson({
    'id': 'song',
    'title': 'Song',
    'isFavorite': favorite,
    'variants': [],
  });
  testWidgets(
    'favorite feedback runs on change, not when scrolling existing favorites',
    (tester) async {
      Widget show(bool favorite) =>
          MaterialApp(home: VideoFavoriteBadge(item: item(favorite)));
      await tester.pumpWidget(show(true));
      expect(find.byType(AppMotionEntrance), findsNothing);
      await tester.pumpWidget(show(false));
      await tester.pumpWidget(show(true));
      expect(find.byType(AppMotionEntrance), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    },
  );
  testWidgets(
    'video context hides audio immediately without deleting its session',
    (tester) async {
      final audio = Get.put<AudioService>(_Audio());
      final nav = Get.put(NavigationController());
      audio.currentItem.value = item(false);
      audio.state.value = PlaybackState.paused;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MiniPlayerBar())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Song'), findsOneWidget);
      nav.isVideoContext.value = true;
      await tester.pump();
      expect(find.text('Song'), findsNothing);
      expect(audio.currentItem.value?.id, 'song');
      expect(audio.miniPlayerDismissed.value, isFalse);
      nav.isVideoContext.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Song'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

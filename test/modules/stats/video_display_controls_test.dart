import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:get/get.dart' hide Translations;
import 'package:listenfy/Modules/player/Video/controller/video_player_controller.dart';
import 'package:listenfy/Modules/player/Video/view/video_player_page.dart';
import 'package:listenfy/Modules/settings/controller/playback_settings_controller.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/services/video_service.dart';

class _Settings extends PlaybackSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Video extends VideoService {
  vp.VideoPlayerController? fixture;
  @override
  vp.VideoPlayerController? get playerController => fixture;
  int seeks = 0, volumeChanges = 0;
  Duration? lastSeek;
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onClose() {}
  @override
  Future<void> seek(Duration value) async {
    seeks++;
    lastSeek = value;
  }

  @override
  Future<void> setVolume(double value) async {
    volumeChanges++;
  }
}

class _Controller extends VideoPlayerController {
  _Controller(_Video video, MediaItem item)
    : super(videoService: video, queue: [item], initialIndex: 0) {
    queue.assignAll([item]);
  }
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
  @override
  void onClose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  });
  tearDown(() => Get.reset());
  for (final brightness in Brightness.values) {
    testWidgets('fit and lock controls work on a narrow $brightness screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('listenfy/pip'),
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('listenfy/pip'),
          null,
        ),
      );
      Get.put<PlaybackSettingsController>(_Settings());
      final video = _Video();
      final player = vp.VideoPlayerController.asset('fixture.mp4');
      player.value = const vp.VideoPlayerValue(
        duration: Duration(minutes: 5),
        isInitialized: true,
        size: Size(1920, 1080),
      );
      video.fixture = player;
      addTearDown(player.dispose);
      video.duration.value = const Duration(minutes: 5);
      final controller = _Controller(
        video,
        MediaItem.fromJson({'id': 'video', 'title': 'Episode', 'variants': []}),
      );
      Get.put<VideoPlayerController>(controller);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const VideoPlayerPage(),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(vp.VideoPlayer), findsOneWidget);
      final progress = find.byKey(const ValueKey('video-progress-slider'));
      final progressRect = tester.getRect(progress);
      // Touching the track must not jump or start scrubbing.
      await tester.tapAt(
        Offset(progressRect.right - 30, progressRect.center.dy),
      );
      await tester.pump();
      expect(video.seeks, 0);
      final thumb = Offset(progressRect.left + 24, progressRect.center.dy);
      await tester.tapAt(thumb);
      await tester.pump();
      expect(video.seeks, 0);
      final drag = await tester.startGesture(thumb);
      await drag.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(video.seeks, 0);
      expect(tester.widget<Slider>(progress).value, greaterThan(0));
      expect(tester.getRect(progress).center.dy, progressRect.center.dy);
      await tester.pump(const Duration(seconds: 4));
      expect(progress, findsOneWidget);
      expect(video.seeks, 0);
      await drag.up();
      await tester.pump();
      expect(video.seeks, 1);
      expect(video.lastSeek, greaterThan(Duration.zero));
      video.seeks = 0;
      video.lastSeek = null;
      expect(find.text('Fill'), findsOneWidget);
      await tester.tap(find.text('Fill'));
      await tester.pump();
      expect(find.text('Fit'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is FittedBox && widget.fit == BoxFit.cover,
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Lock controls'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byTooltip('Unlock controls'), findsOneWidget);
      expect(find.text('Fit'), findsNothing);
      await tester.tapAt(const Offset(80, 200));
      await tester.pump(const Duration(milliseconds: 70));
      await tester.tapAt(const Offset(80, 200));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.dragFrom(const Offset(80, 250), const Offset(0, -90));
      await tester.pump();
      expect(video.seeks, 0);
      expect(video.volumeChanges, 0);
      await tester.tap(find.byTooltip('Unlock controls'));
      await tester.pump();
      expect(find.text('Fit'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Get.find<PlaybackSettingsController>().videoSeekSeconds.value = 15;
      await tester.tapAt(const Offset(260, 200));
      await tester.pump(const Duration(milliseconds: 70));
      await tester.tapAt(const Offset(260, 200));
      await tester.pump(const Duration(milliseconds: 400));
      expect(video.lastSeek, const Duration(seconds: 15));
      await tester.tap(find.byTooltip('Rewind by the selected interval'));
      await tester.pump();
      expect(video.lastSeek, Duration.zero);
      await tester.tap(find.byTooltip('Advance by the selected interval'));
      await tester.pump();
      expect(video.lastSeek, const Duration(seconds: 15));
      tester.view.physicalSize = const Size(640, 360);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
    });
  }
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/services/desktop_video_fullscreen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  late bool nativeFullscreen;
  late List<bool> requests;
  late DesktopVideoFullscreen fullscreen;
  Completer<void>? transition;
  bool fail = false;

  setUp(() {
    nativeFullscreen = false;
    requests = [];
    transition = null;
    fail = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isFullScreen') return nativeFullscreen;
          if (call.method == 'setFullScreen') {
            if (fail) throw PlatformException(code: 'denied');
            final next = (call.arguments as Map)['isFullScreen'] as bool;
            requests.add(next);
            await transition?.future;
            nativeFullscreen = next;
            return null;
          }
          throw StateError('Unexpected method: ${call.method}');
        });
    fullscreen = DesktopVideoFullscreen();
  });

  tearDown(() async {
    await fullscreen.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'toggle uses native state and restores initial window mode on close',
    () async {
      await fullscreen.initialize();
      await fullscreen.toggle();
      expect(nativeFullscreen, isTrue);
      expect(fullscreen.value, isTrue);
      await fullscreen.close();
      expect(nativeFullscreen, isFalse);
      expect(requests, [true, false]);
    },
  );

  test('a window already fullscreen is preserved when leaving video', () async {
    nativeFullscreen = true;
    await fullscreen.initialize();
    expect(fullscreen.value, isTrue);
    await fullscreen.close();
    expect(requests, isEmpty);
    expect(nativeFullscreen, isTrue);
  });

  test('native enter and exit events update player state', () async {
    await fullscreen.initialize();
    var changes = 0;
    fullscreen.addListener(() => changes++);
    nativeFullscreen = true;
    fullscreen.onWindowEnterFullScreen();
    expect(fullscreen.value, isTrue);
    nativeFullscreen = false;
    fullscreen.onWindowLeaveFullScreen();
    expect(fullscreen.value, isFalse);
    expect(changes, 2);
  });

  test(
    'closing during a request waits and restores without notifying disposed UI',
    () async {
      await fullscreen.initialize();
      transition = Completer<void>();
      final request = fullscreen.toggle();
      while (requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final duplicate = fullscreen.toggle();
      final closing = fullscreen.close();
      transition!.complete();
      await Future.wait([request, duplicate, closing]);
      expect(requests, [true, false]);
      expect(nativeFullscreen, isFalse);
    },
  );

  test(
    'failed native request does not claim fullscreen or change initial mode',
    () async {
      await fullscreen.initialize();
      fail = true;
      await expectLater(fullscreen.toggle(), throwsA(isA<PlatformException>()));
      expect(fullscreen.value, isFalse);
      expect(requests, isEmpty);
    },
  );
}

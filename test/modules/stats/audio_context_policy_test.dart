import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:listenfy/app/controllers/navigation_controller.dart';
import 'package:listenfy/app/services/audio_context_policy.dart';

void main() {
  late bool playing;
  late bool loaded;
  late int revision;
  late int pauses;
  late int resumes;
  late AudioContextPolicy policy;
  setUp(() {
    playing = true;
    loaded = true;
    revision = pauses = resumes = 0;
    policy = AudioContextPolicy(
      isPlaying: () => playing,
      canResume: () => loaded,
      intentRevision: () => revision,
      pause: () async {
        pauses++;
        playing = false;
      },
      resume: () async {
        resumes++;
        playing = true;
        revision++;
      },
    );
  });
  tearDown(() => Get.reset());

  test('video pauses temporarily and audio resumes once', () async {
    await policy.update(blocked: true);
    await policy.update(blocked: true);
    expect(pauses, 1);
    await policy.update(blocked: false);
    await policy.update(blocked: false);
    expect(resumes, 1);
  });
  test('already paused audio stays paused', () async {
    playing = false;
    await policy.update(blocked: true);
    await policy.update(blocked: false);
    expect(pauses, 0);
    expect(resumes, 0);
  });
  test('manual pause revokes automatic resume', () async {
    await policy.update(blocked: true);
    revision++;
    await policy.update(blocked: false);
    expect(resumes, 0);
  });
  test('discarded source never resumes', () async {
    await policy.update(blocked: true);
    loaded = false;
    await policy.update(blocked: false);
    expect(resumes, 0);
  });
  test('video still playing keeps block until it stops', () async {
    await policy.update(blocked: true);
    await policy.update(blocked: true);
    expect(resumes, 0);
    await policy.update(blocked: false);
    expect(resumes, 1);
  });
  test('rapid context changes reconcile latest context', () async {
    final first = policy.update(blocked: true);
    final second = policy.update(blocked: false);
    await Future.wait([first, second]);
    expect(playing, isTrue);
    expect(pauses, 0);
  });
  test('all sources routes block audio, music ignores Home video mode', () {
    final nav = Get.put(NavigationController());
    nav.setHomeVideoMode(true);
    for (final route in [
      '/sources',
      '/sources/library',
      '/sources/theme',
      '/sources/playlist',
      '/home',
      '/home/section-list',
      '/player/video',
    ]) {
      nav.setRoute(route);
      expect(nav.isVideoContext.value, isTrue, reason: route);
    }
    nav.setRoute('/artists');
    expect(nav.isVideoContext.value, isFalse);
    nav.setRoute('/home');
    nav.setHomeVideoMode(false);
    expect(nav.isVideoContext.value, isFalse);
  });
  test('nested popups preserve page context and clear on return', () {
    final nav = Get.put(NavigationController());
    final observer = PlaybackNavigationObserver();
    final audio = PageRouteBuilder<void>(
      settings: const RouteSettings(name: '/artists'),
      pageBuilder: (_, animation, secondary) => const SizedBox(),
    );
    final video = PageRouteBuilder<void>(
      settings: const RouteSettings(name: '/sources/library'),
      pageBuilder: (_, animation, secondary) => const SizedBox(),
    );
    final popup = RawDialogRoute<void>(
      pageBuilder: (_, animation, secondary) => const SizedBox(),
    );
    final second = RawDialogRoute<void>(
      pageBuilder: (_, animation, secondary) => const SizedBox(),
    );
    observer.didPush(audio, null);
    observer.didPush(video, audio);
    final editor = PageRouteBuilder<void>(
      settings: const RouteSettings(name: '/edit'),
      pageBuilder: (_, animation, secondary) => const SizedBox(),
    );
    observer.didPush(editor, video);
    expect(nav.isVideoContext.value, isTrue);
    observer.didPop(editor, video);
    observer.didPush(popup, video);
    observer.didPush(second, popup);
    observer.didPop(second, popup);
    expect(nav.isModalOpen.value, isTrue);
    expect(nav.currentRoute.value, '/sources/library');
    observer.didPop(popup, video);
    expect(nav.isModalOpen.value, isFalse);
    observer.didPop(video, audio);
    expect(nav.isVideoContext.value, isFalse);
    expect(nav.currentRoute.value, '/artists');
  });
}

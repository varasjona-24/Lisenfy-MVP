import 'package:get/get.dart';
import 'package:flutter/widgets.dart';

import '../routes/app_routes.dart';
import '../services/audio_context_policy.dart';
import '../services/audio_service.dart';
import '../services/video_service.dart';

class NavigationController extends GetxController {
  final RxString currentRoute = ''.obs;
  final RxBool isEditing = false.obs;
  final RxBool isOverlayOpen = false.obs;
  final RxBool isVideoContext = false.obs;
  final RxBool isModalOpen = false.obs;
  int _overlayDepth = 0;
  bool _homeVideo = false;
  bool _routeVideoOrigin = false;
  AudioContextPolicy? _audioPolicy;
  Worker? _audioWorker;
  Worker? _videoWorker;

  void setHomeVideoMode(bool value) {
    _homeVideo = value;
    _syncPlaybackContext();
  }

  void setRoute(String route, {bool videoOrigin = false}) {
    _routeVideoOrigin = videoOrigin;
    currentRoute.value = route;
    _syncPlaybackContext();
  }

  void _syncPlaybackContext() {
    final route = currentRoute.value;
    isVideoContext.value =
        _routeVideoOrigin ||
        route == AppRoutes.sources ||
        route.startsWith('${AppRoutes.sources}/') ||
        route == AppRoutes.videoPlayer ||
        route.startsWith('${AppRoutes.videoPlayer}/') ||
        (_homeVideo &&
            (route == AppRoutes.home ||
                route.startsWith('${AppRoutes.home}/')));

    if (!Get.isRegistered<AudioService>()) return;
    final audio = Get.find<AudioService>();
    _audioPolicy ??= AudioContextPolicy(
      isPlaying: () => audio.isPlaying.value,
      canResume: () =>
          audio.hasSourceLoaded && !audio.miniPlayerDismissed.value,
      intentRevision: () => audio.playbackIntentRevision,
      pause: audio.pauseForVideoContext,
      resume: audio.resume,
    );
    _audioWorker ??= ever(audio.isPlaying, (_) => _syncPlaybackContext());
    if (Get.isRegistered<VideoService>()) {
      _videoWorker ??= ever(
        Get.find<VideoService>().isPlaying,
        (_) => _syncPlaybackContext(),
      );
    }
    final videoPlaying =
        Get.isRegistered<VideoService>() &&
        Get.find<VideoService>().isPlaying.value;
    // Startup is neither a video context nor an explicit return to audio.
    if (route.isEmpty || route == AppRoutes.entry) return;
    final blocked = isVideoContext.value || videoPlaying;
    _audioPolicy!.update(blocked: blocked).catchError((Object error) {
      debugPrint('Audio context transition failed: $error');
    });
  }

  @override
  void onClose() {
    _audioWorker?.dispose();
    _videoWorker?.dispose();
    super.onClose();
  }

  void setEditing(bool value) {
    isEditing.value = value;
  }

  void setOverlayOpen(bool value) {
    _overlayDepth = value
        ? _overlayDepth + 1
        : (_overlayDepth > 0 ? _overlayDepth - 1 : 0);
    isOverlayOpen.value = _overlayDepth > 0;
  }
}

/// Tracks the visible page independently from popup routes and Get flags.
class PlaybackNavigationObserver extends NavigatorObserver {
  final List<Route<dynamic>> _stack = [];
  final Map<Route<dynamic>, bool> _videoOrigins = {};

  void _rememberOrigin(Route<dynamic> route) {
    final path = Uri.tryParse(route.settings.name ?? '')?.path;
    final shared =
        path == AppRoutes.editEntity ||
        path == AppRoutes.createEntity ||
        path == AppRoutes.captureGallery ||
        path == AppRoutes.captureTags ||
        path == AppRoutes.homeSectionList;
    _videoOrigins[route] =
        shared &&
        Get.isRegistered<NavigationController>() &&
        Get.find<NavigationController>().isVideoContext.value;
  }

  void _publish() {
    if (!Get.isRegistered<NavigationController>()) return;
    final nav = Get.find<NavigationController>();
    nav.isModalOpen.value = _stack.any((route) => route is PopupRoute);
    for (final route in _stack.reversed) {
      if (route is PageRoute && route.settings.name != null) {
        nav.setRoute(
          Uri.parse(route.settings.name!).path,
          videoOrigin: _videoOrigins[route] ?? false,
        );
        break;
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _rememberOrigin(route);
    _stack.add(route);
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _videoOrigins.remove(route);
    _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _videoOrigins.remove(route);
    _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final inherited = oldRoute == null ? false : _videoOrigins.remove(oldRoute);
    if (newRoute != null) {
      _rememberOrigin(newRoute);
      if (inherited == true) _videoOrigins[newRoute] = true;
    }
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _stack.removeAt(index);
      } else {
        _stack[index] = newRoute;
      }
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
    _publish();
  }
}

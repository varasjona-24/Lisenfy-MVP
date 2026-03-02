import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart' as vp;

import 'package:flutter_listenfy/Modules/player/Video/controller/video_player_controller.dart';
import '../../../../app/routes/app_routes.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController controller;
  bool _showControls = true;
  bool _isFullscreen = false;
  Timer? _hideTimer;
  Timer? _speedTimer;
  double? _dragValue;
  String? _speedToast;
  double _speedGestureOffset = 0;
  bool _speedGestureConsumed = false;
  int _activePointers = 0;
  bool _pipRequested = false;
  final MethodChannel _pipChannel = const MethodChannel('listenfy/pip');
  late final _LifecycleObserver _lifecycleObserver;
  Worker? _pipWorker;

  @override
  void initState() {
    super.initState();
    controller = Get.find<VideoPlayerController>();
    _lifecycleObserver = _LifecycleObserver(this);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _scheduleHide();
    _bindPip();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _speedTimer?.cancel();
    _pipWorker?.dispose();
    _pipWorker = null;
    _setPipEnabled(false);
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _bindPip() {
    if (!Platform.isAndroid) return;
    _pipWorker = everAll([controller.isPlaying, controller.isQueueOpen], (_) {
      final enabled =
          controller.isPlaying.value && !controller.isQueueOpen.value;
      _setPipEnabled(enabled);
    });
    _setPipEnabled(controller.isPlaying.value && !controller.isQueueOpen.value);
  }

  Future<void> _setPipEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    final vpCtrl = controller.playerController;
    double aspect = 1.777777;
    if (vpCtrl != null && vpCtrl.value.isInitialized) {
      final size = vpCtrl.value.size;
      if (size.width > 0 && size.height > 0) {
        aspect = size.width / size.height;
      }
    }
    try {
      await _pipChannel.invokeMethod('setEnabled', {
        'enabled': enabled,
        'aspect': aspect,
      });
    } catch (_) {}
  }

  Future<void> _enterPipIfNeeded() async {
    if (_pipRequested) return;
    if (!Platform.isAndroid) return;
    if (controller.isQueueOpen.value) return;
    final vpCtrl = controller.playerController;
    if (vpCtrl == null || !vpCtrl.value.isInitialized) return;
    if (!controller.isPlaying.value) return;
    final size = vpCtrl.value.size;
    if (size.width <= 0 || size.height <= 0) return;
    final aspect = size.width / size.height;
    try {
      _pipRequested = true;
      await _pipChannel.invokeMethod('enter', {'aspect': aspect});
      // Ensure playback continues when entering PiP.
      Future.microtask(() async {
        if (!controller.isPlaying.value) return;
        await controller.videoService.resume();
      });
    } catch (_) {
      _pipRequested = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Obx(() {
          final queue = controller.queue;
          final idx = controller.currentIndex.value;

          final item = (queue.isNotEmpty && idx >= 0 && idx < queue.length)
              ? queue[idx]
              : null;

          if (item == null) {
            return const Center(child: Text('No hay vídeo'));
          }

          return Stack(
            children: [
              Positioned.fill(child: _buildVideoArea(theme)),
              if (_showControls)
                Positioned.fill(child: _buildControls(theme, item)),
              if (_speedToast != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _speedToast!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildVideoArea(ThemeData theme) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _activePointers++,
      onPointerUp: (_) {
        _activePointers = (_activePointers - 1).clamp(0, 10);
        if (_activePointers < 2) _resetSpeedGesture();
      },
      onPointerCancel: (_) {
        _activePointers = 0;
        _resetSpeedGesture();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onDoubleTap: _togglePlayOnDoubleTap,
        onVerticalDragStart: (_) => _resetSpeedGesture(),
        onVerticalDragUpdate: (details) {
          if (_activePointers >= 2) {
            _onVerticalDragUpdate(details);
          }
        },
        onVerticalDragEnd: (_) => _resetSpeedGesture(),
        onVerticalDragCancel: _resetSpeedGesture,
        child: Obx(() {
          final _ = controller.state.value;
          final err = controller.error.value;
          if (err != null) {
            return _ErrorPanel(
              message: err,
              onPickOther: () => Get.toNamed(AppRoutes.videoQueue),
              onRetry: controller.retry,
            );
          }

          final vpCtrl = controller.playerController;
          if (vpCtrl == null || !vpCtrl.value.isInitialized) {
            return Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          final size = vpCtrl.value.size;
          if (size.width <= 0 || size.height <= 0) {
            return Container(
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Center(
                child: Text(
                  'No se pudo obtener el tamaño del vídeo.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Container(
            color: Colors.black,
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: vp.VideoPlayer(vpCtrl),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildControls(ThemeData theme, dynamic item) {
    return IconTheme(
      data: const IconThemeData(color: Colors.white),
      child: Column(
        children: [
          if (!_isFullscreen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: Get.back,
                  ),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ver cola',
                    icon: const Icon(Icons.playlist_play),
                    onPressed: () => Get.toNamed(AppRoutes.videoQueue),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _buildProgress(theme, item),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: controller.previous,
                    ),
                    const SizedBox(width: 12),
                    Obx(() {
                      final playing = controller.isPlaying.value;
                      return ElevatedButton(
                        onPressed: controller.togglePlay,
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.25,
                          ),
                          elevation: 0,
                        ),
                        child: Icon(
                          playing ? Icons.pause : Icons.play_arrow,
                          size: 30,
                          color: Colors.white,
                        ),
                      );
                    }),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: controller.next,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _openSpeedPicker,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.speed),
                      label: Obx(
                        () => Text(
                          '${controller.videoService.speed.value.toStringAsFixed(1)}x',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                      ),
                      onPressed: _toggleFullscreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(ThemeData theme, dynamic item) {
    return Obx(() {
      final dur = controller.duration.value;
      final pos = controller.position.value;
      final previewPos = _dragValue != null
          ? Duration(seconds: _dragValue!.toInt())
          : pos;

      final maxSeconds = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;
      final posSeconds = (previewPos.inSeconds.toDouble()).clamp(
        0.0,
        maxSeconds,
      );

      return Column(
        children: [
          if (_dragValue != null) _buildPreview(item, previewPos),
          Row(
            children: [
              Text(_fmt(previewPos), style: theme.textTheme.bodySmall),
              Expanded(
                child: Slider(
                  value: posSeconds,
                  min: 0.0,
                  max: maxSeconds,
                  onChanged: (v) {
                    setState(() => _dragValue = v);
                    _showControlsTemp();
                  },
                  onChangeEnd: (v) {
                    controller.seek(Duration(seconds: v.toInt()));
                    setState(() => _dragValue = null);
                  },
                ),
              ),
              Text(_fmt(dur), style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildPreview(dynamic item, Duration position) {
    final thumb = item.effectiveThumbnail;
    if (thumb == null || thumb.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          _fmt(position),
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    final image = thumb.startsWith('http')
        ? Image.network(thumb, fit: BoxFit.cover)
        : Image.file(File(thumb), fit: BoxFit.cover);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 56, height: 36, child: image),
          ),
          const SizedBox(width: 8),
          Text(_fmt(position), style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _showControlsTemp() {
    setState(() => _showControls = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _togglePlayOnDoubleTap() {
    controller.togglePlay();
    _showControlsTemp();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_speedGestureConsumed) return;
    _speedGestureOffset += -details.delta.dy;
    if (_speedGestureOffset.abs() < 24) return;
    final step = _speedGestureOffset > 0 ? 0.1 : -0.1;
    _adjustSpeed(step);
    _speedGestureConsumed = true;
  }

  void _resetSpeedGesture() {
    _speedGestureOffset = 0;
    _speedGestureConsumed = false;
  }

  void _adjustSpeed(double delta) {
    final current = controller.videoService.speed.value;
    final next = (current + delta).clamp(0.5, 2.0);
    controller.videoService.setSpeed(next);
    _showSpeedToast('${next.toStringAsFixed(1)}x');
  }

  void _showSpeedToast(String text) {
    setState(() => _speedToast = text);
    _speedTimer?.cancel();
    _speedTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _speedToast = null);
    });
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _openSpeedPicker() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final s in speeds)
                ListTile(
                  title: Text('${s.toStringAsFixed(2)}x'),
                  onTap: () {
                    controller.videoService.setSpeed(s);
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) {
      final hh = h.toString().padLeft(2, '0');
      return '$hh:$m:$s';
    }
    return '$m:$s';
  }
}

class _LifecycleObserver with WidgetsBindingObserver {
  final _VideoPlayerPageState state;

  _LifecycleObserver(this.state);

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused) {
      if (state.controller.isQueueOpen.value) {
        state._setPipEnabled(false);
        unawaited(state.controller.videoService.pause());
        return;
      }
      state._enterPipIfNeeded();
    } else if (appState == AppLifecycleState.resumed) {
      state._pipRequested = false;
      state._setPipEnabled(
        state.controller.isPlaying.value && !state.controller.isQueueOpen.value,
      );
    }
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.onPickOther,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onPickOther;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: onPickOther,
                  child: const Text('Seleccionar otro'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/services/audio_visualizer_service.dart';
import '../../../../app/services/audio_waveform_service.dart';
import '../controller/audio_player_controller.dart';
import 'turntable_needle.dart';

class CoverArt extends StatelessWidget {
  final AudioPlayerController controller;
  final MediaItem item;

  const CoverArt({super.key, required this.controller, required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Obx(() {
      final style = controller.coverStyle.value;

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: switch (style) {
          CoverStyle.square => _SquareCover(colors: colors, item: item),
          CoverStyle.vinyl => _VinylCover(colors: colors, item: item),
          CoverStyle.wave => _WaveCover(
            colors: colors,
            item: item,
            controller: controller,
            displayMode: _WaveDisplayMode.wave,
          ),
          CoverStyle.miniSpectrum => _WaveCover(
            colors: colors,
            item: item,
            controller: controller,
            displayMode: _WaveDisplayMode.miniSpectrum,
          ),
        },
      );
    });
  }
}

class _SquareCover extends StatelessWidget {
  final ColorScheme colors;
  final MediaItem item;

  const _SquareCover({required this.colors, required this.item});

  @override
  Widget build(BuildContext context) {
    final thumb = item.effectiveThumbnail ?? '';
    final hasThumb = thumb.isNotEmpty;
    final isLocal = hasThumb && thumb.startsWith('/');

    return Container(
      key: const ValueKey('square'),
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasThumb
          ? (isLocal
                ? Image.file(
                    File(thumb),
                    width: 260,
                    height: 260,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.music_note_rounded,
                      size: 72,
                      color: colors.onSurfaceVariant.withOpacity(0.7),
                    ),
                  )
                : Image.network(
                    thumb,
                    width: 260,
                    height: 260,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.music_note_rounded,
                      size: 72,
                      color: colors.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ))
          : Icon(
              Icons.music_note_rounded,
              size: 72,
              color: colors.onSurfaceVariant.withOpacity(0.7),
            ),
    );
  }
}

class _VinylCover extends StatefulWidget {
  final ColorScheme colors;
  final MediaItem item;

  const _VinylCover({required this.colors, required this.item});

  @override
  State<_VinylCover> createState() => _VinylCoverState();
}

class _VinylCoverState extends State<_VinylCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationCtrl;
  late final AudioPlayerController controller;

  Worker? _playingWorker;

  @override
  void initState() {
    super.initState();

    controller = Get.find<AudioPlayerController>();

    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    _playingWorker = ever(controller.audioService.isPlaying, (_) {
      if (!mounted) return;
      _syncRotation();
    });

    _syncRotation();
  }

  void _syncRotation() {
    if (!mounted) return;

    final playing = controller.audioService.isPlaying.value;
    if (playing) {
      _rotationCtrl.repeat();
    } else {
      _rotationCtrl.stop();
    }
  }

  @override
  void dispose() {
    _playingWorker?.dispose();
    _rotationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumb = widget.item.effectiveThumbnail ?? '';
    final hasThumb = thumb.isNotEmpty;
    final isLocal = hasThumb && thumb.startsWith('/');

    const double diskSize = 280;
    const double labelSize = 215;

    return SizedBox(
      key: const ValueKey('vinyl'),
      width: diskSize,
      height: diskSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1) VINILO (NO rota)
          Transform.translate(
            offset: const Offset(0, 1), // 👈 bajadito para que se vea “debajo”
            child: Image.asset(
              'assets/ui/vinyl.png', // <-- tu png del disco
              width: diskSize,
              height: diskSize,
              fit: BoxFit.contain,
            ),
          ),

          // 2) LABEL / COVER (SÍ rota)
          ClipOval(
            child: SizedBox(
              width: labelSize,
              height: labelSize,
              child: RotationTransition(
                turns: _rotationCtrl,
                child: hasThumb
                    ? (isLocal
                          ? Image.file(
                              File(thumb),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.music_note_rounded,
                                  size: 52,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            )
                          : Image.network(
                              thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.music_note_rounded,
                                  size: 52,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ))
                    : Center(
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 52,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
              ),
            ),
          ),

          // 3) AGUJA (siempre Positioned para no romper centrado)
          const Positioned(top: -16, right: 23, child: TurntableNeedle()),
        ],
      ),
    );
  }
}

class _WaveCover extends StatefulWidget {
  final ColorScheme colors;
  final MediaItem item;
  final AudioPlayerController controller;
  final _WaveDisplayMode displayMode;

  const _WaveCover({
    required this.colors,
    required this.item,
    required this.controller,
    required this.displayMode,
  });

  @override
  State<_WaveCover> createState() => _WaveCoverState();
}

class _WaveCoverState extends State<_WaveCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationCtrl;
  late List<double> _fallbackHeights;
  late List<double> _baseHeights;
  List<double> _liveBars = const [];
  late final AudioVisualizerService? _visualizerService;
  late final AudioWaveformService? _waveformService;
  StreamSubscription<int?>? _sessionIdSub;
  StreamSubscription<List<double>>? _liveBarsSub;
  int? _attachedSessionId;
  int? _attachedBarCount;
  String? _attachedCaptureMode;
  Worker? _playingWorker;

  @override
  void initState() {
    super.initState();
    _fallbackHeights = _buildBaseHeights(widget.item);
    _baseHeights = _fallbackHeights;
    _visualizerService = Get.isRegistered<AudioVisualizerService>()
        ? Get.find<AudioVisualizerService>()
        : null;
    _waveformService = Get.isRegistered<AudioWaveformService>()
        ? Get.find<AudioWaveformService>()
        : null;
    _animationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _playingWorker = ever(widget.controller.audioService.isPlaying, (_) {
      _syncAnimation();
    });
    _syncAnimation();
    _loadRealWaveform();
    _bindRealtimeVisualizer();
  }

  @override
  void didUpdateWidget(covariant _WaveCover oldWidget) {
    super.didUpdateWidget(oldWidget);

    final modeChanged = oldWidget.displayMode != widget.displayMode;
    final itemChanged =
        oldWidget.item.id != widget.item.id ||
        oldWidget.item.publicId != widget.item.publicId;

    if (itemChanged) {
      _fallbackHeights = _buildBaseHeights(widget.item);
      _baseHeights = _fallbackHeights;
      _loadRealWaveform();
    }

    if (modeChanged) {
      _attachToSession(
        widget.controller.audioService.androidAudioSessionId,
        force: true,
      );
    }
  }

  void _syncAnimation() {
    final playing = widget.controller.audioService.isPlaying.value;
    if (playing) {
      if (!_animationCtrl.isAnimating) _animationCtrl.repeat();
    } else {
      _animationCtrl.stop();
    }
  }

  @override
  void dispose() {
    _playingWorker?.dispose();
    _sessionIdSub?.cancel();
    _liveBarsSub?.cancel();
    _visualizerService?.detach();
    _animationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final isMiniSpectrum = widget.displayMode == _WaveDisplayMode.miniSpectrum;

    return Obx(() {
      final positionMs = widget.controller.position.value.inMilliseconds;
      final totalDurationMs = widget.controller.duration.value.inMilliseconds;
      final playhead = totalDurationMs > 0
          ? (positionMs / totalDurationMs).clamp(0.0, 1.0)
          : 0.0;
      final isPlaying = widget.controller.audioService.isPlaying.value;

      return Container(
        key: ValueKey('${widget.displayMode.name}-${widget.item.id}'),
        width: 280,
        height: 260,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.onSurface.withValues(
              alpha: isMiniSpectrum ? 0.05 : 0.12,
            ),
            width: isMiniSpectrum ? 0.6 : 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(
                alpha: isMiniSpectrum ? 0.03 : 0.08,
              ),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _animationCtrl,
          builder: (context, _) {
            final phase =
                (positionMs / 550.0) + (_animationCtrl.value * math.pi * 2);

            return CustomPaint(
              painter: _WaveformPainter(
                baseHeights: _baseHeights,
                liveBars: _liveBars,
                phase: phase,
                playhead: playhead,
                isPlaying: isPlaying,
                baseColor: colors.primary,
                idleColor: colors.onSurfaceVariant,
                miniSpectrum: isMiniSpectrum,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      );
    });
  }

  void _bindRealtimeVisualizer() {
    final service = _visualizerService;
    if (service == null) return;

    _liveBarsSub = service.barsStream.listen((bars) {
      if (!mounted || bars.isEmpty) return;
      setState(() {
        _liveBars = bars;
      });
    });

    _sessionIdSub = widget.controller.audioService.androidAudioSessionIdStream
        .listen((sessionId) {
          _attachToSession(sessionId);
        });

    _attachToSession(widget.controller.audioService.androidAudioSessionId);
  }

  Future<void> _attachToSession(int? sessionId, {bool force = false}) async {
    final service = _visualizerService;
    if (service == null) return;
    final id = sessionId ?? 0;
    if (id <= 0) return;
    final barCount = widget.displayMode == _WaveDisplayMode.miniSpectrum
        ? 112
        : 56;
    final captureMode = widget.displayMode == _WaveDisplayMode.miniSpectrum
        ? 'fft'
        : 'waveform';
    if (!force &&
        _attachedSessionId == id &&
        _attachedBarCount == barCount &&
        _attachedCaptureMode == captureMode) {
      return;
    }

    try {
      await service.attachToSession(
        id,
        barCount: barCount,
        captureMode: captureMode,
      );
      _attachedSessionId = id;
      _attachedBarCount = barCount;
      _attachedCaptureMode = captureMode;
    } catch (_) {}
  }

  Future<void> _loadRealWaveform() async {
    final service = _waveformService;
    if (service == null) return;

    final localPath = widget.item.localAudioVariant?.localPath?.trim() ?? '';
    if (localPath.isEmpty) return;

    try {
      final data = await service.extractWaveform(
        localPath: localPath,
        buckets: 56,
      );
      if (!mounted || data == null || data.buckets.isEmpty) return;

      setState(() {
        _baseHeights = data.buckets;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _baseHeights = _fallbackHeights;
      });
    }
  }

  List<double> _buildBaseHeights(MediaItem item) {
    final seedSource = '${item.id}|${item.publicId}|${item.title}';
    var seed = seedSource.codeUnits.fold<int>(7, (acc, c) => (acc * 31 + c));
    seed &= 0x7fffffff;
    if (seed == 0) seed = 1;

    const count = 56;
    final raw = <double>[];

    double nextRandom() {
      seed = (1103515245 * seed + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    for (int i = 0; i < count; i++) {
      final center = (count - 1) / 2;
      final dist = ((i - center).abs() / center);
      final profile = (1.0 - dist * 0.55).clamp(0.35, 1.0).toDouble();
      final random = 0.22 + (nextRandom() * 0.78);
      raw.add((random * profile).clamp(0.14, 1.0).toDouble());
    }

    final smooth = List<double>.filled(count, 0);
    for (int i = 0; i < count; i++) {
      final prev = i > 0 ? raw[i - 1] : raw[i];
      final curr = raw[i];
      final next = i < count - 1 ? raw[i + 1] : raw[i];
      smooth[i] = ((prev + curr * 2 + next) / 4).clamp(0.14, 1.0).toDouble();
    }

    return smooth;
  }
}

enum _WaveDisplayMode { wave, miniSpectrum }

class _WaveformPainter extends CustomPainter {
  final List<double> baseHeights;
  final List<double> liveBars;
  final double phase;
  final double playhead;
  final bool isPlaying;
  final Color baseColor;
  final Color idleColor;
  final bool miniSpectrum;

  const _WaveformPainter({
    required this.baseHeights,
    required this.liveBars,
    required this.phase,
    required this.playhead,
    required this.isPlaying,
    required this.baseColor,
    required this.idleColor,
    required this.miniSpectrum,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (baseHeights.isEmpty) return;

    final hasLive = liveBars.isNotEmpty;
    final baseHsl = HSLColor.fromColor(baseColor);
    final startColor = baseHsl
        .withSaturation((baseHsl.saturation * 0.85).clamp(0.35, 1.0).toDouble())
        .withLightness((baseHsl.lightness * 0.75).clamp(0.20, 0.62).toDouble())
        .toColor();
    final endColor = baseHsl
        .withSaturation((baseHsl.saturation * 1.05).clamp(0.45, 1.0).toDouble())
        .withLightness((baseHsl.lightness * 1.20).clamp(0.35, 0.78).toDouble())
        .toColor();

    if (miniSpectrum) {
      _paintCircularSpectrum(
        canvas: canvas,
        size: size,
        hasLive: hasLive,
        startColor: startColor,
        endColor: endColor,
      );
      return;
    }

    final baseY = size.height - 4;
    final count = baseHeights.length;
    final spacing = count >= 64 ? 1.2 : 1.9;
    final barWidth = ((size.width - spacing * (count - 1)) / count)
        .clamp(1.2, 8.0)
        .toDouble();
    final maxHeight = (size.height * 0.78).clamp(18.0, 170.0).toDouble();

    var x = 0.0;
    for (int i = 0; i < count; i++) {
      final barProgress = count > 1 ? i / (count - 1) : 0.0;
      final distanceToPlayhead = (barProgress - playhead).abs();
      final nearPlayheadBoost = (1.0 - distanceToPlayhead * 8.0)
          .clamp(0.0, 1.0)
          .toDouble();
      final liveValue = hasLive ? _sampleLiveBar(i, count) : baseHeights[i];
      final liveLift = hasLive
          ? math.pow(liveValue.clamp(0.0, 1.0), 0.55).toDouble()
          : liveValue;
      final pulse = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(phase + i * 0.43));
      final dynamicGain = hasLive
          ? (isPlaying ? (0.34 + liveLift * 0.86) : (0.22 + liveLift * 0.46))
          : (isPlaying ? (pulse * (1.0 + nearPlayheadBoost * 0.22)) : 0.34);
      final shape = hasLive
          ? ((baseHeights[i] * 0.18) + (liveLift * 0.82))
                .clamp(0.10, 1.0)
                .toDouble()
          : baseHeights[i];
      final barHeight = (maxHeight * shape * dynamicGain).clamp(6.0, maxHeight);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseY - barHeight, barWidth, barHeight),
        Radius.circular(barWidth * 0.7),
      );

      final palette = Color.lerp(startColor, endColor, barProgress)!;
      final t = ((dynamicGain + liveLift) / 2.0).clamp(0.0, 1.0);
      final progressed = barProgress <= playhead;
      final barColor = Color.lerp(
        palette.withValues(alpha: progressed ? 0.46 : 0.22),
        palette.withValues(alpha: progressed ? 0.96 : 0.66),
        t,
      )!;

      canvas.drawRRect(rect, Paint()..color = barColor);
      x += barWidth + spacing;
    }
  }

  void _paintCircularSpectrum({
    required Canvas canvas,
    required Size size,
    required bool hasLive,
    required Color startColor,
    required Color endColor,
  }) {
    final center = size.center(Offset.zero);
    final minHalf = math.min(size.width, size.height) / 2;
    final maxReach = (minHalf - 6).clamp(18.0, 120.0).toDouble();
    final hasLiveBars = hasLive && liveBars.isNotEmpty;
    final sourceCount = hasLiveBars ? liveBars.length : baseHeights.length;
    final count = sourceCount.clamp(96, 192);
    final lowEnd = (sourceCount * 0.22).round().clamp(1, sourceCount);
    final midEnd = (sourceCount * 0.62).round().clamp(lowEnd + 1, sourceCount);
    final bassEnergy = _averageRange(
      hasLiveBars ? liveBars : baseHeights,
      0,
      lowEnd,
    );
    final midEnergy = _averageRange(
      hasLiveBars ? liveBars : baseHeights,
      lowEnd,
      midEnd,
    );
    final highEnergy = _averageRange(
      hasLiveBars ? liveBars : baseHeights,
      midEnd,
      sourceCount,
    );
    final globalEnergy = ((bassEnergy + midEnergy + highEnergy) / 3.0)
        .clamp(0.0, 1.0)
        .toDouble();

    final radius = ((maxReach * 0.56) + bassEnergy * 4.5)
        .clamp(16.0, maxReach - 8)
        .toDouble();
    final maxWave = (maxReach - radius).clamp(6.0, 36.0).toDouble();
    final angleOffset = phase * 0.06;
    final waveColorBase = Color.lerp(startColor, endColor, 0.58)!;
    final waveHsl = HSLColor.fromColor(waveColorBase);
    final neonColor = waveHsl
        .withSaturation((waveHsl.saturation * 1.18).clamp(0.45, 1.0).toDouble())
        .withLightness((waveHsl.lightness * 1.30).clamp(0.42, 0.80).toDouble())
        .toColor();

    canvas.drawCircle(
      center,
      radius + 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = neonColor.withValues(alpha: 0.34),
    );

    final rawWaves = List<double>.filled(count, 0.0);
    for (int i = 0; i < count; i++) {
      final barProgress = i / count;
      final distanceToPlayhead = (barProgress - playhead).abs();
      final nearPlayheadBoost = (1.0 - distanceToPlayhead * 8.0)
          .clamp(0.0, 1.0)
          .toDouble();
      final angle = (-math.pi / 2) + (barProgress * math.pi * 2) + angleOffset;
      final baseValue = _sampleBar(baseHeights, i, count);
      final liveValue = hasLiveBars
          ? _sampleBar(liveBars, i, count)
          : baseValue;
      final level = ((baseValue * 0.24) + (liveValue * 0.76))
          .clamp(0.0, 1.0)
          .toDouble();
      final lift = math.pow(level, 0.58).toDouble();
      final pulse =
          0.44 + 0.56 * (0.5 + 0.5 * math.sin(phase * 1.10 + i * 0.31));
      final dynamicGain = hasLiveBars
          ? (isPlaying ? (0.30 + lift * 0.88) : (0.20 + lift * 0.32))
          : (isPlaying ? (pulse * (1.0 + nearPlayheadBoost * 0.16)) : 0.24);
      final distortion =
          (0.62 * math.sin(angle * 2.4 + phase * 0.82)) +
          (0.38 * math.sin(angle * 5.6 - phase * 0.35));
      final distortionGain = 0.06 + highEnergy * 0.14 + midEnergy * 0.08;
      final wave =
          (maxWave * (0.16 + lift * 0.84) * dynamicGain) +
          (maxWave * distortion * distortionGain);
      rawWaves[i] = wave.clamp(0.6, maxWave).toDouble();
    }

    final waves = List<double>.filled(count, 0.0);
    for (int i = 0; i < count; i++) {
      final prev = rawWaves[(i - 1 + count) % count];
      final curr = rawWaves[i];
      final next = rawWaves[(i + 1) % count];
      waves[i] = ((prev + curr * 2 + next) / 4).clamp(0.6, maxWave).toDouble();
    }

    final points = <Offset>[];
    for (int i = 0; i < count; i++) {
      final barProgress = i / count;
      final angle = (-math.pi / 2) + (barProgress * math.pi * 2) + angleOffset;
      final unitX = math.cos(angle);
      final unitY = math.sin(angle);
      final radiusAtPoint = radius + waves[i];
      points.add(center + Offset(unitX * radiusAtPoint, unitY * radiusAtPoint));
    }

    // Integración inspirada en el repo AudioSpectrum: anillos orbitales + radios.
    for (int ring = 0; ring < 3; ring++) {
      final ringRadius = radius + (ring * 10.5);
      final ringTint = Color.lerp(startColor, endColor, ring / 2)!;
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = ringTint.withValues(
            alpha: ((0.07 + globalEnergy * 0.06) - ring * 0.015)
                .clamp(0.03, 0.14)
                .toDouble(),
          ),
      );
    }

    final spokeStep = count > 140 ? 3 : 2;
    for (int i = 0; i < count; i += spokeStep) {
      final barProgress = i / count;
      final angle = (-math.pi / 2) + (barProgress * math.pi * 2) + angleOffset;
      final unitX = math.cos(angle);
      final unitY = math.sin(angle);
      final wave = waves[i];
      final inner =
          center + Offset(unitX * (radius - 0.6), unitY * (radius - 0.6));
      final outer =
          center +
          Offset(
            unitX * (radius + wave * 0.92),
            unitY * (radius + wave * 0.92),
          );
      final spokeColor = Color.lerp(startColor, endColor, barProgress)!;
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (1.0 + globalEnergy * 0.45).clamp(1.0, 1.5).toDouble()
          ..color = spokeColor.withValues(alpha: 0.16 + highEnergy * 0.18),
      );
    }

    // Malla interna de puntos para look tipo espectro NCS.
    const meshLayers = 10;
    for (int layer = 1; layer <= meshLayers; layer++) {
      final depth = layer / meshLayers;
      final layerRadius = radius * (0.10 + depth * 0.86);
      final layerPoints = <Offset>[];
      for (int i = 0; i < count; i += spokeStep) {
        final barProgress = i / count;
        final angle =
            (-math.pi / 2) + (barProgress * math.pi * 2) + angleOffset;
        final unitX = math.cos(angle);
        final unitY = math.sin(angle);
        final waveAtAngle = waves[i];
        final bulge = waveAtAngle * (0.06 + depth * 0.22);
        final yFlatten = 0.76 + depth * 0.22;
        layerPoints.add(
          center +
              Offset(
                unitX * (layerRadius + bulge),
                unitY * (layerRadius + bulge) * yFlatten,
              ),
        );
      }

      if (layerPoints.isNotEmpty) {
        final tint = Color.lerp(startColor, endColor, 0.20 + depth * 0.60)!;
        canvas.drawPoints(
          ui.PointMode.points,
          layerPoints,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = (0.6 + depth * 0.9).clamp(0.6, 1.6)
            ..color = tint.withValues(
              alpha: (0.06 + depth * 0.18 + globalEnergy * 0.05)
                  .clamp(0.06, 0.28)
                  .toDouble(),
            ),
        );
      }
    }

    final wavePath = _buildSmoothClosedPath(points);
    final sweep = SweepGradient(
      colors: [
        neonColor.withValues(alpha: 0.58),
        endColor.withValues(alpha: 0.98),
        startColor.withValues(alpha: 0.90),
        neonColor.withValues(alpha: 0.58),
      ],
      stops: const [0.0, 0.34, 0.72, 1.0],
      transform: GradientRotation(angleOffset),
    );

    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (10.0 + bassEnergy * 3.8).clamp(10.0, 14.0).toDouble()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = neonColor.withValues(alpha: 0.16 + globalEnergy * 0.08)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          (8.0 + bassEnergy * 3.0).clamp(8.0, 12.0).toDouble(),
        ),
    );
    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (6.2 + globalEnergy * 1.4).clamp(6.2, 7.8).toDouble()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = neonColor.withValues(alpha: 0.32 + globalEnergy * 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
    );
    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = sweep.createShader(Offset.zero & size),
    );
    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.34),
    );
  }

  Path _buildSmoothClosedPath(List<Offset> points) {
    final path = Path();
    if (points.length < 3) {
      if (points.isNotEmpty) path.addPolygon(points, true);
      return path;
    }

    path.moveTo(points[0].dx, points[0].dy);
    final total = points.length;
    for (int i = 0; i < total; i++) {
      final current = points[i];
      final next = points[(i + 1) % total];
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  double _sampleBar(List<double> source, int index, int targetCount) {
    if (source.isEmpty || targetCount <= 1) return 0.0;
    if (source.length == 1) return source.first;
    if (targetCount == source.length) {
      final safe = index.clamp(0, source.length - 1);
      return source[safe];
    }

    final sourceMax = source.length - 1;
    final targetMax = targetCount - 1;
    final sourcePos = (index / targetMax) * sourceMax;
    final low = sourcePos.floor().clamp(0, sourceMax);
    final high = sourcePos.ceil().clamp(0, sourceMax);
    if (low == high) return source[low];
    final t = (sourcePos - low).clamp(0.0, 1.0);
    return (source[low] * (1.0 - t)) + (source[high] * t);
  }

  double _averageRange(List<double> source, int start, int end) {
    if (source.isEmpty) return 0.0;
    final safeStart = start.clamp(0, source.length - 1);
    final safeEnd = end.clamp(safeStart + 1, source.length);
    var sum = 0.0;
    for (int i = safeStart; i < safeEnd; i++) {
      sum += source[i].clamp(0.0, 1.0);
    }
    final span = (safeEnd - safeStart).clamp(1, source.length);
    return (sum / span).clamp(0.0, 1.0).toDouble();
  }

  double _sampleLiveBar(int index, int targetCount) {
    return _sampleBar(liveBars, index, targetCount);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.playhead != playhead ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.miniSpectrum != miniSpectrum ||
        oldDelegate.idleColor != idleColor ||
        oldDelegate.liveBars != liveBars ||
        oldDelegate.baseHeights != baseHeights;
  }
}

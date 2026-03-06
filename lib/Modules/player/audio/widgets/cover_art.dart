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
  List<double> _smoothBars = const [];
  List<double> _peakBars = const [];
  double _prevRms = 0.0;
  int _lastLiveBarsAtMs = 0;
  _VisualizerSignals _signals = const _VisualizerSignals();
  late _SeewavMorpher _seewavMorpher;
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
    _seewavMorpher = _buildSeewavMorpher(widget.displayMode);
    _animationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
      _seewavMorpher.reset();
      _loadRealWaveform();
    }

    if (modeChanged) {
      _seewavMorpher = _buildSeewavMorpher(widget.displayMode);
      _attachToSession(
        widget.controller.audioService.androidAudioSessionId,
        force: true,
      );
    }
  }

  _SeewavMorpher _buildSeewavMorpher(_WaveDisplayMode mode) {
    return _SeewavMorpher(
      barCount: mode == _WaveDisplayMode.miniSpectrum ? 72 : 25,
      baseSpeed: mode == _WaveDisplayMode.miniSpectrum ? 5.4 : 4.8,
    );
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
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final animatedBars = _seewavMorpher.sample(nowMs);
            final liveIsFresh =
                _lastLiveBarsAtMs > 0 && (nowMs - _lastLiveBarsAtMs) <= 260;
            final effectiveLiveBars = liveIsFresh
                ? (animatedBars.isNotEmpty
                      ? animatedBars
                      : (_smoothBars.isNotEmpty ? _smoothBars : _liveBars))
                : const <double>[];

            return RepaintBoundary(
              child: CustomPaint(
                painter: _WaveformPainter(
                  baseHeights: _baseHeights,
                  liveBars: effectiveLiveBars,
                  peakBars: _peakBars,
                  signals: _signals,
                  phase: phase,
                  playhead: playhead,
                  isPlaying: isPlaying,
                  baseColor: colors.primary,
                  idleColor: colors.onSurfaceVariant,
                  miniSpectrum: isMiniSpectrum,
                ),
                child: const SizedBox.expand(),
              ),
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
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _lastLiveBarsAtMs = nowMs;
        _liveBars = bars;
        _smoothBars = _seewavMorpher.ingest(bars, nowMs);
        _peakBars = _updatePeakHold(_peakBars, _smoothBars);
        _signals = _computeSignals(_smoothBars, _prevRms);
        _prevRms = _signals.rmsEnergy;
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
        ? 72
        : 25;
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
    } catch (e) {
      debugPrint('audio visualizer attach failed: $e');
      if (!mounted) return;
      setState(() {
        _lastLiveBarsAtMs = 0;
        _liveBars = const [];
        _smoothBars = const [];
        _peakBars = const [];
        _signals = const _VisualizerSignals();
        _seewavMorpher.reset();
      });
    }
  }

  Future<void> _loadRealWaveform() async {
    final service = _waveformService;
    if (service == null) return;

    final localPath = widget.item.localAudioVariant?.localPath?.trim() ?? '';
    if (localPath.isEmpty) return;

    try {
      final data = await service.extractWaveform(
        localPath: localPath,
        buckets: 25,
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

    const count = 25;
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

  /// Peak-hold with gentle decay for clearer transients.
  List<double> _updatePeakHold(List<double> previous, List<double> current) {
    if (current.isEmpty) return current;
    if (previous.isEmpty || previous.length != current.length) {
      return List<double>.from(current);
    }
    final result = List<double>.filled(current.length, 0.0);
    for (int i = 0; i < current.length; i++) {
      final cur = current[i];
      final prev = previous[i];
      if (cur >= prev) {
        result[i] = cur;
      } else {
        result[i] = (prev - 0.012).clamp(cur, 1.0);
      }
    }
    return result;
  }

  _VisualizerSignals _computeSignals(List<double> bars, double prevRms) {
    if (bars.isEmpty) return const _VisualizerSignals();
    final n = bars.length;

    var sumSq = 0.0;
    for (final v in bars) {
      sumSq += v * v;
    }
    final rms = math.sqrt(sumSq / n).clamp(0.0, 1.0).toDouble();

    var weightedSum = 0.0;
    var totalWeight = 0.0;
    for (int i = 0; i < n; i++) {
      weightedSum += i * bars[i];
      totalWeight += bars[i];
    }
    final centroid = totalWeight > 0.001
        ? (weightedSum / (totalWeight * (n - 1))).clamp(0.0, 1.0).toDouble()
        : 0.5;

    final totalEnergy = totalWeight;
    var accumEnergy = 0.0;
    var rolloffIndex = n - 1;
    for (int i = 0; i < n; i++) {
      accumEnergy += bars[i];
      if (accumEnergy >= totalEnergy * 0.85) {
        rolloffIndex = i;
        break;
      }
    }
    final rolloff = (rolloffIndex / (n - 1)).clamp(0.0, 1.0).toDouble();
    final onset = (rms - prevRms).clamp(0.0, 1.0).toDouble();

    return _VisualizerSignals(
      rmsEnergy: rms,
      spectralCentroid: centroid,
      spectralRolloff: rolloff,
      onsetStrength: onset,
    );
  }
}

/// Port of seewav-style morphing:
/// - compressor (sigmoid)
/// - Hann shaping
/// - volume-dependent transition speed
/// - logistic interpolation between frames
class _SeewavMorpher {
  final int barCount;
  final double baseSpeed;

  final List<double> _window;
  List<double> _from = const [];
  List<double> _to = const [];
  List<double> _current = const [];
  double _loc = 1.0;
  double _speed = 1.0;
  int _lastSampleAtMs = 0;

  _SeewavMorpher({required this.barCount, this.baseSpeed = 4.8})
    : _window = _buildHann(barCount);

  void reset() {
    _from = const [];
    _to = const [];
    _current = const [];
    _loc = 1.0;
    _speed = 1.0;
    _lastSampleAtMs = 0;
  }

  List<double> ingest(List<double> rawBars, int nowMs) {
    final prepared = _prepare(rawBars);
    if (prepared.isEmpty) return prepared;

    _advance(nowMs);
    if (_current.isEmpty || _current.length != prepared.length) {
      _from = List<double>.from(prepared);
      _to = List<double>.from(prepared);
      _current = List<double>.from(prepared);
      _loc = 1.0;
      _speed = baseSpeed;
      _lastSampleAtMs = nowMs;
      return _current;
    }

    _from = List<double>.from(_current);
    _to = prepared;
    _loc = 0.0;
    final speedup = _speedupFromVolume(prepared);
    final dropBoost = 1.0 + _averageDrop(_from, _to) * 3.0;
    _speed = (baseSpeed * speedup * dropBoost).clamp(
      baseSpeed * 0.9,
      baseSpeed * 5.5,
    );
    _lastSampleAtMs = nowMs;
    return List<double>.from(_current);
  }

  List<double> sample(int nowMs) {
    _advance(nowMs);
    return _current;
  }

  void _advance(int nowMs) {
    if (_from.isEmpty || _to.isEmpty) return;
    if (_from.length != _to.length) {
      _current = List<double>.from(_to);
      _from = List<double>.from(_to);
      _loc = 1.0;
      _lastSampleAtMs = nowMs;
      return;
    }

    if (_lastSampleAtMs <= 0) {
      _lastSampleAtMs = nowMs;
      return;
    }

    final dt = ((nowMs - _lastSampleAtMs).clamp(0, 80)) / 1000.0;
    _lastSampleAtMs = nowMs;
    if (dt <= 0) return;

    _loc = (_loc + dt * _speed).clamp(0.0, 1.0);
    final n = _to.length;
    final mixed = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final from = _from[i];
      final to = _to[i];
      final dropping = to < from;
      final drop = (from - to).clamp(0.0, 1.0).toDouble();
      // Asymmetric interpolation: drops move faster than rises.
      final localLoc = dropping ? (_loc * (1.0 + drop * 2.6)) : _loc;
      final w = _sigmoid(4.0 * (localLoc.clamp(0.0, 1.0) - 0.5));
      var v = (from * (1 - w) + to * w).clamp(0.0, 1.0).toDouble();
      if (dropping) {
        // Add a subtle "snap" to make downward peaks more noticeable.
        final snap = (1.0 - localLoc.clamp(0.0, 1.0)) * drop * 0.12;
        v = (v - snap).clamp(to, 1.0).toDouble();
      }
      mixed[i] = v;
    }
    _current = _spatialSmooth(mixed);

    if (_loc >= 0.999) {
      _from = List<double>.from(_to);
      _current = List<double>.from(_to);
    }
  }

  List<double> _prepare(List<double> rawBars) {
    if (rawBars.isEmpty || barCount <= 0) return const [];
    final resampled = _resample(rawBars, barCount);
    final compressed = List<double>.filled(barCount, 0.0);
    for (int i = 0; i < barCount; i++) {
      final v = resampled[i].clamp(0.0, 1.0).toDouble();
      final c = (1.9 * (_sigmoid(2.5 * v) - 0.5)).clamp(0.0, 1.0).toDouble();
      compressed[i] = (c * _window[i]).clamp(0.0, 1.0).toDouble();
    }
    return _spatialSmooth(compressed);
  }

  List<double> _spatialSmooth(List<double> source) {
    if (source.length < 3) return source;
    final out = List<double>.filled(source.length, 0.0);
    for (int i = 0; i < source.length; i++) {
      final prev = i > 0 ? source[i - 1] : source[i];
      final curr = source[i];
      final next = i < source.length - 1 ? source[i + 1] : source[i];
      out[i] = ((prev + curr * 2 + next) / 4).clamp(0.0, 1.0).toDouble();
    }
    return out;
  }

  double _speedupFromVolume(List<double> bars) {
    var maxVal = 0.0;
    for (final v in bars) {
      if (v > maxVal) maxVal = v;
    }
    final maxVol = _log10(1e-4 + maxVal) * 10.0;
    final speedup = _interpole(-6.0, 0.5, 0.0, 2.0, maxVol);
    return speedup.clamp(0.5, 2.0).toDouble();
  }

  double _averageDrop(List<double> from, List<double> to) {
    if (from.isEmpty || to.isEmpty || from.length != to.length) return 0.0;
    var sum = 0.0;
    for (int i = 0; i < from.length; i++) {
      final d = (from[i] - to[i]).clamp(0.0, 1.0).toDouble();
      sum += d;
    }
    return (sum / from.length).clamp(0.0, 1.0).toDouble();
  }

  static double _interpole(
    double x1,
    double y1,
    double x2,
    double y2,
    double x,
  ) {
    if ((x2 - x1).abs() < 1e-9) return y1;
    return y1 + (y2 - y1) * (x - x1) / (x2 - x1);
  }

  static double _log10(double x) {
    return math.log(x) / math.ln10;
  }

  static double _sigmoid(double x) {
    return 1.0 / (1.0 + math.exp(-x));
  }

  static List<double> _resample(List<double> source, int targetCount) {
    if (source.isEmpty || targetCount <= 0) return const [];
    if (source.length == targetCount) {
      return source
          .map((v) => v.clamp(0.0, 1.0).toDouble())
          .toList(growable: false);
    }
    if (source.length == 1) {
      return List<double>.filled(
        targetCount,
        source.first.clamp(0.0, 1.0).toDouble(),
      );
    }

    final out = List<double>.filled(targetCount, 0.0);
    final srcMax = source.length - 1;
    final dstMax = targetCount - 1;
    for (int i = 0; i < targetCount; i++) {
      final pos = (i / dstMax) * srcMax;
      final low = pos.floor().clamp(0, srcMax);
      final high = pos.ceil().clamp(0, srcMax);
      if (low == high) {
        out[i] = source[low].clamp(0.0, 1.0).toDouble();
      } else {
        final t = (pos - low).clamp(0.0, 1.0).toDouble();
        final v = (source[low] * (1.0 - t)) + (source[high] * t);
        out[i] = v.clamp(0.0, 1.0).toDouble();
      }
    }
    return out;
  }

  static List<double> _buildHann(int count) {
    if (count <= 0) return const [];
    if (count == 1) return const [1.0];
    final out = List<double>.filled(count, 0.0);
    for (int i = 0; i < count; i++) {
      final ratio = i / (count - 1);
      final hann = 0.5 * (1 - math.cos(2 * math.pi * ratio));
      out[i] = (0.25 + hann * 0.75).clamp(0.0, 1.0).toDouble();
    }
    return out;
  }
}

class _VisualizerSignals {
  final double rmsEnergy;
  final double spectralCentroid;
  final double spectralRolloff;
  final double onsetStrength;

  const _VisualizerSignals({
    this.rmsEnergy = 0.0,
    this.spectralCentroid = 0.5,
    this.spectralRolloff = 0.5,
    this.onsetStrength = 0.0,
  });
}

enum _WaveDisplayMode { wave, miniSpectrum }

class _WaveformPainter extends CustomPainter {
  final List<double> baseHeights;
  final List<double> liveBars;
  final List<double> peakBars;
  final _VisualizerSignals signals;
  final double phase;
  final double playhead;
  final bool isPlaying;
  final Color baseColor;
  final Color idleColor;
  final bool miniSpectrum;

  const _WaveformPainter({
    required this.baseHeights,
    required this.liveBars,
    required this.peakBars,
    required this.signals,
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

    final count = baseHeights.length;
    final spacing = count >= 64 ? 1.4 : 2.2;
    final barWidth = ((size.width - spacing * (count - 1)) / count)
        .clamp(1.4, 8.0)
        .toDouble();
    final maxHeight = (size.height * 0.62).clamp(18.0, 140.0).toDouble();
    final baseY = size.height * 0.68;
    final reflectionMaxHeight = maxHeight * 0.24;

    var x = 0.0;
    final loudness = math
        .pow(signals.rmsEnergy.clamp(0.0, 1.0), 0.72)
        .toDouble();
    for (int i = 0; i < count; i++) {
      final barProgress = count > 1 ? i / (count - 1) : 0.0;
      final liveValue = hasLive ? _sampleLiveBar(i, count) : baseHeights[i];
      final liveLift = hasLive
          ? math.pow(liveValue.clamp(0.0, 1.0), 0.55).toDouble()
          : liveValue;
      final pulse =
          0.40 +
          0.30 * (0.5 + 0.5 * math.sin(phase + i * 0.38)) +
          0.18 * (0.5 + 0.5 * math.sin(phase * 0.67 + i * 1.13)) +
          0.12 * (0.5 + 0.5 * math.sin(phase * 0.31 + i * 2.47));
      final onsetBoost = signals.onsetStrength;
      final toneShape = hasLive
          ? (0.35 + liveLift * 0.65).clamp(0.30, 1.0).toDouble()
          : baseHeights[i];
      final dynamicGain = hasLive
          ? (isPlaying
                ? (0.08 +
                          loudness * 1.30 +
                          onsetBoost * 0.20 +
                          pulse * 0.10 +
                          liveLift * 0.16)
                      .clamp(0.08, 1.65)
                      .toDouble()
                : (0.16 + loudness * 0.40 + pulse * 0.08))
          : (isPlaying ? (0.34 + pulse * 0.18) : 0.30);
      final shape = hasLive ? toneShape : baseHeights[i];
      final barHeight = (maxHeight * shape * dynamicGain).clamp(6.0, maxHeight);

      final palette = Color.lerp(startColor, endColor, barProgress)!;
      final paletteHsl = HSLColor.fromColor(palette);
      final rmsLift = signals.rmsEnergy;
      final barBottomColor = paletteHsl
          .withLightness(
            (paletteHsl.lightness * (0.45 + rmsLift * 0.15))
                .clamp(0.08, 0.35)
                .toDouble(),
          )
          .toColor()
          .withValues(alpha: 0.82);
      final centroidBoost = signals.spectralCentroid;
      final barTopColor = paletteHsl
          .withSaturation(
            (paletteHsl.saturation * (1.1 + centroidBoost * 0.3))
                .clamp(0.5, 1.0)
                .toDouble(),
          )
          .withLightness(
            (paletteHsl.lightness * (1.2 + centroidBoost * 0.2))
                .clamp(0.45, 0.90)
                .toDouble(),
          )
          .toColor()
          .withValues(alpha: 0.98);

      final barRect = Rect.fromLTWH(x, baseY - barHeight, barWidth, barHeight);
      final barRRect = RRect.fromRectAndRadius(
        barRect,
        Radius.circular(barWidth * 0.7),
      );

      // — Bar with vertical gradient —
      final barGradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [barBottomColor, barTopColor],
      );
      canvas.drawRRect(
        barRRect,
        Paint()..shader = barGradient.createShader(barRect),
      );

      // — Semi-mirror reflection (subtle, fades out quickly) —
      final reflectionHeight = (barHeight * 0.24).clamp(
        2.0,
        reflectionMaxHeight,
      );
      final reflectionRect = Rect.fromLTWH(
        x,
        baseY + 2.0,
        barWidth,
        reflectionHeight,
      );
      final reflectionRRect = RRect.fromRectAndRadius(
        reflectionRect,
        Radius.circular(barWidth * 0.7),
      );
      final reflectionGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          barTopColor.withValues(alpha: 0.18),
          barBottomColor.withValues(alpha: 0.0),
        ],
      );
      canvas.drawRRect(
        reflectionRRect,
        Paint()..shader = reflectionGradient.createShader(reflectionRect),
      );

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
    final maxReach = (minHalf - 4).clamp(18.0, 125.0).toDouble();
    final hasLiveBars = hasLive && liveBars.isNotEmpty;
    final sourceCount = hasLiveBars ? liveBars.length : baseHeights.length;
    final count = sourceCount.clamp(64, 128);
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

    final radius = ((maxReach * 0.52) + bassEnergy * 5.0)
        .clamp(16.0, maxReach - 10)
        .toDouble();
    final maxWave = (maxReach - radius).clamp(8.0, 42.0).toDouble();
    final angleOffset = phase * 0.06;
    final waveColorBase = Color.lerp(startColor, endColor, 0.58)!;
    final waveHsl = HSLColor.fromColor(waveColorBase);
    final neonColor = waveHsl
        .withSaturation((waveHsl.saturation * 1.25).clamp(0.50, 1.0).toDouble())
        .withLightness((waveHsl.lightness * 1.40).clamp(0.48, 0.85).toDouble())
        .toColor();

    // ═══════ 0) WIDE OUTER GLOW ENVELOPE ═══════
    final rolloffExpand = signals.spectralRolloff;
    final onsetBurst = signals.onsetStrength;
    final centroidBright = signals.spectralCentroid;
    canvas.drawCircle(
      center,
      radius + maxWave * (0.5 + rolloffExpand * 0.3),
      Paint()
        ..color = neonColor.withValues(
          alpha: (0.05 + globalEnergy * 0.06 + rolloffExpand * 0.04)
              .clamp(0.04, 0.16)
              .toDouble(),
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          (16.0 + bassEnergy * 6.0 + rolloffExpand * 6.0)
              .clamp(16.0, 30.0)
              .toDouble(),
        ),
    );
    canvas.drawCircle(
      center,
      radius + 2.0,
      Paint()
        ..color = neonColor.withValues(
          alpha: (0.10 + globalEnergy * 0.10).clamp(0.08, 0.22).toDouble(),
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          (10.0 + bassEnergy * 4.0).clamp(10.0, 16.0).toDouble(),
        ),
    );

    // ═══════ 1) RADIAL GRADIENT BACKGROUND INSIDE RING ═══════
    final bgGradient = RadialGradient(
      center: Alignment.center,
      radius: 0.5,
      colors: [
        Colors.black.withValues(alpha: 0.0),
        neonColor.withValues(alpha: 0.04 + globalEnergy * 0.03),
        Colors.black.withValues(alpha: 0.08),
      ],
      stops: const [0.0, 0.65, 1.0],
    );
    canvas.drawCircle(
      center,
      radius - 1.0,
      Paint()
        ..shader = bgGradient.createShader(
          Rect.fromCircle(center: center, radius: radius - 1.0),
        ),
    );

    // ═══════ 2) COMPUTE WAVE HEIGHTS ═══════
    final rawWaves = List<double>.filled(count, 0.0);
    final loudness = math
        .pow(signals.rmsEnergy.clamp(0.0, 1.0), 0.72)
        .toDouble();
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
      final toneLevel = ((baseValue * 0.16) + (liveValue * 0.84))
          .clamp(0.0, 1.0)
          .toDouble();
      final level = (toneLevel * (0.35 + loudness * 0.95))
          .clamp(0.0, 1.0)
          .toDouble();
      final lift = math.pow(level, 0.52).toDouble();
      final pulse =
          0.40 +
          0.30 * (0.5 + 0.5 * math.sin(phase * 1.10 + i * 0.31)) +
          0.18 * (0.5 + 0.5 * math.sin(phase * 0.58 + i * 0.87)) +
          0.12 * (0.5 + 0.5 * math.sin(phase * 0.29 + i * 2.13));
      final dynamicGain = hasLiveBars
          ? (isPlaying
                ? (0.08 +
                          loudness * 1.18 +
                          onsetBurst * 0.20 +
                          pulse * 0.10 +
                          lift * 0.16)
                      .clamp(0.08, 1.55)
                      .toDouble()
                : (0.14 + loudness * 0.36 + pulse * 0.08))
          : (isPlaying ? (pulse * (1.0 + nearPlayheadBoost * 0.18)) : 0.24);
      final distortion =
          (0.62 * math.sin(angle * 2.4 + phase * 0.82)) +
          (0.38 * math.sin(angle * 5.6 - phase * 0.35));
      final distortionGain = 0.08 + highEnergy * 0.16 + midEnergy * 0.10;
      final wave =
          (maxWave * (0.18 + lift * 0.82) * dynamicGain) +
          (maxWave * distortion * distortionGain);
      rawWaves[i] = wave.clamp(0.8, maxWave).toDouble();
    }

    final waves = List<double>.filled(count, 0.0);
    for (int i = 0; i < count; i++) {
      final prev = rawWaves[(i - 1 + count) % count];
      final curr = rawWaves[i];
      final next = rawWaves[(i + 1) % count];
      waves[i] = ((prev + curr * 2 + next) / 4).clamp(0.8, maxWave).toDouble();
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

    // ═══════ 3) ORBITAL RINGS (reactive + pulsating) ═══════
    for (int ring = 0; ring < 4; ring++) {
      final ringPulse = 0.5 + 0.5 * math.sin(phase * 0.8 + ring * 1.2);
      final ringRadius = radius + (ring * 8.5) + (onsetBurst * 4.0 * ringPulse);
      final ringTint = Color.lerp(startColor, endColor, ring / 3)!;
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1.2 + onsetBurst * 1.0).clamp(1.0, 2.4).toDouble()
          ..color = ringTint.withValues(
            alpha:
                ((0.08 + onsetBurst * 0.14 + ringPulse * 0.04) - ring * 0.016)
                    .clamp(0.04, 0.28)
                    .toDouble(),
          ),
      );
    }

    // ═══════ 4) PARTICLE MESH (denser, bigger, brighter) ═══════
    const meshLayers = 10;
    final onsetGate = ((onsetBurst - 0.008) / 0.18).clamp(0.0, 1.0).toDouble();
    final particleVisibility = (0.16 + onsetGate * 0.74 + globalEnergy * 0.16)
        .clamp(0.14, 1.0)
        .toDouble();
    final particleStepBase = count > 110 ? 3 : 2;
    final particleStep = onsetBurst > 0.08
        ? particleStepBase
        : particleStepBase + 1;
    for (int layer = 1; layer <= meshLayers; layer++) {
      final depth = layer / meshLayers;
      final layerRadius = radius * (0.08 + depth * 0.88);
      final layerPulse = 0.5 + 0.5 * math.sin(phase * 0.6 + layer * 0.5);
      final layerPoints = <Offset>[];
      for (int i = 0; i < count; i += particleStep) {
        final barProgress = i / count;
        final angle =
            (-math.pi / 2) + (barProgress * math.pi * 2) + angleOffset;
        final unitX = math.cos(angle);
        final unitY = math.sin(angle);
        final waveAtAngle = waves[i];
        final bulge =
            waveAtAngle * (0.07 + depth * (0.18 + rolloffExpand * 0.14));
        final yFlatten = 0.78 + depth * 0.20;
        layerPoints.add(
          center +
              Offset(
                unitX * (layerRadius + bulge),
                unitY * (layerRadius + bulge) * yFlatten,
              ),
        );
      }

      if (layerPoints.isNotEmpty) {
        final tint = Color.lerp(startColor, endColor, 0.15 + depth * 0.65)!;
        final particleSize =
            (1.4 + depth * 1.2 + layerPulse * 0.3 - centroidBright * 0.4)
                .clamp(0.8, 2.8)
                .toDouble();
        canvas.drawPoints(
          ui.PointMode.points,
          layerPoints,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = particleSize
            ..color = tint.withValues(
              alpha:
                  (0.04 + depth * 0.16 + onsetGate * 0.22 + layerPulse * 0.03)
                      .clamp(0.03, 0.40)
                      .toDouble() *
                  particleVisibility,
            ),
        );
      }
    }

    // ═══════ 5) WAVE PATH (thicker, brighter, multi-glow) ═══════
    final wavePath = _buildSmoothClosedPath(points);
    final sweep = SweepGradient(
      colors: [
        neonColor.withValues(alpha: 0.65),
        endColor.withValues(alpha: 1.0),
        startColor.withValues(alpha: 0.95),
        neonColor.withValues(alpha: 0.65),
      ],
      stops: const [0.0, 0.34, 0.72, 1.0],
      transform: GradientRotation(angleOffset),
    );

    // Layer 1: widest outer glow
    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (14.0 + bassEnergy * 5.0).clamp(14.0, 20.0).toDouble()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = neonColor.withValues(
          alpha: (0.12 + globalEnergy * 0.08).clamp(0.10, 0.22).toDouble(),
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          (12.0 + bassEnergy * 4.0).clamp(12.0, 18.0).toDouble(),
        ),
    );
    // Layer 2: medium glow
    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (8.0 + globalEnergy * 2.0).clamp(8.0, 10.5).toDouble()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = neonColor.withValues(
          alpha: (0.28 + globalEnergy * 0.14).clamp(0.26, 0.44).toDouble(),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.5),
    );
    // Layer 3: core gradient stroke
    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (4.2 + globalEnergy * 0.8).clamp(4.2, 5.2).toDouble()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = sweep.createShader(Offset.zero & size),
    );
    // Layer 4: white hot center
    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.8 + globalEnergy * 0.4).clamp(1.8, 2.4).toDouble()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(
          alpha: (0.38 + globalEnergy * 0.12).clamp(0.34, 0.52).toDouble(),
        ),
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
        oldDelegate.peakBars != peakBars ||
        oldDelegate.signals != signals ||
        oldDelegate.baseHeights != baseHeights;
  }
}

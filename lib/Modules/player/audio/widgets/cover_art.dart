import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/services/audio_service.dart';
import '../controller/audio_player_controller.dart';
import 'turntable_needle.dart';

class CoverArt extends StatelessWidget {
  final AudioPlayerController controller;
  final MediaItem item;
  final double size;

  const CoverArt({
    super.key,
    required this.controller,
    required this.item,
    this.size = 280,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Obx(() {
      final style = controller.coverStyle.value;

      return SizedBox.square(
        dimension: size,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox.square(
            dimension: 280,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: switch (style) {
                  CoverStyle.square => _SquareCover(colors: colors, item: item),
                  CoverStyle.vinyl => _VinylCover(colors: colors, item: item),
                  CoverStyle.landscape => _SquareCover(
                    colors: colors,
                    item: item,
                  ),
                },
              ),
            ),
          ),
        ),
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
            offset: const Offset(-20, 1), // 20px a la izquierda
            child: Image.asset(
              'assets/ui/vinyl.png', // <-- tu png del disco
              width: diskSize,
              height: diskSize,
              fit: BoxFit.contain,
            ),
          ),

          // 2) LABEL / COVER (SÍ rota)
          Transform.translate(
            offset: const Offset(-20, 0), // 20px a la izquierda
            child: ClipOval(
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
          ),

          // 3) AGUJA (siempre Positioned para no romper centrado)
          const Positioned(top: -16, right: 43, child: TurntableNeedle()),

          // 4) Fader de volumen funcional (arrastrable)
          Positioned(
            top: 100,
            right: -30,
            child: _TurntableVolumeSlider(
              audioService: controller.audioService,
            ),
          ),
        ],
      ),
    );
  }
}

class _TurntableVolumeSlider extends StatelessWidget {
  const _TurntableVolumeSlider({required this.audioService});

  final AudioService audioService;

  static const double _trackWidth = 30;
  static const double _trackHeight = 150;
  static const double _touchWidth = 48;
  static const double _knobSize = 20;
  static const double _paddingTop = 8;
  static const double _paddingBottom = 8;

  double get _travel => _trackHeight - _knobSize - _paddingTop - _paddingBottom;

  double _volumeToTop(double volume) {
    final clamped = volume.clamp(0.0, 1.0).toDouble();
    return _paddingTop + (1 - clamped) * _travel;
  }

  double _localDyToVolume(double localDy) {
    final centeredDy = localDy - (_knobSize / 2);
    final normalized = ((centeredDy - _paddingTop) / _travel).clamp(0.0, 1.0);
    return (1 - normalized).toDouble();
  }

  void _setVolume(double next) {
    unawaited(audioService.setVolume(next.clamp(0.0, 1.0).toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: _touchWidth,
      height: _trackHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) =>
            _setVolume(_localDyToVolume(details.localPosition.dy)),
        onVerticalDragUpdate: (details) =>
            _setVolume(_localDyToVolume(details.localPosition.dy)),
        child: Obx(() {
          final volume = audioService.volume.value.clamp(0.0, 1.0).toDouble();
          final top = _volumeToTop(volume);
          final left = (_touchWidth - _trackWidth) / 2;
          final knobLeft = (_touchWidth - _knobSize) / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left,
                top: 0,
                child: SvgPicture.asset(
                  'assets/ui/volumen.svg',
                  width: _trackWidth,
                  height: _trackHeight,
                  fit: BoxFit.fill,
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                left: knobLeft,
                top: top,
                child: Container(
                  width: _knobSize,
                  height: _knobSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.24),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                      ),
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
}

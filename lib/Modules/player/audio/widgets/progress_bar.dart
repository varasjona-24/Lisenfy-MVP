import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/audio_player_controller.dart';

class ProgressBar extends StatefulWidget {
  const ProgressBar({super.key});

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  bool _isDragging = false;
  double _dragValueSeconds = 0.0;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AudioPlayerController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final active = scheme.primary;
    final inactive = scheme.onSurface.withValues(alpha: isDark ? 0.22 : 0.16);

    return Obx(() {
      final pos = controller.position.value;
      final dur = controller.duration.value;
      final canSeek = !controller.audioService.isLoading.value;

      final maxSeconds = dur.inSeconds <= 0 ? 1.0 : dur.inSeconds.toDouble();

      // valor “real” desde el player
      final liveSeconds = dur.inSeconds <= 0
          ? 0.0
          : pos.inSeconds.clamp(0, dur.inSeconds).toDouble();

      // si arrastras, mandamos el valor local; si no, el del player
      final valueSeconds = _isDragging ? _dragValueSeconds : liveSeconds;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20), // ✅ margen
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  onPressed: () => controller.skipBackward10(),
                ),

                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: active,
                      inactiveTrackColor: inactive,

                      // ✅ bolita visible y bonita
                      thumbColor: active,
                      overlayColor: active.withValues(alpha: 0.12),

                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),

                      // opcional: track redondeado
                      trackShape: const RoundedRectSliderTrackShape(),
                    ),
                    child: Slider(
                      value: valueSeconds.clamp(0.0, maxSeconds),
                      max: maxSeconds,

                      // ✅ al empezar a arrastrar, congelamos UI al dedo
                      onChangeStart: canSeek
                          ? (v) {
                              setState(() {
                                _isDragging = true;
                                _dragValueSeconds = v;
                              });
                            }
                          : null,

                      // ✅ mientras arrastras, se mueve la bolita (y puedes hacer scrub live)
                      onChanged: canSeek
                          ? (v) {
                              setState(() => _dragValueSeconds = v);

                              // Si quieres scrub EN VIVO (seeking continuo), descomenta:
                              // controller.seek(Duration(seconds: v.toInt()));
                            }
                          : null,

                      // ✅ cuando sueltas, ahí sí hacemos seek definitivo
                      onChangeEnd: canSeek
                          ? (v) {
                              setState(() => _isDragging = false);
                              controller.seek(Duration(seconds: v.toInt()));
                            }
                          : null,
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.forward_10),
                  onPressed: () => controller.skipForward10(),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmt(Duration(seconds: valueSeconds.toInt())),
                  style: theme.textTheme.bodySmall,
                ),
                Text(_fmt(dur), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      );
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;

    if (h > 0) {
      final hh = h.toString().padLeft(2, '0');
      return '$hh:$m:$s';
    }
    return '$m:$s';
  }
}

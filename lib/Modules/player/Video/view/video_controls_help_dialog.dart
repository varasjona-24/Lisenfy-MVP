import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../settings/controller/playback_settings_controller.dart';
import '../../../../app/ui/widgets/forms/app_option_selector.dart';

class VideoControlsHelpDialog extends StatelessWidget {
  const VideoControlsHelpDialog({super.key, required this.settings});
  final PlaybackSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget hint(IconData icon, String key) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr(key),
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ),
        ],
      ),
    );
    return AlertDialog(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Icon(Icons.touch_app_rounded, color: scheme.primary),
      title: Text(tr('player.video_controls')),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('player.video_seek_interval'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Obx(
              () => AppOptionSelector<int>(
                title: tr('player.video_seek_interval'),
                value: settings.videoSeekSeconds.value,
                icon: Icons.fast_forward_rounded,
                options: {
                  for (final seconds in [5, 10, 15])
                    seconds: tr(
                      'player.video_seek_seconds',
                      args: ['$seconds'],
                    ),
                },
                onChanged: (seconds) async {
                  try {
                    await settings.setVideoSeekSeconds(seconds);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr('player.video_controls_save_error')),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            hint(Icons.touch_app_rounded, 'player.video_gesture_tap'),
            hint(Icons.fast_forward_rounded, 'player.video_gesture_seek'),
            hint(Icons.volume_up_rounded, 'player.video_gesture_volume'),
            hint(Icons.speed_rounded, 'player.video_gesture_speed'),
            hint(Icons.play_arrow_rounded, 'player.video_gesture_play'),
            hint(Icons.lock_outline_rounded, 'player.video_gesture_lock'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('common.close')),
        ),
      ],
    );
  }
}

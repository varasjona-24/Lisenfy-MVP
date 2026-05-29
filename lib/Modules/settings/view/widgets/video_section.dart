import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/playback_settings_controller.dart';

class VideoSection extends StatelessWidget {
  const VideoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playback = Get.find<PlaybackSettingsController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.movie_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Video',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: .12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Obx(
                  () => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    secondary: const Icon(Icons.label_off_rounded),
                    title: Text(
                      'Ocultar etiquetas de estado',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Oculta Pendiente, Seguir viendo, Visto y Completado sin cambiar el progreso guardado.',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: playback.hideVideoStatusLabels.value,
                    onChanged: playback.setHideVideoStatusLabels,
                  ),
                ),
                const SizedBox(height: 8),
                Divider(color: theme.dividerColor.withValues(alpha: .12)),
                const SizedBox(height: 8),
                Obx(
                  () => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    secondary: const Icon(Icons.timelapse_rounded),
                    title: Text(
                      'Ocultar etiquetas en videos de 13 min o menos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Útil para ocultar el estado visual en clips cortos o episodios breves. Viene apagado por defecto.',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: playback.hideShortVideoStatusLabels.value,
                    onChanged: playback.setHideShortVideoStatusLabels,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

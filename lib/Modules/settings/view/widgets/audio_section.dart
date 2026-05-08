import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_settings/app_settings.dart';

import '../../controller/settings_controller.dart';
import '../../controller/playback_settings_controller.dart';
import '../../controller/sleep_timer_controller.dart';
import '../../controller/equalizer_controller.dart';
import '../../../../app/services/bluetooth_audio_service.dart';

import '../widgets/section_block.dart';
import '../widgets/value_pill.dart';
import '../widgets/info_tile.dart';
import '../widgets/device_tile.dart';

class AudioSection extends StatelessWidget {
  const AudioSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playback = Get.find<PlaybackSettingsController>();
    final sleepTimer = Get.find<SleepTimerController>();
    final equalizer = Get.find<EqualizerController>();
    final settings = Get.find<SettingsController>();

    String formatRemaining(Duration d) {
      final total = d.inSeconds;
      final mm = (total ~/ 60).toString().padLeft(2, '0');
      final ss = (total % 60).toString().padLeft(2, '0');
      return '$mm:$ss';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.volume_up_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Audio',
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
            side: BorderSide(color: theme.dividerColor.withOpacity(.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Default volume
                Obx(
                  () => SectionBlock(
                    title: 'Volumen por defecto',
                    subtitle: 'Define el nivel inicial de reproducción.',
                    trailing: ValuePill(
                      text: '${playback.defaultVolume.value.toInt()}%',
                    ),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 18,
                        ),
                      ),
                      child: Slider(
                        value: playback.defaultVolume.value,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${playback.defaultVolume.value.toInt()}%',
                        onChanged: playback.setDefaultVolume,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 8),

                // Autoplay
                Obx(
                  () => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      'Reproducción automática',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Reproduce la siguiente pista al finalizar la actual.',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: playback.autoPlayNext.value,
                    onChanged: playback.setAutoPlayNext,
                  ),
                ),

                const SizedBox(height: 8),
                Obx(() {
                  final crossfadeEnabled = playback.crossfadeSeconds.value > 0;
                  final crossfadeValue = crossfadeEnabled
                      ? playback.crossfadeSeconds.value
                      : 2;

                  return Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Crossfade',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Mezcla canciones al final/inicio de la transición.',
                          style: theme.textTheme.bodySmall,
                        ),
                        value: crossfadeEnabled,
                        onChanged: (enabled) {
                          if (!enabled) {
                            playback.setCrossfadeSeconds(0);
                            return;
                          }
                          final restore = playback.crossfadeSeconds.value > 0
                              ? playback.crossfadeSeconds.value
                              : 2;
                          playback.setCrossfadeSeconds(restore);
                        },
                      ),
                      const SizedBox(height: 6),
                      SectionBlock(
                        title: 'Duración del crossfade',
                        subtitle: 'En segundos',
                        trailing: ValuePill(
                          text: crossfadeEnabled
                              ? '${playback.crossfadeSeconds.value}s'
                              : 'Off',
                        ),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 10,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 18,
                            ),
                          ),
                          child: Slider(
                            value: crossfadeValue.toDouble(),
                            min: 1,
                            max: 12,
                            divisions: 11,
                            label: '${crossfadeValue}s',
                            onChanged: crossfadeEnabled
                                ? (v) => playback.setCrossfadeSeconds(v.round())
                                : null,
                          ),
                        ),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 8),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 8),

                // Equalizer
                Obx(() {
                  if (!equalizer.eqAvailable.value) {
                    return InfoTile(
                      icon: Icons.graphic_eq_rounded,
                      title: 'Ecualizador',
                      subtitle: equalizer.eqUnavailableMessage.value.isNotEmpty
                          ? equalizer.eqUnavailableMessage.value
                          : 'Disponible solo en Android.',
                    );
                  }

                  if (equalizer.eqFrequencies.isEmpty ||
                      equalizer.eqGains.isEmpty) {
                    return InfoTile(
                      icon: Icons.graphic_eq_rounded,
                      title: 'Ecualizador',
                      subtitle: 'Cargando parámetros…',
                      trailing: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final presets = const <String, String>{
                    'normal': 'Normal',
                    'custom': 'Personalizado',
                    'bass': 'Bass',
                    'treble': 'Agudos',
                    'vocal': 'Vocal',
                    'podcast': 'Podcast',
                    'movie': 'Cine',
                    'gaming': 'Gaming',
                    'pop': 'Pop',
                    'rock': 'Rock',
                    'jazz': 'Jazz',
                    'classical': 'Clásica',
                    'acoustic': 'Acústica',
                    'hiphop': 'Hip-Hop',
                    'rnb': 'R&B',
                    'dance': 'Dance',
                    'edm': 'EDM',
                    'latin': 'Latina',
                    'metal': 'Metal',
                    'piano': 'Piano',
                    'blues': 'Blues',
                    'country': 'Country',
                    'reggae': 'Reggae',
                    'electronic': 'Electronic',
                    'night': 'Noche',
                    'loudness': 'Loudness',
                  };

                  final presetGroups = [
                    _EqPresetGroupSpec(
                      id: 'basicos',
                      title: 'Básicos',
                      subtitle: 'Perfiles rápidos para uso general.',
                      icon: Icons.tune_rounded,
                      keys: const [
                        'normal',
                        'custom',
                        'bass',
                        'treble',
                        'vocal',
                      ],
                    ),
                    _EqPresetGroupSpec(
                      id: 'musica_1',
                      title: 'Música',
                      subtitle: 'Perfiles populares y balanceados.',
                      icon: Icons.library_music_rounded,
                      keys: const [
                        'pop',
                        'rock',
                        'jazz',
                        'classical',
                        'acoustic',
                        'piano',
                      ],
                    ),
                    _EqPresetGroupSpec(
                      id: 'musica_2',
                      title: 'Géneros',
                      subtitle: 'Perfiles con más carácter.',
                      icon: Icons.graphic_eq_rounded,
                      keys: const [
                        'hiphop',
                        'rnb',
                        'dance',
                        'edm',
                        'latin',
                        'metal',
                      ],
                    ),
                    _EqPresetGroupSpec(
                      id: 'voz_escena',
                      title: 'Voz y Escena',
                      subtitle:
                          'Mejora diálogo, voz o sensación de cine/juego.',
                      icon: Icons.record_voice_over_rounded,
                      keys: const ['podcast', 'movie', 'gaming'],
                    ),
                    _EqPresetGroupSpec(
                      id: 'extras',
                      title: 'Extras',
                      subtitle: 'Perfiles situacionales y colores adicionales.',
                      icon: Icons.auto_awesome_rounded,
                      keys: const [
                        'blues',
                        'country',
                        'reggae',
                        'electronic',
                        'night',
                        'loudness',
                      ],
                    ),
                  ];

                  return Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Ecualizador',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Ajusta las frecuencias de audio.',
                          style: theme.textTheme.bodySmall,
                        ),
                        value: equalizer.eqEnabled.value,
                        onChanged: equalizer.setEqEnabled,
                      ),
                      const SizedBox(height: 8),

                      SectionBlock(
                        title: 'Presets',
                        subtitle:
                            'Perfiles organizados en secciones desplegables.',
                        trailing: ValuePill(
                          text:
                              presets[equalizer.eqPreset.value] ??
                              equalizer.eqPreset.value,
                        ),
                        child: Column(
                          children: presetGroups.map((group) {
                            final entries = group.keys
                                .where(presets.containsKey)
                                .map((key) => MapEntry(key, presets[key]!))
                                .toList(growable: false);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _EqPresetGroupTile(
                                group: group,
                                presets: entries,
                                selectedKey: equalizer.eqPreset.value,
                                onSelected: (key) => equalizer.setEqPreset(key),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      ...List.generate(equalizer.eqGains.length, (i) {
                        final freq = equalizer.eqFrequencies[i];
                        final value = equalizer.eqGains[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$freq Hz',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 9,
                                ),
                              ),
                              child: Slider(
                                value: value,
                                min: equalizer.eqMinDb.value,
                                max: equalizer.eqMaxDb.value,
                                divisions: 20,
                                label: '${value.toStringAsFixed(1)} dB',
                                onChanged: equalizer.eqEnabled.value
                                    ? (v) => equalizer.setEqGain(i, v)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        );
                      }),
                    ],
                  );
                }),

                const SizedBox(height: 8),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 8),

                // Sleep timer
                Obx(
                  () => Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Temporizador de sueño',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Detiene la reproducción después de un tiempo.',
                          style: theme.textTheme.bodySmall,
                        ),
                        value: sleepTimer.sleepTimerEnabled.value,
                        onChanged: sleepTimer.setSleepTimerEnabled,
                      ),
                      if (sleepTimer.sleepTimerEnabled.value &&
                          sleepTimer.sleepRemaining.value > Duration.zero)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Text(
                              'Tiempo restante: ${formatRemaining(sleepTimer.sleepRemaining.value)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),

                      SectionBlock(
                        title: 'Duración',
                        subtitle: 'En minutos',
                        trailing: ValuePill(
                          text: sleepTimer.sleepTimerEnabled.value
                              ? '${sleepTimer.sleepTimerMinutes.value}m'
                              : 'Off',
                        ),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 10,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 18,
                            ),
                          ),
                          child: Slider(
                            value: sleepTimer.sleepTimerMinutes.value
                                .clamp(5, 90)
                                .toDouble(),
                            min: 5,
                            max: 90,
                            divisions: 17, // pasos de 5 minutos
                            label: '${sleepTimer.sleepTimerMinutes.value}m',
                            onChanged: sleepTimer.sleepTimerEnabled.value
                                ? (v) {
                                    final rounded = ((v / 5).round() * 5)
                                        .clamp(5, 90)
                                        .toInt();
                                    sleepTimer.setSleepTimerMinutes(rounded);
                                  }
                                : null,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Fade-out toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Fade-out gradual',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          sleepTimer.fadeOutEnabled.value
                              ? 'El volumen bajará los últimos ~${(sleepTimer.sleepTimerMinutes.value * 60 * 0.05).clamp(10, 60).toInt()}s'
                              : 'La música se detendrá de golpe.',
                          style: theme.textTheme.bodySmall,
                        ),
                        value: sleepTimer.fadeOutEnabled.value,
                        onChanged: sleepTimer.setFadeOutEnabled,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 8),

                // Inactivity pause
                Obx(
                  () => Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Pausar por inactividad',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Si no interactúas, se pausa automáticamente.',
                          style: theme.textTheme.bodySmall,
                        ),
                        value: sleepTimer.inactivityPauseEnabled.value,
                        onChanged: sleepTimer.setInactivityPauseEnabled,
                      ),
                      const SizedBox(height: 6),
                      SectionBlock(
                        title: 'Tiempo de inactividad',
                        subtitle: 'En minutos',
                        trailing: ValuePill(
                          text: sleepTimer.inactivityPauseEnabled.value
                              ? '${sleepTimer.inactivityPauseMinutes.value}m'
                              : 'Off',
                        ),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 10,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 18,
                            ),
                          ),
                          child: Slider(
                            value: sleepTimer.inactivityPauseMinutes.value
                                .toDouble(),
                            min: 5,
                            max: 60,
                            divisions: 11,
                            label:
                                '${sleepTimer.inactivityPauseMinutes.value}m',
                            onChanged: sleepTimer.inactivityPauseEnabled.value
                                ? (v) => sleepTimer.setInactivityPauseMinutes(
                                    v.round(),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 8),

                // Output / Bluetooth
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.bluetooth_audio_rounded),
                  title: Text(
                    'Salida de audio',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Gestiona tu dispositivo Bluetooth desde Ajustes.',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: OutlinedButton.icon(
                    onPressed: () => AppSettings.openAppSettings(
                      type: AppSettingsType.bluetooth,
                    ),
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Ajustes'),
                  ),
                ),

                const SizedBox(height: 8),

                // Devices snapshot
                Obx(() {
                  settings.bluetoothTick.value; // keep refresh behavior
                  return FutureBuilder<BluetoothAudioSnapshot>(
                    future: settings.getBluetoothSnapshot(),
                    builder: (context, snap) {
                      final loading =
                          snap.connectionState != ConnectionState.done;

                      if (loading) {
                        return InfoTile(
                          icon: Icons.sync_rounded,
                          title: 'Buscando dispositivos…',
                          subtitle: 'Verificando el estado del Bluetooth.',
                          trailing: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final data = snap.data;
                      final devices =
                          data?.devices ?? const <BluetoothAudioDevice>[];
                      final bluetoothOn = data?.bluetoothOn ?? false;

                      if (!bluetoothOn) {
                        return InfoTile(
                          icon: Icons.bluetooth_disabled_rounded,
                          title: 'Bluetooth desactivado',
                          subtitle:
                              'Actívalo para detectar y usar dispositivos de audio.',
                          trailing: IconButton(
                            tooltip: 'Abrir ajustes',
                            onPressed: () => AppSettings.openAppSettings(
                              type: AppSettingsType.bluetooth,
                            ),
                            icon: const Icon(Icons.settings_rounded),
                          ),
                        );
                      }

                      if (devices.isEmpty) {
                        return InfoTile(
                          icon: Icons.headphones_rounded,
                          title: 'Sin dispositivos conectados',
                          subtitle:
                              'Conecta un dispositivo para mostrarlo aquí.',
                          trailing: IconButton(
                            tooltip: 'Actualizar',
                            onPressed: settings.refreshBluetoothDevices,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                'Dispositivos detectados',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          ...devices.map(
                            (device) => DeviceTile(device: device),
                          ),

                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: settings.refreshBluetoothDevices,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Actualizar'),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EqPresetGroupSpec {
  const _EqPresetGroupSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.keys,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> keys;
}

class _EqPresetGroupTile extends StatelessWidget {
  const _EqPresetGroupTile({
    required this.group,
    required this.presets,
    required this.selectedKey,
    required this.onSelected,
  });

  final _EqPresetGroupSpec group;
  final List<MapEntry<String, String>> presets;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    String? selectedLabel;
    for (final entry in presets) {
      if (entry.key == selectedKey) {
        selectedLabel = entry.value;
        break;
      }
    }
    final hasSelected = selectedLabel != null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withOpacity(.35)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('eq_group_${group.id}'),
          maintainState: true,
          initiallyExpanded: hasSelected,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Icon(
            group.icon,
            size: 18,
            color: hasSelected ? scheme.primary : scheme.onSurfaceVariant,
          ),
          title: Text(
            group.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            hasSelected ? 'Seleccionado: $selectedLabel' : group.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.2,
            ),
          ),
          children: [
            ...presets.map((entry) {
              final isSelected = selectedKey == entry.key;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                  size: 20,
                ),
                title: Text(
                  entry.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, color: scheme.primary, size: 20)
                    : null,
                onTap: () => onSelected(entry.key),
              );
            }),
          ],
        ),
      ),
    );
  }
}

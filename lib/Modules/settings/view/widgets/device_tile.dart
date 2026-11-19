import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../app/services/bluetooth_audio_service.dart';
import 'value_pill.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device, this.desktop = false});

  final BluetoothAudioDevice device;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon = Icons.bluetooth_connected_rounded;
    String kindLabel = device.kind;

    switch (device.kind) {
      case 'usb':
        icon = Icons.usb_rounded;
        break;
      case 'hdmi':
        icon = Icons.monitor_rounded;
        break;
      case 'network':
        icon = Icons.wifi_rounded;
        break;
      case 'builtin':
        icon = Icons.computer_rounded;
        break;
      case 'virtual':
        icon = Icons.graphic_eq_rounded;
        break;
      case 'wired':
        icon = Icons.headphones_rounded;
        kindLabel = 'Cable';
        break;
      case 'speaker':
        icon = Icons.speaker_rounded;
        kindLabel = 'Altavoz';
        break;
      case 'earpiece':
        icon = Icons.earbuds_rounded;
        kindLabel = 'Auricular';
        break;
      case 'bluetooth':
        icon = Icons.bluetooth_connected_rounded;
        kindLabel = 'Bluetooth';
        break;
    }

    if (desktop) {
      const kinds = {
        'usb',
        'hdmi',
        'network',
        'builtin',
        'virtual',
        'wired',
        'speaker',
        'earpiece',
        'bluetooth',
      };
      final kind = kinds.contains(device.kind) ? device.kind : 'unknown';
      kindLabel = tr('settings.audio.output_kind_$kind');
      if (kind == 'unknown') icon = Icons.speaker_group_rounded;
    }
    final battery =
        (device.batteryPercent != null && device.batteryPercent! >= 0)
        ? '${device.batteryPercent}%'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .12)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Icon(icon),
        title: Text(
          device.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          device.kind == 'bluetooth' && !desktop
              ? '$kindLabel • ${device.address}'
              : kindLabel,
          style: theme.textTheme.bodySmall,
        ),
        trailing: device.isActive || battery != null
            ? Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (device.isActive)
                    ValuePill(text: tr('settings.audio.system_default')),
                  if (battery != null) ValuePill(text: battery),
                ],
              )
            : null,
      ),
    );
  }
}

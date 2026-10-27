import 'package:flutter/material.dart';
import '../../../../app/services/bluetooth_audio_service.dart';
import 'value_pill.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device});

  final BluetoothAudioDevice device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon = Icons.bluetooth_connected_rounded;
    String kindLabel = device.kind;

    switch (device.kind) {
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
          device.kind == 'bluetooth'
              ? '$kindLabel • ${device.address}'
              : kindLabel,
          style: theme.textTheme.bodySmall,
        ),
        trailing: battery != null ? ValuePill(text: battery) : null,
      ),
    );
  }
}

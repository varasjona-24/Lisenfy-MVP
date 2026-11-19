import 'dart:io';
import 'package:flutter/services.dart';

class BluetoothAudioDevice {
  final String name;
  final String address;
  final String kind; // bluetooth, wired, speaker, earpiece, unknown
  final int? batteryPercent;
  final bool isActive;

  const BluetoothAudioDevice({
    required this.name,
    required this.address,
    required this.kind,
    this.batteryPercent,
    this.isActive = false,
  });
}

class BluetoothAudioSnapshot {
  final bool bluetoothOn;
  final bool isAvailable;
  final List<BluetoothAudioDevice> devices;
  final List<String> outputs;

  const BluetoothAudioSnapshot({
    required this.bluetoothOn,
    required this.devices,
    required this.outputs,
    this.isAvailable = true,
  });
}

class BluetoothAudioService {
  BluetoothAudioService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('listenfy/bluetooth_audio');
  final MethodChannel _channel;
  static bool get isDesktop => Platform.isMacOS || Platform.isWindows;

  Future<bool> openAudioSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAudioSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<BluetoothAudioSnapshot> getSnapshot() async {
    try {
      final raw = await _channel
          .invokeMethod<Map>('getAudioDevices')
          .timeout(const Duration(seconds: 5));
      if (raw == null) {
        throw const FormatException('Audio snapshot unavailable');
      }
      final map = Map<String, dynamic>.from(raw);

      final bluetoothOn = map['bluetoothOn'] == true;
      final outputsRaw = map['outputs'];
      final outputs = <String>[];
      if (outputsRaw is List) {
        for (final entry in outputsRaw) {
          if (entry is String && entry.trim().isNotEmpty) {
            outputs.add(entry.trim());
          }
        }
      }

      final devicesRaw = map['devices'];
      final devices = <BluetoothAudioDevice>[];

      if (devicesRaw is List) {
        for (final entry in devicesRaw) {
          if (entry is Map) {
            final data = Map<String, dynamic>.from(entry);
            final name = (data['name'] as String?)?.trim() ?? '';
            final address = (data['address'] as String?)?.trim() ?? '';
            final kind = (data['kind'] as String?)?.trim() ?? 'unknown';
            final battery = data['battery'];
            final batteryPercent =
                battery is num && battery >= 0 && battery <= 100
                ? battery.toInt()
                : null;
            if (address.isNotEmpty) {
              devices.add(
                BluetoothAudioDevice(
                  name: name.isNotEmpty ? name : 'Dispositivo Bluetooth',
                  address: address,
                  kind: kind,
                  batteryPercent: batteryPercent,
                  isActive: data['isActive'] == true,
                ),
              );
            } else if (name.isNotEmpty) {
              devices.add(
                BluetoothAudioDevice(
                  name: name,
                  address: '',
                  kind: kind,
                  batteryPercent: batteryPercent,
                  isActive: data['isActive'] == true,
                ),
              );
            }
          }
        }
      }

      if (isDesktop) {
        devices.sort(
          (a, b) => a.isActive != b.isActive
              ? (a.isActive ? -1 : 1)
              : a.name.compareTo(b.name),
        );
      }
      return BluetoothAudioSnapshot(
        bluetoothOn: bluetoothOn,
        devices: devices,
        outputs: outputs,
      );
    } catch (_) {
      return const BluetoothAudioSnapshot(
        bluetoothOn: false,
        isAvailable: false,
        devices: <BluetoothAudioDevice>[],
        outputs: <String>[],
      );
    }
  }
}

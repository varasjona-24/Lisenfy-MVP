import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../app/services/bluetooth_audio_service.dart';
import 'device_tile.dart';
import 'info_tile.dart';

class DesktopAudioOutputs extends StatefulWidget {
  const DesktopAudioOutputs({super.key, this.service});
  final BluetoothAudioService? service;
  @override
  State<DesktopAudioOutputs> createState() => _DesktopAudioOutputsState();
}

class _DesktopAudioOutputsState extends State<DesktopAudioOutputs>
    with WidgetsBindingObserver {
  late final BluetoothAudioService _service;
  Timer? _timer;
  bool _loading = false;
  bool _active = true;
  BluetoothAudioSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? BluetoothAudioService();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_active) _load();
    });
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final snapshot = await _service.getSnapshot();
      if (mounted) setState(() => _snapshot = snapshot);
    } finally {
      _loading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openSettings() async {
    if (!await _service.openAudioSettings() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('settings.audio.output_settings_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.speaker_group_rounded),
          title: Text(tr('settings.audio.audio_output')),
          subtitle: Text(tr('settings.audio.desktop_output_description')),
          trailing: OutlinedButton.icon(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: Text(tr('settings.audio.settings_button')),
          ),
        ),
        const SizedBox(height: 8),
        if (snapshot == null)
          const Center(child: CircularProgressIndicator())
        else if (!snapshot.isAvailable || snapshot.devices.isEmpty)
          InfoTile(
            icon: snapshot.isAvailable
                ? Icons.headphones_rounded
                : Icons.error_outline_rounded,
            title: tr(
              snapshot.isAvailable
                  ? 'settings.audio.no_devices'
                  : 'settings.audio.outputs_unavailable',
            ),
            subtitle: tr('settings.audio.desktop_output_description'),
          )
        else
          ...snapshot.devices.map(
            (device) => DeviceTile(device: device, desktop: true),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(tr('settings.audio.refresh')),
          ),
        ),
      ],
    );
  }
}

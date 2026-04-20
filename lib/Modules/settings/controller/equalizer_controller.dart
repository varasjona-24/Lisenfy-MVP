import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/services/audio_service.dart';

/// Gestiona: ecualizador completo (presets, gains, bandas).
class EqualizerController extends GetxController {
  final GetStorage _storage = GetStorage();

  // 🎚️ Ecualizador
  final RxBool eqEnabled = false.obs;
  final RxString eqPreset = 'custom'.obs;
  final RxList<double> eqGains = <double>[].obs;
  final RxList<int> eqFrequencies = <int>[].obs;
  final RxDouble eqMinDb = (-6.0).obs;
  final RxDouble eqMaxDb = (6.0).obs;
  final RxBool eqAvailable = false.obs;
  final RxString eqUnavailableMessage = 'Disponible solo en Android.'.obs;
  StreamSubscription<int?>? _audioSessionSub;
  int? _lastAudioSessionId;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    _bindAudioSession();
    _initEqualizer();
  }

  @override
  void onClose() {
    _audioSessionSub?.cancel();
    super.onClose();
  }

  void _loadSettings() {
    eqEnabled.value = _storage.read('eqEnabled') ?? false;
    eqPreset.value = _storage.read('eqPreset') ?? 'custom';
    final rawGains = _storage.read<List>('eqGains');
    if (rawGains != null) {
      eqGains.assignAll(rawGains.whereType<num>().map((e) => e.toDouble()));
    }
  }

  // ============================
  // 🎚️ EQ CONTROL
  // ============================
  Future<void> setEqEnabled(bool value) async {
    eqEnabled.value = value;
    _storage.write('eqEnabled', value);
    if (Get.isRegistered<AudioService>()) {
      await Get.find<AudioService>().setEqEnabled(value);
    }
  }

  Future<void> setEqPreset(String preset) async {
    eqPreset.value = preset;
    _storage.write('eqPreset', preset);
    await _applyPreset();
  }

  Future<void> setEqGain(int index, double gain) async {
    if (index < 0) return;
    if (index >= eqGains.length) return;
    eqGains[index] = gain;
    eqPreset.value = 'custom';
    _storage.write('eqPreset', 'custom');
    _storage.write('eqGains', eqGains.toList());
    if (Get.isRegistered<AudioService>()) {
      await Get.find<AudioService>().setEqBandGain(index, gain);
    }
  }

  // ============================
  // 🔧 INIT / REFRESH
  // ============================
  Future<void> refreshEqualizer() => _initEqualizer();

  void _bindAudioSession() {
    if (!Get.isRegistered<AudioService>()) return;
    final audio = Get.find<AudioService>();
    if (!audio.eqSupported) return;

    _audioSessionSub?.cancel();
    _audioSessionSub = audio.androidAudioSessionIdStream.listen((sessionId) {
      if (sessionId == null || sessionId <= 0) return;
      if (_lastAudioSessionId == sessionId && eqAvailable.value) return;
      _lastAudioSessionId = sessionId;
      _initEqualizer();
    });
  }

  Future<void> _initEqualizer() async {
    if (!Get.isRegistered<AudioService>()) {
      eqAvailable.value = false;
      eqUnavailableMessage.value = 'Audio no inicializado.';
      return;
    }
    final audio = Get.find<AudioService>();
    if (!audio.eqSupported) {
      eqAvailable.value = false;
      eqUnavailableMessage.value = 'Disponible solo en Android.';
      return;
    }

    try {
      final params = await audio.getEqParameters();
      if (params == null) {
        eqAvailable.value = false;
        eqUnavailableMessage.value =
            'Reproduce una pista para activar el ecualizador.';
        return;
      }

      eqAvailable.value = true;
      eqUnavailableMessage.value = '';
      eqMinDb.value = params.minDecibels;
      eqMaxDb.value = params.maxDecibels;
      eqFrequencies.assignAll(
        params.bands.map((b) => b.centerFrequency.round()),
      );

      // Ajustar tamaño de gains
      if (eqGains.length != params.bands.length) {
        eqGains.assignAll(List<double>.filled(params.bands.length, 0.0));
      }

      // Aplicar preset o gains guardados
      await _applyPreset();
      await setEqEnabled(eqEnabled.value);
    } catch (e) {
      debugPrint('Equalizer init error: $e');
      eqAvailable.value = false;
      eqUnavailableMessage.value = 'No se pudo iniciar el ecualizador.';
    }
  }

  Future<void> _applyPreset() async {
    if (!Get.isRegistered<AudioService>()) return;
    if (!eqAvailable.value) return;

    final audio = Get.find<AudioService>();
    final bands = eqFrequencies.length;
    if (bands == 0) return;

    List<double> gains;
    if (eqPreset.value == 'custom' && eqGains.length == bands) {
      gains = eqGains.toList();
    } else {
      gains = _presetGains(eqPreset.value, bands, eqMinDb.value, eqMaxDb.value);
      eqGains.assignAll(gains);
    }

    _storage.write('eqGains', eqGains.toList());
    for (var i = 0; i < gains.length; i++) {
      await audio.setEqBandGain(i, gains[i]);
    }
  }

  Future<void> resetEqualizerSettings() async {
    eqEnabled.value = false;
    eqPreset.value = 'custom';
    if (eqGains.isNotEmpty) {
      eqGains.assignAll(List<double>.filled(eqGains.length, 0.0));
    }

    await _storage.write('eqEnabled', false);
    await _storage.write('eqPreset', 'custom');
    await _storage.write('eqGains', eqGains.toList());

    if (Get.isRegistered<AudioService>()) {
      final audio = Get.find<AudioService>();
      for (var i = 0; i < eqGains.length; i++) {
        await audio.setEqBandGain(i, 0.0);
      }
      await audio.setEqEnabled(false);
    }
  }

  List<double> _presetGains(
    String preset,
    int bands,
    double minDb,
    double maxDb,
  ) {
    final base = switch (preset) {
      'normal' => [0.0, 0.0, 0.0, 0.0, 0.0],
      'bass' => [0.6, 0.4, 0.0, -0.2, -0.3],
      'pop' => [0.2, 0.1, 0.15, 0.25, 0.2],
      'jazz' => [0.15, 0.25, 0.05, 0.15, 0.2],
      'classical' => [0.0, 0.05, 0.05, 0.15, 0.2],
      'acoustic' => [0.05, 0.15, 0.2, 0.1, 0.0],
      'vocal' => [-0.2, 0.1, 0.5, 0.4, -0.1],
      'podcast' => [-0.45, -0.15, 0.35, 0.45, 0.15],
      'hiphop' => [0.7, 0.45, -0.1, 0.1, 0.15],
      'rnb' => [0.35, 0.15, 0.05, 0.2, 0.25],
      'dance' => [0.45, 0.25, -0.15, 0.1, 0.45],
      'edm' => [0.55, 0.25, -0.15, 0.2, 0.5],
      'latin' => [0.3, 0.2, 0.0, 0.15, 0.25],
      'blues' => [0.15, 0.05, 0.2, 0.1, 0.05],
      'country' => [0.05, 0.15, 0.2, 0.15, 0.1],
      'reggae' => [0.35, 0.25, 0.0, 0.1, 0.2],
      'electronic' => [0.45, 0.2, -0.1, 0.2, 0.45],
      'night' => [0.2, 0.1, 0.05, 0.0, -0.05],
      'loudness' => [0.25, 0.15, 0.05, 0.2, 0.25],
      'treble' => [-0.3, -0.2, 0.0, 0.4, 0.6],
      'rock' => [0.4, 0.3, 0.1, 0.2, 0.4],
      'metal' => [0.55, 0.2, -0.2, 0.3, 0.6],
      'piano' => [-0.05, 0.1, 0.2, 0.15, 0.0],
      'movie' => [0.1, 0.0, 0.2, 0.35, 0.2],
      'gaming' => [0.15, -0.05, 0.25, 0.35, 0.15],
      _ => [0.0, 0.0, 0.0, 0.0, 0.0],
    };

    double clampDb(double v) {
      if (v < minDb) return minDb;
      if (v > maxDb) return maxDb;
      return v;
    }

    final maxAbs = [maxDb.abs(), minDb.abs()].reduce((a, b) => a < b ? a : b);

    if (bands <= 1) {
      return [clampDb(base.first * maxAbs)];
    }

    final gains = <double>[];
    for (var i = 0; i < bands; i++) {
      final t = i / (bands - 1);
      final rawIndex = t * (base.length - 1);
      final lo = rawIndex.floor();
      final hi = rawIndex.ceil();
      final frac = rawIndex - lo;
      final v = (lo == hi)
          ? base[lo]
          : (base[lo] + (base[hi] - base[lo]) * frac);
      gains.add(clampDb(v * maxAbs));
    }
    return gains;
  }
}

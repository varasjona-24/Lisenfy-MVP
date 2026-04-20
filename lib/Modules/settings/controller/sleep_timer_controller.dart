import 'dart:async';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/services/audio_service.dart';

/// Gestiona: sleep timer (con fade-out) y pausa por inactividad.
class SleepTimerController extends GetxController {
  final GetStorage _storage = GetStorage();

  /// Opciones discretas de duración del timer (minutos).
  static const List<int> timerPresets = [5, 10, 15, 20, 30, 40, 60, 90];

  // 🌙 Sleep timer
  final RxBool sleepTimerEnabled = false.obs;
  final RxInt sleepTimerMinutes = 30.obs;
  final Rx<Duration> sleepRemaining = Duration.zero.obs;
  Timer? _sleepTimer;

  // 🔉 Fade-out
  final RxBool fadeOutEnabled = true.obs;
  double? _originalVolume;
  bool _isFadingOut = false;

  // 💤 Pausa por inactividad
  final RxBool inactivityPauseEnabled = false.obs;
  final RxInt inactivityPauseMinutes = 15.obs;
  Timer? _inactivityTimer;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    _bindPlaybackActivity();
  }

  void _loadSettings() {
    sleepTimerEnabled.value = _storage.read('sleepTimerEnabled') ?? false;
    sleepTimerMinutes.value = _storage.read('sleepTimerMinutes') ?? 30;
    fadeOutEnabled.value = _storage.read('fadeOutEnabled') ?? true;

    final sleepEndMs = _storage.read('sleepTimerEndMs');
    if (sleepEndMs is int && sleepEndMs > 0) {
      final remaining = Duration(
        milliseconds: sleepEndMs - DateTime.now().millisecondsSinceEpoch,
      );
      if (remaining > Duration.zero) {
        sleepTimerEnabled.value = true;
        _startSleepTimer(remaining);
      } else {
        _clearSleepTimerPersisted();
      }
    }

    inactivityPauseEnabled.value =
        _storage.read('inactivityPauseEnabled') ?? false;
    inactivityPauseMinutes.value =
        _storage.read('inactivityPauseMinutes') ?? 15;
  }

  // ============================
  // 🌙 SLEEP TIMER
  // ============================
  void setSleepTimerEnabled(bool value) {
    sleepTimerEnabled.value = value;
    _storage.write('sleepTimerEnabled', value);
    if (!value) {
      _cancelSleepTimer();
      _restoreVolume();
      _clearSleepTimerPersisted();
      if (Get.isRegistered<AudioService>()) {
        Get.find<AudioService>().refreshNotification();
      }
      return;
    }
    final minutes = sleepTimerMinutes.value;
    _startSleepTimer(Duration(minutes: minutes));
  }

  void setSleepTimerMinutes(int minutes) {
    sleepTimerMinutes.value = minutes;
    _storage.write('sleepTimerMinutes', minutes);
    if (sleepTimerEnabled.value) {
      _restoreVolume();
      _startSleepTimer(Duration(minutes: minutes));
    }
  }

  void setFadeOutEnabled(bool value) {
    fadeOutEnabled.value = value;
    _storage.write('fadeOutEnabled', value);
    // Si se desactiva mientras está en fade, restaurar volumen
    if (!value && _isFadingOut) {
      _restoreVolume();
    }
  }

  /// Calcula la duración del fade-out: 5% del total, entre 10s y 60s.
  int get _fadeDurationSeconds {
    final totalSeconds = sleepTimerMinutes.value * 60;
    return (totalSeconds * 0.05).clamp(10, 60).toInt();
  }

  void _startSleepTimer(Duration duration) {
    _cancelSleepTimer();
    _isFadingOut = false;
    _originalVolume = null;

    final endMs =
        DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
    _storage.write('sleepTimerEndMs', endMs);
    sleepRemaining.value = duration;

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final remaining = Duration(
        milliseconds: endMs - DateTime.now().millisecondsSinceEpoch,
      );

      if (remaining <= Duration.zero) {
        // Timer acabó → pausar
        sleepRemaining.value = Duration.zero;
        t.cancel();
        _sleepTimer = null;
        sleepTimerEnabled.value = false;
        _storage.write('sleepTimerEnabled', false);
        _clearSleepTimerPersisted();

        if (Get.isRegistered<AudioService>()) {
          final audio = Get.find<AudioService>();
          await audio.pause();
          // Restaurar volumen original para la próxima reproducción
          _restoreVolume();
          audio.refreshNotification();
        }
        return;
      }

      sleepRemaining.value = remaining;

      // 🔉 Fade-out gradual
      if (fadeOutEnabled.value && Get.isRegistered<AudioService>()) {
        final audio = Get.find<AudioService>();
        final fadeSecs = _fadeDurationSeconds;

        if (remaining.inSeconds <= fadeSecs) {
          // Guardar volumen original la primera vez que entramos al fade
          if (!_isFadingOut) {
            _isFadingOut = true;
            _originalVolume = audio.volume.value;
          }

          final fraction = remaining.inSeconds / fadeSecs; // 1.0 → 0.0
          final fadeVolume = (_originalVolume ?? 1.0) * fraction;
          audio.setVolume(fadeVolume.clamp(0.0, 1.0));
        }
      }

      if (Get.isRegistered<AudioService>()) {
        Get.find<AudioService>().refreshNotification();
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepRemaining.value = Duration.zero;
    _isFadingOut = false;
  }

  void _restoreVolume() {
    if (_originalVolume != null && Get.isRegistered<AudioService>()) {
      Get.find<AudioService>().setVolume(_originalVolume!);
    }
    _originalVolume = null;
    _isFadingOut = false;
  }

  void _clearSleepTimerPersisted() {
    _storage.remove('sleepTimerEndMs');
  }

  // ============================
  // 💤 PAUSA POR INACTIVIDAD
  // ============================
  void setInactivityPauseEnabled(bool value) {
    inactivityPauseEnabled.value = value;
    _storage.write('inactivityPauseEnabled', value);
    if (!value) {
      _cancelInactivityTimer();
      return;
    }
    _resetInactivityTimer();
  }

  void setInactivityPauseMinutes(int minutes) {
    inactivityPauseMinutes.value = minutes;
    _storage.write('inactivityPauseMinutes', minutes);
    if (inactivityPauseEnabled.value) {
      _resetInactivityTimer();
    }
  }

  void notifyPlaybackActivity() {
    if (!inactivityPauseEnabled.value) return;
    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _cancelInactivityTimer();
    final minutes = inactivityPauseMinutes.value;
    _inactivityTimer = Timer(Duration(minutes: minutes), () async {
      if (Get.isRegistered<AudioService>()) {
        final audio = Get.find<AudioService>();
        if (audio.isPlaying.value) {
          await audio.pause();
        }
      }
    });
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _bindPlaybackActivity() {
    if (!Get.isRegistered<AudioService>()) return;
    final audio = Get.find<AudioService>();
    ever<bool>(audio.isPlaying, (playing) {
      if (!playing) {
        _cancelInactivityTimer();
      } else if (inactivityPauseEnabled.value) {
        _resetInactivityTimer();
      }
    });
  }

  Future<void> resetSleepSettings() async {
    _cancelSleepTimer();
    _cancelInactivityTimer();
    _restoreVolume();

    sleepTimerEnabled.value = false;
    sleepTimerMinutes.value = 30;
    sleepRemaining.value = Duration.zero;
    fadeOutEnabled.value = true;
    inactivityPauseEnabled.value = false;
    inactivityPauseMinutes.value = 15;

    await _storage.write('sleepTimerEnabled', false);
    await _storage.write('sleepTimerMinutes', 30);
    await _storage.write('fadeOutEnabled', true);
    await _storage.write('inactivityPauseEnabled', false);
    await _storage.write('inactivityPauseMinutes', 15);
    await _storage.remove('sleepTimerEndMs');

    if (Get.isRegistered<AudioService>()) {
      Get.find<AudioService>().refreshNotification();
    }
  }

  @override
  void onClose() {
    _sleepTimer?.cancel();
    _inactivityTimer?.cancel();
    _restoreVolume();
    super.onClose();
  }
}

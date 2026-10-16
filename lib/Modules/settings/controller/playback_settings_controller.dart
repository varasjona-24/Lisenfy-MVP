import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/services/audio_service.dart';
import '../../../app/services/video_service.dart';
import '../../../app/data/playback/playback_state_storage.dart';

/// Gestiona: volumen, autoplay, crossfade, calidad de descarga y uso de datos.
class PlaybackSettingsController extends GetxController {
  PlaybackSettingsController({GetStorage? storage})
    : _storage = storage ?? playbackStateStorage();
  static const videoSeekSecondsKey = 'video_seek_seconds';
  static const hideVideoStatusLabelsKey = 'hide_video_status_labels';
  static const hideShortVideoStatusLabelsKey = 'hide_short_video_status_labels';

  final GetStorage _storage;
  final RxInt videoSeekSeconds = 5.obs;

  Future<void> setVideoSeekSeconds(int seconds) async {
    if (![5, 10, 15].contains(seconds)) return;
    await _storage.write(videoSeekSecondsKey, seconds);
    videoSeekSeconds.value = seconds;
  }

  // 🔊 Volumen por defecto (0-100)
  final RxDouble defaultVolume = 100.0.obs;

  // 🎵 Reproducción automática
  final RxBool autoPlayNext = true.obs;
  final RxInt crossfadeSeconds = 0.obs;

  // 🎬 Etiquetas visuales de video
  final RxBool hideVideoStatusLabels = false.obs;
  final RxBool hideShortVideoStatusLabels = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    _applyCrossfade();
  }

  void _loadSettings() {
    final storedSeek = _storage.read<int>(videoSeekSecondsKey);
    videoSeekSeconds.value = [5, 10, 15].contains(storedSeek) ? storedSeek! : 5;
    defaultVolume.value = _storage.read('defaultVolume') ?? 100.0;
    autoPlayNext.value = _storage.read('autoPlayNext') ?? true;
    crossfadeSeconds.value = _storage.read('audio_crossfade_seconds') ?? 0;
    hideVideoStatusLabels.value =
        _storage.read(hideVideoStatusLabelsKey) ?? false;
    hideShortVideoStatusLabels.value =
        _storage.read(hideShortVideoStatusLabelsKey) ?? false;

    _applyVolumeToPlayers(defaultVolume.value);
  }

  // ============================
  // 🔊 Volumen
  // ============================
  void setDefaultVolume(double volume) {
    defaultVolume.value = volume;
    _storage.write('defaultVolume', volume);
    _applyVolumeToPlayers(volume);
  }

  void _applyVolumeToPlayers(double volume) {
    final v = (volume / 100).clamp(0.0, 1.0);
    if (Get.isRegistered<AudioService>()) {
      Get.find<AudioService>().setVolume(v);
    }
    if (Get.isRegistered<VideoService>()) {
      Get.find<VideoService>().setVolume(v);
    }
  }

  // ============================
  // 🎵 Reproducción automática
  // ============================
  void setAutoPlayNext(bool value) {
    autoPlayNext.value = value;
    _storage.write('autoPlayNext', value);
  }

  // ============================
  // 🔀 Crossfade
  // ============================
  Future<void> setCrossfadeSeconds(int seconds) async {
    final safe = seconds.clamp(0, 12).toInt();
    crossfadeSeconds.value = safe;
    await _storage.write('audio_crossfade_seconds', safe);
    if (Get.isRegistered<AudioService>()) {
      await Get.find<AudioService>().setCrossfadeSeconds(safe);
    }
  }

  void _applyCrossfade() {
    if (!Get.isRegistered<AudioService>()) return;
    Get.find<AudioService>().setCrossfadeSeconds(crossfadeSeconds.value);
  }

  // ============================
  // 🎬 Etiquetas visuales de video
  // ============================
  void setHideVideoStatusLabels(bool value) {
    hideVideoStatusLabels.value = value;
    _storage.write(hideVideoStatusLabelsKey, value);
  }

  void setHideShortVideoStatusLabels(bool value) {
    hideShortVideoStatusLabels.value = value;
    _storage.write(hideShortVideoStatusLabelsKey, value);
  }

  // ============================
  // 🔄 Reset
  // ============================
  Future<void> resetPlaybackSettings() async {
    defaultVolume.value = 100.0;
    autoPlayNext.value = true;
    crossfadeSeconds.value = 0;
    hideVideoStatusLabels.value = false;
    hideShortVideoStatusLabels.value = false;

    await _storage.write('defaultVolume', defaultVolume.value);
    await _storage.write('autoPlayNext', autoPlayNext.value);
    await _storage.write('audio_crossfade_seconds', crossfadeSeconds.value);
    await _storage.write(hideVideoStatusLabelsKey, hideVideoStatusLabels.value);
    await _storage.write(
      hideShortVideoStatusLabelsKey,
      hideShortVideoStatusLabels.value,
    );

    _applyVolumeToPlayers(defaultVolume.value);
    _applyCrossfade();
  }
}

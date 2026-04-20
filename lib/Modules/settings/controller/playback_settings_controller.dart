import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/services/audio_service.dart';
import '../../../app/services/video_service.dart';

/// Gestiona: volumen, autoplay, crossfade, calidad de descarga y uso de datos.
class PlaybackSettingsController extends GetxController {
  final GetStorage _storage = GetStorage();

  // 🔊 Volumen por defecto (0-100)
  final RxDouble defaultVolume = 100.0.obs;

  // 🎵 Reproducción automática
  final RxBool autoPlayNext = true.obs;
  final RxInt crossfadeSeconds = 0.obs;

  // 📱 Calidad de descarga
  final Rx<String> downloadQuality = 'high'.obs; // low, medium, high

  // 📡 Uso de datos
  final Rx<String> dataUsage = 'all'.obs; // wifi_only, all

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    _applyCrossfade();
  }

  void _loadSettings() {
    defaultVolume.value = _storage.read('defaultVolume') ?? 100.0;
    downloadQuality.value = _storage.read('downloadQuality') ?? 'high';
    dataUsage.value = _storage.read('dataUsage') ?? 'all';
    autoPlayNext.value = _storage.read('autoPlayNext') ?? true;
    crossfadeSeconds.value = _storage.read('audio_crossfade_seconds') ?? 0;

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
    _storage.write('audio_crossfade_seconds', safe);
    if (Get.isRegistered<AudioService>()) {
      await Get.find<AudioService>().setCrossfadeSeconds(safe);
    }
  }

  void _applyCrossfade() {
    if (!Get.isRegistered<AudioService>()) return;
    Get.find<AudioService>().setCrossfadeSeconds(crossfadeSeconds.value);
  }

  // ============================
  // 📱 Calidad de descarga
  // ============================
  void setDownloadQuality(String quality) {
    downloadQuality.value = quality;
    _storage.write('downloadQuality', quality);
  }

  // ============================
  // 📡 Uso de datos
  // ============================
  void setDataUsage(String usage) {
    dataUsage.value = usage;
    _storage.write('dataUsage', usage);
  }

  // ============================
  // 📊 Quality helpers
  // ============================
  String getAudioBitrate(String? quality) {
    final q = quality ?? downloadQuality.value;
    switch (q) {
      case 'low':
        return '128 kbps';
      case 'medium':
        return '192 kbps';
      case 'high':
        return '320 kbps';
      default:
        return '320 kbps';
    }
  }

  String getVideoResolution(String? quality) {
    final q = quality ?? downloadQuality.value;
    switch (q) {
      case 'low':
        return '360p';
      case 'medium':
        return '720p';
      case 'high':
        return '1080p';
      default:
        return '1080p';
    }
  }

  String getQualityDescription(String? quality) {
    final q = quality ?? downloadQuality.value;
    final audio = getAudioBitrate(q);
    final video = getVideoResolution(q);
    return 'Audio: $audio | Video: $video';
  }

  Map<String, dynamic> getDownloadSpecs() {
    return {
      'quality': downloadQuality.value,
      'audio_bitrate': getAudioBitrate(null),
      'video_resolution': getVideoResolution(null),
      'data_usage': dataUsage.value,
      'wifi_only': dataUsage.value == 'wifi_only',
    };
  }

  // ============================
  // 🔄 Reset
  // ============================
  Future<void> resetPlaybackSettings() async {
    defaultVolume.value = 100.0;
    downloadQuality.value = 'high';
    dataUsage.value = 'all';
    autoPlayNext.value = true;
    crossfadeSeconds.value = 0;

    await _storage.write('defaultVolume', defaultVolume.value);
    await _storage.write('downloadQuality', downloadQuality.value);
    await _storage.write('dataUsage', dataUsage.value);
    await _storage.write('autoPlayNext', autoPlayNext.value);
    await _storage.write('audio_crossfade_seconds', crossfadeSeconds.value);

    _applyVolumeToPlayers(defaultVolume.value);
    _applyCrossfade();
  }
}

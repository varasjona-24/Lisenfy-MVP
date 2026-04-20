import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart';

import '../../../app/controllers/theme_controller.dart';
import '../../../app/data/network/dio_client.dart';
import '../../../app/services/bluetooth_audio_service.dart';
import 'playback_settings_controller.dart';
import 'sleep_timer_controller.dart';
import 'equalizer_controller.dart';

/// Gestiona: apariencia, caché, bluetooth, cookies YouTube, storage info y reset.
///
/// Las demás responsabilidades fueron extraídas a:
/// - [PlaybackSettingsController] — volumen, autoplay, crossfade, calidad, datos
/// - [SleepTimerController] — sleep timer + pausa por inactividad
/// - [EqualizerController] — ecualizador completo
/// - [BackupRestoreController] — export/import de librería
class SettingsController extends GetxController {
  final GetStorage _storage = GetStorage();

  // 🎨 Paleta actual
  final Rx<String> selectedPalette = 'green'.obs;

  // 🌗 Modo de brillo
  final Rx<Brightness> brightness = Brightness.dark.obs;

  // 🔄 Forzar refresco de datos de almacenamiento
  final RxInt storageTick = 0.obs;
  final RxInt bluetoothTick = 0.obs;
  final RxString cacheSummary = 'Calculando...'.obs;
  final BluetoothAudioService _bluetoothAudio = BluetoothAudioService();

  // 🍪 YouTube cookies
  final TextEditingController ytdlpAdminTokenController =
      TextEditingController();
  final RxString ytdlpAdminToken = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    _configureAudioSession();
    refreshCacheSummary();
  }

  void _loadSettings() {
    selectedPalette.value = _storage.read('selectedPalette') ?? 'green';
    brightness.value = (_storage.read('brightness') ?? 'dark') == 'light'
        ? Brightness.light
        : Brightness.dark;

    ytdlpAdminToken.value = _storage.read('ytdlpAdminToken') ?? '';
    ytdlpAdminTokenController.text = ytdlpAdminToken.value;

    _applyTheme();
  }

  // ============================
  // 🎨 APARIENCIA
  // ============================
  Future<void> setPalette(String paletteKey) async {
    selectedPalette.value = paletteKey;
    _storage.write('selectedPalette', paletteKey);
    _applyTheme();
  }

  Future<void> setBrightness(Brightness b) async {
    brightness.value = b;
    _storage.write('brightness', b == Brightness.light ? 'light' : 'dark');
    _applyTheme();
  }

  void _applyTheme() {
    if (Get.isRegistered<ThemeController>()) {
      final themeCtrl = Get.find<ThemeController>();
      themeCtrl.setPalette(selectedPalette.value);
      themeCtrl.setBrightness(brightness.value);
    }
  }

  // ============================
  // 🔊 Audio session
  // ============================
  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  // ============================
  // 📱 Bluetooth
  // ============================
  Future<BluetoothAudioSnapshot> getBluetoothSnapshot() =>
      _bluetoothAudio.getSnapshot();

  void refreshBluetoothDevices() {
    bluetoothTick.value++;
  }

  // ============================
  // 🧹 CACHÉ
  // ============================
  static const _worldModeStationsCacheKey = 'world_mode_stations_cache_v1';

  Future<void> refreshCacheSummary() async {
    try {
      final bytes = await _estimateClearableCacheBytes();
      cacheSummary.value = _formatBytes(bytes);
    } catch (_) {
      cacheSummary.value = '—';
    }
  }

  Future<void> clearCache() async {
    try {
      final bytesBefore = await _estimateClearableCacheBytes();

      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        await tempDir.create(recursive: true);
      }

      final appDir = await getApplicationDocumentsDirectory();
      final karaokeDir = Directory(
        p.join(appDir.path, 'downloads', 'karaoke_remote'),
      );
      if (await karaokeDir.exists()) {
        await karaokeDir.delete(recursive: true);
      }

      await _storage.remove(_worldModeStationsCacheKey);

      storageTick.value++;
      await refreshCacheSummary();
      Get.snackbar(
        'Caché',
        bytesBefore > 0
            ? 'Se liberaron ${_formatBytes(bytesBefore)} de caché regenerable.'
            : 'No había caché temporal para limpiar.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('clearCache error: $e');
      Get.snackbar(
        'Caché',
        'No se pudo limpiar el caché',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ============================
  // 📊 Storage info
  // ============================
  Future<String> getStorageInfo() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(appDir.path, 'downloads'));
      final mediaDir = Directory(p.join(appDir.path, 'media'));

      final totalBytes =
          await _dirSize(downloadsDir) + await _dirSize(mediaDir);
      final mb = totalBytes / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB';
    } catch (e) {
      debugPrint('storage info error: $e');
      return '0 MB';
    }
  }

  Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final len = await entity.length();
        total += len;
      }
    }
    return total;
  }

  Future<int> _estimateClearableCacheBytes() async {
    var total = 0;

    final tempDir = await getTemporaryDirectory();
    total += await _dirSize(tempDir);

    final appDir = await getApplicationDocumentsDirectory();
    final karaokeDir = Directory(
      p.join(appDir.path, 'downloads', 'karaoke_remote'),
    );
    total += await _dirSize(karaokeDir);

    total += _storedValueSize(_worldModeStationsCacheKey);
    return total;
  }

  int _storedValueSize(String key) {
    final raw = _storage.read(key);
    if (raw == null) return 0;
    try {
      return utf8.encode(jsonEncode(raw)).length;
    } catch (_) {
      return 0;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final decimals = unitIndex == 0 ? 0 : 2;
    return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }

  // ============================
  // 🍪 YOUTUBE COOKIES
  // ============================
  void setYtDlpAdminToken(String token) {
    ytdlpAdminToken.value = token.trim();
    _storage.write('ytdlpAdminToken', ytdlpAdminToken.value);
  }

  Future<void> uploadYtDlpCookies() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
      );
      if (res == null || res.files.isEmpty) return;

      final path = res.files.first.path;
      if (path == null || path.trim().isEmpty) return;

      final cookieFile = File(path);
      if (!await cookieFile.exists()) {
        Get.snackbar(
          'Cookies',
          'Archivo no encontrado',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final dioClient = Get.find<DioClient>();
      final formData = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(path, filename: 'cookies.txt'),
      });

      final token = ytdlpAdminToken.value.trim();
      if (token.isEmpty) {
        Get.snackbar(
          'Cookies',
          'Introduce un token admin antes de subir.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      await dioClient.dio.post(
        '/api/v1/admin/ytdlp/cookies',
        data: formData,
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      Get.snackbar(
        'Cookies',
        'Cookies actualizadas correctamente.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('uploadYtDlpCookies error: $e');
      Get.snackbar(
        'Cookies',
        'No se pudieron subir las cookies.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ============================
  // 🔄 RESET
  // ============================
  Future<void> resetSettings() async {
    selectedPalette.value = 'green';
    brightness.value = Brightness.dark;
    await _storage.write('selectedPalette', 'green');
    await _storage.write('brightness', 'dark');
    ytdlpAdminToken.value = '';
    ytdlpAdminTokenController.clear();
    await _storage.remove('ytdlpAdminToken');
    _applyTheme();

    if (Get.isRegistered<PlaybackSettingsController>()) {
      await Get.find<PlaybackSettingsController>().resetPlaybackSettings();
    }
    if (Get.isRegistered<SleepTimerController>()) {
      await Get.find<SleepTimerController>().resetSleepSettings();
    }
    if (Get.isRegistered<EqualizerController>()) {
      await Get.find<EqualizerController>().resetEqualizerSettings();
    }

    storageTick.value++;
    bluetoothTick.value++;
  }

  @override
  void onClose() {
    ytdlpAdminTokenController.dispose();
    super.onClose();
  }
}

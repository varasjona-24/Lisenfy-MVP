import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:dio/dio.dart' as dio;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart';

import '../../../app/controllers/theme_controller.dart';
import '../../../app/data/network/dio_client.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/services/bluetooth_audio_service.dart';
import '../../edit/view/desktop_image_cropper_dialog.dart';
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
class SettingsController extends GetxController with WidgetsBindingObserver {
  final GetStorage _storage = GetStorage();
  static const _smartCarouselInterval = Duration(minutes: 90);
  static const _smartCarouselEnabledKey = 'smartBackgroundCarouselEnabled';
  static const _orderedCarouselEnabledKey = 'orderedBackgroundCarouselEnabled';
  static const _lastBackgroundRotationKey = 'lastBackgroundRotationAt';

  // 🎨 Paleta actual
  final Rx<String> selectedPalette = 'green'.obs;

  // 🌗 Modo de brillo
  final Rx<Brightness> brightness = Brightness.dark.obs;

  // 🖼️ Fondo personalizado
  final RxString appBackgroundImagePath = ''.obs;
  final RxList<String> appBackgroundImagePaths = <String>[].obs;
  final RxBool smartBackgroundCarouselEnabled = false.obs;
  final RxBool orderedBackgroundCarouselEnabled = false.obs;
  Timer? _backgroundCarouselTimer;
  bool _isRotatingBackground = false;

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
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _startBackgroundCarouselTimer();
    _rotateBackgroundIfDue();
    _configureAudioSession();
    refreshCacheSummary();
  }

  void _loadSettings() {
    selectedPalette.value = _storage.read('selectedPalette') ?? 'green';
    brightness.value = (_storage.read('brightness') ?? 'dark') == 'light'
        ? Brightness.light
        : Brightness.dark;
    final storedBackgroundPath =
        (_storage.read<String>('appBackgroundImagePath') ?? '').trim();
    final storedBackgroundPaths =
        (_storage.read<List>('appBackgroundImagePaths') ?? const [])
            .map((value) => value.toString().trim())
            .where((path) => path.isNotEmpty && File(path).existsSync())
            .toSet()
            .toList();
    if (storedBackgroundPaths.isEmpty &&
        storedBackgroundPath.isNotEmpty &&
        File(storedBackgroundPath).existsSync()) {
      storedBackgroundPaths.add(storedBackgroundPath);
    }
    appBackgroundImagePaths.assignAll(storedBackgroundPaths);
    appBackgroundImagePath.value =
        storedBackgroundPaths.contains(storedBackgroundPath)
        ? storedBackgroundPath
        : storedBackgroundPaths.firstOrNull ?? '';
    smartBackgroundCarouselEnabled.value =
        _storage.read<bool>(_smartCarouselEnabledKey) ?? false;
    orderedBackgroundCarouselEnabled.value =
        _storage.read<bool>(_orderedCarouselEnabledKey) ?? false;

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

  Future<void> setSmartBackgroundCarouselEnabled(bool enabled) async {
    smartBackgroundCarouselEnabled.value = enabled;
    await _storage.write(_smartCarouselEnabledKey, enabled);
    if (enabled) {
      await _storage.write(
        _lastBackgroundRotationKey,
        DateTime.now().toIso8601String(),
      );
    }
  }

  Future<void> setOrderedBackgroundCarouselEnabled(bool enabled) async {
    orderedBackgroundCarouselEnabled.value = enabled;
    await _storage.write(_orderedCarouselEnabledKey, enabled);
  }

  void _startBackgroundCarouselTimer() {
    _backgroundCarouselTimer?.cancel();
    _backgroundCarouselTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _rotateBackgroundIfDue(),
    );
  }

  Future<void> _rotateBackgroundIfDue({bool force = false}) async {
    if (_isRotatingBackground ||
        !smartBackgroundCarouselEnabled.value ||
        appBackgroundImagePaths.length < 2) {
      return;
    }

    _isRotatingBackground = true;
    final now = DateTime.now();
    try {
      final storedLastRotation = _storage.read<String>(
        _lastBackgroundRotationKey,
      );
      final lastRotation = DateTime.tryParse(storedLastRotation ?? '');
      if (!force &&
          lastRotation != null &&
          now.difference(lastRotation) < _smartCarouselInterval) {
        return;
      }

      final currentIndex = appBackgroundImagePaths.indexOf(
        appBackgroundImagePath.value,
      );
      final nextIndex = orderedBackgroundCarouselEnabled.value
          ? (currentIndex + 1) % appBackgroundImagePaths.length
          : _randomBackgroundIndex(currentIndex);
      await setActiveAppBackgroundImage(appBackgroundImagePaths[nextIndex]);
      await _storage.write(_lastBackgroundRotationKey, now.toIso8601String());
    } finally {
      _isRotatingBackground = false;
    }
  }

  int _randomBackgroundIndex(int currentIndex) {
    final candidateIndexes = List<int>.generate(
      appBackgroundImagePaths.length,
      (index) => index,
    )..remove(currentIndex);
    return candidateIndexes[Random().nextInt(candidateIndexes.length)];
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _rotateBackgroundIfDue();
    } else if (state == AppLifecycleState.detached) {
      _rotateBackgroundIfDue(force: true);
    }
  }

  Future<void> selectAppBackgroundImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final sourcePath = result.files.single.path?.trim() ?? '';
      if (sourcePath.isEmpty) return;

      await _setAppBackgroundFromSource(sourcePath);
    } catch (e) {
      debugPrint('selectAppBackgroundImage error: $e');
      _showBackgroundImageError();
    }
  }

  Future<void> selectAppBackgroundImageFromWeb(String imageUrl) async {
    final cleanedUrl = imageUrl.trim();
    if (cleanedUrl.isEmpty) return;

    String? downloadedPath;
    try {
      final repository = Get.find<MediaRepository>();
      downloadedPath = await repository.cacheThumbnailForItem(
        itemId: 'app-background-raw-${DateTime.now().millisecondsSinceEpoch}',
        thumbnailUrl: cleanedUrl,
      );
      if (downloadedPath == null || downloadedPath.trim().isEmpty) {
        _showBackgroundImageError();
        return;
      }

      await _setAppBackgroundFromSource(downloadedPath);
    } catch (e) {
      debugPrint('selectAppBackgroundImageFromWeb error: $e');
      _showBackgroundImageError();
    } finally {
      final clean = downloadedPath?.trim() ?? '';
      if (clean.isNotEmpty && clean != appBackgroundImagePath.value) {
        await _deleteBackgroundFile(clean);
      }
    }
  }

  Future<void> _setAppBackgroundFromSource(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      _showBackgroundImageError(message: 'No se encontró la imagen elegida.');
      return;
    }

    final croppedPath = await _cropAppBackgroundImage(sourcePath);
    if (croppedPath == null || croppedPath.trim().isEmpty) return;

    final croppedSource = File(croppedPath);
    if (!await croppedSource.exists()) return;

    final appDir = await getApplicationDocumentsDirectory();
    final backgroundsDir = Directory(p.join(appDir.path, 'appearance'));
    await backgroundsDir.create(recursive: true);

    final extension = p.extension(croppedPath).toLowerCase() == '.png'
        ? '.png'
        : '.jpg';
    final destination = File(
      p.join(
        backgroundsDir.path,
        'app_background_${DateTime.now().millisecondsSinceEpoch}$extension',
      ),
    );
    await croppedSource.copy(destination.path);

    appBackgroundImagePaths.add(destination.path);
    appBackgroundImagePath.value = destination.path;
    await _persistAppBackgroundImages();
    await _deleteTemporaryCrop(croppedPath, sourcePath);
  }

  void _showBackgroundImageError({
    String message = 'settings_messages.wallpaper.error_default',
  }) {
    Get.snackbar(
      tr('settings_messages.wallpaper.title'),
      tr(message),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> setActiveAppBackgroundImage(String imagePath) async {
    final clean = imagePath.trim();
    if (!appBackgroundImagePaths.contains(clean) ||
        !await File(clean).exists()) {
      return;
    }
    appBackgroundImagePath.value = clean;
    await _storage.write('appBackgroundImagePath', clean);
  }

  Future<void> removeAppBackgroundImage([String? imagePath]) async {
    final clean = (imagePath ?? appBackgroundImagePath.value).trim();
    if (clean.isEmpty) return;

    final removedIndex = appBackgroundImagePaths.indexOf(clean);
    appBackgroundImagePaths.remove(clean);
    await _deleteBackgroundFile(clean);

    if (appBackgroundImagePath.value == clean) {
      if (appBackgroundImagePaths.isEmpty) {
        appBackgroundImagePath.value = '';
      } else {
        final nextIndex = removedIndex
            .clamp(0, appBackgroundImagePaths.length - 1)
            .toInt();
        appBackgroundImagePath.value = appBackgroundImagePaths[nextIndex];
      }
    }
    await _persistAppBackgroundImages();
  }

  Future<void> removeAllAppBackgroundImages() async {
    final paths = List<String>.from(appBackgroundImagePaths);
    appBackgroundImagePaths.clear();
    appBackgroundImagePath.value = '';
    await _persistAppBackgroundImages();
    for (final path in paths) {
      await _deleteBackgroundFile(path);
    }
  }

  Future<void> restoreAppBackgroundImages(
    List<String> restoredPaths, {
    String? activePath,
  }) async {
    final validPaths = <String>[];
    for (final rawPath in restoredPaths) {
      final clean = rawPath.trim();
      if (clean.isNotEmpty && await File(clean).exists()) {
        validPaths.add(clean);
      }
    }

    final previousPaths = List<String>.from(appBackgroundImagePaths);
    appBackgroundImagePaths.assignAll(validPaths.toSet());
    final cleanActive = activePath?.trim() ?? '';
    appBackgroundImagePath.value = appBackgroundImagePaths.contains(cleanActive)
        ? cleanActive
        : appBackgroundImagePaths.firstOrNull ?? '';
    await _persistAppBackgroundImages();

    for (final path in previousPaths) {
      if (!appBackgroundImagePaths.contains(path)) {
        await _deleteBackgroundFile(path);
      }
    }
  }

  Future<void> restoreAppBackgroundImage(String restoredPath) {
    return restoreAppBackgroundImages([restoredPath], activePath: restoredPath);
  }

  Future<void> _persistAppBackgroundImages() async {
    await _storage.write(
      'appBackgroundImagePaths',
      appBackgroundImagePaths.toList(),
    );
    if (appBackgroundImagePath.value.isEmpty) {
      await _storage.remove('appBackgroundImagePath');
    } else {
      await _storage.write(
        'appBackgroundImagePath',
        appBackgroundImagePath.value,
      );
    }
  }

  Future<String?> _cropAppBackgroundImage(String sourcePath) async {
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return Get.dialog<String>(
        DesktopImageCropperDialog(
          sourcePath: sourcePath,
          ratioX: 9,
          ratioY: 16,
          title: tr('settings.appearance.adjust_wallpaper'),
        ),
        barrierDismissible: false,
      );
    }

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 9, ratioY: 16),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: tr('settings.appearance.adjust_background'),
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: tr('settings.appearance.adjust_background'),
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      return cropped?.path;
    } catch (e) {
      debugPrint('_cropAppBackgroundImage error: $e');
      return sourcePath;
    }
  }

  Future<void> _deleteTemporaryCrop(
    String croppedPath,
    String sourcePath,
  ) async {
    if (croppedPath == sourcePath) return;
    final tempDir = await getTemporaryDirectory();
    if (p.isWithin(tempDir.path, croppedPath)) {
      await _deleteBackgroundFile(croppedPath);
    }
  }

  Future<void> _deleteBackgroundFile(String filePath) async {
    if (filePath.trim().isEmpty) return;
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
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
        tr('settings_messages.cache.title'),
        bytesBefore > 0
            ? tr(
                'settings_messages.cache.cleared',
              ).replaceFirst('{}', _formatBytes(bytesBefore))
            : tr('settings_messages.cache.empty'),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('clearCache error: $e');
      Get.snackbar(
        tr('settings_messages.cache.title'),
        tr('settings_messages.cache.error'),
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
          tr('settings_messages.cookies.title'),
          tr('settings_messages.cookies.file_not_found'),
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
          tr('settings_messages.cookies.title'),
          tr('settings_messages.cookies.token_required'),
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
        tr('settings_messages.cookies.title'),
        tr('settings_messages.cookies.success'),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('uploadYtDlpCookies error: $e');
      Get.snackbar(
        tr('settings_messages.cookies.title'),
        tr('settings_messages.cookies.error'),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ============================
  // 🔄 RESET
  // ============================
  Future<void> resetSettings() async {
    await removeAllAppBackgroundImages();
    smartBackgroundCarouselEnabled.value = false;
    orderedBackgroundCarouselEnabled.value = false;
    await _storage.remove(_smartCarouselEnabledKey);
    await _storage.remove(_orderedCarouselEnabledKey);
    await _storage.remove(_lastBackgroundRotationKey);
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
    WidgetsBinding.instance.removeObserver(this);
    _backgroundCarouselTimer?.cancel();
    ytdlpAdminTokenController.dispose();
    super.onClose();
  }
}

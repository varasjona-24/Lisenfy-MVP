import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/services/notification_service.dart';

class NotificationSettingsController extends GetxController {
  final GetStorage _storage = GetStorage();
  final NotificationService _notifications = Get.find<NotificationService>();

  final RxBool notificationsEnabled = false.obs;
  final RxBool importsEnabled = true.obs;
  final RxBool connectEnabled = true.obs;
  final RxBool timersEnabled = true.obs;
  final RxBool weeklyEnabled = false.obs;
  final RxBool recommendationsEnabled = false.obs;

  @override
  void onInit() {
    super.onInit();
    notificationsEnabled.value =
        _storage.read<bool>(NotificationService.masterEnabledKey) ?? false;
    importsEnabled.value =
        _storage.read<bool>(NotificationService.importsEnabledKey) ?? true;
    connectEnabled.value =
        _storage.read<bool>(NotificationService.connectEnabledKey) ?? true;
    timersEnabled.value =
        _storage.read<bool>(NotificationService.timersEnabledKey) ?? true;
    weeklyEnabled.value =
        _storage.read<bool>(NotificationService.weeklyEnabledKey) ?? false;
    recommendationsEnabled.value =
        _storage.read<bool>(NotificationService.recommendationsEnabledKey) ??
        false;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _notifications.requestPermission();
      if (!granted) {
        notificationsEnabled.value = false;
        Get.snackbar(
          'Notificaciones desactivadas',
          'Puedes habilitarlas más tarde desde los ajustes del sistema.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
        );
        return;
      }
    }

    notificationsEnabled.value = enabled;
    await _storage.write(NotificationService.masterEnabledKey, enabled);
    await _notifications.syncScheduledNotifications();
  }

  Future<void> setImportsEnabled(bool enabled) {
    importsEnabled.value = enabled;
    return _storage.write(NotificationService.importsEnabledKey, enabled);
  }

  Future<void> setConnectEnabled(bool enabled) {
    connectEnabled.value = enabled;
    return _storage.write(NotificationService.connectEnabledKey, enabled);
  }

  Future<void> setTimersEnabled(bool enabled) {
    timersEnabled.value = enabled;
    return _storage.write(NotificationService.timersEnabledKey, enabled);
  }

  Future<void> setWeeklyEnabled(bool enabled) async {
    weeklyEnabled.value = enabled;
    await _storage.write(NotificationService.weeklyEnabledKey, enabled);
    await _notifications.syncScheduledNotifications();
  }

  Future<void> setRecommendationsEnabled(bool enabled) async {
    recommendationsEnabled.value = enabled;
    await _storage.write(
      NotificationService.recommendationsEnabledKey,
      enabled,
    );
    await _notifications.syncScheduledNotifications();
  }
}

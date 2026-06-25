import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/notification_settings_controller.dart';

class NotificationsSection extends StatelessWidget {
  const NotificationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<NotificationSettingsController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                tr('settings.notifications.title'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: .12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(() {
              final enabled = controller.notificationsEnabled.value;
              return Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tr('settings.notifications.master_title'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      tr('settings.notifications.master_subtitle'),
                    ),
                    value: enabled,
                    onChanged: controller.setNotificationsEnabled,
                  ),
                  Divider(color: theme.dividerColor.withValues(alpha: .12)),
                  _NotificationToggle(
                    icon: Icons.download_done_rounded,
                    title: tr('settings.notifications.imports_title'),
                    subtitle: tr('settings.notifications.imports_subtitle'),
                    value: controller.importsEnabled.value,
                    enabled: enabled,
                    onChanged: controller.setImportsEnabled,
                  ),
                  _NotificationToggle(
                    icon: Icons.devices_rounded,
                    title: tr('settings.notifications.connect_title'),
                    subtitle: tr('settings.notifications.connect_subtitle'),
                    value: controller.connectEnabled.value,
                    enabled: enabled,
                    onChanged: controller.setConnectEnabled,
                  ),
                  _NotificationToggle(
                    icon: Icons.bedtime_rounded,
                    title: tr('settings.notifications.timers_title'),
                    subtitle: tr('settings.notifications.timers_subtitle'),
                    value: controller.timersEnabled.value,
                    enabled: enabled,
                    onChanged: controller.setTimersEnabled,
                  ),
                  _NotificationToggle(
                    icon: Icons.insights_rounded,
                    title: tr('settings.notifications.weekly_title'),
                    subtitle: tr('settings.notifications.weekly_subtitle'),
                    value: controller.weeklyEnabled.value,
                    enabled: enabled,
                    onChanged: controller.setWeeklyEnabled,
                  ),
                  _NotificationToggle(
                    icon: Icons.auto_awesome_rounded,
                    title: tr('settings.notifications.recommendations_title'),
                    subtitle: tr(
                      'settings.notifications.recommendations_subtitle',
                    ),
                    value: controller.recommendationsEnabled.value,
                    enabled: enabled,
                    onChanged: controller.setRecommendationsEnabled,
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  const _NotificationToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

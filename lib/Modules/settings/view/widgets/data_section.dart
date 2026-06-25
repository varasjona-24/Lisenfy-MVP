import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_settings/app_settings.dart';

import '../../controller/settings_controller.dart';
import '../../controller/playback_settings_controller.dart';
import '../../controller/backup_restore_controller.dart';
import '../widgets/section_header.dart';
import '../widgets/choice_chip_row.dart';
import '../widgets/info_tile.dart';

class DataSection extends StatelessWidget {
  const DataSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playback = Get.find<PlaybackSettingsController>();
    final backup = Get.find<BackupRestoreController>();
    final settings = Get.find<SettingsController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.cloud_download_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                tr('settings.data.title'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: .12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Data usage
                Obx(() {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: tr('settings.data.usage'),
                        subtitle: tr('settings.data.usage_subtitle'),
                      ),
                      const SizedBox(height: 8),
                      ChoiceChipRow(
                        options: [
                          ChoiceOption(
                            value: 'wifi_only',
                            label: tr('settings.data.wifi_only'),
                          ),
                          ChoiceOption(
                            value: 'all',
                            label: tr('settings.data.wifi_mobile'),
                          ),
                        ],
                        selectedValue: playback.dataUsage.value,
                        onSelected: (v) => playback.setDataUsage(v),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 12),
                Divider(color: theme.dividerColor.withValues(alpha: .12)),
                const SizedBox(height: 12),

                // Actions
                SizedBox(
                  width: double.infinity,
                  child: Obx(
                    () => ElevatedButton.icon(
                      onPressed: settings.clearCache,
                      icon: const Icon(Icons.delete_sweep_rounded),
                      label: Text(
                        settings.cacheSummary.value == 'Calculando...'
                            ? tr('settings.data.clear_cache')
                            : tr(
                                'settings.data.clear_cache_with_size',
                                args: [settings.cacheSummary.value],
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                if (Platform.isAndroid) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: .25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr('settings.data.battery_note'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoTile(
                    icon: Icons.battery_saver_rounded,
                    title: tr('settings.data.battery_saver'),
                    subtitle: tr('settings.data.battery_saver_subtitle'),
                    trailing: TextButton(
                      onPressed: () => AppSettings.openAppSettings(
                        type: AppSettingsType.batteryOptimization,
                      ),
                      child: Text(tr('common.open')),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: .25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('settings.data.backup_title'),
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('settings.data.backup_body'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Obx(() {
                  final isExporting = backup.isExporting.value;
                  final isImporting = backup.isImporting.value;
                  final isLoading = isExporting || isImporting;

                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLoading
                              ? null
                              : backup.confirmExportLibrary,
                          icon: isExporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.archive_rounded),
                          label: Text(
                            isExporting
                                ? tr('settings.data.exporting')
                                : tr('settings.data.export_zip'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLoading
                              ? null
                              : backup.confirmImportLibrary,
                          icon: isImporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.restore_rounded),
                          label: Text(
                            isImporting
                                ? tr('settings.data.importing')
                                : tr('settings.data.restore_zip'),
                          ),
                        ),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

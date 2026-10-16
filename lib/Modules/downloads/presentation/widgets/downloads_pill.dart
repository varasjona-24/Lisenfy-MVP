import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/utils/listenfy_deep_link.dart';
import '../../controller/downloads_controller.dart';
import '../../../../app/ui/themes/app_spacing.dart';
import '../../../../app/models/media_item.dart';
import '../../../nearby_transfer/view/nearby_qr_scanner_page.dart';

/// Widget tipo "pill" con opciones de descargas
class DownloadsPill extends GetView<DownloadsController> {
  const DownloadsPill({super.key});

  // ============================
  // 🎨 UI
  // ============================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📥 Header
            Row(
              children: [
                Icon(Icons.cloud_download_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  tr('downloads.title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              tr('downloads.pill_subtitle'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children:
                    [
                      _importActionTile(
                        context: context,
                        icon: Icons.folder_open_rounded,
                        title: tr('downloads.local_import_title'),
                        subtitle: tr('downloads.local_import_subtitle'),
                        onTap: () => _pickLocalFiles(context),
                      ),
                      const SizedBox(height: 6),
                      _importActionTile(
                        context: context,
                        icon: Icons.qr_code_scanner_rounded,
                        title: tr('downloads.scan_qr_title'),
                        subtitle: tr('downloads.scan_qr_subtitle'),
                        onTap: () => _scanListenfyQr(),
                      ),
                    ].map((child) {
                      if (child is SizedBox) return child;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: child,
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _importActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = highlighted ? scheme.primaryContainer : scheme.surface;

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: scheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  // ============================
  // 📁 IMPORTS LOCAL
  // ============================
  /// 📁 Descargar desde dispositivo local
  Future<void> _pickLocalFiles(BuildContext context) async {
    if (context.mounted) {
      showLocalImportDialog(context, controller);
    }
  }

  Future<void> _scanListenfyQr() async {
    final raw = await Get.to<String>(() => const NearbyQrScannerPage());
    if (raw == null || raw.trim().isEmpty) return;

    final target = ListenfyDeepLink.parseRaw(raw);
    switch (target) {
      case ListenfyDeepLinkTarget.nearbyInvite:
        Get.toNamed(AppRoutes.nearbyTransfer, arguments: {'inviteUri': raw});
        return;
      case ListenfyDeepLinkTarget.nearbyTransfer:
        Get.toNamed(AppRoutes.nearbyTransfer);
        return;
      case ListenfyDeepLinkTarget.openLocalImport:
        Get.snackbar(
          tr('qr.listenfy_title'),
          tr('qr.import_ready'),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      case ListenfyDeepLinkTarget.unknown:
        Get.snackbar(
          tr('qr.invalid_title'),
          tr('qr.invalid_body'),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
    }
  }

  /// 📋 Dialog para importar archivos locales
  static Future<void> showLocalImportDialog(
    BuildContext context,
    DownloadsController controller,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;
        final screenMaxHeight = MediaQuery.of(ctx).size.height * 0.72;

        return Obx(() {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              width: 520,
              height: screenMaxHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.folder_open_rounded,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Archivos del dispositivo',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: tr('common.close'),
                          onPressed: () {
                            controller.clearLocalFilesForImport();
                            Navigator.of(ctx).pop();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('downloads.select_files_hint'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await controller.pickLocalFilesForImport();
                        },
                        icon: const Icon(Icons.folder_open_rounded),
                        label: Text(tr('downloads.select_files')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tr(
                          'downloads.selected_count',
                          args: ['${controller.localFilesForImport.length}'],
                        ),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Obx(() {
                        final list = controller.localFilesForImport;
                        if (list.isEmpty) {
                          return Center(
                            child: Text(
                              tr('imports.no_files_selected'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, index) =>
                              Divider(color: scheme.outlineVariant, height: 1),
                          itemBuilder: (ctx2, i) {
                            final item = list[i];
                            final v = item.variants.first;
                            final isVideo = v.kind == MediaVariantKind.video;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 4,
                              ),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.music_note_rounded,
                                  color: scheme.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                v.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: Obx(
                                () => controller.importing.value
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.download_done_rounded,
                                        ),
                                        tooltip: tr('common.import'),
                                        onPressed: () => _importItem(
                                          context: context,
                                          controller: controller,
                                          item: item,
                                        ),
                                      ),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Obx(
                        () => FilledButton.icon(
                          onPressed: controller.importing.value
                              ? null
                              : () => _importAllItems(
                                  context: context,
                                  controller: controller,
                                ),
                          icon: controller.importing.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.playlist_add_check_rounded),
                          label: Text(
                            controller.importing.value
                                ? tr('downloads.importing')
                                : tr('downloads.import_all'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                controller.clearLocalFilesForImport();
                                Navigator.of(ctx).pop();
                              },
                              child: Text(tr('common.cancel')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                controller.clearLocalFilesForImport();
                              },
                              icon: const Icon(Icons.cleaning_services_rounded),
                              label: Text(tr('common.clear')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  /// 📥 Importar un archivo específico
  static Future<void> _importItem({
    required BuildContext context,
    required DownloadsController controller,
    required MediaItem item,
  }) async {
    final result = await controller.importLocalFileToApp(item);
    if (result != null && context.mounted) {
      Get.snackbar(
        tr('imports.imported_title'),
        tr('imports.imported_body').replaceFirst('{}', item.title),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  static Future<void> _importAllItems({
    required BuildContext context,
    required DownloadsController controller,
  }) async {
    final items = controller.localFilesForImport.toList();
    if (items.isEmpty) {
      Get.snackbar(
        'Imports',
        tr('imports.no_files_selected'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    int success = 0;
    for (final item in items) {
      final result = await controller.importLocalFileToApp(item);
      if (result != null) success++;
    }

    if (!context.mounted) return;

    final failed = items.length - success;
    if (success > 0) {
      controller.clearLocalFilesForImport();
      Navigator.of(context).pop();
    }

    Get.snackbar(
      'Imports',
      failed == 0
          ? tr(
              'imports.import_success_single',
            ).replaceFirst('{}', success.toString())
          : tr(
              'imports.import_success_multiple',
            ).replaceFirst('{}', '$success').replaceFirst('{}', '$failed'),
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

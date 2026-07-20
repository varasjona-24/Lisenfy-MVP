import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/utils/listenfy_deep_link.dart';
import '../../../../app/data/repo/media_repository.dart';
import '../../controller/downloads_controller.dart';
import '../../../../app/ui/themes/app_spacing.dart';
import '../../../../app/models/media_item.dart';
import '../../../nearby_transfer/view/nearby_qr_scanner_page.dart';
import '../views/imports_webview_page.dart';

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

    return Card(
      elevation: 0,
      color: scheme.surfaceContainer,
      margin: EdgeInsets.zero,
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
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _importActionTile(
                    context: context,
                    icon: Icons.link_rounded,
                    title: tr('downloads.url_import_title'),
                    subtitle: tr('downloads.url_import_subtitle'),
                    onTap: () =>
                        DownloadsPill.showImportUrlDialog(context, controller),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _importActionTile(
                    context: context,
                    icon: Icons.folder_open_rounded,
                    title: tr('downloads.local_import_title'),
                    subtitle: tr('downloads.local_import_subtitle'),
                    onTap: () => _pickLocalFiles(context),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _importActionTile(
                    context: context,
                    icon: Icons.qr_code_scanner_rounded,
                    title: tr('downloads.scan_qr_title'),
                    subtitle: tr('downloads.scan_qr_subtitle'),
                    onTap: () => _scanListenfyQr(),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _importActionTile(
                    context: context,
                    icon: Icons.public_rounded,
                    title: tr('downloads.web_search_title'),
                    subtitle: tr('downloads.web_search_subtitle'),
                    onTap: () async {
                      final size = MediaQuery.of(context).size;
                      final scheme = Theme.of(context).colorScheme;
                      await showDialog<void>(
                        context: context,
                        barrierDismissible: true,
                        builder: (ctx) {
                          return Dialog(
                            insetPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            backgroundColor: scheme.surface,
                            child: SizedBox(
                              width: size.width * 0.9,
                              height: size.height * 0.54,
                              child: const ImportsWebViewPage(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
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
    final bg = highlighted
        ? scheme.primary.withValues(alpha: 0.1)
        : Colors.transparent;

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
  // 🌐 IMPORTS URL (DIALOG)
  // ============================
  /// 🌐 Dialog mejorado de descargas online
  static Future<void> showImportUrlDialog(
    BuildContext context,
    DownloadsController controller, {
    String? initialUrl,
    bool clearSharedOnClose = false,
  }) async {
    try {
      final result = await showDialog<_ImportUrlResult>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return _ImportUrlDialog(initialUrl: initialUrl);
        },
      );

      if (result != null) {
        List<String>? selectedPlaylistUrls;
        if (_isLikelyYoutubePlaylistUrl(result.url)) {
          Get.snackbar(
            tr('imports.playlist_selection_title'),
            tr('imports.playlist_loading'),
            snackPosition: SnackPosition.BOTTOM,
          );
          final preview = await controller.resolvePlaylistPreview(result.url);
          if (preview == null || preview.entries.isEmpty) {
            Get.snackbar(
              tr('imports.playlist_selection_title'),
              tr('imports.playlist_failed'),
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.orange,
            );
            return;
          }
          if (!context.mounted) return;
          selectedPlaylistUrls = await showDialog<List<String>>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _PlaylistSelectionDialog(preview: preview),
          );
          if (selectedPlaylistUrls == null || selectedPlaylistUrls.isEmpty) {
            return;
          }
        }

        await controller.downloadFromUrl(
          url: result.url,
          kind: result.kind,
          selectedPlaylistUrls: selectedPlaylistUrls,
        );
      }
    } finally {
      if (clearSharedOnClose) {
        controller.sharedUrl.value = '';
      }
    }
  }

  static bool _isLikelyYoutubePlaylistUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (!host.contains('youtube.com') && host != 'youtu.be') return false;
    final list = uri.queryParameters['list']?.trim() ?? '';
    return list.length > 8;
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

class _ImportUrlResult {
  final String url;
  final String kind;

  const _ImportUrlResult({required this.url, required this.kind});
}

class _PlaylistSelectionDialog extends StatefulWidget {
  const _PlaylistSelectionDialog({required this.preview});

  final PlaylistPreview preview;

  @override
  State<_PlaylistSelectionDialog> createState() =>
      _PlaylistSelectionDialogState();
}

class _PlaylistSelectionDialogState extends State<_PlaylistSelectionDialog> {
  late final Set<String> _selectedUrls;

  @override
  void initState() {
    super.initState();
    _selectedUrls = widget.preview.entries
        .where((entry) => entry.isAvailable)
        .map((entry) => entry.url)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = widget.preview.entries;
    final unavailableCount = entries
        .where((entry) => !entry.isAvailable)
        .length;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.playlist_add_check_rounded,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('imports.playlist_selection_title'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.preview.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('common.close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  'imports.playlist_selection_subtitle',
                  args: [entries.length.toString()],
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (unavailableCount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: scheme.error.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    tr(
                      'imports.playlist_unavailable_notice',
                      args: [unavailableCount.toString()],
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    avatar: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      tr(
                        'imports.playlist_selected_count',
                        args: [_selectedUrls.length.toString()],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _selectAll,
                    icon: const Icon(Icons.done_all_rounded),
                    label: Text(tr('imports.playlist_select_all')),
                  ),
                  TextButton.icon(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.remove_done_rounded),
                    label: Text(tr('imports.playlist_clear_selection')),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: scheme.outlineVariant),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final selected = _selectedUrls.contains(entry.url);
                        final artist = entry.artist?.trim() ?? '';
                        final duration = _formatDuration(entry.durationMs);
                        final enabled = entry.isAvailable;
                        final reason = _availabilityLabel(entry);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: enabled ? (_) => _toggle(entry.url) : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          secondary: _PlaylistEntryCover(entry: entry),
                          title: Text(
                            entry.title.isNotEmpty
                                ? entry.title
                                : tr('imports.playlist_unknown_track'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: enabled
                                ? null
                                : TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          subtitle: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (artist.isNotEmpty || duration.isNotEmpty)
                                Text(
                                  [
                                    if (artist.isNotEmpty) artist,
                                    if (duration.isNotEmpty) duration,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              if (!enabled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.errorContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    reason,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onErrorContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(tr('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _selectedUrls.isEmpty ? null : _submit,
                      icon: const Icon(Icons.download_rounded),
                      label: Text(tr('imports.playlist_import_selected')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(String url) {
    setState(() {
      if (_selectedUrls.contains(url)) {
        _selectedUrls.remove(url);
      } else {
        _selectedUrls.add(url);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedUrls
        ..clear()
        ..addAll(
          widget.preview.entries
              .where((entry) => entry.isAvailable)
              .map((entry) => entry.url),
        );
    });
  }

  void _clearSelection() {
    setState(_selectedUrls.clear);
  }

  void _submit() {
    if (_selectedUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('imports.playlist_no_selection'))),
      );
      return;
    }
    Navigator.of(context).pop(_selectedUrls.toList(growable: false));
  }

  String _formatDuration(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return '';
    final totalSeconds = durationMs ~/ 1000;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _availabilityLabel(PlaylistPreviewEntry entry) {
    final reason = entry.availabilityReason?.trim().toLowerCase() ?? '';
    if (reason.contains('private')) return tr('imports.playlist_private_item');
    if (reason.contains('deleted')) return tr('imports.playlist_deleted_item');
    return tr('imports.playlist_unavailable_item');
  }
}

class _PlaylistEntryCover extends StatelessWidget {
  const _PlaylistEntryCover({required this.entry});

  final PlaylistPreviewEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumbnail = entry.thumbnail?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        color: scheme.surfaceContainerHighest,
        child: thumbnail.isEmpty
            ? Icon(Icons.music_note_rounded, color: scheme.onSurfaceVariant)
            : Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.music_note_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _ImportUrlDialog extends StatefulWidget {
  final String? initialUrl;

  const _ImportUrlDialog({this.initialUrl});

  @override
  State<_ImportUrlDialog> createState() => _ImportUrlDialogState();
}

class _ImportUrlDialogState extends State<_ImportUrlDialog> {
  late final TextEditingController _urlCtrl;
  String _kind = 'audio';

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.initialUrl?.trim() ?? '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                    child: Icon(Icons.link_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('downloads.url_import_title'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('common.close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr('downloads.url_import_dialog_subtitle'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(context),
                decoration: InputDecoration(
                  labelText: tr('downloads.url'),
                  hintText: 'https://www.youtube.com/watch?v=...',
                  prefixIcon: const Icon(Icons.link_rounded),
                  suffixIcon: IconButton(
                    tooltip: tr('common.paste'),
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      final text = data?.text?.trim() ?? '';
                      if (text.isEmpty) return;
                      _urlCtrl.text = text;
                      _urlCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: _urlCtrl.text.length),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr('downloads.import_type'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(tr('settings.audio.title')),
                      selected: _kind == 'audio',
                      onSelected: (_) => setState(() => _kind = 'audio'),
                      avatar: const Icon(Icons.music_note_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(tr('settings.video.title')),
                      selected: _kind == 'video',
                      onSelected: (_) => setState(() => _kind = 'video'),
                      avatar: const Icon(Icons.videocam_rounded, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(tr('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _submit(context),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(tr('common.import')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('downloads.url_required'))));
      return;
    }
    Navigator.of(context).pop(_ImportUrlResult(url: url, kind: _kind));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/utils/listenfy_deep_link.dart';
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
                  'Imports',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Importa desde enlace, archivos locales o navegador web.',
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
                    title: 'Importar desde URL',
                    subtitle: 'Comparte o pega un link e importarlo',
                    onTap: () =>
                        DownloadsPill.showImportUrlDialog(context, controller),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _importActionTile(
                    context: context,
                    icon: Icons.folder_open_rounded,
                    title: 'Importar desde archivo local',
                    subtitle: 'Selecciona archivos de tu almacenamiento',
                    onTap: () => _pickLocalFiles(context),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _importActionTile(
                    context: context,
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Escanear QR Listenfy',
                    subtitle: 'Recibir canción desde otro Listenfy',
                    onTap: () => _scanListenfyQr(),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _importActionTile(
                    context: context,
                    icon: Icons.public_rounded,
                    title: 'Buscador web',
                    subtitle: 'Pega un enlace para abrir el navegador ',
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
        await controller.downloadFromUrl(url: result.url, kind: result.kind);
      }
    } finally {
      if (clearSharedOnClose) {
        controller.sharedUrl.value = '';
      }
    }
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
          'QR Listenfy',
          'Listo. Ya estás en la sección de importación.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      case ListenfyDeepLinkTarget.unknown:
        Get.snackbar(
          'QR no válido',
          'Ese código no corresponde a una acción de Listenfy.',
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
                          tooltip: 'Cerrar',
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
                      'Selecciona qué archivos quieres importar a la biblioteca.',
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
                        label: const Text('Seleccionar archivos'),
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
                        '${controller.localFilesForImport.length} seleccionados',
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
                              'No hay archivos seleccionados.',
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
                                        tooltip: 'Importar',
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
                                ? 'Importando...'
                                : 'Importar todos',
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
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                controller.clearLocalFilesForImport();
                              },
                              icon: const Icon(Icons.cleaning_services_rounded),
                              label: const Text('Limpiar'),
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
        '✅ Importado',
        '${item.title} agregado a tu biblioteca',
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
        'No hay archivos seleccionados para importar.',
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
          ? 'Se importaron $success archivo(s).'
          : 'Importados: $success · Fallidos: $failed',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

class _ImportUrlResult {
  final String url;
  final String kind;

  const _ImportUrlResult({required this.url, required this.kind});
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
                      'Importar desde URL',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Pega el enlace y elige el tipo de archivo a importar.',
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
                  labelText: 'URL',
                  hintText: 'https://www.youtube.com/watch?v=...',
                  prefixIcon: const Icon(Icons.link_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Pegar',
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
                'Tipo de importación',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Audio'),
                      selected: _kind == 'audio',
                      onSelected: (_) => setState(() => _kind = 'audio'),
                      avatar: const Icon(Icons.music_note_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Video'),
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
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _submit(context),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Importar'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa una URL')),
      );
      return;
    }
    Navigator.of(context).pop(_ImportUrlResult(url: url, kind: _kind));
  }
}

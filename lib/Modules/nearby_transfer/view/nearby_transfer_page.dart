import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/utils/listenfy_deep_link.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../controller/nearby_transfer_controller.dart';
import 'nearby_qr_scanner_page.dart';

class NearbyTransferPage extends GetView<NearbyTransferController> {
  const NearbyTransferPage({super.key});

  Future<void> _showSendInviteQr() async {
    final item = controller.selectedItem.value;
    if (item == null) {
      Get.snackbar(
        'Transferencia',
        'Abre esta pantalla desde una canción para generar QR de envío.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final inviteUri = await controller.prepareInviteUriForSelectedItem();
    if (inviteUri == null) {
      Get.snackbar(
        'Transferencia',
        'No se pudo preparar el envío para esta canción.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final payload = inviteUri.toString();

    await Get.dialog<void>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'QR de envío Listenfy',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Canción: ${item.title}\n'
                  'Dispositivo emisor: ${controller.nickName}\n\n'
                  'Escanea este QR desde Listenfy en el otro teléfono para iniciar descarga con metadata.',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: payload));
                          Get.snackbar(
                            'QR',
                            'Código copiado al portapapeles.',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        },
                        child: const Text('Copiar enlace'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Get.back<void>(),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _scanAndHandleQr() async {
    final raw = await Get.to<String>(() => const NearbyQrScannerPage());
    if (raw == null || raw.trim().isEmpty) return;

    final target = ListenfyDeepLink.parseRaw(raw);
    switch (target) {
      case ListenfyDeepLinkTarget.nearbyInvite:
        final invite = ListenfyDeepLink.parseNearbyInviteRaw(raw);
        if (invite == null) {
          Get.snackbar(
            'QR no válido',
            'No se pudo leer la invitación de transferencia.',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
        await controller.startReceiveFromInvite(invite);
        Get.snackbar(
          'Transferencia',
          'Conectando con ${invite.senderName} para recibir "${invite.title}".',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      case ListenfyDeepLinkTarget.openLocalImport:
        Get.toNamed(AppRoutes.downloads, arguments: {'openLocalImport': true});
        return;
      case ListenfyDeepLinkTarget.nearbyTransfer:
        if (Get.currentRoute != AppRoutes.nearbyTransfer) {
          Get.toNamed(AppRoutes.nearbyTransfer);
        }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Transferencia offline'),
        actions: [
          IconButton(
            tooltip: 'Escanear QR',
            onPressed: () {
              _scanAndHandleQr();
            },
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
      body: AppGradientBackground(
        child: SafeArea(
          top: false,
          child: Obx(() {
            final item = controller.selectedItem.value;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.wifi_tethering_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Centro de transferencia',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        controller.statusText.value,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusBadge(
                            icon: Icons.link_rounded,
                            label: controller.connectedPeers.isNotEmpty
                                ? '${controller.connectedPeers.length} conectado(s)'
                                : 'Sin conexión',
                            active: controller.connectedPeers.isNotEmpty,
                          ),
                        ],
                      ),
                      if (item != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.34),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.16,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Canción lista para enviar',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(item.title, style: theme.textTheme.bodyLarge),
                              if (item.subtitle.trim().isNotEmpty)
                                Text(
                                  item.subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acciones',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.qr_code_rounded,
                              title: 'Mostrar QR',
                              subtitle: 'Invitar dispositivo',
                              onTap: () {
                                _showSendInviteQr();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.qr_code_scanner_rounded,
                              title: 'Escanear QR',
                              subtitle: 'Unirse y recibir',
                              onTap: () {
                                _scanAndHandleQr();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (controller.transferProgress.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transferencias',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...controller.transferProgress.entries.map((entry) {
                          final progress = entry.value.clamp(0, 1).toDouble();
                          final pct = (progress * 100).toStringAsFixed(0);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Payload ${entry.key}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$pct%',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 7,
                                    value: progress,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? scheme.primary.withValues(alpha: 0.2)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.outline.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: active ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

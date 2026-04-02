import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../controller/local_connect_controller.dart';
import '../../domain/entities/local_connect_models.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';

class LocalConnectPage extends GetView<LocalConnectController> {
  const LocalConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listenfy Connect')),
      body: AppGradientBackground(
        child: Obx(() {
          final running = controller.isRunning.value;
          final url = controller.serverUrl.value.trim();
          final error = controller.serverError.value.trim();
          final pending = controller.pendingRequests.toList();
          final clients = controller.sessions.toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 940;

              if (isWide) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _MainColumn(
                          running: running,
                          url: url,
                          error: error,
                          pending: pending,
                          onStart: controller.startServer,
                          onStop: controller.stopServer,
                          onApprove: controller.approvePairing,
                          onReject: controller.rejectPairing,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: _SideColumn(
                          running: running,
                          url: url,
                          clients: clients,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _ConnectCard(
                    running: running,
                    url: url,
                    error: error,
                    onStart: controller.startServer,
                    onStop: controller.stopServer,
                  ),
                  const SizedBox(height: 12),
                  _PendingCard(
                    pending: pending,
                    onApprove: controller.approvePairing,
                    onReject: controller.rejectPairing,
                  ),
                  const SizedBox(height: 12),
                  _ClientsCard(clients: clients),
                ],
              );
            },
          );
        }),
      ),
    );
  }
}

class _MainColumn extends StatelessWidget {
  const _MainColumn({
    required this.running,
    required this.url,
    required this.error,
    required this.pending,
    required this.onStart,
    required this.onStop,
    required this.onApprove,
    required this.onReject,
  });

  final bool running;
  final String url;
  final String error;
  final List<LocalConnectPairingRequest> pending;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;
  final Future<void> Function(String id) onApprove;
  final Future<void> Function(String id) onReject;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _ConnectCard(
          running: running,
          url: url,
          error: error,
          onStart: onStart,
          onStop: onStop,
        ),
        const SizedBox(height: 12),
        _PendingCard(
          pending: pending,
          onApprove: onApprove,
          onReject: onReject,
        ),
      ],
    );
  }
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({
    required this.running,
    required this.url,
    required this.clients,
  });

  final bool running;
  final String url;
  final List<LocalConnectClientSession> clients;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _QrCard(running: running, url: url),
        const SizedBox(height: 12),
        _ClientsCard(clients: clients),
      ],
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({
    required this.running,
    required this.url,
    required this.error,
    required this.onStart,
    required this.onStop,
  });

  final bool running;
  final String url;
  final String error;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Abrir en computadora',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusPill(
                  label: running ? 'Servidor activo' : 'Servidor detenido',
                  icon: running ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: running ? Colors.green : scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Misma WiFi. Abre la URL o escanea el QR.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: running ? null : onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Iniciar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: running ? onStop : null,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Detener'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!running || url.isEmpty)
              _EmptyMessage(
                text: 'Inicia la sesión para mostrar el enlace y el QR.',
                icon: Icons.info_outline_rounded,
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: SelectableText(
                  url,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final copyButton = OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      Get.snackbar(
                        'Listenfy Connect',
                        'URL copiada al portapapeles',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copiar URL'),
                  );

                  final shareButton = OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await Share.share(url, subject: 'Listenfy Connect');
                      } catch (_) {
                        Get.snackbar(
                          'Listenfy Connect',
                          'No se pudo compartir la URL',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Compartir'),
                  );

                  if (constraints.maxWidth < 360) {
                    return Column(
                      children: [
                        SizedBox(width: double.infinity, child: copyButton),
                        const SizedBox(height: 8),
                        SizedBox(width: double.infinity, child: shareButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: copyButton),
                      const SizedBox(width: 8),
                      Expanded(child: shareButton),
                    ],
                  );
                },
              ),
            ],
            if (error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.error.withValues(alpha: 0.42),
                  ),
                ),
                child: Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.running, required this.url});

  final bool running;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR de acceso',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (!running || url.isEmpty)
              const _EmptyMessage(
                text: 'Sin URL activa',
                icon: Icons.qr_code_2_rounded,
              )
            else
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: QrImageView(
                    data: url,
                    size: 210,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.pending,
    required this.onApprove,
    required this.onReject,
  });

  final List<LocalConnectPairingRequest> pending;
  final Future<void> Function(String id) onApprove;
  final Future<void> Function(String id) onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Solicitudes de conexión ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  label: 'Pendientes: ${pending.length}',
                  icon: Icons.devices_rounded,
                  color: pending.isEmpty
                      ? scheme.onSurfaceVariant
                      : scheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (pending.isEmpty)
              const _EmptyMessage(
                text: 'No hay solicitudes pendientes.',
                icon: Icons.check_circle_outline_rounded,
              )
            else
              ...pending.map(
                (request) => _PairRequestTile(
                  request: request,
                  onApprove: () => onApprove(request.id),
                  onReject: () => onReject(request.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PairRequestTile extends StatelessWidget {
  const _PairRequestTile({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final LocalConnectPairingRequest request;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.clientName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'ID: ${request.clientId}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onApprove,
                  child: const Text('Aprobar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientsCard extends StatelessWidget {
  const _ClientsCard({required this.clients});

  final List<LocalConnectClientSession> clients;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connectedCount = clients.where((client) => client.isConnected).length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Clientes autorizados',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusPill(
                  label: 'Conectados: $connectedCount',
                  icon: Icons.lan_rounded,
                  color: connectedCount > 0
                      ? Colors.green
                      : scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (clients.isEmpty)
              const _EmptyMessage(
                text: 'Aún no hay clientes autorizados.',
                icon: Icons.computer_outlined,
              )
            else
              ...clients.map((client) {
                final connected = client.isConnected;
                final expiryMain = _formatExpiryRelative(client.expiresAt);
                final expiryLimit = _formatDateTimeCompact(
                  client.expiresAt.toLocal(),
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      connected ? Icons.lan_rounded : Icons.computer_outlined,
                      color: connected ? Colors.green : scheme.onSurfaceVariant,
                    ),
                    title: Text(client.clientName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          expiryMain,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: client.isExpired
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hora límite: $expiryLimit',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    trailing: _StatusPill(
                      label: connected ? 'Conectado' : 'Inactivo',
                      icon: connected
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      color: connected ? Colors.green : scheme.onSurfaceVariant,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color == scheme.onSurfaceVariant ? color : color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTimeCompact(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)} ${two(value.hour)}:${two(value.minute)}';
}

String _formatExpiryRelative(DateTime expiresAt) {
  final now = DateTime.now();
  final diff = expiresAt.difference(now);
  if (diff.isNegative) {
    return 'Expiró hace ${_formatDurationCompact(diff.abs())}';
  }
  return 'Expira en ${_formatDurationCompact(diff)}';
}

String _formatDurationCompact(Duration duration) {
  if (duration.inDays >= 1) return '${duration.inDays}d';
  if (duration.inHours >= 1) return '${duration.inHours}h';
  if (duration.inMinutes >= 1) return '${duration.inMinutes}m';
  final seconds = duration.inSeconds < 1 ? 1 : duration.inSeconds;
  return '${seconds}s';
}

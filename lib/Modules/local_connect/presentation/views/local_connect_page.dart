import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../controller/local_connect_controller.dart';

class LocalConnectPage extends GetView<LocalConnectController> {
  const LocalConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Listenfy Local Connect')),
      body: Obx(() {
        final running = controller.isRunning.value;
        final url = controller.serverUrl.value;
        final error = controller.serverError.value;
        final pending = controller.pendingRequests.toList();
        final clients = controller.sessions.toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado de sesión',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            running ? 'Servidor activo' : 'Servidor detenido',
                          ),
                          avatar: Icon(
                            running ? Icons.check_circle : Icons.pause_circle,
                            color: running
                                ? Colors.green
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        if (running)
                          Chip(
                            label: const Text('Emparejamiento manual'),
                            avatar: Icon(
                              Icons.verified_user_rounded,
                              color: scheme.primary,
                            ),
                          ),
                      ],
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: running ? null : controller.startServer,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Iniciar sesión'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: running ? controller.stopServer : null,
                            icon: const Icon(Icons.stop_rounded),
                            label: const Text('Detener'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (running && url.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acceso desde navegador (misma WiFi)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        url,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: QrImageView(
                          data: url,
                          size: 220,
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
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitudes pendientes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (pending.isEmpty)
                      Text(
                        'No hay solicitudes de emparejamiento pendientes.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      ...pending.map((request) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
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
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${request.clientId}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        controller.rejectPairing(request.id);
                                      },
                                      child: const Text('Rechazar'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () {
                                        controller.approvePairing(request.id);
                                      },
                                      child: const Text('Aprobar'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clientes autorizados',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (clients.isEmpty)
                      Text(
                        'Aún no hay clientes autorizados.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      ...clients.map((client) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            client.isConnected
                                ? Icons.lan_rounded
                                : Icons.computer_outlined,
                            color: client.isConnected
                                ? Colors.green
                                : scheme.onSurfaceVariant,
                          ),
                          title: Text(client.clientName),
                          subtitle: Text(
                            'Expira: ${client.expiresAt.toLocal()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Chip(
                            label: Text(
                              client.isConnected ? 'Conectado' : 'Inactivo',
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

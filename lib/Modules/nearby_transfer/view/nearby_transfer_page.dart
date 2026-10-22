import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/models/media_item.dart';
import '../../../app/utils/listenfy_deep_link.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../controller/nearby_transfer_controller.dart';
import 'nearby_qr_scanner_page.dart';

String _t(String key, [List<String> args = const []]) =>
    tr('nearby_session.$key', args: args);

class NearbyTransferPage extends GetView<NearbyTransferController> {
  const NearbyTransferPage({super.key});

  bool get _locked =>
      controller.busy.value ||
      controller.phase.value == TransferPhase.pairing ||
      controller.phase.value == TransferPhase.preparingWifi;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      Get.snackbar(
        _t('title'),
        _t('action_failed'),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _scan() async {
    final raw = await Get.to<String>(() => const NearbyQrScannerPage());
    if (raw == null || _locked || controller.isConnected) return;
    final invite = ListenfyDeepLink.parseNearbyInviteRaw(raw);
    if (invite == null || invite.isExpired) {
      Get.snackbar(_t('title'), _t('invalid_invite'));
      return;
    }
    await _run(() => controller.startReceiveFromInvite(invite));
    if (controller.statusKey.value == 'nearby_session.invalid_code') {
      Get.snackbar(_t('title'), _t('invalid_invite'));
    }
  }

  Future<void> _showQr() => _run(controller.prepareInvitation);

  Widget _invitation(Uri uri) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(_t('show_qr'), style: Get.textTheme.titleLarge),
          const SizedBox(height: 16),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: QrImageView(
              data: uri.toString(),
              size: 220,
              eyeStyle: const QrEyeStyle(color: Colors.black),
              dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(
            controller.inviteCode.value,
            style: Get.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(_t('expiry_hint'))),
            ],
          ),
          Text(_t('scan_hint')),
        ],
      ),
    ),
  );

  Future<void> _enterCode() async {
    final form = GlobalKey<FormState>();
    var code = '';
    final result = await Get.dialog<String>(
      AlertDialog(
        title: Text(_t('enter_code')),
        content: Form(
          key: form,
          child: TextFormField(
            autofocus: true,
            maxLength: 7,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              TextInputFormatter.withFunction(
                (oldValue, newValue) =>
                    newValue.copyWith(text: newValue.text.toUpperCase()),
              ),
            ],
            onChanged: (value) => code = value,
            decoration: InputDecoration(labelText: _t('code_label')),
            validator: (value) => RegExp(r'^[A-Z0-9]{7}$').hasMatch(value ?? '')
                ? null
                : _t('code_invalid'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<String>(),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Get.back(result: code);
            },
            child: Text(_t('connect')),
          ),
        ],
      ),
    );
    if (result != null && !_locked && !controller.isConnected) {
      await _run(() => controller.joinCode(result));
    }
  }

  Future<void> _send() async {
    await _run(() async {
      final items = await Get.dialog<List<MediaItem>>(
        _LibraryPicker(
          items: controller.libraryItems(),
          preselected: controller.outgoingItems,
        ),
      );
      if (items == null ||
          items.isEmpty ||
          !controller.isConnected ||
          _locked) {
        return;
      }
      var bytes = 0;
      for (final item in items) {
        final variant = controller.shareVariant(item);
        final path = variant?.localPath;
        try {
          if (path == null || path.trim().isEmpty) {
            throw const FileSystemException();
          }
          final size = await File(path).length();
          if (size <= 0) throw const FileSystemException();
          bytes += size;
        } on FileSystemException {
          Get.snackbar(_t('title'), _t('file_unavailable'));
          return;
        }
      }
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: Text(_t('confirm_send')),
          content: Text(_t('send_summary', ['${items.length}', _size(bytes)])),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text(_t('cancel')),
            ),
            FilledButton(
              onPressed: () => Get.back(result: true),
              child: Text(_t('send')),
            ),
          ],
        ),
      );
      if (confirmed == true && controller.isConnected && !_locked) {
        await controller.sendItems(items);
      }
    });
  }

  Future<void> _close() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(_t('close_title')),
        content: Text(_t('close_hint')),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text(_t('close')),
          ),
        ],
      ),
    );
    if (confirmed == true) await _run(controller.closeConnection);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: Text(_t('title'))),
    body: AppGradientBackground(
      child: SafeArea(
        top: false,
        child: Obx(() {
          final connected = controller.isConnected;
          final phase = controller.phase.value;
          final status = controller.statusKey.value;
          final locked = _locked;
          final uri = controller.inviteUri.value;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        connected
                            ? Icons.swap_horiz_rounded
                            : Icons.devices_rounded,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        connected
                            ? _t('connected_to', [controller.peerName.value])
                            : _t('bridge_title'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(_t('identity', [controller.nickName])),
                      Text(_t('wifi_direct')),
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          status.startsWith('nearby_session.')
                              ? tr(status)
                              : _t('ready'),
                        ),
                      ),
                      if (phase == TransferPhase.failed)
                        Text(
                          _t('action_failed'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (locked)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(),
                        ),
                      const SizedBox(height: 16),
                      if (connected) ...[
                        FilledButton.icon(
                          key: const Key('transfer-send'),
                          onPressed: locked ? null : _send,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(_t('send')),
                        ),
                        OutlinedButton.icon(
                          key: const Key('transfer-close'),
                          onPressed: _close,
                          icon: const Icon(Icons.link_off),
                          label: Text(_t('close')),
                        ),
                      ] else ...[
                        Text(_t('bridge_hint')),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const Key('transfer-scan-qr'),
                          onPressed: locked ? null : _scan,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(_t('scan_qr')),
                        ),
                        OutlinedButton.icon(
                          key: const Key('transfer-show-qr'),
                          onPressed: locked ? null : _showQr,
                          icon: const Icon(Icons.qr_code),
                          label: Text(_t('show_qr')),
                        ),
                        OutlinedButton.icon(
                          key: const Key('transfer-enter-code'),
                          onPressed: locked ? null : _enterCode,
                          icon: const Icon(Icons.keyboard),
                          label: Text(_t('enter_code')),
                        ),
                        if (phase == TransferPhase.pairing ||
                            phase == TransferPhase.preparingWifi)
                          OutlinedButton.icon(
                            key: const Key('transfer-close'),
                            onPressed: () => _run(controller.closeConnection),
                            icon: const Icon(Icons.link_off),
                            label: Text(_t('cancel_connection')),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              if (phase == TransferPhase.advertising && uri != null)
                _invitation(uri),
              if (connected ||
                  controller.sent.isNotEmpty ||
                  controller.received.isNotEmpty) ...[
                _entries(context, 'sent', controller.sent.toList()),
                _entries(context, 'received', controller.received.toList()),
              ],
            ],
          );
        }),
      ),
    ),
  );

  Widget _entries(
    BuildContext context,
    String direction,
    List<TransferEntry> entries,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(
          _t(direction),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      Text(
        _t('success_count', [
          '${entries.where((e) => e.state == 'completed').length}',
        ]),
      ),
      if (entries.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_t('empty_$direction')),
        ),
      for (final entry in entries)
        Card(
          key: ValueKey('$direction-${entry.sessionId}-${entry.id}'),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(entry.title),
                subtitle: Text(
                  '${_t({'sending', 'receiving', 'completed', 'failed'}.contains(entry.state) ? entry.state : 'ready')} · ${_size(entry.bytes)}'
                  '${entry.bytesPerSecond > 0 ? ' · ${_t('speed', [_size(entry.bytesPerSecond.round())])}' : ''}',
                ),
                trailing: entry.state == 'completed'
                    ? const Icon(Icons.check_circle_outline)
                    : entry.state == 'failed'
                    ? Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      )
                    : Text(
                        _t('percent', [
                          '${(_progress(entry.progress) * 100).round()}',
                        ]),
                      ),
              ),
              LinearProgressIndicator(
                value: _progress(entry.progress),
                semanticsLabel: _t(direction),
              ),
            ],
          ),
        ),
    ],
  );
}

double _progress(double value) => value.isFinite ? value.clamp(0.0, 1.0) : 0;
String _size(int bytes) {
  final mb = bytes / (1024 * 1024);
  return mb >= 1
      ? _t('size_mb', [mb.toStringAsFixed(1)])
      : _t('size_kb', [(bytes / 1024).toStringAsFixed(1)]);
}

class _LibraryPicker extends StatefulWidget {
  const _LibraryPicker({required this.items, required this.preselected});
  final List<MediaItem> items;
  final List<MediaItem> preselected;
  @override
  State<_LibraryPicker> createState() => _LibraryPickerState();
}

class _LibraryPickerState extends State<_LibraryPicker> {
  final Map<String, MediaItem> _selected = {};
  String _query = '';
  @override
  void initState() {
    super.initState();
    for (final item in widget.preselected) {
      final variants = item.variants
          .where((v) => (v.localPath ?? '').isNotEmpty)
          .toList();
      if (variants.isNotEmpty) {
        _selected[item.id] = item.copyWith(variants: [variants.first]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where(
          (item) =>
              item.title.toLowerCase().contains(_query) ||
              item.subtitle.toLowerCase().contains(_query),
        )
        .toList();
    return AlertDialog(
      title: Text(_t('library')),
      content: SizedBox(
        width: 480,
        height: MediaQuery.sizeOf(context).height * .5,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: _t('search'),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(child: Text(_t('empty_library')))
                  : ListView(
                      children: [
                        for (final item in items)
                          for (final kind in MediaVariantKind.values)
                            if (item.variants.any(
                              (v) =>
                                  v.kind == kind &&
                                  (v.localPath ?? '').isNotEmpty,
                            ))
                              CheckboxListTile(
                                title: Text(item.title),
                                subtitle: Text(
                                  _t(
                                    kind == MediaVariantKind.audio
                                        ? 'audio'
                                        : 'video',
                                  ),
                                ),
                                value:
                                    _selected[item.id]?.variants.first.kind ==
                                    kind,
                                onChanged: (checked) => setState(() {
                                  if (checked == true) {
                                    final variant = item.variants.firstWhere(
                                      (v) =>
                                          v.kind == kind &&
                                          (v.localPath ?? '').isNotEmpty,
                                    );
                                    _selected[item.id] = item.copyWith(
                                      variants: [variant],
                                    );
                                  } else {
                                    _selected.remove(item.id);
                                  }
                                }),
                              ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back<List<MediaItem>>(),
          child: Text(_t('cancel')),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Get.back(result: _selected.values.toList()),
          child: Text(_t('review_selection', ['${_selected.length}'])),
        ),
      ],
    );
  }
}

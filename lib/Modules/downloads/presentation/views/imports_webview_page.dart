import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controller/downloads_controller.dart';

class ImportsWebViewPage extends StatefulWidget {
  const ImportsWebViewPage({super.key});

  @override
  State<ImportsWebViewPage> createState() => _ImportsWebViewPageState();
}

class _ImportsWebViewPageState extends State<ImportsWebViewPage> {
  final DownloadsController _downloadsController =
      Get.find<DownloadsController>();
  final TextEditingController _urlCtrl = TextEditingController(
    text: 'https://m.youtube.com',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final border = scheme.outlineVariant.withAlpha(120);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                    color: scheme.primary.withAlpha(28),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.public_rounded, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Buscador web',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Abre un navegador externo para copiar enlaces rápidamente.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) =>
                  _downloadsController.openCustomTab(context, _urlCtrl.text),
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Obx(() {
                    final opening = _downloadsController.customTabOpening.value;
                    return FilledButton.icon(
                      onPressed: opening
                          ? null
                          : () => _downloadsController.openCustomTab(
                              context,
                              _urlCtrl.text,
                            ),
                      icon: opening
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.open_in_new_rounded),
                      label: const Text('Abrir navegador'),
                    );
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Obx(() {
                    final opening = _downloadsController.customTabOpening.value;
                    return OutlinedButton.icon(
                      onPressed: opening ? null : () => _urlCtrl.clear(),
                      icon: const Icon(Icons.clear_rounded),
                      label: const Text('Limpiar'),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: Text(
                'Tip: Si quieres PiP, usa un navegador compatible.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

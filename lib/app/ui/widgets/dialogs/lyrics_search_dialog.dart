import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:get/get.dart';

/// Dialog de busqueda web para letras.
/// El usuario selecciona texto manualmente y se retorna tal cual.
class LyricsSearchDialog extends StatefulWidget {
  const LyricsSearchDialog({super.key, required this.initialQuery});

  final String initialQuery;

  @override
  State<LyricsSearchDialog> createState() => _LyricsSearchDialogState();
}

class _LyricsSearchDialogState extends State<LyricsSearchDialog> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      );
    _loadSearch();
  }

  void _loadSearch() {
    final query = Uri.encodeComponent('${widget.initialQuery} lyrics');
    final url = 'https://www.google.com/search?q=$query';
    _controller.loadRequest(Uri.parse(url));
  }

  Future<String> _readSelectedText() async {
    const js = '''
      (() => {
        const selected = window.getSelection ? window.getSelection().toString() : '';
        if (selected && selected.length > 0) return JSON.stringify(selected);

        const el = document.activeElement;
        if (
          el &&
          typeof el.value === 'string' &&
          typeof el.selectionStart === 'number' &&
          typeof el.selectionEnd === 'number' &&
          el.selectionEnd > el.selectionStart
        ) {
          return JSON.stringify(el.value.substring(el.selectionStart, el.selectionEnd));
        }

        return JSON.stringify('');
      })();
    ''';

    try {
      final raw = await _controller.runJavaScriptReturningResult(js);
      return _decodeJsResult(raw);
    } catch (_) {
      return '';
    }
  }

  String _decodeJsResult(dynamic raw) {
    if (raw == null) return '';
    var value = raw is String ? raw.trim() : raw.toString().trim();
    if (value.isEmpty || value == 'null' || value == 'undefined') return '';

    // Algunos WebView retornan el string JSON-escaped una o dos veces.
    for (var i = 0; i < 2; i++) {
      final decoded = _tryDecodeJsonString(value);
      if (decoded == null) break;
      value = decoded;
    }

    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }

    return _unescapeCommonSequences(value);
  }

  String? _tryDecodeJsonString(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is String ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String _unescapeCommonSequences(String value) {
    var out = value;

    // Double-escaped first
    out = out.replaceAll(r'\\r\\n', '\n');
    out = out.replaceAll(r'\\n', '\n');
    out = out.replaceAll(r'\\r', '\r');
    out = out.replaceAll(r'\\t', '\t');

    // Single-escaped leftovers
    out = out.replaceAll(r'\r\n', '\n');
    out = out.replaceAll(r'\n', '\n');
    out = out.replaceAll(r'\r', '\r');
    out = out.replaceAll(r'\t', '\t');

    out = out.replaceAll(r'\"', '"');
    out = out.replaceAll(r"\'", "'");
    out = out.replaceAll(r'\\', '\\');

    return out;
  }

  Future<void> _selectCurrent() async {
    final selected = await _readSelectedText();
    if (!mounted) return;

    if (selected.trim().isEmpty) {
      Get.snackbar(
        'Letras',
        'Selecciona texto manualmente en la pagina y luego pulsa Seleccionar.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.back(result: selected);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            AppBar(
              title: const Text('Buscar letras'),
              actions: [
                TextButton(
                  onPressed: () => _selectCurrent(),
                  child: const Text('Seleccionar'),
                ),
              ],
            ),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

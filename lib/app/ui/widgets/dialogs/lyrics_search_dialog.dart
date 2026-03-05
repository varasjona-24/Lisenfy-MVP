import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:get/get.dart';

/// Simple dialog that loads a Google search for lyrics and allows the user to
/// return the current page URL.
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

  void _selectCurrent() async {
    final current = await _controller.currentUrl();
    if (current != null && mounted) {
      Get.back(result: current);
    }
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
                  onPressed: _selectCurrent,
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

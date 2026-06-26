import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../branding/listenfy_logo.dart';

/// Dialog que permite buscar imágenes en Google Images y devuelve la URL
/// seleccionada al caller:

class ImageSearchDialog extends StatefulWidget {
  const ImageSearchDialog({
    super.key,
    required this.initialQuery,
    this.onImageSelected,
    this.onDownloadImage,
  });

  final String initialQuery;
  final ValueChanged<String>? onImageSelected;
  final Future<String?> Function(String imageUrl)? onDownloadImage;

  @override
  State<ImageSearchDialog> createState() => _ImageSearchDialogState();
}

class _ImageSearchDialogState extends State<ImageSearchDialog> {
  WebViewController? _controller;
  late final TextEditingController _manualUrlController;

  bool _loading = true;
  bool _picked = false;

  static const String _imageTapScript = r'''
(function() {
  function pickUrl(img) {
    if (!img) return '';
    try {
      if ((img.naturalWidth || 0) < 120 || (img.naturalHeight || 0) < 120) {
        return '';
      }
    } catch (e) {}

    var dataIurl = img.getAttribute('data-iurl');
    if (dataIurl && dataIurl.startsWith('http')) return dataIurl;

    var dataSrc = img.getAttribute('data-src') || img.getAttribute('data-lowsrc');
    if (dataSrc && dataSrc.startsWith('http')) return dataSrc;

    var src = img.getAttribute('src');
    if (src && src.startsWith('http')) return src;

    var srcset = img.getAttribute('srcset');
    if (srcset) {
      var parts = srcset
        .split(',')
        .map(function(p){ return p.trim().split(' ')[0]; })
        .filter(Boolean);
      if (parts.length) return parts[parts.length - 1];
    }

    return '';
  }

  document.addEventListener('click', function(e) {
    var img = e.target.closest('img');
    if (!img) return;

    var url = pickUrl(img);
    if (url) {
      try {
        if (window.ListenfyImage && window.ListenfyImage.postMessage) {
          window.ListenfyImage.postMessage(url);
        }
      } catch (err) {
        console.log('Error posting message: ' + err);
      }
      e.preventDefault();
      e.stopPropagation();
    }
  }, true);
})();
''';

  @override
  void initState() {
    super.initState();
    _manualUrlController = TextEditingController();

    if (Platform.isMacOS) {
      _loading = false;
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ListenfyImage',
        onMessageReceived: (msg) {
          final url = msg.message.trim();
          if (!mounted) return;
          if (url.isEmpty) return;
          if (_picked) return; // evita doble pop por doble click/mensaje
          _picked = true;

          // Inicia descarga en background si se proporcionó callback, sin esperar
          if (widget.onDownloadImage != null) {
            widget.onDownloadImage!(url)
                .then((localPath) {
                  // Callback después de descarga completada
                  try {
                    if (widget.onImageSelected != null && mounted) {
                      widget.onImageSelected!(url);
                    }
                  } catch (_) {}
                })
                .catchError((e) {
                  if (kDebugMode) {
                    print('Image download failed: $e');
                  }
                  // Intenta al menos llamar el callback de selección
                  try {
                    if (widget.onImageSelected != null && mounted) {
                      widget.onImageSelected!(url);
                    }
                  } catch (_) {}
                });
          } else {
            // Sin descarga, solo callback de selección
            try {
              if (widget.onImageSelected != null) {
                widget.onImageSelected!(url);
              }
            } catch (_) {}
          }

          // Cierra el diálogo inmediatamente con la URL remota
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop(url);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => _loading = false);

            // Espera un poco para que la página se renderice completamente
            await Future.delayed(const Duration(milliseconds: 500));

            if (!mounted) return;
            try {
              await _controller?.runJavaScript(_imageTapScript);
            } catch (e) {
              // Ignora si falla la inyección (cambios en la página / WebView)
              if (kDebugMode) {
                print('Failed to inject image tap script: $e');
              }
            }
          },
        ),
      );

    _loadQuery(widget.initialQuery);
  }

  void _loadQuery(String query) {
    final q = query.trim().isEmpty ? 'album cover' : query.trim();
    final encoded = Uri.encodeComponent(q);
    final url = 'https://www.google.com/search?tbm=isch&q=$encoded';
    _controller?.loadRequest(Uri.parse(url));
  }

  String _searchUrl() {
    final q = widget.initialQuery.trim().isEmpty
        ? 'album cover'
        : widget.initialQuery.trim();
    return 'https://www.google.com/search?tbm=isch&q=${Uri.encodeComponent(q)}';
  }

  Future<void> _openInSystemBrowser() async {
    try {
      await Process.run('/usr/bin/open', [_searchUrl()]);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to open image search: $e');
      }
    }
  }

  void _selectManualUrl() {
    final url = _manualUrlController.text.trim();
    if (url.isEmpty) return;
    widget.onImageSelected?.call(url);
    Navigator.of(context, rootNavigator: true).pop(url);
  }

  @override
  void dispose() {
    _manualUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface70 = scheme.onSurface.withAlpha(179);

    if (Platform.isMacOS) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ListenfyLogo(size: 22, showText: false),
                    const SizedBox(width: 10),
                    Text(
                      tr('edit.search_cover'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  tr('edit.image_search_macos_hint'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _manualUrlController,
                  decoration: InputDecoration(
                    labelText: tr('edit.image_url'),
                    prefixIcon: const Icon(Icons.link_rounded),
                  ),
                  onSubmitted: (_) => _selectManualUrl(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _openInSystemBrowser,
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: Text(tr('edit.open_search')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _selectManualUrl,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(tr('edit.use_url')),
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

    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const ListenfyLogo(size: 22, showText: false),
                  const SizedBox(width: 10),
                  Text(
                    'Listenfy',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
                child: Stack(
                  children: [
                    WebViewWidget(controller: controller),
                    if (_loading)
                      Positioned.fill(
                        child: Container(
                          color: scheme.surface.withAlpha(230),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: onSurface70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Toca una imagen para seleccionarla.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onSurface70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

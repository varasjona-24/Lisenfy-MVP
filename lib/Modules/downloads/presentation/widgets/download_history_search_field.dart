import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

// ============================
// 🔍 WIDGET: CAMPO DE BÚSQUEDA
// Tiene su propio TextEditingController para mostrar
// el botón de limpiar (X) y sincronizar con el criterio
// de búsqueda del controlador externo.
// ============================
class DownloadHistorySearchField extends StatefulWidget {
  const DownloadHistorySearchField({
    super.key,
    required this.onChanged,
    this.initialValue = '',
  });

  final ValueChanged<String> onChanged;
  final String initialValue;

  @override
  State<DownloadHistorySearchField> createState() =>
      _DownloadHistorySearchFieldState();
}

class _DownloadHistorySearchFieldState
    extends State<DownloadHistorySearchField> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _hasText = widget.initialValue.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    widget.onChanged(_controller.text);
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TextField(
      controller: _controller,
      style: theme.textTheme.bodyLarge,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: tr('downloads.search_hint'),
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
        suffixIcon: _hasText
            ? IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: _clear,
                tooltip: tr('downloads.clear_search'),
              )
            : null,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
    );
  }
}

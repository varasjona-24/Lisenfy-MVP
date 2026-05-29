import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/services/capture_gallery_service.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';

// ─── Sort options ───────────────────────────────────────────────────────────
enum _CaptureSort { date, size, name }

class CaptureGalleryPage extends StatefulWidget {
  const CaptureGalleryPage({super.key});

  @override
  State<CaptureGalleryPage> createState() => _CaptureGalleryPageState();
}

class _CaptureGalleryPageState extends State<CaptureGalleryPage> {
  final CaptureGalleryService _service = const CaptureGalleryService();
  late Future<List<ListenfyCapture>> _future;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  _CaptureSort _sort = _CaptureSort.date;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _future = _service.listCaptures();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _service.listCaptures();
    });
  }

  // ─── Sort ──────────────────────────────────────────────────────────────────
  List<ListenfyCapture> _sorted(List<ListenfyCapture> captures) {
    final filtered = _query.isEmpty
        ? captures
        : captures
            .where((c) => c.name.toLowerCase().contains(_query))
            .toList();

    final sorted = List<ListenfyCapture>.from(filtered);
    switch (_sort) {
      case _CaptureSort.date:
        sorted.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
      case _CaptureSort.size:
        sorted.sort((a, b) => a.size.compareTo(b.size));
      case _CaptureSort.name:
        sorted.sort((a, b) => a.name.compareTo(b.name));
    }
    if (!_ascending) return sorted.reversed.toList();
    return sorted;
  }

  // ─── Actions ───────────────────────────────────────────────────────────────
  Future<void> _rename(ListenfyCapture capture) async {
    final controller = TextEditingController(text: capture.name);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar captura'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null || next.trim().isEmpty) return;
    await _service.renameCapture(capture.path, next);
    _reload();
  }

  Future<void> _delete(ListenfyCapture capture) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar captura'),
        content: Text('¿Eliminar "${capture.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteCapture(capture.path);
    _reload();
  }

  // ─── Bottom-sheet action menu ─────────────────────────────────────────────
  void _showOptionsSheet(ListenfyCapture capture) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capture.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _BottomSheetOption(
                  icon: Icons.drive_file_rename_outline_rounded,
                  label: 'Renombrar',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _rename(capture);
                  },
                ),
                const SizedBox(height: 8),
                _BottomSheetOption(
                  icon: Icons.delete_outline_rounded,
                  label: 'Eliminar',
                  destructive: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _delete(capture);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Sort filter bottom-sheet ─────────────────────────────────────────────
  void _showSortSheet() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            void pick(_CaptureSort sort) {
              if (_sort == sort) {
                setState(() => _ascending = !_ascending);
                modalSetState(() {});
              } else {
                setState(() {
                  _sort = sort;
                  _ascending = false;
                });
                modalSetState(() {});
              }
            }

            String directionLabel(_CaptureSort s) {
              if (s != _sort) {
                return switch (s) {
                  _CaptureSort.date => 'Más reciente primero',
                  _CaptureSort.size => 'Mayor a menor',
                  _CaptureSort.name => 'A-Z',
                };
              }
              return switch (s) {
                _CaptureSort.date =>
                  _ascending ? 'Más antiguo primero' : 'Más reciente primero',
                _CaptureSort.size =>
                  _ascending ? 'Menor a mayor' : 'Mayor a menor',
                _CaptureSort.name => _ascending ? 'A-Z' : 'Z-A',
              };
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ordenar capturas',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SortOption(
                      icon: Icons.access_time_rounded,
                      label: 'Antigüedad',
                      sublabel: directionLabel(_CaptureSort.date),
                      selected: _sort == _CaptureSort.date,
                      ascending: _sort == _CaptureSort.date ? _ascending : null,
                      onTap: () => pick(_CaptureSort.date),
                    ),
                    const SizedBox(height: 6),
                    _SortOption(
                      icon: Icons.data_usage_rounded,
                      label: 'Peso',
                      sublabel: directionLabel(_CaptureSort.size),
                      selected: _sort == _CaptureSort.size,
                      ascending: _sort == _CaptureSort.size ? _ascending : null,
                      onTap: () => pick(_CaptureSort.size),
                    ),
                    const SizedBox(height: 6),
                    _SortOption(
                      icon: Icons.sort_by_alpha_rounded,
                      label: 'Nombre',
                      sublabel: directionLabel(_CaptureSort.name),
                      selected: _sort == _CaptureSort.name,
                      ascending: _sort == _CaptureSort.name ? _ascending : null,
                      onTap: () => pick(_CaptureSort.name),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Aceptar'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Preview ───────────────────────────────────────────────────────────────
  void _openPreview(ListenfyCapture capture) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CapturePreviewPage(
          capture: capture,
          onRename: () async {
            await _rename(capture);
            if (mounted) Navigator.of(context).maybePop();
          },
          onDelete: () async {
            await _delete(capture);
            if (mounted) Navigator.of(context).maybePop();
          },
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Capturas',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        forceMaterialTransparency: true,
        actions: [
          IconButton(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort_rounded),
            onPressed: _showSortSheet,
          ),
        ],
      ),
      body: AppGradientBackground(
        child: FutureBuilder<List<ListenfyCapture>>(
          future: _future,
          builder: (context, snapshot) {
            final captures = snapshot.data ?? const <ListenfyCapture>[];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (captures.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 72,
                        color: scheme.onSurfaceVariant.withValues(alpha: .55),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aún no hay capturas',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Las capturas tomadas desde el reproductor aparecerán aquí.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final sorted = _sorted(captures);

            return Column(
              children: [
                // ── Search bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SearchBar(
                    controller: _searchCtrl,
                    hintText: 'Buscar por nombre…',
                    leading: const Icon(Icons.search_rounded),
                    trailing: [
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                    ],
                    elevation: const WidgetStatePropertyAll(0),
                    backgroundColor: WidgetStatePropertyAll(
                      scheme.surfaceContainerHigh.withValues(alpha: .65),
                    ),
                    side: WidgetStatePropertyAll(
                      BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: .4),
                      ),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),

                // ── Grid ────────────────────────────────────────────────
                Expanded(
                  child: sorted.isEmpty
                      ? Center(
                          child: Text(
                            'Sin resultados para "$_query"',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _reload(),
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: sorted.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              // 16:9 image + ~44px label row
                              childAspectRatio: 16 / (9 + 5),
                            ),
                            itemBuilder: (context, index) {
                              final capture = sorted[index];
                              return _CaptureTile(
                                capture: capture,
                                onTap: () => _openPreview(capture),
                                onOptions: () => _showOptionsSheet(capture),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Tile ──────────────────────────────────────────────────────────────────
class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    required this.capture,
    required this.onTap,
    required this.onOptions,
  });

  final ListenfyCapture capture;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: .62),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image (no rounded corners) ──────────────────────────
            Expanded(
              child: Image.file(
                File(capture.path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded, size: 32),
                  ),
                ),
              ),
            ),
            // ── Label row ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      capture.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onOptions,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
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

// ─── Bottom-sheet action option ───────────────────────────────────────────
class _BottomSheetOption extends StatelessWidget {
  const _BottomSheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = destructive ? scheme.error : scheme.onSurface;
    final bg = destructive
        ? scheme.errorContainer.withValues(alpha: .18)
        : scheme.surfaceContainerHighest.withValues(alpha: .55);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (destructive ? scheme.error : scheme.outlineVariant)
                .withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sort filter option ───────────────────────────────────────────────────
class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
    this.ascending,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final bool? ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                ascending == true
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 18,
                color: scheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Preview page ─────────────────────────────────────────────────────────
class _CapturePreviewPage extends StatelessWidget {
  const _CapturePreviewPage({
    required this.capture,
    required this.onRename,
    required this.onDelete,
  });

  final ListenfyCapture capture;
  final Future<void> Function() onRename;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          capture.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => onRename(),
            icon: const Icon(Icons.drive_file_rename_outline_rounded),
            tooltip: 'Renombrar',
          ),
          IconButton(
            onPressed: () => onDelete(),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Eliminar',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: .8,
          maxScale: 4,
          child: Image.file(File(capture.path), fit: BoxFit.contain),
        ),
      ),
    );
  }
}

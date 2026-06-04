import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../controller/capture_gallery_controller.dart';
import '../domain/capture_gallery_models.dart';
import '../ui/capture_action_sheet.dart';
import '../ui/capture_cover_target_sheet.dart';
import '../ui/capture_empty_state.dart';
import '../ui/capture_preview_page.dart';
import '../ui/capture_sort_sheet.dart';
import '../ui/capture_tile.dart';

class CaptureGalleryPage extends StatefulWidget {
  const CaptureGalleryPage({super.key});

  @override
  State<CaptureGalleryPage> createState() => _CaptureGalleryPageState();
}

class _CaptureGalleryPageState extends State<CaptureGalleryPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final CaptureGalleryController _controller;
  static const _tagPalette = <int>[
    0xFFE53935,
    0xFFFF8F00,
    0xFFFDD835,
    0xFF43A047,
    0xFF00ACC1,
    0xFF1E88E5,
    0xFF8E24AA,
    0xFF7C8BA1,
  ];

  @override
  void initState() {
    super.initState();
    _controller = Get.find<CaptureGalleryController>();
    _searchCtrl.addListener(() => _controller.setQuery(_searchCtrl.text));
    final args = Get.arguments;
    if (args is Map && args['query'] != null) {
      _searchCtrl.text = args['query'].toString();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _rename(CaptureItem capture) async {
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
    await _controller.renameCapture(capture, next);
  }

  Future<void> _delete(CaptureItem capture) async {
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
    await _controller.deleteCapture(capture);
  }

  Future<void> _editTags(CaptureItem capture) async {
    final controller = TextEditingController(text: capture.tags.join(', '));
    final raw = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return AlertDialog(
          title: const Text('Etiquetas'),
          content: SizedBox(
            width: 360,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final tags = value.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(growable: false);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Separadas por coma',
                        hintText: 'anime, escena, portada',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Color de etiqueta',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in tags)
                                _TagColorChip(
                                  tag: tag,
                                  color: Color(_controller.colorForTag(tag)),
                                  palette: _tagPalette,
                                  onPick: (colorValue) async {
                                    await _controller.setTagColor(
                                      tag,
                                      colorValue,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Agrega una etiqueta para asignarle color.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
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
        );
      },
    );
    controller.dispose();
    if (raw == null) return;
    final tags = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    await _controller.setTags(capture, tags);
  }

  Future<void> _useAsCover(CaptureItem capture) async {
    final target = await showModalBottomSheet<CaptureCoverTarget>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return CaptureCoverTargetSheet(targets: _controller.loadCoverTargets());
      },
    );
    if (target == null) return;
    await _controller.applyCover(capture: capture, target: target);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Portada actualizada para ${target.label}.')),
    );
  }

  void _toggleSelection(CaptureItem capture) {
    final changed = _controller.toggleSelection(capture);
    if (!changed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puedes seleccionar hasta 20 imágenes.')),
      );
    }
  }

  void _showOptionsSheet(CaptureItem capture) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return CaptureActionSheet(
          capture: capture,
          onShare: () {
            Navigator.of(ctx).pop();
            _controller.shareCaptures([capture]);
          },
          onUseAsCover: () {
            Navigator.of(ctx).pop();
            _useAsCover(capture);
          },
          onEditTags: () {
            Navigator.of(ctx).pop();
            _editTags(capture);
          },
          onRename: () {
            Navigator.of(ctx).pop();
            _rename(capture);
          },
          onDelete: () {
            Navigator.of(ctx).pop();
            _delete(capture);
          },
        );
      },
    );
  }

  void _showSortSheet() {
    final scheme = Theme.of(context).colorScheme;
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
            return CaptureSortSheet(
              currentSort: _controller.sort.value,
              ascending: _controller.ascending.value,
              directionLabel: _controller.directionLabel,
              onPick: (sort) {
                _controller.pickSort(sort);
                modalSetState(() {});
              },
            );
          },
        );
      },
    );
  }

  void _openPreview(CaptureItem capture) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CapturePreviewPage(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Obx(() {
      final captures = _controller.captures;
      final sorted = _controller.visibleCaptures;
      final query = _controller.query.value;

      return Scaffold(
        appBar: AppBar(
          title: Text(
            _controller.hasSelection
                ? '${_controller.selectedCount}/20 seleccionadas'
                : 'Capturas',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          forceMaterialTransparency: true,
          actions: [
            if (_controller.hasSelection) ...[
              IconButton(
                tooltip: 'Compartir externo',
                icon: const Icon(Icons.bluetooth_searching_rounded),
                onPressed: _controller.shareSelected,
              ),
              IconButton(
                tooltip: 'Cancelar selección',
                icon: const Icon(Icons.close_rounded),
                onPressed: _controller.clearSelection,
              ),
            ] else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Etiquetas',
                    icon: const Icon(Icons.folder_special_rounded),
                    onPressed: () => Get.toNamed(AppRoutes.captureTags),
                  ),
                  IconButton(
                    tooltip: 'Ordenar',
                    icon: const Icon(Icons.sort_rounded),
                    onPressed: _showSortSheet,
                  ),
                ],
              ),
          ],
        ),
        body: AppGradientBackground(
          child: Builder(
            builder: (context) {
              if (_controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (captures.isEmpty) {
                return const CaptureEmptyState();
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: SearchBar(
                      controller: _searchCtrl,
                      hintText: 'Buscar por nombre o etiqueta…',
                      leading: const Icon(Icons.search_rounded),
                      trailing: [
                        if (query.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchCtrl.clear();
                              _controller.setQuery('');
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
                  Expanded(
                    child: sorted.isEmpty
                        ? Center(
                            child: Text(
                              'Sin resultados para "$query"',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _controller.reload,
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: sorted.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 16 / (9 + 5),
                                  ),
                              itemBuilder: (context, index) {
                                final capture = sorted[index];
                                return CaptureTile(
                                  capture: capture,
                                  selected: _controller.selectedPaths.contains(
                                    capture.path,
                                  ),
                                  onTap: () => _openPreview(capture),
                                  onLongPress: () => _toggleSelection(capture),
                                  onOptions: () => _showOptionsSheet(capture),
                                  tagColorBuilder: _controller.colorForTag,
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
    });
  }
}

class _TagColorChip extends StatefulWidget {
  const _TagColorChip({
    required this.tag,
    required this.color,
    required this.palette,
    required this.onPick,
  });

  final String tag;
  final Color color;
  final List<int> palette;
  final Future<void> Function(int colorValue) onPick;

  @override
  State<_TagColorChip> createState() => _TagColorChipState();
}

class _TagColorChipState extends State<_TagColorChip> {
  late Color _color = widget.color;

  @override
  void didUpdateWidget(covariant _TagColorChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag || oldWidget.color != widget.color) {
      _color = widget.color;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopupMenuButton<int>(
      tooltip: 'Color de ${widget.tag}',
      onSelected: (value) async {
        setState(() => _color = Color(value));
        await widget.onPick(value);
      },
      itemBuilder: (context) {
        return [
          for (final value in widget.palette)
            PopupMenuItem<int>(
              value: value,
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(value),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: 18, height: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('#${widget.tag}'),
                ],
              ),
            ),
        ];
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 12, height: 12),
              ),
              const SizedBox(width: 7),
              Text(
                '#${widget.tag}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

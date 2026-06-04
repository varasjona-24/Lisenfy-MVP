import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../controller/capture_gallery_controller.dart';
import '../domain/capture_gallery_models.dart';
import '../ui/capture_action_sheet.dart';
import '../ui/capture_cover_target_sheet.dart';
import '../ui/capture_empty_state.dart';
import '../ui/capture_preview_page.dart';
import '../ui/capture_sort_sheet.dart';
import '../ui/capture_tile.dart';
import 'capture_tags_page.dart';

class CaptureGalleryPage extends StatefulWidget {
  const CaptureGalleryPage({super.key});

  @override
  State<CaptureGalleryPage> createState() => _CaptureGalleryPageState();
}

class _CaptureGalleryPageState extends State<CaptureGalleryPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final CaptureGalleryController _controller;

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

  Future<void> _editCapture(CaptureItem capture) async {
    final changed = await Get.toNamed(
      AppRoutes.editEntity,
      arguments: EditEntityArgs.capture(capture),
    );
    if (changed == true) {
      await _controller.reload();
    }
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
          onEdit: () {
            Navigator.of(ctx).pop();
            _editCapture(capture);
          },
          onShare: () {
            Navigator.of(ctx).pop();
            _controller.shareCaptures([capture]);
          },
          onUseAsCover: () {
            Navigator.of(ctx).pop();
            _useAsCover(capture);
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

  Future<void> _openTagFolders() async {
    await _controller.reload();
    if (!mounted) return;
    final selectedTag = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const CaptureTagsPage()));
    final tag = selectedTag?.trim();
    if (tag == null || tag.isEmpty) return;
    _searchCtrl.text = tag;
    _controller.setQuery(tag);
  }

  void _openPreview(CaptureItem capture) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CapturePreviewPage(
          capture: capture,
          onRename: () async {
            await _editCapture(capture);
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
                  if (query.isEmpty)
                    IconButton(
                      tooltip: 'Etiquetas',
                      icon: const Icon(Icons.folder_special_rounded),
                      onPressed: _openTagFolders,
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../controller/capture_gallery_controller.dart';
import '../domain/capture_gallery_models.dart';

class CaptureTagsPage extends StatefulWidget {
  const CaptureTagsPage({super.key});

  @override
  State<CaptureTagsPage> createState() => _CaptureTagsPageState();
}

class _CaptureTagsPageState extends State<CaptureTagsPage> {
  final CaptureGalleryController controller =
      Get.find<CaptureGalleryController>();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Obx(() {
      final folders = controller.tagFolders;
      final query = _searchCtrl.text.trim().toLowerCase();
      final visibleFolders = query.isEmpty
          ? folders
          : folders.where((folder) {
              return folder.tag.toLowerCase().contains(query);
            }).toList();

      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          forceMaterialTransparency: true,
          actions: [
            IconButton(
              tooltip: 'Crear etiqueta',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _createTag(context),
            ),
          ],
        ),
        body: AppGradientBackground(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Etiquetas',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Buscar etiqueta',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              ),
                        filled: true,
                        fillColor: scheme.surfaceContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: folders.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_special_outlined,
                                size: 72,
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: .55,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Sin etiquetas',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Agrega etiquetas a tus capturas para verlas como carpetas.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : visibleFolders.isEmpty
                    ? Center(
                        child: Text(
                          'Sin resultados para "$query"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: visibleFolders.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.08,
                            ),
                        itemBuilder: (context, index) {
                          final folder = visibleFolders[index];
                          return _TagFolderTile(
                            folder: folder,
                            onEdit: () => _editFolder(context, folder),
                            onTap: () {
                              final tag = folder.tag;
                              if (Navigator.of(context).canPop()) {
                                Get.back(result: tag);
                              } else {
                                Get.offNamed(
                                  AppRoutes.captureGallery,
                                  arguments: {'query': tag},
                                );
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _editFolder(
    BuildContext context,
    CaptureTagFolder folder,
  ) async {
    final changed = await Get.toNamed(
      AppRoutes.editEntity,
      arguments: EditEntityArgs.captureTag(folder),
    );
    if (changed == true) {
      await controller.reload();
    }
  }

  Future<void> _createTag(BuildContext context) async {
    final nameCtrl = TextEditingController();
    var colorValue = CaptureGalleryController.defaultTagColor;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final scheme = theme.colorScheme;
        const colors = <int>[
          0xFFFF5252,
          0xFFFFD740,
          0xFF4CE76B,
          0xFF42A5F5,
          0xFFB56CFF,
          0xFFFF9F40,
          0xFFB0B8C4,
        ];
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Crear etiqueta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ej: Rojo, favoritos, escena...',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Color',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final value in colors)
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => setDialogState(() => colorValue = value),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(value),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorValue == value
                                    ? scheme.onSurface
                                    : scheme.outlineVariant,
                                width: colorValue == value ? 3 : 1,
                              ),
                            ),
                            child: const SizedBox(width: 30, height: 30),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (created != true || name.isEmpty) return;
    await controller.setTagCollection(
      tag: name,
      name: name,
      colorValue: colorValue,
    );
  }
}

class _TagFolderTile extends StatelessWidget {
  const _TagFolderTile({
    required this.folder,
    required this.onTap,
    required this.onEdit,
  });

  final CaptureTagFolder folder;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = Color(folder.colorValue);
    final previewPath =
        folder.thumbnailPath ??
        (folder.captures.isEmpty ? null : folder.captures.first.path);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Icon(
                        Icons.folder_rounded,
                        size: 98,
                        color: color.withValues(alpha: .26),
                      ),
                    ),
                    if (previewPath != null)
                      Align(
                        alignment: Alignment.center,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(previewPath),
                            width: 76,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                                  width: 76,
                                  height: 48,
                                  child: Icon(
                                    Icons.image_not_supported_rounded,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 2,
                      top: 2,
                      child: IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onEdit,
                        iconSize: 16,
                        icon: const Icon(Icons.more_horiz_rounded),
                        tooltip: 'Editar etiqueta',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 1.5),
                    ),
                    child: const SizedBox(width: 12, height: 12),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      folder.tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${folder.count} capturas',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

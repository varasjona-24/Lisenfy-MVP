import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../controller/capture_gallery_controller.dart';
import '../domain/capture_gallery_models.dart';

class CaptureTagsPage extends GetView<CaptureGalleryController> {
  const CaptureTagsPage({super.key});

  static const _palette = <int>[
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Obx(() {
      final folders = controller.tagFolders;

      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Etiquetas',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          forceMaterialTransparency: true,
        ),
        body: AppGradientBackground(
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
                          color: scheme.onSurfaceVariant.withValues(alpha: .55),
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
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: folders.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.08,
                  ),
                  itemBuilder: (context, index) {
                    return _TagFolderTile(
                      folder: folders[index],
                      onEdit: () => _editFolder(context, folders[index]),
                      onTap: () {
                        Get.offNamed(
                          AppRoutes.captureGallery,
                          arguments: {'query': folders[index].tag},
                        );
                      },
                    );
                  },
                ),
        ),
      );
    });
  }

  Future<void> _editFolder(
    BuildContext context,
    CaptureTagFolder folder,
  ) async {
    final nameCtrl = TextEditingController(text: folder.tag);
    var selectedColor = folder.colorValue;
    var selectedThumb =
        folder.thumbnailPath ??
        (folder.captures.isEmpty ? null : folder.captures.first.path);
    final result = await showDialog<_TagFolderEditResult>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Editar etiqueta'),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Color',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in _palette)
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => setState(() {
                                selectedColor = value;
                              }),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Color(value),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selectedColor == value
                                        ? scheme.onSurface
                                        : scheme.outlineVariant,
                                    width: selectedColor == value ? 3 : 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Thumbnail',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: folder.captures.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final capture = folder.captures[index];
                            final selected = selectedThumb == capture.path;
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(() {
                                selectedThumb = capture.path;
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected
                                        ? Color(selectedColor)
                                        : scheme.outlineVariant,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(capture.path),
                                    width: 84,
                                    height: 58,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (
                                          context,
                                          error,
                                          stackTrace,
                                        ) => ColoredBox(
                                          color: scheme.surfaceContainerHighest,
                                          child: const SizedBox(
                                            width: 84,
                                            height: 58,
                                            child: Icon(Icons.image_rounded),
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _TagFolderEditResult(
                      name: nameCtrl.text,
                      colorValue: selectedColor,
                      thumbnailPath: selectedThumb,
                    ),
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
    nameCtrl.dispose();
    if (result == null) return;
    final nextName = result.name.trim();
    if (nextName.isNotEmpty && nextName.toLowerCase() != folder.key) {
      await controller.renameTag(folder.key, nextName);
    }
    await controller.setTagCollection(
      tag: nextName.isNotEmpty ? nextName : folder.key,
      name: nextName.isNotEmpty ? nextName : folder.tag,
      colorValue: result.colorValue,
      thumbnailPath: result.thumbnailPath,
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
                    Positioned(
                      right: 4,
                      top: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 2),
                        ),
                        child: const SizedBox(width: 14, height: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                folder.tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
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

class _TagFolderEditResult {
  const _TagFolderEditResult({
    required this.name,
    required this.colorValue,
    this.thumbnailPath,
  });

  final String name;
  final int colorValue;
  final String? thumbnailPath;
}

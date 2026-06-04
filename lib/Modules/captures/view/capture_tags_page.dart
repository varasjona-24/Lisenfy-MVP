import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../controller/capture_gallery_controller.dart';
import '../domain/capture_gallery_models.dart';

class CaptureTagsPage extends GetView<CaptureGalleryController> {
  const CaptureTagsPage({super.key});

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
    final changed = await Get.toNamed(
      AppRoutes.editEntity,
      arguments: EditEntityArgs.captureTag(folder),
    );
    if (changed == true) {
      await controller.reload();
    }
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

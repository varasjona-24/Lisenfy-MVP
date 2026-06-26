import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../../sources/ui/source_filter_toolbar.dart';
import '../controller/capture_gallery_controller.dart';
import '../domain/capture_gallery_models.dart';

enum _CaptureTagSort { name, count, date, size }

class CaptureTagsPage extends StatefulWidget {
  const CaptureTagsPage({super.key});

  @override
  State<CaptureTagsPage> createState() => _CaptureTagsPageState();
}

class _CaptureTagsPageState extends State<CaptureTagsPage> {
  final CaptureGalleryController controller =
      Get.find<CaptureGalleryController>();
  final TextEditingController _searchCtrl = TextEditingController();
  _CaptureTagSort _sort = _CaptureTagSort.name;
  bool _ascending = true;

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
      final visibleFolders =
          (query.isEmpty
                ? folders.toList()
                : folders.where((folder) {
                    return folder.tag.toLowerCase().contains(query);
                  }).toList())
            ..sort((a, b) {
              final comparison = switch (_sort) {
                _CaptureTagSort.name => a.tag.toLowerCase().compareTo(
                  b.tag.toLowerCase(),
                ),
                _CaptureTagSort.count => a.count.compareTo(b.count),
                _CaptureTagSort.date => _latestModifiedAt(
                  a,
                ).compareTo(_latestModifiedAt(b)),
                _CaptureTagSort.size => _folderSize(
                  a,
                ).compareTo(_folderSize(b)),
              };
              return _ascending ? comparison : -comparison;
            });

      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('captures.tags.title'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${folders.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          centerTitle: true,
          forceMaterialTransparency: true,
          actions: [
            IconButton(
              tooltip: tr('captures.tags.create'),
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
                    SourceFilterToolbar(
                      controller: _searchCtrl,
                      query: query,
                      hintText: tr('captures.tags.search'),
                      onQueryChanged: (_) => setState(() {}),
                      onClearQuery: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                      onSort: _showSortSheet,
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
                                tr('captures.tags.empty'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tr('captures.tags.empty_body'),
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
                          tr('captures.tags.no_results', args: [query]),
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
                            onOptions: () =>
                                _showFolderOptions(context, folder),
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
    final changed = await Get.toNamed(
      AppRoutes.createEntity,
      preventDuplicates: false,
      arguments: const CreateEntityArgs.captureTag(
        storageId: 'capture_tag_create',
        initialColorValue: CaptureGalleryController.defaultTagColor,
      ),
    );
    if (changed == true) await controller.reload();
  }

  Future<void> _showSortSheet() async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void pick(_CaptureTagSort next) {
            setState(() {
              if (_sort == next) {
                _ascending = !_ascending;
              } else {
                _sort = next;
                _ascending = next == _CaptureTagSort.name;
              }
            });
            setSheetState(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('captures.tags.sort_title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TagSortOption(
                    icon: Icons.sort_by_alpha_rounded,
                    label: tr('captures.tags.name'),
                    selected: _sort == _CaptureTagSort.name,
                    ascending: _ascending,
                    onTap: () => pick(_CaptureTagSort.name),
                  ),
                  const SizedBox(height: 8),
                  _TagSortOption(
                    icon: Icons.numbers_rounded,
                    label: tr('captures.tags.capture_count'),
                    selected: _sort == _CaptureTagSort.count,
                    ascending: _ascending,
                    onTap: () => pick(_CaptureTagSort.count),
                  ),
                  const SizedBox(height: 8),
                  _TagSortOption(
                    icon: Icons.access_time_rounded,
                    label: tr('captures.tags.age'),
                    selected: _sort == _CaptureTagSort.date,
                    ascending: _ascending,
                    onTap: () => pick(_CaptureTagSort.date),
                  ),
                  const SizedBox(height: 8),
                  _TagSortOption(
                    icon: Icons.data_usage_rounded,
                    label: tr('captures.tags.folder_weight'),
                    selected: _sort == _CaptureTagSort.size,
                    ascending: _ascending,
                    onTap: () => pick(_CaptureTagSort.size),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  DateTime _latestModifiedAt(CaptureTagFolder folder) {
    if (folder.captures.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return folder.captures
        .map((capture) => capture.modifiedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  int _folderSize(CaptureTagFolder folder) {
    return folder.captures.fold<int>(
      0,
      (total, capture) => total + capture.size,
    );
  }

  Future<void> _showFolderOptions(
    BuildContext context,
    CaptureTagFolder folder,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(tr('common.edit')),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _editFolder(context, folder);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
              title: Text(
                tr('common.delete'),
                style: TextStyle(color: scheme.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteTag(context, folder);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTag(
    BuildContext context,
    CaptureTagFolder folder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('captures.tags.delete_title')),
        content: Text(
          tr(
            'captures.tags.delete_confirm',
            args: [folder.tag, '${folder.count}'],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('common.cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteTag(folder.key);
  }
}

class _TagSortOption extends StatelessWidget {
  const _TagSortOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.ascending,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest.withValues(alpha: .55),
      leading: Icon(icon, color: selected ? scheme.primary : null),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      trailing: selected
          ? Icon(
              ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: scheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _TagFolderTile extends StatelessWidget {
  const _TagFolderTile({
    required this.folder,
    required this.onTap,
    required this.onOptions,
  });

  final CaptureTagFolder folder;
  final VoidCallback onTap;
  final VoidCallback onOptions;

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
                        onPressed: onOptions,
                        iconSize: 16,
                        icon: const Icon(Icons.more_horiz_rounded),
                        tooltip: tr('captures.tags.edit'),
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
                tr('captures.tags.count_label', args: ['${folder.count}']),
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

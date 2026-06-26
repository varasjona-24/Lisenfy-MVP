import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../data/local/local_library_store.dart';
import '../models/media_item.dart';
import 'navigation_controller.dart';
import '../routes/app_routes.dart';
import '../../Modules/edit/controller/edit_entity_controller.dart';

class MediaActionsController extends GetxController {
  static const int externalShareLimitBytes = 300 * 1024 * 1024;
  static const int listenfyConnectShareLimitBytes = 1024 * 1024 * 1024;

  // ============================
  // 🔌 DEPENDENCIAS
  // ============================
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();

  // ============================
  // 🧭 NAVEGACION UI
  // ============================
  Future<bool?> openEditPage(MediaItem item) async {
    final result = await Get.toNamed(
      AppRoutes.editEntity,
      arguments: EditEntityArgs.media(item),
    );
    return result is bool ? result : null;
  }

  // ============================
  // ⭐️ FAVORITOS
  // ============================
  Future<void> toggleFavorite(
    MediaItem item, {
    Future<void> Function()? onChanged,
  }) async {
    try {
      final next = !item.isFavorite;
      final all = await _store.readAll();
      final pid = item.publicId.trim();

      final matches = all.where((e) {
        if (e.id == item.id) return true;
        return pid.isNotEmpty && e.publicId.trim() == pid;
      }).toList();

      if (matches.isEmpty) {
        await _store.upsert(item.copyWith(isFavorite: next));
      } else {
        for (final entry in matches) {
          await _store.upsert(entry.copyWith(isFavorite: next));
        }
      }

      if (onChanged != null) await onChanged();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      Get.snackbar(
        tr('dialogs.favorites.title'),
        tr('dialogs.favorites.update_error'),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ============================
  // 🗑️ ELIMINAR
  // ============================
  Future<void> deleteFromDevice(
    MediaItem item, {
    Future<void> Function()? onChanged,
  }) async {
    try {
      for (final v in item.variants) {
        final pth = v.localPath;
        if (pth != null && pth.isNotEmpty) {
          final f = File(pth);
          if (await f.exists()) await f.delete();
        }
      }

      await _store.remove(item.id);
      if (onChanged != null) await onChanged();

      Get.snackbar(
        'Imports',
        tr('media_actions.delete_success'),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Error deleting media: $e');
      Get.snackbar(
        'Imports',
        tr('media_actions.delete_error'),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> confirmDelete(
    BuildContext context,
    MediaItem item, {
    Future<void> Function()? onChanged,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('media_actions.delete_file_title')),
        content: Text(tr('media_actions.delete_file_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('common.cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('common.delete')),
          ),
        ],
      ),
    );

    if (ok == true) {
      await deleteFromDevice(item, onChanged: onChanged);
    }
  }

  // ============================
  // 🗑️ ELIMINAR MÚLTIPLES
  // ============================
  Future<void> deleteMultipleFromDevice(
    List<MediaItem> items, {
    Future<void> Function()? onChanged,
  }) async {
    if (items.isEmpty) return;

    try {
      var deletedCount = 0;
      var failedCount = 0;

      for (final item in items) {
        try {
          for (final v in item.variants) {
            final pth = v.localPath;
            if (pth != null && pth.isNotEmpty) {
              final f = File(pth);
              if (await f.exists()) await f.delete();
            }
          }
          await _store.remove(item.id);
          deletedCount++;
        } catch (e) {
          debugPrint('Error deleting media ${item.id}: $e');
          failedCount++;
        }
      }

      if (onChanged != null) await onChanged();

      if (deletedCount > 0) {
        final msg = deletedCount == 1
            ? tr('media_actions.deleted_one')
            : tr('media_actions.deleted_many', args: ['$deletedCount']);
        Get.snackbar(
          'Imports',
          failedCount > 0 ? '$msg ($failedCount ${tr('common.error')})' : msg,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else if (failedCount > 0) {
        Get.snackbar(
          'Imports',
          tr('media_actions.delete_files_error'),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      debugPrint('Error in deleteMultipleFromDevice: $e');
      Get.snackbar(
        'Imports',
        tr('media_actions.delete_files_error'),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> confirmDeleteMultiple(
    BuildContext context,
    List<MediaItem> items, {
    Future<void> Function()? onChanged,
  }) async {
    if (items.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('media_actions.delete_files_title')),
        content: Text(
          tr('media_actions.delete_files_body', args: ['${items.length}']),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('common.cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('common.delete')),
          ),
        ],
      ),
    );

    if (ok == true) {
      await deleteMultipleFromDevice(items, onChanged: onChanged);
    }
  }

  // ============================
  // 📤 COMPARTIR
  // ============================
  Future<int> shareSizeForItems(List<MediaItem> items) async {
    var total = 0;
    for (final item in items) {
      final variant = _pickShareVariant(item);
      final localPath = variant?.localPath?.trim() ?? '';
      if (localPath.isEmpty) continue;

      try {
        final file = File(localPath);
        if (await file.exists()) {
          total += await file.length();
        }
      } catch (e) {
        debugPrint('Error measuring media ${item.id}: $e');
      }
    }
    return total;
  }

  Future<void> shareMediaExternallyMultiple(List<MediaItem> items) async {
    if (items.isEmpty) return;

    try {
      final files = <XFile>[];
      var totalBytes = 0;
      var skipped = 0;

      for (final item in items) {
        final variant = _pickShareVariant(item);
        final localPath = variant?.localPath?.trim() ?? '';
        if (variant == null || localPath.isEmpty) {
          skipped++;
          continue;
        }

        final mediaFile = File(localPath);
        if (!await mediaFile.exists()) {
          skipped++;
          continue;
        }

        final length = await mediaFile.length();
        totalBytes += length;
        files.add(
          XFile(
            mediaFile.path,
            name: p.basename(mediaFile.path),
            mimeType: _guessMimeType(variant),
          ),
        );
      }

      if (files.isEmpty) {
        Get.snackbar(
          tr('media_actions.share'),
          tr('media_actions.no_local_files'),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      if (totalBytes > externalShareLimitBytes) {
        Get.snackbar(
          tr('media_actions.share_external'),
          tr('media_actions.external_limit'),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      await Share.shareXFiles(
        files,
        subject: tr('media_actions.shared_files_subject'),
        text: files.length == 1
            ? tr('media_actions.share_one_text')
            : tr('media_actions.share_many_text'),
      );

      if (skipped > 0) {
        Get.snackbar(
          tr('media_actions.share'),
          tr('media_actions.skipped_items', args: ['$skipped']),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      debugPrint('Error sharing media selection: $e');
      Get.snackbar(
        tr('media_actions.share'),
        tr('media_actions.share_failed'),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> transferMediaInternallyMultiple(List<MediaItem> items) async {
    if (items.isEmpty) return;

    final totalBytes = await shareSizeForItems(items);
    if (totalBytes > listenfyConnectShareLimitBytes) {
      Get.snackbar(
        'Listenfy Connect',
        tr('media_actions.internal_limit'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    await Get.toNamed(AppRoutes.nearbyTransfer, arguments: {'items': items});
  }

  Future<void> shareMediaExternally(MediaItem item) async {
    try {
      final variant = _pickShareVariant(item);

      if (variant == null) {
        Get.snackbar(
          tr('media_actions.share'),
          tr('media_actions.no_local_file'),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final localPath = variant.localPath?.trim();
      if (localPath == null || localPath.isEmpty) {
        Get.snackbar(
          tr('media_actions.share'),
          tr('media_actions.no_local_file'),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final mediaFile = File(localPath);
      if (!await mediaFile.exists()) {
        Get.snackbar(
          tr('media_actions.share'),
          tr('media_actions.file_missing'),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      await Share.shareXFiles(
        <XFile>[
          XFile(
            mediaFile.path,
            name: p.basename(mediaFile.path),
            mimeType: _guessMimeType(variant),
          ),
        ],
        subject: tr('media_actions.shared_file_subject'),
        text: tr('media_actions.share_song_text'),
      );
    } catch (e) {
      debugPrint('Error sharing song: $e');
      Get.snackbar(
        tr('media_actions.share'),
        tr('media_actions.song_share_failed'),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  MediaVariant? _pickShareVariant(MediaItem item) {
    final localVariants = item.variants.where((v) {
      final pth = v.localPath?.trim() ?? '';
      return pth.isNotEmpty;
    }).toList();
    if (localVariants.isEmpty) return null;

    for (final variant in localVariants) {
      if (variant.kind != MediaVariantKind.audio) continue;
      if (variant.isInstrumental || variant.isSpatial8d) continue;
      return variant;
    }

    for (final variant in localVariants) {
      if (variant.kind == MediaVariantKind.audio) return variant;
    }

    return localVariants.first;
  }

  String _guessMimeType(MediaVariant variant) {
    final ext = variant.format.toLowerCase().trim();
    if (variant.kind == MediaVariantKind.video) {
      return switch (ext) {
        'mp4' => 'video/mp4',
        'mov' => 'video/quicktime',
        'mkv' => 'video/x-matroska',
        'webm' => 'video/webm',
        _ => 'video/*',
      };
    }

    return switch (ext) {
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'wav' => 'audio/wav',
      'flac' => 'audio/flac',
      'aac' => 'audio/aac',
      'ogg' => 'audio/ogg',
      'opus' => 'audio/opus',
      _ => 'audio/*',
    };
  }

  // ============================
  // 🧾 ACCIONES UI
  // ============================
  Future<MediaItem> _resolveLatest(MediaItem item) async {
    try {
      final all = await _store.readAll();
      final pid = item.publicId.trim();
      for (final entry in all) {
        if (entry.id == item.id) return entry;
        if (pid.isNotEmpty && entry.publicId.trim() == pid) return entry;
      }
    } catch (e) {
      debugPrint('Error resolving latest item: $e');
    }
    return item;
  }

  Future<void> showItemActions(
    BuildContext context,
    MediaItem item, {
    Future<void> Function()? onChanged,
    VoidCallback? onStartMultiSelect,
  }) async {
    final theme = Theme.of(context);
    final nav = Get.isRegistered<NavigationController>()
        ? Get.find<NavigationController>()
        : null;

    final selected = item;
    Future<void> Function()? pendingAction;

    nav?.setOverlayOpen(true);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        final scheme = theme.colorScheme;
        final thumb = selected.effectiveThumbnail ?? '';
        final hasThumb = thumb.isNotEmpty;
        final isLocal = hasThumb && thumb.startsWith('/');

        return SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(ctx).size.height * 0.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 64,
                            height: 64,
                            color: scheme.surfaceContainerHigh,
                            child: hasThumb
                                ? (isLocal
                                      ? Image.file(
                                          File(thumb),
                                          fit: BoxFit.cover,
                                        )
                                      : Image.network(thumb, fit: BoxFit.cover))
                                : Icon(
                                    selected.localVideoVariant != null
                                        ? Icons.videocam_rounded
                                        : Icons.music_note_rounded,
                                    color: scheme.onSurfaceVariant,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selected.displaySubtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // Actions section
                  _ActionItem(
                    icon: Icons.edit_rounded,
                    label: tr('common.edit'),
                    onTap: () {
                      pendingAction = () async {
                        final latest = await _resolveLatest(selected);
                        final changed = await openEditPage(latest);
                        if (changed == true && onChanged != null) {
                          await onChanged();
                        }
                      };
                      Navigator.of(ctx).pop();
                    },
                  ),
                  if (onStartMultiSelect != null)
                    _ActionItem(
                      icon: Icons.checklist_rtl_rounded,
                      label: tr('media_actions.multi_select'),
                      onTap: () {
                        pendingAction = () async {
                          onStartMultiSelect();
                        };
                        Navigator.of(ctx).pop();
                      },
                    ),
                  _ActionItem(
                    icon: selected.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: selected.isFavorite
                        ? tr('media_actions.remove_favorite')
                        : tr('media_actions.add_favorite'),
                    color: selected.isFavorite ? scheme.primary : null,
                    onTap: () {
                      pendingAction = () async {
                        final latest = await _resolveLatest(selected);
                        await toggleFavorite(latest, onChanged: onChanged);
                      };
                      Navigator.of(ctx).pop();
                    },
                  ),
                  _ActionItem(
                    icon: Icons.delete_outline_rounded,
                    label: tr('media_actions.delete_device'),
                    color: Colors.redAccent,
                    onTap: () {
                      pendingAction = () async {
                        final latest = await _resolveLatest(selected);
                        if (!context.mounted) return;
                        await confirmDelete(
                          context,
                          latest,
                          onChanged: onChanged,
                        );
                      };
                      Navigator.of(ctx).pop();
                    },
                  ),
                  _ActionItem(
                    icon: Icons.bluetooth_searching_rounded,
                    label: tr('media_actions.transfer_offline'),
                    onTap: () {
                      pendingAction = () async {
                        final latest = await _resolveLatest(selected);
                        await Get.toNamed(
                          AppRoutes.nearbyTransfer,
                          arguments: {'item': latest},
                        );
                      };
                      Navigator.of(ctx).pop();
                    },
                  ),
                  _ActionItem(
                    icon: Icons.ios_share_rounded,
                    label: tr('media_actions.share_external'),
                    onTap: () {
                      pendingAction = () async {
                        final latest = await _resolveLatest(selected);
                        await shareMediaExternally(latest);
                      };
                      Navigator.of(ctx).pop();
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
    final action = pendingAction;
    if (action != null) {
      await action();
    }
    nav?.setOverlayOpen(false);
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (color ?? scheme.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color ?? scheme.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color ?? scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.outlineVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

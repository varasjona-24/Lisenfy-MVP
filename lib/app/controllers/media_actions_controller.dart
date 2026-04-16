import 'dart:io';

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
        'Favoritos',
        'No se pudo actualizar',
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
        'Eliminado correctamente',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Error deleting media: $e');
      Get.snackbar(
        'Imports',
        'Error al eliminar',
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
        title: const Text('Eliminar'),
        content: const Text('¿Eliminar este archivo importado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
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
            ? 'Se eliminó 1 archivo'
            : 'Se eliminaron $deletedCount archivos';
        Get.snackbar(
          'Imports',
          failedCount > 0
              ? '$msg ($failedCount error${failedCount > 1 ? 's' : ''})'
              : msg,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else if (failedCount > 0) {
        Get.snackbar(
          'Imports',
          'Error al eliminar archivos',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      debugPrint('Error in deleteMultipleFromDevice: $e');
      Get.snackbar(
        'Imports',
        'Error al eliminar archivos',
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
        title: const Text('Eliminar archivos'),
        content: Text(
          '¿Eliminar ${items.length} archivo${items.length > 1 ? 's' : ''} importado${items.length > 1 ? 's' : ''}?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
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
  Future<void> shareMediaExternally(MediaItem item) async {
    try {
      final variant = _pickShareVariant(item);

      if (variant == null) {
        Get.snackbar(
          'Compartir',
          'No hay archivo local para compartir.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final localPath = variant.localPath?.trim();
      if (localPath == null || localPath.isEmpty) {
        Get.snackbar(
          'Compartir',
          'No hay archivo local para compartir.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final mediaFile = File(localPath);
      if (!await mediaFile.exists()) {
        Get.snackbar(
          'Compartir',
          'El archivo ya no existe en el dispositivo.',
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
        subject: 'Archivo compartido desde Listenfy',
        text: 'Comparte esta canción/video con otra app o dispositivo.',
      );
    } catch (e) {
      debugPrint('Error sharing song: $e');
      Get.snackbar(
        'Compartir',
        'No se pudo compartir la canción.',
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Editar cancion'),
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
                  ListTile(
                    leading: const Icon(Icons.checklist_rtl_rounded),
                    title: const Text('Seleccionar varios'),
                    onTap: () {
                      pendingAction = () async {
                        onStartMultiSelect();
                      };
                      Navigator.of(ctx).pop();
                    },
                  ),
                ListTile(
                  leading: Icon(
                    selected.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                  title: Text(
                    selected.isFavorite
                        ? 'Quitar de favoritos'
                        : 'Agregar a favoritos',
                  ),
                  onTap: () {
                    pendingAction = () async {
                      final latest = await _resolveLatest(selected);
                      await toggleFavorite(latest, onChanged: onChanged);
                    };
                    Navigator.of(ctx).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Borrar del dispositivo'),
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
                ListTile(
                  leading: const Icon(Icons.bluetooth_searching_rounded),
                  title: const Text('Transferir a Listenfy (offline)'),
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
                ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: const Text('Compartir archivo (externo)'),
                  onTap: () {
                    pendingAction = () async {
                      final latest = await _resolveLatest(selected);
                      await shareMediaExternally(latest);
                    };
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
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

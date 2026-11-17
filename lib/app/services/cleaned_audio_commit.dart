import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/local/local_library_store.dart';
import '../models/media_item.dart';
import 'desktop_media_tools.dart';

/// Save the validated new variant durably before removing the old local audio.
class CleanedAudioCommit {
  CleanedAudioCommit(this.store, {bool Function(String)? isInUse})
    : _isInUse = isInUse ?? ((_) => false);
  final LocalLibraryStore store;
  final bool Function(String) _isInUse;

  static bool samePath(String? a, String? b) =>
      a != null &&
      b != null &&
      p.equals(
        p.absolute(DesktopMediaTools.localPath(a)),
        p.absolute(DesktopMediaTools.localPath(b)),
      );

  Future<({MediaItem item, bool originalRetained})> save({
    required MediaItem media,
    required MediaVariant cleaned,
    required String sourcePath,
    required bool replaceOriginal,
  }) async {
    final newFile = File(cleaned.localPath!);
    if (samePath(sourcePath, newFile.path) ||
        !await newFile.exists() ||
        await newFile.length() == 0) {
      throw StateError('La versión limpia no es válida.');
    }
    final withBoth = media.copyWith(
      variants: [
        cleaned,
        ...media.variants.where(
          (v) => !samePath(v.localPath, cleaned.localPath),
        ),
      ],
    );
    await store.upsert(withBoth);
    if (!replaceOriginal) return (item: withBoth, originalRetained: true);
    final remaining = withBoth.variants
        .where(
          (v) =>
              !(samePath(v.localPath, sourcePath) &&
                  v.kind == MediaVariantKind.audio &&
                  !v.isInstrumental &&
                  !v.isSpatial8d),
        )
        .toList();
    final shared =
        remaining.any((v) => samePath(v.localPath, sourcePath)) ||
        (await store.readAll()).any(
          (item) =>
              item.id != media.id &&
              item.variants.any((v) => samePath(v.localPath, sourcePath)),
        );
    if (shared || _isInUse(sourcePath)) {
      return (item: withBoth, originalRetained: true);
    }
    final replaced = withBoth.copyWith(variants: remaining);
    // If this save fails, the original file is still untouched.
    await store.upsert(replaced);
    try {
      final original = File(DesktopMediaTools.localPath(sourcePath));
      if (await original.exists()) await original.delete();
      return (item: replaced, originalRetained: false);
    } on FileSystemException {
      // Windows can reject deletion if another process has opened the file.
      await store.upsert(withBoth);
      return (item: withBoth, originalRetained: true);
    }
  }
}

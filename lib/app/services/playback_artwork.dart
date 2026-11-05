import 'dart:convert';
import 'dart:io';
import '../models/media_item.dart';

/// Resolves notification/lock-screen artwork without selecting a stale file.
Uri? resolvePlaybackArtwork(
  MediaItem item, {
  required bool android,
  required String androidAuthority,
  bool Function(String path)? fileExists,
}) {
  bool exists(String path) {
    try {
      return (fileExists ?? (path) => File(path).existsSync())(path);
    } on FileSystemException {
      return false;
    }
  }

  Uri? localArtwork(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final raw = value.trim();
    final uri = Uri.tryParse(raw);
    String path;
    try {
      path = uri?.scheme == 'file' ? uri!.toFilePath() : raw;
    } on ArgumentError {
      return null;
    }
    if (!exists(path)) return null;
    if (!android) return Uri.file(path);
    return Uri(
      scheme: 'content',
      host: androidAuthority,
      pathSegments: [
        'cover',
        base64Url.encode(utf8.encode(path)).replaceAll('=', ''),
      ],
    );
  }

  final local = localArtwork(item.thumbnailLocalPath);
  if (local != null) return local;
  final remote = item.thumbnail?.trim();
  if (remote == null || remote.isEmpty) return null;
  final uri = Uri.tryParse(remote);
  if (uri != null &&
      ['https', 'http'].contains(uri.scheme) &&
      uri.host.isNotEmpty) {
    return uri;
  }
  // Older library entries can store a local path in the thumbnail field.
  return localArtwork(remote);
}

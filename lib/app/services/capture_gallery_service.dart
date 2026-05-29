import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ListenfyCapture {
  const ListenfyCapture({
    required this.path,
    required this.name,
    required this.modifiedAt,
    required this.size,
  });

  final String path;
  final String name;
  final DateTime modifiedAt;
  final int size;
}

class CaptureGalleryService {
  static const directoryName = 'ListenfyCaptures';

  const CaptureGalleryService();

  Future<Directory> captureDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, directoryName));
    await dir.create(recursive: true);
    return dir;
  }

  Future<String> saveCapture({
    required Uint8List bytes,
    required String title,
  }) async {
    final dir = await captureDirectory();
    final fileName =
        'listenfy_capture_${sanitizeFileName(title)}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<List<ListenfyCapture>> listCaptures() async {
    final dir = await captureDirectory();
    final captures = <ListenfyCapture>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.jpg' && ext != '.jpeg' && ext != '.png') continue;
      final stat = await entity.stat();
      captures.add(
        ListenfyCapture(
          path: entity.path,
          name: p.basenameWithoutExtension(entity.path),
          modifiedAt: stat.modified,
          size: stat.size,
        ),
      );
    }
    captures.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return captures;
  }

  Future<String> renameCapture(String path, String nextName) async {
    final clean = sanitizeFileName(nextName);
    if (clean.isEmpty) {
      throw ArgumentError('El nombre no puede estar vacío.');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('La captura no existe.', path);
    }
    final ext = p.extension(path).isEmpty ? '.jpg' : p.extension(path);
    final dir = p.dirname(path);
    var candidate = p.join(dir, '$clean$ext');
    var index = 2;
    while (await File(candidate).exists() && candidate != path) {
      candidate = p.join(dir, '${clean}_$index$ext');
      index++;
    }
    final renamed = await file.rename(candidate);
    return renamed.path;
  }

  Future<void> deleteCapture(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static String sanitizeFileName(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.isEmpty ? 'captura' : sanitized;
  }
}

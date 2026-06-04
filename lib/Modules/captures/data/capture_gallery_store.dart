import 'dart:io';
import 'dart:typed_data';

import 'package:get_storage/get_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/capture_item.dart';

class CaptureGalleryStore {
  static const directoryName = 'ListenfyCaptures';
  static const _tagsKey = 'capture_gallery_tags';
  static const _tagColorsKey = 'capture_gallery_tag_colors';

  CaptureGalleryStore(this._box);

  final GetStorage _box;

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

  Future<List<CaptureItem>> listCaptures() async {
    final dir = await captureDirectory();
    final captures = <CaptureItem>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.jpg' && ext != '.jpeg' && ext != '.png') continue;
      final stat = await entity.stat();
      captures.add(
        CaptureItem(
          path: entity.path,
          name: p.basenameWithoutExtension(entity.path),
          modifiedAt: stat.modified,
          size: stat.size,
          tags: tagsFor(entity.path),
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
    final tags = tagsFor(path);
    if (tags.isNotEmpty) {
      await removeTags(path);
      await setTags(renamed.path, tags);
    }
    return renamed.path;
  }

  Future<void> deleteCapture(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    await removeTags(path);
  }

  List<String> tagsFor(String path) {
    final raw = _box.read<Map>(_tagsKey) ?? const {};
    final value = raw[path];
    if (value is! List) return const <String>[];
    return normalizeTags(value.map((e) => e.toString()));
  }

  Future<void> setTags(String path, Iterable<String> tags) async {
    final raw = _box.read<Map>(_tagsKey) ?? const {};
    final next = Map<String, dynamic>.from(raw);
    final normalized = normalizeTags(tags);
    if (normalized.isEmpty) {
      next.remove(path);
    } else {
      next[path] = normalized;
    }
    await _box.write(_tagsKey, next);
  }

  Map<String, int> tagColors() {
    final raw = _box.read<Map>(_tagColorsKey) ?? const {};
    final colors = <String, int>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      if (key.isEmpty) continue;
      final value = entry.value;
      final color = value is num ? value.toInt() : int.tryParse('$value');
      if (color == null) continue;
      colors[key] = color;
    }
    return colors;
  }

  Future<void> setTagColor(String tag, int colorValue) async {
    final clean = tag.trim();
    if (clean.isEmpty) return;
    final next = Map<String, dynamic>.from(
      _box.read<Map>(_tagColorsKey) ?? const {},
    );
    next[clean.toLowerCase()] = colorValue;
    await _box.write(_tagColorsKey, next);
  }

  Future<void> removeTags(String path) async {
    final raw = _box.read<Map>(_tagsKey) ?? const {};
    if (!raw.containsKey(path)) return;
    final next = Map<String, dynamic>.from(raw)..remove(path);
    await _box.write(_tagsKey, next);
  }

  Future<void> restoreTags(String path, Iterable<String> tags) async {
    await setTags(path, tags);
  }

  static String sanitizeFileName(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.isEmpty ? 'captura' : sanitized;
  }

  static List<String> normalizeTags(Iterable<String> tags) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final raw in tags) {
      final tag = raw.trim();
      if (tag.isEmpty) continue;
      final key = tag.toLowerCase();
      if (!seen.add(key)) continue;
      normalized.add(tag);
      if (normalized.length >= 20) break;
    }
    return normalized;
  }
}

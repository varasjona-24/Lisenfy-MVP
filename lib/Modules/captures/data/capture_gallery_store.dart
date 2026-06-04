import 'dart:io';
import 'dart:typed_data';

import 'package:get_storage/get_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/capture_tag_collection.dart';
import '../domain/capture_item.dart';

class CaptureGalleryStore {
  static const directoryName = 'ListenfyCaptures';
  static const _tagsKey = 'capture_gallery_tags';
  static const _tagColorsKey = 'capture_gallery_tag_colors';
  static const _sourceKey = 'capture_gallery_sources';
  static const _tagCollectionsKey = 'capture_gallery_tag_collections';

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
    String? sourceTitle,
    String? sourceId,
  }) async {
    final dir = await captureDirectory();
    final fileName =
        'listenfy_capture_${sanitizeFileName(title)}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await setSource(file.path, title: sourceTitle ?? title, sourceId: sourceId);
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
          sourceTitle: sourceFor(entity.path).title,
          sourceId: sourceFor(entity.path).id,
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
    final source = sourceFor(path);
    if (tags.isNotEmpty) {
      await removeTags(path);
      await setTags(renamed.path, tags);
    }
    if (source.title != null || source.id != null) {
      await removeSource(path);
      await setSource(renamed.path, title: source.title, sourceId: source.id);
    }
    return renamed.path;
  }

  Future<void> deleteCapture(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    await removeTags(path);
    await removeSource(path);
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
    for (final tag in normalized) {
      await ensureTagCollection(tag, thumbnailPath: path);
    }
  }

  Map<String, int> tagColors() {
    final rawCollections = _box.read<Map>(_tagCollectionsKey) ?? const {};
    final colors = <String, int>{};
    for (final entry in rawCollections.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      final value = entry.value;
      if (key.isEmpty || value is! Map) continue;
      final color = value['colorValue'];
      final parsed = color is num ? color.toInt() : int.tryParse('$color');
      if (parsed != null) colors[key] = parsed;
    }
    colors.addAll(_legacyTagColors());
    return colors;
  }

  Map<String, int> _legacyTagColors() {
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
    await setTagCollection(tag, colorValue: colorValue);
  }

  Map<String, CaptureTagCollection> tagCollections({
    required int fallbackColor,
  }) {
    final raw = _box.read<Map>(_tagCollectionsKey) ?? const {};
    final legacyColors = _legacyTagColors();
    final collections = <String, CaptureTagCollection>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      final value = entry.value;
      if (key.isEmpty || value is! Map) continue;
      collections[key] = CaptureTagCollection.fromJson(
        value,
        fallbackName: key,
        fallbackColor: legacyColors[key] ?? fallbackColor,
      );
    }
    for (final entry in legacyColors.entries) {
      collections.putIfAbsent(
        entry.key,
        () => CaptureTagCollection(name: entry.key, colorValue: entry.value),
      );
    }
    return collections;
  }

  Future<void> ensureTagCollection(
    String tag, {
    String? thumbnailPath,
    int fallbackColor = 0xFF7C8BA1,
  }) async {
    final clean = tag.trim();
    if (clean.isEmpty) return;
    final next = Map<String, dynamic>.from(
      _box.read<Map>(_tagCollectionsKey) ?? const {},
    );
    final key = clean.toLowerCase();
    if (next.containsKey(key)) return;
    next[key] = CaptureTagCollection(
      name: clean,
      colorValue: tagColors()[key] ?? fallbackColor,
      thumbnailPath: thumbnailPath,
    ).toJson();
    await _box.write(_tagCollectionsKey, next);
  }

  Future<void> setTagCollection(
    String tag, {
    String? name,
    int? colorValue,
    String? thumbnailPath,
  }) async {
    final clean = tag.trim();
    if (clean.isEmpty) return;
    final key = clean.toLowerCase();
    final collections = tagCollections(fallbackColor: 0xFF7C8BA1);
    final current =
        collections[key] ??
        CaptureTagCollection(
          name: clean,
          colorValue: tagColors()[key] ?? 0xFF7C8BA1,
        );
    final next = Map<String, dynamic>.from(
      _box.read<Map>(_tagCollectionsKey) ?? const {},
    );
    next[key] = CaptureTagCollection(
      name: name?.trim().isNotEmpty == true ? name!.trim() : current.name,
      colorValue: colorValue ?? current.colorValue,
      thumbnailPath: thumbnailPath?.trim().isNotEmpty == true
          ? thumbnailPath!.trim()
          : current.thumbnailPath,
    ).toJson();
    await _box.write(_tagCollectionsKey, next);
  }

  Future<void> renameTag(String oldTag, String nextName) async {
    final oldKey = oldTag.trim().toLowerCase();
    final cleanName = nextName.trim();
    final newKey = cleanName.toLowerCase();
    if (oldKey.isEmpty || newKey.isEmpty || oldKey == newKey) return;

    final rawTags = _box.read<Map>(_tagsKey) ?? const {};
    final updatedTags = Map<String, dynamic>.from(rawTags);
    for (final entry in rawTags.entries) {
      final tags = normalizeTags(
        (entry.value is List ? entry.value as List : const [])
            .map((e) => e.toString())
            .map((tag) => tag.trim().toLowerCase() == oldKey ? cleanName : tag),
      );
      updatedTags[entry.key.toString()] = tags;
    }
    await _box.write(_tagsKey, updatedTags);

    final rawCollections = Map<String, dynamic>.from(
      _box.read<Map>(_tagCollectionsKey) ?? const {},
    );
    final current = rawCollections.remove(oldKey);
    if (current is Map) {
      final parsed = CaptureTagCollection.fromJson(
        current,
        fallbackName: oldTag,
        fallbackColor: tagColors()[oldKey] ?? 0xFF7C8BA1,
      );
      rawCollections[newKey] = CaptureTagCollection(
        name: cleanName,
        colorValue: parsed.colorValue,
        thumbnailPath: parsed.thumbnailPath,
      ).toJson();
      await _box.write(_tagCollectionsKey, rawCollections);
    }
  }

  ({String? title, String? id}) sourceFor(String path) {
    final raw = _box.read<Map>(_sourceKey) ?? const {};
    final value = raw[path];
    if (value is! Map) return (title: null, id: null);
    final title = value['title']?.toString().trim();
    final id = value['id']?.toString().trim();
    return (
      title: title == null || title.isEmpty ? null : title,
      id: id == null || id.isEmpty ? null : id,
    );
  }

  Future<void> setSource(String path, {String? title, String? sourceId}) async {
    final cleanTitle = title?.trim();
    final cleanId = sourceId?.trim();
    if ((cleanTitle == null || cleanTitle.isEmpty) &&
        (cleanId == null || cleanId.isEmpty)) {
      return;
    }
    final raw = _box.read<Map>(_sourceKey) ?? const {};
    final next = Map<String, dynamic>.from(raw);
    next[path] = {
      if (cleanTitle != null && cleanTitle.isNotEmpty) 'title': cleanTitle,
      if (cleanId != null && cleanId.isNotEmpty) 'id': cleanId,
    };
    await _box.write(_sourceKey, next);
  }

  Future<void> removeSource(String path) async {
    final raw = _box.read<Map>(_sourceKey) ?? const {};
    if (!raw.containsKey(path)) return;
    final next = Map<String, dynamic>.from(raw)..remove(path);
    await _box.write(_sourceKey, next);
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

  Future<void> restoreTagCollections(
    Map<dynamic, dynamic> rawCollections,
  ) async {
    final next = Map<String, dynamic>.from(
      _box.read<Map>(_tagCollectionsKey) ?? const {},
    );
    for (final entry in rawCollections.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      final value = entry.value;
      if (key.isEmpty || value is! Map) continue;
      final parsed = CaptureTagCollection.fromJson(
        value,
        fallbackName: key,
        fallbackColor: tagColors()[key] ?? 0xFF7C8BA1,
      );
      next[key] = parsed.toJson();
    }
    await _box.write(_tagCollectionsKey, next);
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

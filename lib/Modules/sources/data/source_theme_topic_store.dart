import 'package:get_storage/get_storage.dart';

import '../domain/source_theme_topic.dart';

class SourceThemeTopicStore {
  // ============================
  // 💾 STORAGE
  // ============================
  SourceThemeTopicStore(this._box);

  final GetStorage _box;
  static const _key = 'source_theme_topics';

  // ============================
  // 📚 READ
  // ============================
  Future<List<SourceThemeTopic>> readAll() async {
    return readAllSync();
  }

  List<SourceThemeTopic> readAllSync() {
    final raw = _box.read<List>(_key) ?? <dynamic>[];
    return raw
        .whereType<Map>()
        .map((m) => SourceThemeTopic.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  // ============================
  // ✍️ WRITE
  // ============================
  Future<void> upsert(SourceThemeTopic topic) async {
    final list = await readAll();
    final idx = list.indexWhere((e) => e.id == topic.id);
    if (idx == -1) {
      list.insert(0, topic);
    } else {
      list[idx] = topic;
    }
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }

  Future<void> upsertAll(List<SourceThemeTopic> topics) async {
    if (topics.isEmpty) return;

    final existing = await readAll();
    final incomingIds = topics.map((e) => e.id).toSet();
    final merged = <SourceThemeTopic>[
      ...topics.reversed,
      ...existing.where((e) => !incomingIds.contains(e.id)),
    ];

    await _box.write(_key, merged.map((e) => e.toJson()).toList());
  }

  // ============================
  // 🗑️ DELETE
  // ============================
  Future<void> remove(String id) async {
    final list = await readAll();
    list.removeWhere((e) => e.id == id);
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }
}

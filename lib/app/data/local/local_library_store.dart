import 'package:get_storage/get_storage.dart';
import '../../models/media_item.dart';

class LocalLibraryStore {
  LocalLibraryStore(this._box);

  final GetStorage _box;
  static const _key = 'local_library_items';

  Future<List<MediaItem>> readAll() async {
    return readAllSync();
  }

  List<MediaItem> readAllSync() {
    final raw = _box.read<List>(_key) ?? <dynamic>[];
    return raw
        .whereType<Map>()
        .map((m) => MediaItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> upsert(MediaItem item) async {
    final list = await readAll();
    final idx = list.indexWhere((e) => e.id == item.id);

    if (idx == -1) {
      list.insert(0, item);
    } else {
      list[idx] = item;
    }

    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }

  Future<void> remove(String id) async {
    final list = await readAll();
    list.removeWhere((e) => e.id == id);
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }
}

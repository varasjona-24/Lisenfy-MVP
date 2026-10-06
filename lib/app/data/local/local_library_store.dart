import 'package:get_storage/get_storage.dart';
import '../../models/media_item.dart';
import 'catalog_storage.dart';

class LocalLibraryStore {
  LocalLibraryStore(GetStorage box, {this.metricsLoader})
    : _box = catalogStorage(box);
  final Future<Map<String, Map<String, dynamic>>> Function()? metricsLoader;
  Map<String, Map<String, dynamic>> _metrics = {};
  Object? _preservedSnapshot;
  Map<String, Map<String, dynamic>> _preservedMetricFields = {};

  final GetStorage _box;
  static const _key = 'local_library_items';
  int _revision = 0;
  Object? _lastSnapshot;

  /// Detect in-memory replacement immediately, including other store instances.
  int get revision {
    final snapshot = _box.read<List>(_key);
    if (!identical(snapshot, _lastSnapshot)) {
      _lastSnapshot = snapshot;
      _revision++;
    }
    return _revision;
  }

  Future<List<MediaItem>> readAll() async {
    final loader = metricsLoader;
    if (loader != null) {
      _metrics = await loader();
      _revision++;
    }
    return readAllSync();
  }

  List<MediaItem> readAllSync() {
    final raw = _box.read<List>(_key) ?? <dynamic>[];
    return raw.whereType<Map>().map((m) {
      final json = Map<String, dynamic>.from(m);
      if (metricsLoader != null) {
        json.addAll(
          _metrics[json['id']] ??
              {
                'playCount': 0,
                'skipCount': 0,
                'fullListenCount': 0,
                'avgListenProgress': 0.0,
                'lastPlayedAt': null,
                'lastCompletedAt': null,
              },
        );
      }
      return MediaItem.fromJson(json);
    }).toList();
  }

  Future<void> upsert(MediaItem item) async {
    final list = await readAll();
    final idx = list.indexWhere((e) => e.id == item.id);

    if (idx == -1) {
      list.insert(0, item);
    } else {
      list[idx] = item;
    }

    await _box.write(_key, list.map(_metadataJson).toList());
  }

  Future<void> upsertAll(List<MediaItem> items) async {
    if (items.isEmpty) return;

    final existing = await readAll();
    final incomingIds = items.map((e) => e.id).toSet();
    final merged = <MediaItem>[
      ...items.reversed,
      ...existing.where((e) => !incomingIds.contains(e.id)),
    ];

    await _box.write(_key, merged.map(_metadataJson).toList());
  }

  Future<void> remove(String id) async {
    final list = await readAll();
    list.removeWhere((e) => e.id == id);
    await _box.write(_key, list.map(_metadataJson).toList());
  }

  Map<String, dynamic> _metadataJson(MediaItem item) {
    final json = item.toJson();
    if (metricsLoader != null) {
      const fields = [
        'playCount',
        'skipCount',
        'fullListenCount',
        'avgListenProgress',
        'lastPlayedAt',
        'lastCompletedAt',
      ];
      final raw = _box.read<List>(_key);
      if (!identical(raw, _preservedSnapshot)) {
        _preservedSnapshot = raw;
        _preservedMetricFields = {
          for (final entry in (raw ?? []).whereType<Map>())
            if (entry['id'] is String)
              entry['id'] as String: {
                for (final key in fields)
                  if (entry.containsKey(key)) key: entry[key],
              },
        };
      }
      for (final key in fields) {
        json.remove(key);
      }
      // Keep the untouched legacy baseline when testing with the same app id.
      // Projected SQL counters are NEVER written back into GetStorage.
      json.addAll(_preservedMetricFields[item.id] ?? {});
    }
    return json;
  }
}

import 'package:get_storage/get_storage.dart';

import '../../../app/utils/artist_credit_parser.dart';
import '../domain/artist_profile.dart';

class ArtistStore {
  ArtistStore(this._box);

  final GetStorage _box;
  static const _key = 'artist_profiles';

  Future<List<ArtistProfile>> readAll() async {
    return readAllSync();
  }

  List<ArtistProfile> readAllSync() {
    final raw = _box.read<List>(_key) ?? <dynamic>[];
    return raw
        .whereType<Map>()
        .map((m) => ArtistProfile.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<ArtistProfile?> getByKey(String key) async {
    return getByKeySync(key);
  }

  ArtistProfile? getByKeySync(String key) {
    final target = ArtistCreditParser.normalizeKey(key);
    if (target.isEmpty || target == 'unknown') return null;
    final list = readAllSync();
    for (final profile in list) {
      if (ArtistCreditParser.normalizeKey(profile.key) == target) {
        return profile;
      }
    }
    return null;
  }

  Future<void> upsert(ArtistProfile profile) async {
    final list = await readAll();
    final idx = list.indexWhere((e) => e.key == profile.key);
    if (idx == -1) {
      list.insert(0, profile);
    } else {
      list[idx] = profile;
    }
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }

  Future<void> remove(String key) async {
    final list = await readAll();
    list.removeWhere((e) => e.key == key);
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }
}

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../data/artist_store.dart';
import '../domain/artist_profile.dart';

enum ArtistSort { name, count, random }

class ArtistGroup {
  final String key;
  final String name;
  final int count;
  final String? country;
  final String? countryCode;
  final ArtistMainRegion mainRegion;
  final String? thumbnail;
  final String? thumbnailLocalPath;
  final ArtistProfileKind kind;
  final List<String> memberKeys;
  final List<MediaItem> items;

  ArtistGroup({
    required this.key,
    required this.name,
    required this.count,
    required this.items,
    required this.kind,
    this.country,
    this.countryCode,
    this.mainRegion = ArtistMainRegion.none,
    this.memberKeys = const <String>[],
    this.thumbnail,
    this.thumbnailLocalPath,
  });
}

class _ArtistBucket {
  _ArtistBucket({required this.key, required this.name});

  final String key;
  String name;
  String? fallbackThumb;
  final List<MediaItem> items = <MediaItem>[];
}

class ArtistsController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final ArtistStore _artistStore = Get.find<ArtistStore>();

  final RxList<ArtistGroup> artists = <ArtistGroup>[].obs;
  final RxList<ArtistGroup> recentArtists = <ArtistGroup>[].obs;
  final RxBool isLoading = false.obs;
  final RxString query = ''.obs;
  final Rx<ArtistSort> sort = ArtistSort.name.obs;
  final RxBool sortAscending = true.obs;
  final RxBool bandsMinimized = false.obs;
  final RxBool singersMinimized = false.obs;

  String? _normalizeCountryCode(String? raw) {
    final value = (raw ?? '').trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(value)) return null;
    return value;
  }

  List<String> _normalizeMemberKeysForOwner({
    required String ownerKey,
    required List<String> members,
  }) {
    final owner = ArtistCreditParser.normalizeKey(ownerKey);
    final out = <String>[];
    final seen = <String>{};
    for (final raw in members) {
      final key = ArtistCreditParser.normalizeKey(raw);
      if (key.isEmpty || key == 'unknown') continue;
      if (key == owner) continue;
      if (!seen.add(key)) continue;
      out.add(key);
    }
    return out;
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final items = (await _repo.getLibrary())
          .where(
            (item) =>
                item.variants.any((v) => v.kind == MediaVariantKind.audio),
          )
          .toList();
      final profiles = await _artistStore.readAll();
      final profilesByKey = {for (final p in profiles) p.key: p};
      final memberKeysReferencedByBands = <String>{};
      for (final profile in profiles) {
        if (profile.kind != ArtistProfileKind.band) continue;
        for (final member in profile.memberKeys) {
          final key = ArtistCreditParser.normalizeKey(member);
          if (key.isEmpty || key == 'unknown') continue;
          memberKeysReferencedByBands.add(key);
        }
      }

      final Map<String, _ArtistBucket> grouped = {};
      for (final item in items) {
        final credits = ArtistCreditParser.parse(item.subtitle);
        final artistNames = credits.allArtists;

        if (artistNames.isEmpty) {
          final key = ArtistCreditParser.normalizeKey(item.subtitle);
          final bucket = grouped.putIfAbsent(
            key,
            () => _ArtistBucket(key: key, name: 'Artista desconocido'),
          );
          bucket.items.add(item);
          bucket.fallbackThumb ??= item.effectiveThumbnail;
          continue;
        }

        for (final artistName in artistNames) {
          final key = ArtistCreditParser.normalizeKey(artistName);
          final bucket = grouped.putIfAbsent(
            key,
            () => _ArtistBucket(key: key, name: artistName),
          );
          bucket.name = bucket.name.trim().isEmpty ? artistName : bucket.name;
          bucket.items.add(item);
          bucket.fallbackThumb ??= item.effectiveThumbnail;
        }
      }

      for (final profile in profiles) {
        final key = profile.key.trim();
        if (key.isEmpty) continue;
        final hasSongs = grouped.containsKey(key);
        final shouldIncludeWithoutSongs =
            profile.kind == ArtistProfileKind.band ||
            memberKeysReferencedByBands.contains(key);
        if (!hasSongs && !shouldIncludeWithoutSongs) continue;

        grouped.putIfAbsent(
          key,
          () => _ArtistBucket(
            key: key,
            name: profile.displayName.trim().isEmpty
                ? 'Artista desconocido'
                : profile.displayName.trim(),
          ),
        );
      }

      final list = <ArtistGroup>[];
      for (final entry in grouped.entries) {
        final bucket = entry.value;
        final key = bucket.key;
        final itemsForArtist = bucket.items;
        final profile = profilesByKey[key];
        final displayName = (profile?.displayName.trim().isNotEmpty == true)
            ? profile!.displayName
            : (bucket.name.trim().isNotEmpty
                  ? bucket.name
                  : 'Artista desconocido');

        list.add(
          ArtistGroup(
            key: key,
            name: displayName,
            count: itemsForArtist.length,
            items: itemsForArtist,
            kind: profile?.kind ?? ArtistProfileKind.singer,
            country: profile?.country,
            countryCode: profile?.countryCode,
            mainRegion: profile?.mainRegion ?? ArtistMainRegion.none,
            memberKeys: _normalizeMemberKeysForOwner(
              ownerKey: key,
              members: profile?.memberKeys ?? const <String>[],
            ),
            thumbnail: profile?.thumbnail ?? bucket.fallbackThumb,
            thumbnailLocalPath: profile?.thumbnailLocalPath,
          ),
        );
      }

      artists.assignAll(_applySort(list));
      _refreshRecentArtists(list);
    } catch (e) {
      debugPrint('Error loading artists: $e');
    } finally {
      isLoading.value = false;
    }
  }

  List<ArtistGroup> get filtered {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return artists.toList();
    return artists.where((a) {
      final name = a.name.toLowerCase();
      final country = (a.country ?? '').trim().toLowerCase();
      final countryCode = (a.countryCode ?? '').trim().toLowerCase();
      final region = a.mainRegion.label.toLowerCase();
      return name.contains(q) ||
          country.contains(q) ||
          countryCode.contains(q) ||
          region.contains(q);
    }).toList();
  }

  void setQuery(String value) {
    query.value = value;
  }

  void setSort(ArtistSort value) {
    sort.value = value;
    artists.assignAll(_applySort(artists));
    _refreshRecentArtists(artists);
  }

  void setSortAscending(bool value) {
    sortAscending.value = value;
    artists.assignAll(_applySort(artists));
    _refreshRecentArtists(artists);
  }

  void toggleBandsMinimized() {
    bandsMinimized.value = !bandsMinimized.value;
  }

  void toggleSingersMinimized() {
    singersMinimized.value = !singersMinimized.value;
  }

  List<ArtistGroup> _applySort(List<ArtistGroup> input) {
    final list = List<ArtistGroup>.from(input);
    switch (sort.value) {
      case ArtistSort.count:
        list.sort((a, b) => a.count.compareTo(b.count));
        break;
      case ArtistSort.random:
        list.shuffle(Random());
        break;
      case ArtistSort.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    if (sort.value != ArtistSort.random && !sortAscending.value) {
      return list.reversed.toList();
    }
    return list;
  }

  void _refreshRecentArtists(List<ArtistGroup> source) {
    final recent =
        source
            .map(
              (artist) => MapEntry(
                artist,
                artist.items
                    .map((e) => e.lastPlayedAt ?? 0)
                    .fold<int>(0, (a, b) => a > b ? a : b),
              ),
            )
            .where((entry) => entry.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    recentArtists.assignAll(recent.map((e) => e.key).take(8));
  }

  Future<void> updateArtist({
    required String key,
    required String newName,
    required String country,
    String? countryCode,
    required ArtistMainRegion mainRegion,
    required ArtistProfileKind kind,
    required List<String> memberKeys,
    String? thumbnail,
    String? thumbnailLocalPath,
  }) async {
    final normalizedCurrentKey = ArtistCreditParser.normalizeKey(key);
    final normalizedNewKey = ArtistCreditParser.normalizeKey(newName);
    final normalizedMembers = kind == ArtistProfileKind.band
        ? _normalizeMemberKeysForOwner(
            ownerKey: normalizedNewKey,
            members: memberKeys,
          )
        : const <String>[];

    if (normalizedCurrentKey != normalizedNewKey) {
      await _artistStore.remove(normalizedCurrentKey);
    }

    final profile = ArtistProfile(
      key: normalizedNewKey,
      displayName: newName.trim().isEmpty
          ? 'Artista desconocido'
          : newName.trim(),
      country: country.trim(),
      countryCode: _normalizeCountryCode(countryCode),
      mainRegion: mainRegion,
      thumbnail: thumbnail,
      thumbnailLocalPath: thumbnailLocalPath,
      kind: kind,
      memberKeys: normalizedMembers,
    );
    await _artistStore.upsert(profile);

    final all = await _store.readAll();
    for (final item in all) {
      final credits = ArtistCreditParser.parse(item.subtitle);
      if (!credits.containsArtistKey(normalizedCurrentKey)) continue;

      final nextArtistField = ArtistCreditParser.replaceArtistName(
        item.subtitle,
        artistKey: normalizedCurrentKey,
        newName: profile.displayName,
      );

      if (nextArtistField == item.subtitle.trim()) continue;
      await _store.upsert(item.copyWith(subtitle: nextArtistField));
    }

    final allProfiles = await _artistStore.readAll();
    for (final existing in allProfiles) {
      if (existing.key == profile.key) continue;

      final remapped = existing.memberKeys
          .map(
            (member) =>
                ArtistCreditParser.normalizeKey(member) == normalizedCurrentKey
                ? normalizedNewKey
                : member,
          )
          .toList(growable: false);

      final normalized = existing.kind == ArtistProfileKind.band
          ? _normalizeMemberKeysForOwner(
              ownerKey: existing.key,
              members: remapped,
            )
          : const <String>[];

      if (listEquals(existing.memberKeys, normalized)) continue;
      await _artistStore.upsert(existing.copyWith(memberKeys: normalized));
    }

    await load();
  }

  Future<void> removeLocalArtist(ArtistGroup artist) async {
    for (final item in artist.items) {
      final credits = ArtistCreditParser.parse(item.subtitle);
      if (!credits.isPrimaryArtistKey(artist.key)) continue;
      for (final v in item.variants) {
        await _deleteFile(v.localPath);
      }
      await _deleteFile(item.thumbnailLocalPath);
      await _store.remove(item.id);
    }
    await _artistStore.remove(artist.key);

    final allProfiles = await _artistStore.readAll();
    for (final existing in allProfiles) {
      if (existing.kind != ArtistProfileKind.band) continue;
      final nextMembers = _normalizeMemberKeysForOwner(
        ownerKey: existing.key,
        members: existing.memberKeys
            .where(
              (k) =>
                  ArtistCreditParser.normalizeKey(k) !=
                  ArtistCreditParser.normalizeKey(artist.key),
            )
            .toList(),
      );
      if (listEquals(existing.memberKeys, nextMembers)) continue;
      await _artistStore.upsert(existing.copyWith(memberKeys: nextMembers));
    }

    await load();
  }

  Future<void> _deleteFile(String? path) async {
    final pth = path?.trim();
    if (pth == null || pth.isEmpty) return;
    final f = File(pth);
    if (await f.exists()) await f.delete();
  }
}

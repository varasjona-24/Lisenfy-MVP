import '../../../app/models/media_item.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../../../app/utils/country_catalog.dart';
import '../../artists/data/artist_store.dart';
import '../domain/entities/world_station_type.dart';

class LocalAffinityEngine {
  LocalAffinityEngine({ArtistStore? artistStore}) : _artistStore = artistStore;

  final ArtistStore? _artistStore;
  Map<String, String>? _artistCountryByKeyCache;

  Map<String, double> buildCountryAffinity(List<MediaItem> library) {
    final weights = <String, double>{};

    for (final item in library) {
      final countryCode = _resolveCountryCode(item);
      if (countryCode == null) continue;
      final engagement = _engagementWeight(item);
      weights[countryCode] = (weights[countryCode] ?? 0) + engagement;
    }

    if (weights.isEmpty) return const <String, double>{};
    final maxWeight = weights.values.fold<double>(0, (a, b) => a > b ? a : b);
    if (maxWeight <= 0) return const <String, double>{};

    final normalized = <String, double>{};
    weights.forEach((key, value) {
      normalized[key] = (value / maxWeight).clamp(0, 1).toDouble();
    });
    return normalized;
  }

  double scoreItemForCountry({
    required MediaItem item,
    required String targetCountryCode,
    required WorldStationType stationType,
    required Map<String, double> countryAffinity,
    String? resolvedCountryCode,
  }) {
    final targetCode = targetCountryCode.trim().toUpperCase();
    final itemCode = resolvedCountryCode ?? _resolveCountryCode(item);
    final countryBoost = itemCode == null
        ? 0.0
        : (itemCode == targetCode ? 1.0 : _sameRegion(itemCode, targetCode));

    final affinityBoost = countryAffinity[targetCode] ?? 0;
    final novelty = _noveltyScore(item);
    final quality = _qualityScore(item);
    final engagement = _engagementWeight(item).clamp(0, 1).toDouble();

    switch (stationType) {
      case WorldStationType.gateway:
        return (countryBoost * 0.48) +
            (quality * 0.22) +
            (engagement * 0.2) +
            (affinityBoost * 0.1);
      case WorldStationType.essentials:
        return (countryBoost * 0.42) +
            (engagement * 0.30) +
            (quality * 0.20) +
            (affinityBoost * 0.08);
      case WorldStationType.discovery:
        return (countryBoost * 0.30) +
            (novelty * 0.45) +
            (quality * 0.15) +
            (affinityBoost * 0.10);
      case WorldStationType.energy:
        return (countryBoost * 0.35) +
            (engagement * 0.35) +
            (quality * 0.20) +
            (affinityBoost * 0.10);
      case WorldStationType.chill:
        return (countryBoost * 0.35) +
            (quality * 0.40) +
            ((1 - novelty) * 0.15) +
            (affinityBoost * 0.10);
    }
  }

  String? resolveCountryCode(MediaItem item) => _resolveCountryCode(item);

  String? _resolveCountryCode(MediaItem item) {
    final byItem = _resolveCountryCodeFromRaw(item.country);
    if (byItem != null) return byItem;

    final artistMap = _artistCountryByKey();
    if (artistMap.isEmpty) return null;

    final credits = ArtistCreditParser.parse(item.displaySubtitle);
    final keyCandidates = <String>{
      ArtistCreditParser.normalizeKey(credits.primaryArtist),
      ArtistCreditParser.normalizeKey(item.displaySubtitle),
      ...credits.allArtists.map(ArtistCreditParser.normalizeKey),
    }..removeWhere((key) => key.isEmpty || key == 'unknown');

    for (final key in keyCandidates) {
      final code = artistMap[key];
      if (code != null) return code;
    }
    return null;
  }

  Map<String, String> _artistCountryByKey() {
    final cached = _artistCountryByKeyCache;
    if (cached != null) return cached;

    final store = _artistStore;
    if (store == null) {
      _artistCountryByKeyCache = const <String, String>{};
      return _artistCountryByKeyCache!;
    }

    final profiles = store.readAllSync();
    if (profiles.isEmpty) {
      _artistCountryByKeyCache = const <String, String>{};
      return _artistCountryByKeyCache!;
    }

    final map = <String, String>{};
    for (final profile in profiles) {
      final code =
          _resolveCountryCodeFromRaw(profile.countryCode) ??
          _resolveCountryCodeFromRaw(profile.country);
      if (code == null) continue;

      final keys = <String>{
        ArtistCreditParser.normalizeKey(profile.key),
        ArtistCreditParser.normalizeKey(profile.displayName),
      }..removeWhere((key) => key.isEmpty || key == 'unknown');

      for (final key in keys) {
        map.putIfAbsent(key, () => code);
      }
    }

    _artistCountryByKeyCache = Map<String, String>.unmodifiable(map);
    return _artistCountryByKeyCache!;
  }

  String? _resolveCountryCodeFromRaw(String? rawCountry) {
    final raw = (rawCountry ?? '').trim();
    if (raw.isEmpty) return null;

    if (raw.length == 2) {
      final code = raw.toUpperCase();
      if (CountryCatalog.findByCode(code) != null) return code;
    }

    final byName = CountryCatalog.findByName(raw)?.code;
    if (byName != null) return byName;

    final sanitized = _sanitizeCountryLabel(raw);
    if (sanitized.isEmpty) return null;

    if (sanitized.length == 2) {
      final code = sanitized.toUpperCase();
      if (CountryCatalog.findByCode(code) != null) return code;
    }

    return CountryCatalog.findByName(sanitized)?.code;
  }

  String _sanitizeCountryLabel(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]', unicode: true), '');
    text = text.replaceAll(RegExp(r'[\(\)\[\]\{\}]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  double _sameRegion(String codeA, String codeB) {
    final regionA = CountryCatalog.regionKeyFromCode(codeA);
    final regionB = CountryCatalog.regionKeyFromCode(codeB);
    if (regionA == null || regionB == null) return 0;
    return regionA == regionB ? 0.55 : 0.0;
  }

  double _qualityScore(MediaItem item) {
    final completion = _completionRate(item);
    final progress = item.avgListenProgress.clamp(0, 1).toDouble();
    final skipRate = _skipRate(item);
    return ((completion * 0.55) + (progress * 0.30) + ((1 - skipRate) * 0.15))
        .clamp(0, 1)
        .toDouble();
  }

  double _noveltyScore(MediaItem item) {
    final activity = (item.playCount + item.fullListenCount).toDouble();
    return (1 - (activity / 24).clamp(0, 1)).toDouble();
  }

  double _engagementWeight(MediaItem item) {
    final playSignal = (item.playCount / 40).clamp(0, 1).toDouble();
    final favSignal = item.isFavorite ? 1.0 : 0.0;
    final completion = _completionRate(item);
    final recent = _recentSignal(item.lastPlayedAt);
    return ((playSignal * 0.35) +
            (favSignal * 0.20) +
            (completion * 0.30) +
            (recent * 0.15))
        .clamp(0, 1)
        .toDouble();
  }

  double _skipRate(MediaItem item) {
    final total = item.skipCount + item.fullListenCount + item.playCount;
    if (total <= 0) return 0;
    return (item.skipCount / total).clamp(0, 1).toDouble();
  }

  double _completionRate(MediaItem item) {
    final total = item.skipCount + item.fullListenCount;
    if (total <= 0) return item.avgListenProgress.clamp(0, 1).toDouble();
    return (item.fullListenCount / total).clamp(0, 1).toDouble();
  }

  double _recentSignal(int? ts) {
    final value = ts ?? 0;
    if (value <= 0) return 0;
    final ageHours =
        (DateTime.now().millisecondsSinceEpoch - value) / 3600000.0;
    if (ageHours <= 24) return 1;
    if (ageHours <= 24 * 3) return 0.7;
    if (ageHours <= 24 * 7) return 0.45;
    return 0.2;
  }
}

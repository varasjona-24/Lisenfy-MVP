import 'dart:math';

import '../../artists/domain/artist_profile.dart';
import '../../../app/models/media_item.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../../sources/domain/source_origin.dart';
import '../../sources/domain/source_theme_topic.dart';
import '../../sources/domain/source_theme_topic_playlist.dart';
import '../data/recommendation_store.dart';
import '../domain/recommendation_models.dart';

class LocalRecommendationService {
  LocalRecommendationService({
    required RecommendationStore store,
    required Future<List<MediaItem>> Function() libraryLoader,
    Future<List<ArtistProfile>> Function()? artistProfileLoader,
    Future<List<SourceThemeTopic>> Function()? topicLoader,
    Future<List<SourceThemeTopicPlaylist>> Function()? topicPlaylistLoader,
    DateTime Function()? now,
  }) : _store = store,
       _libraryLoader = libraryLoader,
       _artistProfileLoader = artistProfileLoader ?? _emptyArtistProfileLoader,
       _topicLoader = topicLoader ?? _emptyTopicLoader,
       _topicPlaylistLoader = topicPlaylistLoader ?? _emptyTopicPlaylistLoader,
       _now = now ?? DateTime.now;

  final RecommendationStore _store;
  final Future<List<MediaItem>> Function() _libraryLoader;
  final Future<List<ArtistProfile>> Function() _artistProfileLoader;
  final Future<List<SourceThemeTopic>> Function() _topicLoader;
  final Future<List<SourceThemeTopicPlaylist>> Function() _topicPlaylistLoader;
  final DateTime Function() _now;

  RecommendationState? _stateCache;
  static const int _dailySetTargetSize = 80;
  static const int _manualRefreshDailyLimit = 2;

  static Future<List<ArtistProfile>> _emptyArtistProfileLoader() async {
    return const <ArtistProfile>[];
  }

  static Future<List<SourceThemeTopic>> _emptyTopicLoader() async {
    return const <SourceThemeTopic>[];
  }

  static Future<List<SourceThemeTopicPlaylist>>
  _emptyTopicPlaylistLoader() async {
    return const <SourceThemeTopicPlaylist>[];
  }

  Future<RecommendationDailySet> getOrBuildForDay({
    required RecommendationMode mode,
  }) async {
    final state = await _ensureState();
    final dateKey = _dateKey(_now());
    final key = _dailySetKey(dateKey: dateKey, mode: mode);
    final cached = state.dailySets[key];
    if (cached != null) return cached;

    final built = await _buildDailySet(
      dateKey: dateKey,
      mode: mode,
      seedSalt: 0,
      manualRefreshCount: 0,
      lastRefreshAt: null,
      baseProfile: state.profile,
    );

    await _saveState(
      state.copyWith(
        profile: built.profile,
        dailySets: _updatedDailySets(state.dailySets, key, built.set),
      ),
    );
    return built.set;
  }

  Future<RecommendationDailySet> refreshManually({
    required RecommendationMode mode,
  }) async {
    final state = await _ensureState();
    final dateKey = _dateKey(_now());
    final key = _dailySetKey(dateKey: dateKey, mode: mode);

    final current = state.dailySets[key];
    final currentCount = current?.manualRefreshCount ?? 0;
    if (currentCount >= _manualRefreshDailyLimit && current != null) {
      return current;
    }

    final nextCount = currentCount + 1;
    final built = await _buildDailySet(
      dateKey: dateKey,
      mode: mode,
      seedSalt: nextCount,
      manualRefreshCount: nextCount,
      lastRefreshAt: _now().millisecondsSinceEpoch,
      baseProfile: state.profile,
    );

    await _saveState(
      state.copyWith(
        profile: built.profile,
        dailySets: _updatedDailySets(state.dailySets, key, built.set),
      ),
    );

    return built.set;
  }

  bool canManualRefreshToday({required RecommendationMode mode}) {
    final state = _stateCache;
    if (state == null) return true;
    final key = _dailySetKey(dateKey: _dateKey(_now()), mode: mode);
    final set = state.dailySets[key];
    return (set?.manualRefreshCount ?? 0) < _manualRefreshDailyLimit;
  }

  String? nextRefreshHint({required RecommendationMode mode}) {
    if (canManualRefreshToday(mode: mode)) return null;
    final nextDay = _now().add(const Duration(days: 1));
    return 'Refresh disponible el ${_dateKey(nextDay)}';
  }

  Future<void> reloadFromStore() async {
    var state = await _store.readState();
    if (state.installId.trim().isEmpty) {
      state = state.copyWith(installId: _generateInstallId());
      await _store.writeState(state);
    }
    _stateCache = state;
  }

  Future<RecommendationState> _ensureState() async {
    if (_stateCache != null) return _stateCache!;
    var state = await _store.readState();
    if (state.installId.trim().isEmpty) {
      state = state.copyWith(installId: _generateInstallId());
      await _store.writeState(state);
    }
    _stateCache = state;
    return state;
  }

  Future<void> _saveState(RecommendationState state) async {
    _stateCache = state;
    await _store.writeState(state);
  }

  Map<String, RecommendationDailySet> _updatedDailySets(
    Map<String, RecommendationDailySet> previous,
    String nextKey,
    RecommendationDailySet nextSet,
  ) {
    final map = Map<String, RecommendationDailySet>.from(previous);
    map[nextKey] = nextSet;
    final threshold = _now().subtract(const Duration(days: 30));
    map.removeWhere((_, set) {
      final date = _tryParseDateKey(set.dateKey);
      if (date == null) return false;
      return date.isBefore(
        DateTime(threshold.year, threshold.month, threshold.day),
      );
    });
    return map;
  }

  Future<_BuildResult> _buildDailySet({
    required String dateKey,
    required RecommendationMode mode,
    required int seedSalt,
    required int manualRefreshCount,
    required int? lastRefreshAt,
    required RecommendationProfile baseProfile,
  }) async {
    final allItems = await _libraryLoader();
    final candidatesPool = allItems.where((item) {
      if (mode == RecommendationMode.audio) return item.hasAudioLocal;
      return item.hasVideoLocal;
    }).toList();

    if (candidatesPool.isEmpty) {
      return _BuildResult(
        profile: baseProfile.copyWith(
          lastComputedAt: _now().millisecondsSinceEpoch,
        ),
        set: RecommendationDailySet(
          dateKey: dateKey,
          mode: mode,
          entries: const <RecommendationEntry>[],
          manualRefreshCount: manualRefreshCount,
          lastRefreshAt: lastRefreshAt,
        ),
      );
    }

    final sourceLabels = await _buildSourceLabelMap();
    final artistLocaleByKey = await _buildArtistLocaleMap();
    final nowMs = _now().millisecondsSinceEpoch;
    final candidates = candidatesPool
        .map(
          (item) => _candidateFromItem(item, sourceLabels, artistLocaleByKey),
        )
        .whereType<_RecommendationCandidate>()
        .toList();

    final profile = _buildProfile(
      candidates: candidates,
      previous: baseProfile,
      nowMs: nowMs,
    );
    final coldStart = _isColdStart(candidates, profile);
    final seed = _hashToSeed(
      '$dateKey|${mode.key}|${_stateCache?.installId ?? ''}|$seedSalt',
    );

    final scored = <_ScoredCandidate>[];
    for (final candidate in candidates) {
      final scoreData = _scoreCandidate(
        candidate: candidate,
        profile: profile,
        coldStart: coldStart,
      );
      final jitter = _deterministicJitter(candidate.stableKey, seed);
      scored.add(
        _ScoredCandidate(
          candidate: candidate,
          score: scoreData.score + (jitter * 0.12),
          reasonCode: scoreData.reasonCode,
          reasonText: scoreData.reasonText,
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final selected = _selectDiverse(
      scored,
      limit: min(_dailySetTargetSize, scored.length),
    );
    final generatedAt = _now().millisecondsSinceEpoch;
    final entries = selected
        .map(
          (entry) => RecommendationEntry(
            itemId: entry.candidate.item.id,
            publicId: entry.candidate.item.publicId.trim(),
            score: entry.score,
            reasonCode: entry.reasonCode,
            reasonText: entry.reasonText,
            generatedAt: generatedAt,
          ),
        )
        .toList();

    return _BuildResult(
      profile: profile.copyWith(lastComputedAt: generatedAt),
      set: RecommendationDailySet(
        dateKey: dateKey,
        mode: mode,
        entries: entries,
        manualRefreshCount: manualRefreshCount,
        lastRefreshAt: lastRefreshAt,
      ),
    );
  }

  Future<Map<String, _SourceLabels>> _buildSourceLabelMap() async {
    final labels = <String, _SourceLabels>{};
    List<SourceThemeTopic> topics;
    List<SourceThemeTopicPlaylist> playlists;

    try {
      topics = await _topicLoader();
    } catch (_) {
      topics = const <SourceThemeTopic>[];
    }
    try {
      playlists = await _topicPlaylistLoader();
    } catch (_) {
      playlists = const <SourceThemeTopicPlaylist>[];
    }

    for (final topic in topics) {
      final title = topic.title.trim();
      if (title.isEmpty) continue;
      for (final itemId in topic.itemIds) {
        final key = itemId.trim();
        if (key.isEmpty) continue;
        labels.putIfAbsent(key, _SourceLabels.new).topics.add(title);
      }
    }

    for (final playlist in playlists) {
      final name = playlist.name.trim();
      if (name.isEmpty) continue;
      for (final itemId in playlist.itemIds) {
        final key = itemId.trim();
        if (key.isEmpty) continue;
        labels.putIfAbsent(key, _SourceLabels.new).playlists.add(name);
      }
    }

    return labels;
  }

  Future<Map<String, _ArtistLocale>> _buildArtistLocaleMap() async {
    List<ArtistProfile> profiles;
    try {
      profiles = await _artistProfileLoader();
    } catch (_) {
      profiles = const <ArtistProfile>[];
    }

    final map = <String, _ArtistLocale>{};
    for (final profile in profiles) {
      final key = ArtistCreditParser.normalizeKey(profile.key);
      if (key.isEmpty || key == 'unknown') continue;
      final countryDisplay = _normalizedCountryDisplay(profile.country);
      final countryKey = _normalizedCountryKey(countryDisplay);
      final mainRegionKey = profile.mainRegion == ArtistMainRegion.none
          ? _inferMainRegionKeyFromCountry(countryKey)
          : profile.mainRegion.key;
      if (countryKey == null && mainRegionKey == null) continue;
      map[key] = _ArtistLocale(
        countryDisplay: countryDisplay,
        mainRegionKey: mainRegionKey,
        isMainRegionExplicit: profile.mainRegion != ArtistMainRegion.none,
      );
    }
    return map;
  }

  _RecommendationCandidate? _candidateFromItem(
    MediaItem item,
    Map<String, _SourceLabels> sourceLabels,
    Map<String, _ArtistLocale> artistLocaleByKey,
  ) {
    final publicId = item.publicId.trim();
    final id = item.id.trim();
    if (publicId.isEmpty && id.isEmpty) return null;

    final labelByPublic = publicId.isEmpty ? null : sourceLabels[publicId];
    final labelById = id.isEmpty ? null : sourceLabels[id];
    final sourceText = [
      ...?labelByPublic?.topics,
      ...?labelByPublic?.playlists,
      ...?labelById?.topics,
      ...?labelById?.playlists,
    ].join(' ');

    final parsed = ArtistCreditParser.parse(item.displaySubtitle);
    final artistNames = parsed.allArtists.isNotEmpty
        ? parsed.allArtists
        : _fallbackArtists(item.displaySubtitle);

    final artistMap = <String, String>{};
    for (final artist in artistNames) {
      final clean = ArtistCreditParser.cleanName(artist);
      final key = ArtistCreditParser.normalizeKey(clean);
      if (clean.isEmpty || key == 'unknown') continue;
      artistMap[key] = clean;
    }

    if (artistMap.isEmpty && item.displaySubtitle.trim().isNotEmpty) {
      final clean = ArtistCreditParser.cleanName(item.displaySubtitle);
      final key = ArtistCreditParser.normalizeKey(clean);
      if (clean.isNotEmpty && key != 'unknown') {
        artistMap[key] = clean;
      }
    }

    final primaryArtistName =
        ArtistCreditParser.cleanName(parsed.primaryArtist).isNotEmpty
        ? ArtistCreditParser.cleanName(parsed.primaryArtist)
        : (artistMap.isNotEmpty ? artistMap.values.first : '');
    final primaryArtistKey = ArtistCreditParser.normalizeKey(primaryArtistName);

    final artistCountries = <String>[];
    final countrySeen = <String>{};
    final explicitArtistRegions = <String>[];
    final inferredArtistRegions = <String>[];
    final explicitRegionSeen = <String>{};
    final inferredRegionSeen = <String>{};

    void addCountryByArtistKey(String key) {
      final locale = artistLocaleByKey[key];
      if (locale == null) return;
      final regionKey = locale.mainRegionKey?.trim() ?? '';
      if (regionKey.isNotEmpty && locale.isMainRegionExplicit) {
        if (explicitRegionSeen.add(regionKey)) {
          explicitArtistRegions.add(regionKey);
        }
      } else if (regionKey.isNotEmpty) {
        if (inferredRegionSeen.add(regionKey)) {
          inferredArtistRegions.add(regionKey);
        }
      }
      final countryDisplay = locale.countryDisplay;
      if (countryDisplay == null) return;
      final countryKey = _normalizedCountryKey(countryDisplay);
      if (countryKey == null) return;
      if (!countrySeen.add(countryKey)) return;
      artistCountries.add(countryDisplay);
    }

    if (primaryArtistKey.isNotEmpty && primaryArtistKey != 'unknown') {
      addCountryByArtistKey(primaryArtistKey);
    }
    for (final artistKey in artistMap.keys) {
      if (artistKey == primaryArtistKey) continue;
      addCountryByArtistKey(artistKey);
    }

    // Backward compatibility for existing backups/libraries that still have
    // country at song level before migrating to artist profiles.
    if (artistCountries.isEmpty) {
      final fallback = _normalizedCountryDisplay(item.country);
      if (fallback != null) {
        artistCountries.add(fallback);
      }
    }

    final mergedText =
        '${item.title} ${item.subtitle} ${artistCountries.join(' ')} $sourceText';
    final normalized = _normalizeText(mergedText);
    final tokens = _tokenize(normalized);
    final genres = _extractLexiconMatches(
      normalizedText: normalized,
      tokens: tokens,
      lexicon: _genreLexicon,
    );
    final regionMatches = _extractLexiconMatches(
      normalizedText: normalized,
      tokens: tokens,
      lexicon: _regionLexicon,
    );
    final countryDisplay = artistCountries.isNotEmpty
        ? artistCountries.first
        : null;
    final countryKey = _normalizedCountryKey(countryDisplay);
    final regions = <String>[
      ...explicitArtistRegions,
      if (countryKey != null) countryKey,
      ...inferredArtistRegions.where((entry) => entry != countryKey),
      ...regionMatches.where(
        (entry) =>
            entry != countryKey &&
            !explicitArtistRegions.contains(entry) &&
            !inferredArtistRegions.contains(entry),
      ),
    ];
    final regionDisplayByKey = <String, String>{};
    for (final region in regions) {
      regionDisplayByKey[region] = _regionLabel(region);
    }
    if (countryKey != null) {
      regionDisplayByKey[countryKey] = countryDisplay!;
    }
    final dominantTag = genres.isNotEmpty
        ? 'genre:${genres.first}'
        : (regions.isNotEmpty
              ? 'region:${regions.first}'
              : 'origin:${item.origin.key}');

    final stableKey = publicId.isNotEmpty ? 'p:$publicId' : 'i:$id';

    return _RecommendationCandidate(
      item: item,
      stableKey: stableKey,
      primaryArtistKey: primaryArtistKey == 'unknown' ? '' : primaryArtistKey,
      primaryArtistName: primaryArtistName,
      artistKeys: artistMap.keys.toList(),
      artistNameByKey: artistMap,
      genres: genres,
      regions: regions,
      countryKey: countryKey,
      regionDisplayByKey: regionDisplayByKey,
      dominantTag: dominantTag,
      originKey: item.origin.key,
    );
  }

  RecommendationProfile _buildProfile({
    required List<_RecommendationCandidate> candidates,
    required RecommendationProfile previous,
    required int nowMs,
  }) {
    final genre = <String, double>{};
    final region = <String, double>{};
    final artist = <String, double>{};
    final origin = <String, double>{};

    void absorbPrevious(
      Map<String, double> target,
      Map<String, double> source,
    ) {
      source.forEach((key, value) {
        target[key] = (target[key] ?? 0) + (value * 0.55);
      });
    }

    absorbPrevious(genre, previous.genreWeights);
    absorbPrevious(region, previous.regionWeights);
    absorbPrevious(artist, previous.artistWeights);
    absorbPrevious(origin, previous.originWeights);

    for (final candidate in candidates) {
      final weight = _interactionWeight(candidate.item, nowMs);
      if (weight <= 0) continue;

      for (final tag in candidate.genres) {
        genre[tag] = (genre[tag] ?? 0) + (weight * 1.15);
      }
      for (final tag in candidate.regions) {
        final boost =
            candidate.countryKey != null && candidate.countryKey == tag
            ? 1.35
            : 1.0;
        region[tag] = (region[tag] ?? 0) + (weight * boost);
      }
      for (final artistKey in candidate.artistKeys) {
        artist[artistKey] = (artist[artistKey] ?? 0) + (weight * 0.9);
      }
      origin[candidate.originKey] =
          (origin[candidate.originKey] ?? 0) + (weight * 0.7);
    }

    return RecommendationProfile(
      genreWeights: _normalizeWeightMap(genre),
      regionWeights: _normalizeWeightMap(region),
      artistWeights: _normalizeWeightMap(artist),
      originWeights: _normalizeWeightMap(origin),
      lastComputedAt: nowMs,
    );
  }

  bool _isColdStart(
    List<_RecommendationCandidate> candidates,
    RecommendationProfile profile,
  ) {
    final hasUsage = candidates.any(
      (c) =>
          c.item.isFavorite ||
          c.item.playCount > 0 ||
          c.item.fullListenCount > 0 ||
          c.item.skipCount > 0 ||
          c.item.avgListenProgress >= 0.2 ||
          ((c.item.lastPlayedAt ?? 0) > 0) ||
          ((c.item.lastCompletedAt ?? 0) > 0),
    );

    final profileStrength = [
      ...profile.genreWeights.values,
      ...profile.regionWeights.values,
      ...profile.artistWeights.values,
      ...profile.originWeights.values,
    ].fold<double>(0, (acc, value) => max(acc, value));

    return !hasUsage || profileStrength < 0.2;
  }

  _ScoreResult _scoreCandidate({
    required _RecommendationCandidate candidate,
    required RecommendationProfile profile,
    required bool coldStart,
  }) {
    final item = candidate.item;
    final playSignal = min(item.playCount / 30, 1.0);
    final favoriteSignal = item.isFavorite ? 1.0 : 0.0;
    final fullListenSignal = min(item.fullListenCount / 24, 1.0);
    final skipSignal = min(item.skipCount / 24, 1.0);
    final progressSignal = _clampedProgress(item);
    final completionRate = _completionRate(item);
    final retentionSignal =
        ((completionRate * 0.6) + (progressSignal * 0.4)) *
        (1 - (skipSignal * 0.7));
    final recentSignal = _recentScore(
      item.lastPlayedAt,
      _now().millisecondsSinceEpoch,
    );
    final affinitySignals =
        (favoriteSignal * 0.42) +
        (playSignal * 0.28) +
        (recentSignal * 0.12) +
        (retentionSignal * 0.18);

    final genreMatch = _bestWeight(candidate.genres, profile.genreWeights);
    final regionMatch = _bestWeight(candidate.regions, profile.regionWeights);
    final artistMatch = _bestWeight(
      candidate.artistKeys,
      profile.artistWeights,
    );
    final originMatch = profile.originWeights[candidate.originKey] ?? 0;
    final semanticMatch =
        (genreMatch * 0.45) +
        (regionMatch * 0.25) +
        (artistMatch * 0.2) +
        (originMatch * 0.1);

    final engagement =
        (playSignal * 0.30) +
        (favoriteSignal * 0.25) +
        (recentSignal * 0.20) +
        (fullListenSignal * 0.15) +
        (progressSignal * 0.10);

    final noveltyBase =
        1 - min((item.playCount + item.fullListenCount) / 30, 1.0);
    final novelty =
        (noveltyBase +
                ((item.lastPlayedAt ?? 0) <= 0 ? 0.15 : 0) +
                (skipSignal > 0.6 ? 0.05 : 0))
            .clamp(0, 1);

    var score =
        (0.33 * affinitySignals) +
        (0.34 * semanticMatch) +
        (0.23 * engagement) +
        (0.10 * novelty);

    final recencyPenalty = _recencyPenalty(
      item.lastPlayedAt,
      _now().millisecondsSinceEpoch,
    );
    score *= recencyPenalty;
    score *= (1 - (skipSignal * 0.35)).clamp(0.45, 1.0);

    if (coldStart) {
      score = (score * 0.65) + (novelty * 0.35);
    }

    final reason = _pickReason(
      candidate: candidate,
      coldStart: coldStart,
      genreMatch: genreMatch,
      regionMatch: regionMatch,
      artistMatch: artistMatch,
      originMatch: originMatch,
      favoriteSignal: favoriteSignal,
      recentSignal: recentSignal,
    );

    return _ScoreResult(
      score: score.clamp(0, 1).toDouble(),
      reasonCode: reason.code,
      reasonText: reason.text,
    );
  }

  _ReasonResult _pickReason({
    required _RecommendationCandidate candidate,
    required bool coldStart,
    required double genreMatch,
    required double regionMatch,
    required double artistMatch,
    required double originMatch,
    required double favoriteSignal,
    required double recentSignal,
  }) {
    if (coldStart) {
      return const _ReasonResult(
        code: RecommendationReasonCode.coldStart,
        text: 'Selección inicial para ti',
      );
    }

    if (genreMatch >= 0.5 && candidate.genres.isNotEmpty) {
      final genre = candidate.genres.first;
      if (genre == 'trap' && _isLatinRegion(candidate.regions)) {
        return const _ReasonResult(
          code: RecommendationReasonCode.genreMatch,
          text: 'Por trap latino',
        );
      }
      return _ReasonResult(
        code: RecommendationReasonCode.genreMatch,
        text: 'Por ${_genreLabel(genre)}',
      );
    }

    if (regionMatch >= 0.5 && candidate.regions.isNotEmpty) {
      final region = candidate.regions.first;
      final regionLabel =
          candidate.regionDisplayByKey[region] ?? _regionLabel(region);
      return _ReasonResult(
        code: RecommendationReasonCode.regionMatch,
        text: 'Por $regionLabel',
      );
    }

    if (artistMatch >= 0.45 && candidate.primaryArtistName.isNotEmpty) {
      return _ReasonResult(
        code: RecommendationReasonCode.artistAffinity,
        text: 'Porque escuchas a ${candidate.primaryArtistName}',
      );
    }

    if (originMatch >= 0.55) {
      return _ReasonResult(
        code: RecommendationReasonCode.originAffinity,
        text: 'Por tu origen ${_originLabel(candidate.originKey)}',
      );
    }

    if (favoriteSignal >= 0.9) {
      return const _ReasonResult(
        code: RecommendationReasonCode.favoriteAffinity,
        text: 'Por tus favoritos recientes',
      );
    }

    if (recentSignal >= 0.45) {
      return const _ReasonResult(
        code: RecommendationReasonCode.recentAffinity,
        text: 'Por tu actividad reciente',
      );
    }

    return const _ReasonResult(
      code: RecommendationReasonCode.freshPick,
      text: 'Para variar tu biblioteca',
    );
  }

  List<_ScoredCandidate> _selectDiverse(
    List<_ScoredCandidate> ordered, {
    required int limit,
  }) {
    final selected = <_ScoredCandidate>[];
    final selectedKeys = <String>{};
    final deferred = <_ScoredCandidate>[];
    final dominantTagCount = <String, int>{};

    bool canSelect(_ScoredCandidate candidate) {
      if (selectedKeys.contains(candidate.candidate.stableKey)) return false;

      final tag = candidate.candidate.dominantTag;
      if (tag.isNotEmpty && (dominantTagCount[tag] ?? 0) >= 6) {
        return false;
      }

      if (selected.length >= 2) {
        final a = selected[selected.length - 1].candidate.primaryArtistKey;
        final b = selected[selected.length - 2].candidate.primaryArtistKey;
        final c = candidate.candidate.primaryArtistKey;
        if (a.isNotEmpty && a == b && b == c) {
          return false;
        }
      }

      return true;
    }

    for (final candidate in ordered) {
      if (selected.length >= limit) break;
      if (canSelect(candidate)) {
        selected.add(candidate);
        selectedKeys.add(candidate.candidate.stableKey);
        final tag = candidate.candidate.dominantTag;
        if (tag.isNotEmpty) {
          dominantTagCount[tag] = (dominantTagCount[tag] ?? 0) + 1;
        }
      } else {
        deferred.add(candidate);
      }
    }

    if (selected.length >= limit) return selected;

    for (final candidate in [...deferred, ...ordered]) {
      if (selected.length >= limit) break;
      if (selectedKeys.contains(candidate.candidate.stableKey)) continue;
      selected.add(candidate);
      selectedKeys.add(candidate.candidate.stableKey);
    }

    return selected.take(limit).toList();
  }

  List<String> _extractLexiconMatches({
    required String normalizedText,
    required Set<String> tokens,
    required Map<String, List<String>> lexicon,
  }) {
    final result = <String>[];
    for (final entry in lexicon.entries) {
      for (final alias in entry.value) {
        if (_containsAlias(
          normalizedText: normalizedText,
          tokens: tokens,
          alias: alias,
        )) {
          result.add(entry.key);
          break;
        }
      }
    }
    return result;
  }

  bool _containsAlias({
    required String normalizedText,
    required Set<String> tokens,
    required String alias,
  }) {
    final normalizedAlias = _normalizeText(alias);
    if (normalizedAlias.isEmpty) return false;
    if (normalizedAlias.contains(' ')) {
      return normalizedText.contains(normalizedAlias);
    }
    return tokens.contains(normalizedAlias);
  }

  Set<String> _tokenize(String normalizedText) {
    final matches = RegExp(r'[a-z0-9]+').allMatches(normalizedText);
    return matches
        .map((m) => m.group(0) ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  List<String> _fallbackArtists(String subtitle) {
    final clean = subtitle.trim();
    if (clean.isEmpty) return const <String>[];
    return clean
        .split(RegExp(r',|&|/|\bx\b', caseSensitive: false))
        .map(ArtistCreditParser.cleanName)
        .where((name) => name.isNotEmpty)
        .toList();
  }

  double _interactionWeight(MediaItem item, int nowMs) {
    final favoriteWeight = item.isFavorite ? 3.0 : 0.0;
    final playWeight = min(item.playCount, 60) * 0.14;
    final recentWeight = _recentScore(item.lastPlayedAt, nowMs) * 1.8;
    final fullListenWeight = min(item.fullListenCount, 40) * 0.12;
    final progressWeight = _clampedProgress(item) * 1.2;
    final skipRate = item.skipCount <= 0
        ? 0.0
        : (item.skipCount /
                  max(
                    1,
                    item.fullListenCount + item.skipCount + item.playCount,
                  ))
              .clamp(0.0, 1.0);
    final skipPenalty = (1 - (skipRate * 0.65)).clamp(0.35, 1.0).toDouble();
    return (favoriteWeight +
            playWeight +
            recentWeight +
            fullListenWeight +
            progressWeight) *
        skipPenalty;
  }

  double _clampedProgress(MediaItem item) {
    return item.avgListenProgress.clamp(0.0, 1.0).toDouble();
  }

  double _completionRate(MediaItem item) {
    final completed = item.fullListenCount;
    final skipped = item.skipCount;
    final total = completed + skipped;
    if (total <= 0) return _clampedProgress(item);
    return (completed / total).clamp(0.0, 1.0).toDouble();
  }

  double _recentScore(int? lastPlayedAt, int nowMs) {
    final ts = lastPlayedAt ?? 0;
    if (ts <= 0) return 0;
    final ageHours = max(
      0,
      ((nowMs - ts) / const Duration(hours: 1).inMilliseconds).round(),
    );
    if (ageHours <= 24) return 1;
    if (ageHours <= 24 * 3) return 0.85;
    if (ageHours <= 24 * 7) return 0.65;
    if (ageHours <= 24 * 14) return 0.45;
    if (ageHours <= 24 * 30) return 0.25;
    return 0.1;
  }

  double _recencyPenalty(int? lastPlayedAt, int nowMs) {
    final ts = lastPlayedAt ?? 0;
    if (ts <= 0) return 1;
    final ageHours = max(
      0,
      ((nowMs - ts) / const Duration(hours: 1).inMilliseconds).round(),
    );
    if (ageHours <= 6) return 0.25;
    if (ageHours <= 24) return 0.55;
    if (ageHours <= 48) return 0.72;
    return 1;
  }

  double _bestWeight(List<String> keys, Map<String, double> map) {
    var best = 0.0;
    for (final key in keys) {
      final value = map[key] ?? 0;
      if (value > best) best = value;
    }
    return best;
  }

  Map<String, double> _normalizeWeightMap(Map<String, double> map) {
    if (map.isEmpty) return const <String, double>{};
    final maxValue = map.values.fold<double>(0, max);
    if (maxValue <= 0) return const <String, double>{};
    final normalized = <String, double>{};
    map.forEach((key, value) {
      if (value <= 0) return;
      normalized[key] = (value / maxValue).clamp(0, 1).toDouble();
    });
    return normalized;
  }

  bool _isLatinRegion(List<String> regions) {
    const latinKeys = {
      'latino',
      'puerto rico',
      'mexico',
      'argentina',
      'colombia',
      'chile',
      'espana',
      'peru',
      'venezuela',
      'ecuador',
      'uruguay',
      'paraguay',
      'bolivia',
      'republica dominicana',
      'cuba',
    };
    return regions.any(latinKeys.contains);
  }

  String _genreLabel(String key) {
    return _genreLabels[key] ?? key;
  }

  String _regionLabel(String key) {
    return _regionLabels[key] ?? key;
  }

  String _originLabel(String key) {
    return _originLabels[key] ?? key;
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _dailySetKey({
    required String dateKey,
    required RecommendationMode mode,
  }) {
    return '$dateKey|${mode.key}';
  }

  DateTime? _tryParseDateKey(String value) {
    final normalized = value.trim();
    if (normalized.length != 10) return null;
    final parts = normalized.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  String _generateInstallId() {
    final now = _now().millisecondsSinceEpoch;
    final rnd = Random(now).nextInt(1 << 32);
    return 'lfy-${now.toRadixString(16)}-${rnd.toRadixString(16)}';
  }

  int _hashToSeed(String value) {
    var hash = 0x811C9DC5;
    for (var i = 0; i < value.length; i++) {
      hash ^= value.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  double _deterministicJitter(String key, int seed) {
    final hash = _hashToSeed('$key|$seed');
    return (hash % 1000) / 1000.0;
  }

  String _normalizeText(String value) {
    var normalized = value.toLowerCase();
    _accentReplace.forEach((raw, clean) {
      normalized = normalized.replaceAll(raw, clean);
    });
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  String? _normalizedCountryDisplay(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    return value.replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _normalizedCountryKey(String? rawDisplay) {
    if (rawDisplay == null) return null;
    final key = _normalizeText(rawDisplay);
    return key.isEmpty ? null : key;
  }

  String? _inferMainRegionKeyFromCountry(String? countryKey) {
    final key = (countryKey ?? '').trim();
    if (key.isEmpty) return null;

    const latino = {
      'puerto rico',
      'mexico',
      'argentina',
      'colombia',
      'chile',
      'peru',
      'venezuela',
      'ecuador',
      'uruguay',
      'paraguay',
      'bolivia',
      'republica dominicana',
      'cuba',
      'panama',
      'costa rica',
      'el salvador',
      'guatemala',
      'honduras',
      'nicaragua',
      'españa',
      'espana',
    };
    if (latino.contains(key)) return 'latino';

    const anglo = {
      'estados unidos',
      'usa',
      'united states',
      'canada',
      'reino unido',
      'uk',
      'inglaterra',
      'australia',
      'nueva zelanda',
      'new zealand',
      'irlanda',
    };
    if (anglo.contains(key)) return 'anglo';

    const asia = {
      'japon',
      'japón',
      'corea del sur',
      'korea',
      'corea',
      'china',
      'taiwan',
      'tailandia',
      'india',
      'filipinas',
      'indonesia',
      'malasia',
      'singapur',
      'vietnam',
    };
    if (asia.contains(key)) return 'asiatico';

    const europa = {
      'francia',
      'alemania',
      'italia',
      'portugal',
      'holanda',
      'paises bajos',
      'belgica',
      'suiza',
      'austria',
      'noruega',
      'suecia',
      'dinamarca',
      'finlandia',
      'polonia',
      'ucrania',
      'rumania',
      'grecia',
      'turquia',
      'turquía',
      'rusia',
    };
    if (europa.contains(key)) return 'europeo';

    const africa = {
      'sudafrica',
      'sudáfrica',
      'nigeria',
      'ghana',
      'kenia',
      'egipto',
      'marruecos',
      'argelia',
      'tunez',
      'túnez',
      'senegal',
      'camerun',
      'camerún',
      'etiopia',
      'etiopía',
    };
    if (africa.contains(key)) return 'africano';

    const medioOriente = {
      'arabia saudita',
      'israel',
      'libano',
      'líbano',
      'jordania',
      'qatar',
      'emiratos arabes unidos',
      'iran',
      'irak',
      'siria',
      'palestina',
      'oman',
      'yemen',
      'kuwait',
      'barein',
      'baréin',
    };
    if (medioOriente.contains(key)) return 'medio_oriente';

    const oceania = {
      'australia',
      'nueva zelanda',
      'new zealand',
      'fiyi',
      'fiji',
      'papua nueva guinea',
    };
    if (oceania.contains(key)) return 'oceania';

    return null;
  }

  static const Map<String, String> _accentReplace = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'à': 'a',
    'è': 'e',
    'ì': 'i',
    'ò': 'o',
    'ù': 'u',
    'ä': 'a',
    'ë': 'e',
    'ï': 'i',
    'ö': 'o',
    'ü': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  static const Map<String, List<String>> _genreLexicon = {
    'trap': ['trap', 'trap latino', 'latin trap'],
    'reggaeton': ['reggaeton', 'regueton', 'regueton'],
    'dembow': ['dembow'],
    'drill': ['drill'],
    'hiphop': ['hiphop', 'hip hop'],
    'rap': ['rap'],
    'edm': ['edm', 'electro', 'electronic'],
    'salsa': ['salsa'],
    'bachata': ['bachata'],
    'cumbia': ['cumbia'],
    'rock': ['rock'],
    'pop': ['pop'],
    'house': ['house'],
    'techno': ['techno'],
    'rnb': ['rnb', 'r&b'],
  };

  static const Map<String, List<String>> _regionLexicon = {
    'latino': ['latino', 'latina', 'latin'],
    'asiatico': ['asiatico', 'asiatica', 'kpop', 'jpop', 'asian'],
    'anglo': ['anglo', 'english', 'ingles', 'uk', 'usa'],
    'europeo': ['euro', 'europe', 'europeo', 'europea'],
    'africano': ['afro', 'african', 'africano', 'africa'],
    'medio_oriente': ['middle east', 'medio oriente', 'arabic'],
    'oceania': ['oceania', 'australia', 'new zealand'],
    'global': ['global', 'world'],
    'puerto rico': ['puerto rico', 'boricua', 'pr'],
    'mexico': ['mexico', 'mexicano'],
    'argentina': ['argentina', 'argentino'],
    'colombia': ['colombia', 'colombiano'],
    'chile': ['chile', 'chileno'],
    'espana': ['espana', 'españa', 'espanol', 'español'],
    'peru': ['peru', 'peruano'],
    'venezuela': ['venezuela', 'venezolano'],
    'ecuador': ['ecuador', 'ecuatoriano'],
    'republica dominicana': ['republica dominicana', 'dominicana', 'rd'],
    'cuba': ['cuba', 'cubano'],
  };

  static const Map<String, String> _genreLabels = {
    'trap': 'trap',
    'reggaeton': 'reggaetón',
    'dembow': 'dembow',
    'drill': 'drill',
    'hiphop': 'hip hop',
    'rap': 'rap',
    'edm': 'EDM',
    'salsa': 'salsa',
    'bachata': 'bachata',
    'cumbia': 'cumbia',
    'rock': 'rock',
    'pop': 'pop',
    'house': 'house',
    'techno': 'techno',
    'rnb': 'R&B',
  };

  static const Map<String, String> _regionLabels = {
    'latino': 'mix latino',
    'asiatico': 'mix asiatico',
    'anglo': 'mix anglo',
    'europeo': 'mix euro',
    'africano': 'mix africano',
    'medio_oriente': 'mix medio oriente',
    'oceania': 'mix oceania',
    'global': 'mix global',
    'puerto rico': 'Puerto Rico',
    'mexico': 'México',
    'argentina': 'Argentina',
    'colombia': 'Colombia',
    'chile': 'Chile',
    'espana': 'España',
    'peru': 'Perú',
    'venezuela': 'Venezuela',
    'ecuador': 'Ecuador',
    'republica dominicana': 'República Dominicana',
    'cuba': 'Cuba',
  };

  static const Map<String, String> _originLabels = {
    'youtube': 'YouTube',
    'instagram': 'Instagram',
    'device': 'tu dispositivo',
    'telegram': 'Telegram',
    'reddit': 'Reddit',
    'facebook': 'Facebook',
    'generic': 'tu biblioteca',
  };
}

class _BuildResult {
  const _BuildResult({required this.profile, required this.set});

  final RecommendationProfile profile;
  final RecommendationDailySet set;
}

class _SourceLabels {
  final List<String> topics = <String>[];
  final List<String> playlists = <String>[];
}

class _ArtistLocale {
  const _ArtistLocale({
    required this.countryDisplay,
    required this.mainRegionKey,
    required this.isMainRegionExplicit,
  });

  final String? countryDisplay;
  final String? mainRegionKey;
  final bool isMainRegionExplicit;
}

class _RecommendationCandidate {
  const _RecommendationCandidate({
    required this.item,
    required this.stableKey,
    required this.primaryArtistKey,
    required this.primaryArtistName,
    required this.artistKeys,
    required this.artistNameByKey,
    required this.genres,
    required this.regions,
    required this.countryKey,
    required this.regionDisplayByKey,
    required this.dominantTag,
    required this.originKey,
  });

  final MediaItem item;
  final String stableKey;
  final String primaryArtistKey;
  final String primaryArtistName;
  final List<String> artistKeys;
  final Map<String, String> artistNameByKey;
  final List<String> genres;
  final List<String> regions;
  final String? countryKey;
  final Map<String, String> regionDisplayByKey;
  final String dominantTag;
  final String originKey;
}

class _ScoredCandidate {
  const _ScoredCandidate({
    required this.candidate,
    required this.score,
    required this.reasonCode,
    required this.reasonText,
  });

  final _RecommendationCandidate candidate;
  final double score;
  final RecommendationReasonCode reasonCode;
  final String reasonText;
}

class _ScoreResult {
  const _ScoreResult({
    required this.score,
    required this.reasonCode,
    required this.reasonText,
  });

  final double score;
  final RecommendationReasonCode reasonCode;
  final String reasonText;
}

class _ReasonResult {
  const _ReasonResult({required this.code, required this.text});

  final RecommendationReasonCode code;
  final String text;
}

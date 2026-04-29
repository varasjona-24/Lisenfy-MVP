import 'package:dio/dio.dart';

import '../../../app/data/network/dio_client.dart';
import '../../../app/models/media_item.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../../sources/domain/source_origin.dart';
import '../domain/contracts/recommendation_engine.dart';
import '../domain/recommendation_feedback_models.dart';
import '../domain/recommendation_models.dart';
import 'local_recommendation_service.dart';
import 'recommendation_feedback_service.dart';

class HybridRecommendationService implements RecommendationEngine {
  HybridRecommendationService({
    required LocalRecommendationService localEngine,
    required DioClient client,
    required Future<List<MediaItem>> Function() libraryLoader,
    RecommendationFeedbackService? feedbackService,
    DateTime Function()? now,
  }) : _localEngine = localEngine,
       _client = client,
       _libraryLoader = libraryLoader,
       _feedbackService = feedbackService,
       _now = now ?? DateTime.now;

  final LocalRecommendationService _localEngine;
  final DioClient _client;
  final Future<List<MediaItem>> Function() _libraryLoader;
  final RecommendationFeedbackService? _feedbackService;
  final DateTime Function() _now;

  static const int _minimumRemoteEntries = 8;
  static const int _remoteLimit = 80;

  @override
  Future<RecommendationDailySet> getOrBuildForDay({
    required RecommendationMode mode,
  }) async {
    final local = await _localEngine.getOrBuildForDay(mode: mode);
    final remote = await _tryRemoteDaily(
      mode: mode,
      manualRefreshCount: local.manualRefreshCount,
      lastRefreshAt: local.lastRefreshAt,
    );
    return remote ?? local;
  }

  @override
  Future<RecommendationDailySet> refreshManually({
    required RecommendationMode mode,
  }) async {
    if (!_localEngine.canManualRefreshToday(mode: mode)) {
      return _localEngine.getOrBuildForDay(mode: mode);
    }

    final local = await _localEngine.refreshManually(mode: mode);
    final remote = await _tryRemoteDaily(
      mode: mode,
      manualRefreshCount: local.manualRefreshCount,
      lastRefreshAt: local.lastRefreshAt,
    );
    return remote ?? local;
  }

  @override
  bool canManualRefreshToday({required RecommendationMode mode}) {
    return _localEngine.canManualRefreshToday(mode: mode);
  }

  @override
  String? nextRefreshHint({required RecommendationMode mode}) {
    return _localEngine.nextRefreshHint(mode: mode);
  }

  @override
  Future<void> reloadFromStore() async {
    await _localEngine.reloadFromStore();
  }

  Future<RecommendationDailySet?> _tryRemoteDaily({
    required RecommendationMode mode,
    required int manualRefreshCount,
    required int? lastRefreshAt,
  }) async {
    try {
      final library = await _libraryLoader();
      final candidates = library
          .where(
            (item) => mode == RecommendationMode.audio
                ? item.hasAudioLocal
                : item.hasVideoLocal,
          )
          .toList(growable: false);
      if (candidates.length < _minimumRemoteEntries) return null;

      final feedback = await _readFeedback();
      final response = await _client
          .post<Map<String, dynamic>>(
            '/agent/recommendations/daily',
            data: <String, dynamic>{
              'mode': mode.key,
              'dateKey': _dateKey(_now()),
              'limit': _remoteLimit,
              'tracks': candidates.take(600).map(_trackPayload).toList(),
              'recentTrackIds': _recentTrackIds(candidates),
              'hiddenTrackIds': _hiddenTrackIds(feedback),
              'feedback': _feedbackPayload(feedback),
            },
            options: Options(
              sendTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 5),
            ),
          )
          .timeout(const Duration(seconds: 6));

      final data = response.data;
      if (data == null) return null;
      final responseMap = Map<String, dynamic>.from(data);
      final rawBody = responseMap['data'];
      final body = rawBody is Map
          ? Map<String, dynamic>.from(rawBody)
          : responseMap;
      final set = RecommendationDailySet.fromJson({
        ...body,
        'manualRefreshCount': manualRefreshCount,
        'lastRefreshAt': lastRefreshAt,
      });
      if (set.entries.length < _minimumRemoteEntries) return null;
      return set;
    } catch (_) {
      return null;
    }
  }

  Future<RecommendationFeedbackSnapshot> _readFeedback() async {
    final service = _feedbackService;
    if (service == null) return RecommendationFeedbackSnapshot.empty();
    try {
      return await service.readSnapshot();
    } catch (_) {
      return RecommendationFeedbackSnapshot.empty();
    }
  }

  Map<String, dynamic> _trackPayload(MediaItem item) {
    final artist = item.displaySubtitle.trim();
    return <String, dynamic>{
      'id': item.id,
      'publicId': item.publicId.trim().isNotEmpty ? item.publicId : item.id,
      'title': item.title,
      'artist': artist,
      'artistKey': ArtistCreditParser.normalizeKey(artist),
      'source': item.source.name,
      'originKey': item.origin.key,
      'thumbnail': item.effectiveThumbnail,
      'durationSeconds': item.effectiveDurationSeconds,
      'isFavorite': item.isFavorite,
      'playCount': item.playCount,
      'lastPlayedAt': item.lastPlayedAt,
      'skipCount': item.skipCount,
      'fullListenCount': item.fullListenCount,
      'avgListenProgress': item.avgListenProgress,
      'lastCompletedAt': item.lastCompletedAt,
    };
  }

  List<String> _recentTrackIds(List<MediaItem> items) {
    final recent = items.where((item) => (item.lastPlayedAt ?? 0) > 0).toList()
      ..sort((a, b) => (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0));
    return recent
        .take(80)
        .map(
          (item) => item.publicId.trim().isNotEmpty ? item.publicId : item.id,
        )
        .toList(growable: false);
  }

  List<String> _hiddenTrackIds(RecommendationFeedbackSnapshot feedback) {
    return feedback.state.hiddenTrackKeys
        .map((key) {
          final value = key.trim();
          if (value.startsWith('p:') || value.startsWith('i:')) {
            return value.substring(2);
          }
          return value;
        })
        .where((key) => key.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> _feedbackPayload(
    RecommendationFeedbackSnapshot feedback,
  ) {
    return <String, dynamic>{
      'trackBias': feedback.state.trackBias,
      'artistBias': feedback.state.artistBias,
      'tagBias': feedback.state.tagBias,
      'hiddenArtistKeys': feedback.state.hiddenArtistKeys.toList(),
      'updatedAt': feedback.state.updatedAt,
    };
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

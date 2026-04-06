import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/recommendations/application/recommendation_feedback_service.dart';
import 'package:listenfy/Modules/recommendations/data/recommendation_feedback_store.dart';

void main() {
  group('RecommendationFeedbackService', () {
    test('marca track interesado y refleja bias positivo', () async {
      final service = RecommendationFeedbackService(
        store: RecommendationFeedbackStore.memory(),
      );

      await service.markTrackInterested('p:abc');
      final snapshot = await service.readSnapshot();

      expect(snapshot.trackBiasForStableKey('p:abc'), greaterThan(0));
      expect(snapshot.isTrackHidden('p:abc'), isFalse);
    });

    test('oculta artista y lo reporta en snapshot', () async {
      final service = RecommendationFeedbackService(
        store: RecommendationFeedbackStore.memory(),
      );

      await service.hideArtist('artist:foo');
      final snapshot = await service.readSnapshot();

      expect(snapshot.hasHiddenArtist(const ['artist:foo']), isTrue);
      expect(snapshot.hasHiddenArtist(const ['artist:bar']), isFalse);
    });
  });
}

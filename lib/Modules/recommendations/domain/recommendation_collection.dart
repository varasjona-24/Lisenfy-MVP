import '../../../app/models/media_item.dart';

class RecommendationCollection {
  const RecommendationCollection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<MediaItem> items;
}

import 'package:listenfy/app/models/media_item.dart';

abstract class HistoryRepository {
  Future<List<MediaItem>> loadHistoryItems();
}


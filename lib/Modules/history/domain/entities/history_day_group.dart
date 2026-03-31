import 'package:listenfy/app/models/media_item.dart';

class HistoryDayGroup {
  const HistoryDayGroup({
    required this.date,
    required this.label,
    required this.items,
  });

  final DateTime date;
  final String label;
  final List<MediaItem> items;
}


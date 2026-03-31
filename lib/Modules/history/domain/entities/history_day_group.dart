import 'package:listenfy/app/models/media_item.dart';

/// Entidad de dominio para renderizar el historial agrupado por día.
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

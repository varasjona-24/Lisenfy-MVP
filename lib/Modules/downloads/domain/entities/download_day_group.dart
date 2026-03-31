import 'package:listenfy/app/models/media_item.dart';

/// Entidad de dominio para renderizar historial de imports agrupado por día.
class DownloadDayGroup {
  const DownloadDayGroup({
    required this.date,
    required this.label,
    required this.items,
  });

  final DateTime date;
  final String label;
  final List<MediaItem> items;
}

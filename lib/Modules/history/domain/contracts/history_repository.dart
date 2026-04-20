import 'package:listenfy/app/models/media_item.dart';

/// Contrato de dominio para obtener el historial.
/// La implementación concreta vive en `data/repositories`.
abstract class HistoryRepository {
  /// Devuelve items con actividad reciente (ya normalizados por la impl).
  Future<List<MediaItem>> loadHistoryItems();
}

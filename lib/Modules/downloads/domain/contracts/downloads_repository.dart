import 'package:listenfy/app/models/media_item.dart';

/// Contrato de dominio para el módulo de imports/descargas.
abstract class DownloadsRepository {
  /// Lista de elementos con variantes locales disponibles (biblioteca local).
  Future<List<MediaItem>> loadDownloadedItems();

  /// Lista de elementos marcados como offline para historial de imports.
  Future<List<MediaItem>> loadDownloadHistoryItems();
}

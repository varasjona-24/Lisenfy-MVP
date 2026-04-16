import 'media_item.dart';

/// Entidad recursiva para agrupar historial por niveles (Mes > Semana > Día).
class HistoryGroup {
  const HistoryGroup({
    required this.id,
    required this.label,
    required this.date,
    this.items,
    this.subGroups,
  }) : assert(items != null || subGroups != null, 'Debe tener items o subgrupos');

  /// Identificador único para el estado de colapsado (ej: "2024-03-W1").
  final String id;

  /// Etiqueta visible (ej: "Marzo", "Semana 1").
  final String label;

  /// Fecha de referencia para ordenamiento.
  final DateTime date;

  /// Lista de canciones (nodos hoja).
  final List<MediaItem>? items;

  /// Subniveles anidados (ej: las semanas dentro de un mes).
  final List<HistoryGroup>? subGroups;

  bool get isLeaf => items != null;
  bool get hasSubGroups => subGroups != null && subGroups!.isNotEmpty;
}

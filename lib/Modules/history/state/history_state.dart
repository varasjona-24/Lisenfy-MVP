import 'package:listenfy/app/models/history_group.dart';
import 'package:listenfy/Modules/history/domain/entities/history_kind_filter.dart';
import 'package:listenfy/app/core/presentation/view_status.dart';
import 'package:listenfy/app/models/media_item.dart';

// ============================
// 🧭 STATE: HISTORIAL
// ============================
// Estado inmutable para la pantalla de historial.
class HistoryState {
  const HistoryState({
    required this.status,
    required this.allItems,
    required this.filteredItems,
    required this.groups,
    required this.filter,
    required this.expandedSections,
    this.errorMessage,
  });

  // Estado inicial del módulo.
  factory HistoryState.initial() {
    return const HistoryState(
      status: ViewStatus.idle,
      allItems: <MediaItem>[],
      filteredItems: <MediaItem>[],
      groups: <HistoryGroup>[],
      filter: HistoryKindFilter.audio,
      expandedSections: <String>{},
      errorMessage: null,
    );
  }

  final ViewStatus status;
  final List<MediaItem> allItems;
  final List<MediaItem> filteredItems;
  final List<HistoryGroup> groups;
  final HistoryKindFilter filter;
  final Set<String> expandedSections;
  final String? errorMessage;

  // Actualiza campos de forma declarativa.
  HistoryState copyWith({
    ViewStatus? status,
    List<MediaItem>? allItems,
    List<MediaItem>? filteredItems,
    List<HistoryGroup>? groups,
    HistoryKindFilter? filter,
    Set<String>? expandedSections,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HistoryState(
      status: status ?? this.status,
      allItems: allItems ?? this.allItems,
      filteredItems: filteredItems ?? this.filteredItems,
      groups: groups ?? this.groups,
      filter: filter ?? this.filter,
      expandedSections: expandedSections ?? this.expandedSections,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

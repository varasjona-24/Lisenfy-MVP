import 'package:listenfy/Modules/history/domain/entities/history_day_group.dart';
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
    this.errorMessage,
  });

  // Estado inicial del módulo.
  factory HistoryState.initial() {
    return const HistoryState(
      status: ViewStatus.idle,
      allItems: <MediaItem>[],
      filteredItems: <MediaItem>[],
      groups: <HistoryDayGroup>[],
      filter: HistoryKindFilter.audio,
      errorMessage: null,
    );
  }

  final ViewStatus status;
  final List<MediaItem> allItems;
  final List<MediaItem> filteredItems;
  final List<HistoryDayGroup> groups;
  final HistoryKindFilter filter;
  final String? errorMessage;

  // Actualiza campos de forma declarativa.
  HistoryState copyWith({
    ViewStatus? status,
    List<MediaItem>? allItems,
    List<MediaItem>? filteredItems,
    List<HistoryDayGroup>? groups,
    HistoryKindFilter? filter,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HistoryState(
      status: status ?? this.status,
      allItems: allItems ?? this.allItems,
      filteredItems: filteredItems ?? this.filteredItems,
      groups: groups ?? this.groups,
      filter: filter ?? this.filter,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

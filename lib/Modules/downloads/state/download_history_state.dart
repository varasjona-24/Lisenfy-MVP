import 'package:listenfy/app/models/history_group.dart';
import 'package:listenfy/Modules/downloads/domain/entities/download_history_filter.dart';
import 'package:listenfy/app/core/presentation/view_status.dart';
import 'package:listenfy/app/models/media_item.dart';

// ============================
// 🧭 STATE: HISTORIAL DE IMPORTS
// ============================
class DownloadHistoryState {
  const DownloadHistoryState({
    required this.status,
    required this.allItems,
    required this.filteredItems,
    required this.groups,
    required this.filter,
    required this.query,
    required this.expandedSections,
    this.errorMessage,
  });

  factory DownloadHistoryState.initial() {
    return const DownloadHistoryState(
      status: ViewStatus.idle,
      allItems: <MediaItem>[],
      filteredItems: <MediaItem>[],
      groups: <HistoryGroup>[],
      filter: DownloadHistoryFilter.audio,
      query: '',
      expandedSections: <String>{},
      errorMessage: null,
    );
  }

  final ViewStatus status;
  final List<MediaItem> allItems;
  final List<MediaItem> filteredItems;
  final List<HistoryGroup> groups;
  final DownloadHistoryFilter filter;
  final String query;
  final Set<String> expandedSections;
  final String? errorMessage;

  DownloadHistoryState copyWith({
    ViewStatus? status,
    List<MediaItem>? allItems,
    List<MediaItem>? filteredItems,
    List<HistoryGroup>? groups,
    DownloadHistoryFilter? filter,
    String? query,
    Set<String>? expandedSections,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DownloadHistoryState(
      status: status ?? this.status,
      allItems: allItems ?? this.allItems,
      filteredItems: filteredItems ?? this.filteredItems,
      groups: groups ?? this.groups,
      filter: filter ?? this.filter,
      query: query ?? this.query,
      expandedSections: expandedSections ?? this.expandedSections,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

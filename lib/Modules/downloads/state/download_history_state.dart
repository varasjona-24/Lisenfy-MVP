import 'package:listenfy/Modules/downloads/domain/entities/download_day_group.dart';
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
    this.errorMessage,
  });

  factory DownloadHistoryState.initial() {
    return const DownloadHistoryState(
      status: ViewStatus.idle,
      allItems: <MediaItem>[],
      filteredItems: <MediaItem>[],
      groups: <DownloadDayGroup>[],
      filter: DownloadHistoryFilter.audio,
      query: '',
      errorMessage: null,
    );
  }

  final ViewStatus status;
  final List<MediaItem> allItems;
  final List<MediaItem> filteredItems;
  final List<DownloadDayGroup> groups;
  final DownloadHistoryFilter filter;
  final String query;
  final String? errorMessage;

  DownloadHistoryState copyWith({
    ViewStatus? status,
    List<MediaItem>? allItems,
    List<MediaItem>? filteredItems,
    List<DownloadDayGroup>? groups,
    DownloadHistoryFilter? filter,
    String? query,
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
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

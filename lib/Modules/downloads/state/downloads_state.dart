import 'package:listenfy/app/core/presentation/view_status.dart';
import 'package:listenfy/app/models/media_item.dart';

// ============================
// 🧭 STATE: IMPORTS
// ============================
class DownloadsState {
  const DownloadsState({
    required this.status,
    required this.items,
    this.errorMessage,
  });

  factory DownloadsState.initial() {
    return const DownloadsState(
      status: ViewStatus.idle,
      items: <MediaItem>[],
      errorMessage: null,
    );
  }

  final ViewStatus status;
  final List<MediaItem> items;
  final String? errorMessage;

  DownloadsState copyWith({
    ViewStatus? status,
    List<MediaItem>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DownloadsState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

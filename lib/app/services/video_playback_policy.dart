import 'dart:async';
import 'dart:io';

/// Engine completion is not the statistical threshold for a watched video.
bool videoEngineCompleted({
  required bool completed,
  required bool buffering,
  required bool hasError,
}) => completed && !buffering && !hasError;

String videoFailureKey(Object error, {required bool remote}) {
  if (error is TimeoutException) return 'player.video_timeout';
  if (error is SocketException || error is HttpException) {
    return 'player.video_network_error';
  }
  if (error is FileSystemException) return 'player.video_file_missing';
  final message = error.toString().toLowerCase();
  if (message.contains('format_unsupported') ||
      message.contains('decoder_init_failed') ||
      message.contains('no suitable decoder')) {
    return 'player.video_format_error';
  }
  if (remote &&
      (message.contains('network') ||
          message.contains('http') ||
          message.contains('unable to connect'))) {
    return 'player.video_network_error';
  }
  return 'player.video_engine_error';
}

import 'dart:io';

import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

/// Register before any AudioPlayer or VideoPlayerController is constructed.
/// macOS and mobile retain their existing native implementations.
void initializeDesktopPlaybackBackend() {
  if (!Platform.isWindows) return;
  JustAudioMediaKit.title = 'Listenfy';
  JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
  VideoPlayerMediaKit.ensureInitialized(windows: true);
}

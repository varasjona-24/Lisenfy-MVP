import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/services/video_playback_policy.dart';

void main() {
  test('only an actual engine end completes playback', () {
    expect(
      videoEngineCompleted(completed: false, buffering: false, hasError: false),
      isFalse,
    );
    expect(
      videoEngineCompleted(completed: true, buffering: false, hasError: false),
      isTrue,
    );
    expect(
      videoEngineCompleted(completed: true, buffering: true, hasError: false),
      isFalse,
    );
    expect(
      videoEngineCompleted(completed: true, buffering: false, hasError: true),
      isFalse,
    );
  });
  test('failures distinguish missing files, network and timeout', () {
    expect(
      videoFailureKey(const FileSystemException('missing'), remote: false),
      'player.video_file_missing',
    );
    expect(
      videoFailureKey(const SocketException('offline'), remote: true),
      'player.video_network_error',
    );
    expect(
      videoFailureKey(TimeoutException('slow initialization'), remote: false),
      'player.video_timeout',
    );
    expect(
      videoFailureKey(const HttpException('HTTP 404'), remote: true),
      'player.video_network_error',
    );
  });
  test('unknown errors never claim a file is corrupt', () {
    expect(
      videoFailureKey(StateError('unknown engine failure'), remote: false),
      'player.video_engine_error',
    );
    expect(
      videoFailureKey(StateError('decoder_init_failed'), remote: false),
      'player.video_format_error',
    );
    expect(
      videoFailureKey(StateError('network unavailable'), remote: true),
      'player.video_network_error',
    );
  });
}

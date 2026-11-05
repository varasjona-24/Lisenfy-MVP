import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/services/playback_artwork.dart';

void main() {
  MediaItem item({String? local, String? remote}) => MediaItem.fromJson({
    'id': 'song',
    'title': 'Song',
    'thumbnailLocalPath': local,
    'thumbnail': remote,
    'variants': [],
  });
  Uri? resolve(
    MediaItem media, {
    bool android = true,
    Set<String> files = const {},
  }) => resolvePlaybackArtwork(
    media,
    android: android,
    androidAuthority: 'test.listenfy.android_auto_artwork',
    fileExists: files.contains,
  );

  test(
    'existing downloaded, transferred and capture artwork uses the media provider',
    () {
      for (final path in [
        '/app/app_flutter/downloads/covers/song.jpg',
        '/app/app_flutter/media/covers/song.png',
        '/app/app_flutter/ListenfyCaptures/mi captura á.jpg',
      ]) {
        final uri = resolve(item(local: path), files: {path})!;
        expect(uri.scheme, 'content');
        expect(uri.host, 'test.listenfy.android_auto_artwork');
        expect(
          utf8.decode(
            base64Url.decode(base64Url.normalize(uri.pathSegments.last)),
          ),
          path,
        );
      }
    },
  );
  test('missing local art falls back to a valid remote thumbnail', () {
    expect(
      resolve(
        item(local: '/missing.jpg', remote: 'https://example.com/cover.jpg'),
      ),
      Uri.parse('https://example.com/cover.jpg'),
    );
    expect(resolve(item(local: '/missing.jpg')), isNull);
    expect(resolve(item(remote: 'not a valid remote URL')), isNull);
  });
  test('local artwork wins, and non-Android clients get file URIs', () {
    const path = '/covers/song.jpg';
    final media = item(local: path, remote: 'https://example.com/cover.jpg');
    expect(resolve(media, files: {path})!.scheme, 'content');
    expect(resolve(media, android: false, files: {path}), Uri.file(path));
  });
  test('legacy local thumbnail and encoded file paths remain usable', () {
    const path = '/covers/cover with spaces.png';
    expect(resolve(item(remote: path), files: {path})!.scheme, 'content');
    expect(
      resolve(
        item(local: Uri.file(path).toString()),
        android: false,
        files: {path},
      ),
      Uri.file(path),
    );
  });
}

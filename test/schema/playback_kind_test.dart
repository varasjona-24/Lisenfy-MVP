import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/utils/playback_kind.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';

void main() {
  MediaItem item(List<MediaVariantKind> kinds) => MediaItem(
    id: 'test',
    publicId: 'test',
    origin: SourceOrigin.device,
    title: 'Honey',
    subtitle: '',
    source: MediaSource.local,
    variants: kinds
        .map(
          (kind) => MediaVariant(
            kind: kind,
            format: 'mp3',
            fileName: 'file.mp3',
            createdAt: 1,
          ),
        )
        .toList(),
  );
  test('audio-only cannot be routed to video by another screen preference', () {
    expect(
      playbackKindFor(
        item([MediaVariantKind.audio]),
        preferred: MediaVariantKind.video,
      ),
      MediaVariantKind.audio,
    );
  });
  test('video-only selects video, independent of home', () {
    expect(
      playbackKindFor(item([MediaVariantKind.video])),
      MediaVariantKind.video,
    );
  });
  test('dual media follows explicit caller, defaults to audio', () {
    final dual = item([MediaVariantKind.audio, MediaVariantKind.video]);
    expect(playbackKindFor(dual), MediaVariantKind.audio);
    expect(
      playbackKindFor(dual, preferred: MediaVariantKind.video),
      MediaVariantKind.video,
    );
  });
}

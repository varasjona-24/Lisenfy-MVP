import '../models/media_item.dart';

/// Screen preference is explicit, never inherited from another module.
MediaVariantKind playbackKindFor(
  MediaItem item, {
  MediaVariantKind preferred = MediaVariantKind.audio,
}) {
  bool supports(MediaVariantKind kind) =>
      item.variants.any((v) => v.kind == kind && v.isValid);
  if (supports(preferred)) return preferred;
  final alternate = preferred == MediaVariantKind.audio
      ? MediaVariantKind.video
      : MediaVariantKind.audio;
  return supports(alternate) ? alternate : preferred;
}

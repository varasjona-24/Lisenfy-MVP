enum CaptureCoverTargetType { video, audio, topic, playlist }

class CaptureCoverTarget {
  const CaptureCoverTarget({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.type,
    this.thumbnailLocalPath,
    this.thumbnailUrl,
  });

  final String id;
  final String label;
  final String subtitle;
  final CaptureCoverTargetType type;
  final String? thumbnailLocalPath;
  final String? thumbnailUrl;

  bool get isVideo => type == CaptureCoverTargetType.video;
  bool get isAudio => type == CaptureCoverTargetType.audio;
  bool get isMedia => isVideo || isAudio;
  bool get isCollection => !isMedia;
}

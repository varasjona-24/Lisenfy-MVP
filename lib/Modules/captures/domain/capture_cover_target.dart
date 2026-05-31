enum CaptureCoverTargetType { video, topic, playlist }

class CaptureCoverTarget {
  const CaptureCoverTarget({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.type,
  });

  final String id;
  final String label;
  final String subtitle;
  final CaptureCoverTargetType type;

  bool get isVideo => type == CaptureCoverTargetType.video;
  bool get isCollection => !isVideo;
}

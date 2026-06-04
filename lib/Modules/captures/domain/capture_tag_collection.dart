class CaptureTagCollection {
  const CaptureTagCollection({
    required this.name,
    required this.colorValue,
    this.thumbnailPath,
  });

  final String name;
  final int colorValue;
  final String? thumbnailPath;

  factory CaptureTagCollection.fromJson(
    Map<dynamic, dynamic> json, {
    required String fallbackName,
    required int fallbackColor,
  }) {
    return CaptureTagCollection(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : fallbackName,
      colorValue: (json['colorValue'] as num?)?.toInt() ?? fallbackColor,
      thumbnailPath:
          (json['thumbnailPath'] as String?)?.trim().isNotEmpty == true
          ? (json['thumbnailPath'] as String).trim()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'colorValue': colorValue,
    if (thumbnailPath != null && thumbnailPath!.trim().isNotEmpty)
      'thumbnailPath': thumbnailPath,
  };
}

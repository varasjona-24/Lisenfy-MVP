class CaptureItem {
  const CaptureItem({
    required this.path,
    required this.name,
    required this.modifiedAt,
    required this.size,
    this.tags = const <String>[],
    this.sourceTitle,
    this.sourceId,
  });

  final String path;
  final String name;
  final DateTime modifiedAt;
  final int size;
  final List<String> tags;
  final String? sourceTitle;
  final String? sourceId;

  factory CaptureItem.fromJson(Map<String, dynamic> json) {
    return CaptureItem(
      path: (json['path'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      modifiedAt:
          DateTime.tryParse((json['modifiedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      size: (json['size'] as num?)?.toInt() ?? 0,
      tags:
          (json['tags'] as List?)
              ?.map((tag) => tag.toString())
              .where((tag) => tag.trim().isNotEmpty)
              .toList() ??
          const <String>[],
      sourceTitle: (json['sourceTitle'] as String?)?.trim(),
      sourceId: (json['sourceId'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'modifiedAt': modifiedAt.toIso8601String(),
    'size': size,
    'tags': tags,
    'sourceTitle': sourceTitle,
    'sourceId': sourceId,
  };
}

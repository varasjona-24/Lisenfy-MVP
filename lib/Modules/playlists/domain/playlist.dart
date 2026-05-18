class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.itemIds,
    required this.createdAt,
    required this.updatedAt,
    this.itemAddedAt = const {},
    this.coverUrl,
    this.coverLocalPath,
    this.coverCleared = false,
  });

  final String id;
  final String name;
  final List<String> itemIds;
  final int createdAt;
  final int updatedAt;
  final Map<String, int> itemAddedAt;
  final String? coverUrl;
  final String? coverLocalPath;
  final bool coverCleared;

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? itemIds,
    int? createdAt,
    int? updatedAt,
    Map<String, int>? itemAddedAt,
    String? coverUrl,
    String? coverLocalPath,
    bool? coverCleared,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      itemAddedAt: itemAddedAt ?? this.itemAddedAt,
      coverUrl: coverUrl ?? this.coverUrl,
      coverLocalPath: coverLocalPath ?? this.coverLocalPath,
      coverCleared: coverCleared ?? this.coverCleared,
    );
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['itemIds'] as List?) ?? const [];
    final rawAddedAt = (json['itemAddedAt'] as Map?) ?? const {};
    return Playlist(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? 'Lista sin nombre',
      itemIds: rawItems.whereType<String>().toList(),
      createdAt: (json['createdAt'] as int?) ?? 0,
      updatedAt: (json['updatedAt'] as int?) ?? 0,
      itemAddedAt: rawAddedAt.map(
        (key, value) => MapEntry(
          key.toString(),
          value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0,
        ),
      ),
      coverUrl: (json['coverUrl'] as String?)?.trim(),
      coverLocalPath: (json['coverLocalPath'] as String?)?.trim(),
      coverCleared: (json['coverCleared'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'itemIds': itemIds,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'itemAddedAt': itemAddedAt,
    'coverUrl': coverUrl,
    'coverLocalPath': coverLocalPath,
    'coverCleared': coverCleared,
  };
}

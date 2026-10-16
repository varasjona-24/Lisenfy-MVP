/// Portable supplement for modules not present in older logical manifests.
class DomainBackupCodec {
  static const keys = {
    'recommendation_mix_state_v2',
    'recommendation_ml_state_v1',
    'world_mode_country_discovery_v1',
    'world_mode_station_memory_v1',
    'world_mode_country_affinity_v1',
    'world_mode_playback_events_v1',
    'instrumental_tasks_v1',
    'spatial8d_tasks_v1',
  };
  static const fileFields = {
    'localPath',
    'sourcePath',
    'outputPath',
    'resultPath',
    'thumbnailLocalPath',
    'coverLocalPath',
    'thumbnailPath',
  };
  static const marker = '__sqlite_backup_file_v1';

  static Future<dynamic> encode(
    dynamic value,
    Future<String?> Function(String) copyFile, {
    String? field,
  }) async {
    if (fileFields.contains(field) && value is String && value.isNotEmpty) {
      return {marker: await copyFile(value)};
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        result[entry.key as String] = await encode(
          entry.value,
          copyFile,
          field: entry.key as String,
        );
      }
      return result;
    }
    if (value is List) {
      return [for (final entry in value) await encode(entry, copyFile)];
    }
    return value;
  }

  static Future<dynamic> decode(
    dynamic value,
    Future<String?> Function(String) restoreFile, {
    String? field,
  }) async {
    if (fileFields.contains(field) &&
        value is Map &&
        value.containsKey(marker)) {
      if (value.length != 1) throw FormatException('Invalid file reference');
      final locator = value[marker];
      if (locator == null) return null;
      if (locator is! String ||
          locator.startsWith('/') ||
          locator.contains('\\') ||
          locator.contains(':') ||
          locator.isEmpty ||
          locator
              .split('/')
              .any((part) => part == '..' || part == '.' || part.isEmpty)) {
        throw FormatException('Invalid backup file locator');
      }
      return restoreFile(locator);
    }
    if (fileFields.contains(field) && value is String && value.isNotEmpty) {
      throw FormatException('Unrebased file in durable backup');
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        result[entry.key as String] = await decode(
          entry.value,
          restoreFile,
          field: entry.key as String,
        );
      }
      return result;
    }
    if (value is List) {
      return [for (final entry in value) await decode(entry, restoreFile)];
    }
    return value;
  }
}

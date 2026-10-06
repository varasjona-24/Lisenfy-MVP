import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../playback/playback_repository.dart';

GetStorage domainStorage(GetStorage legacy) =>
    Get.isRegistered<DomainStorage>() ? Get.find<DomainStorage>() : legacy;

/// SQL-backed read projection for durable domains; other keys remain preferences.
class DomainStorage implements GetStorage {
  DomainStorage._(this.repository, this.preferences, this._values);
  final PlaybackRepository repository;
  final GetStorage preferences;
  final Map<String, dynamic> _values;
  Future<void> _tail = Future<void>.value();
  Object? failure;

  static Future<DomainStorage> open(
    PlaybackRepository repository,
    GetStorage legacy,
    String scope, {
    Directory? supportDirectory,
    Directory? capturesDirectory,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(scope)) {
      throw ArgumentError('Invalid durable migration scope');
    }
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}/playback/debug-migration-$scope',
    );
    await directory.create(recursive: true);
    final source = File('${directory.path}/domains_source.json');
    if (!await source.exists()) {
      final values = {
        for (final key in durableDomainKeys.keys) key: legacy.read(key),
      };
      final captures =
          capturesDirectory ??
          Directory(
            '${(await getApplicationDocumentsDirectory()).path}/ListenfyCaptures',
          );
      final files = Map<String, dynamic>.from(
        values['capture_files_v1'] as Map? ?? {},
      );
      if (await captures.exists()) {
        await for (final entity in captures.list(followLinks: false)) {
          if (entity is! File ||
              !RegExp(
                r'\.(jpg|jpeg|png)$',
                caseSensitive: false,
              ).hasMatch(entity.path)) {
            continue;
          }
          final stat = await entity.stat();
          files[entity.path] = {
            'size': stat.size,
            'modifiedAt': stat.modified.millisecondsSinceEpoch,
          };
        }
      }
      values['capture_files_v1'] = files;
      // Older versions may only have the single selected background path.
      final backgrounds = values['appBackgroundImagePaths'];
      final selected = legacy.read<String>('appBackgroundImagePath');
      if ((backgrounds == null || backgrounds is List && backgrounds.isEmpty) &&
          selected != null &&
          selected.isNotEmpty) {
        values['appBackgroundImagePaths'] = [selected];
      }
      final pending = File('${source.path}.pending');
      await pending.writeAsString(jsonEncode(values), flush: true);
      await pending.rename(source.path);
    }
    final bytes = await source.readAsString();
    await repository.importDomains(
      'domains-$scope',
      sha256.convert(utf8.encode(bytes)).toString(),
      jsonDecode(bytes) as Map<String, dynamic>,
    );
    return DomainStorage._(repository, legacy, await repository.readDomains());
  }

  @override
  T? read<T>(String key) => durableDomainKeys.containsKey(key)
      ? _values[key] as T?
      : preferences.read<T>(key);

  Future<void> reload() async {
    await flush();
    final loaded = await repository.readDomains();
    _values
      ..clear()
      ..addAll(loaded);
  }

  Future<void> flush() async {
    await _tail;
    if (failure != null) throw StateError('Durable storage failed: $failure');
  }

  Future<void> restoreValues(Map<String, dynamic> values) {
    final copy = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(values)) as Map,
    );
    final operation = _tail.then((_) async {
      if (failure != null) throw StateError('Durable storage failed: $failure');
      await repository.restoreDomainValues(copy);
      final loaded = await repository.readDomains();
      _values
        ..clear()
        ..addAll(loaded);
    });
    _tail = operation.catchError((Object error) {
      failure = error;
    });
    return operation;
  }

  @override
  Future<void> write(String key, dynamic value) {
    if (!durableDomainKeys.containsKey(key)) {
      return preferences.write(key, value);
    }
    final copy = jsonDecode(jsonEncode(value));
    if ((key == 'instrumental_tasks_v1' || key == 'spatial8d_tasks_v1') &&
        copy is Map) {
      for (final snapshot in copy.values) {
        if (snapshot is Map) {
          snapshot.remove('progress');
          snapshot.remove('message');
        }
      }
    }
    final operation = _tail.then((_) async {
      if (failure != null) throw StateError('Durable storage failed: $failure');
      await repository.replaceDomain(key, copy);
      if (copy == null) {
        _values.remove(key);
      } else {
        _values[key] = copy;
      }
    });
    _tail = operation.catchError((Object error) {
      failure = error;
    });
    return operation;
  }

  @override
  Future<void> remove(String key) => durableDomainKeys.containsKey(key)
      ? write(key, null)
      : preferences.remove(key);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Durable adapter supports read/write/remove only');
}

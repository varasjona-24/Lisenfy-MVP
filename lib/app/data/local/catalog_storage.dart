import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../playback/playback_repository.dart';

GetStorage catalogStorage(GetStorage legacy) =>
    Get.isRegistered<CatalogStorage>() ? Get.find<CatalogStorage>() : legacy;

/// Transitional synchronous read projection. SQL commits own durable data.
/// Only catalog keys are supported; preferences never pass through this adapter.
class CatalogStorage implements GetStorage {
  CatalogStorage._(this.repository, this._values);
  final PlaybackRepository repository;
  final Map<String, List<dynamic>> _values;
  Future<void> _tail = Future<void>.value();
  Object? failure;

  Future<void> flush() async {
    await _tail;
    if (failure != null) {
      throw StateError('Catalog persistence failed: $failure');
    }
  }

  static Future<CatalogStorage> open(
    PlaybackRepository repository,
    GetStorage legacy,
    String scope, {
    Directory? supportDirectory,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(scope)) {
      throw ArgumentError('Invalid catalog migration scope');
    }
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}/playback/debug-migration-$scope',
    );
    await directory.create(recursive: true);
    final source = File('${directory.path}/catalog_source.json');
    if (!await source.exists()) {
      final snapshot = jsonEncode({
        for (final key in catalogKeys) key: legacy.read<List>(key) ?? [],
      });
      final pending = File('${source.path}.pending');
      await pending.writeAsString(snapshot, flush: true);
      await pending.rename(source.path);
    }
    final bytes = await source.readAsString();
    final decoded = jsonDecode(bytes) as Map<String, dynamic>;
    await repository.importCatalog(
      sourceId: 'catalog-$scope',
      sourceHash: sha256.convert(utf8.encode(bytes)).toString(),
      data: {for (final key in catalogKeys) key: decoded[key] as List},
    );
    return CatalogStorage._(repository, await repository.readCatalog());
  }

  @override
  T? read<T>(String key) {
    if (!catalogKeys.contains(key)) throw ArgumentError.value(key, 'key');
    return _values[key] as T?;
  }

  @override
  Future<void> write(String key, dynamic value) {
    if (failure != null) {
      return Future.error(StateError('Catalog persistence failed: $failure'));
    }
    if (!catalogKeys.contains(key) || value is! List) {
      return Future.error(ArgumentError('Invalid catalog write: $key'));
    }
    final snapshot = jsonDecode(jsonEncode(value)) as List<dynamic>;
    final operation = _tail.then((_) async {
      if (failure != null) {
        throw StateError('Catalog persistence failed: $failure');
      }
      await repository.replaceCatalog(key, snapshot);
      _values[key] = snapshot; // Publish only after SQL commit.
    });
    _tail = operation.catchError((Object error) {
      failure = error;
    });
    return operation;
  }

  @override
  Future<void> remove(String key) => write(key, <dynamic>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Catalog adapter only supports read/write/remove');
}

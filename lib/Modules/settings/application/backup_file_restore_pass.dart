/// One ZIP restore operation, not a persistent cache. Reuse only successful
/// extraction + verification; failures remain retryable and concurrent users
/// await the same work. Paths must already be validated by the caller.
class BackupFileRestorePass {
  final _operations = <String, Future<void>>{};

  Future<void> run(String relativePath, Future<void> Function() restore) {
    return _operations.putIfAbsent(relativePath, () async {
      try {
        await Future<void>.sync(restore);
      } catch (_) {
        _operations.remove(relativePath);
        rethrow;
      }
    });
  }
}

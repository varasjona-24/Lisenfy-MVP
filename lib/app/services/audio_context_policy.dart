/// Serializes temporary context pauses without owning playback persistence.
class AudioContextPolicy {
  AudioContextPolicy({
    required this.isPlaying,
    required this.canResume,
    required this.intentRevision,
    required this.pause,
    required this.resume,
  });

  final bool Function() isPlaying;
  final bool Function() canResume;
  final int Function() intentRevision;
  final Future<void> Function() pause;
  final Future<void> Function() resume;
  bool _blocked = false;
  int? _pausedRevision;
  Future<void> _pending = Future<void>.value();

  Future<void> update({required bool blocked}) {
    _blocked = blocked;
    final operation = _pending.then((_) async {
      if (_pausedRevision != null && _pausedRevision != intentRevision()) {
        _pausedRevision = null;
      }
      if (_blocked) {
        if (isPlaying()) {
          final revision = intentRevision();
          await pause();
          if (revision == intentRevision()) _pausedRevision = revision;
        }
      } else if (_pausedRevision != null) {
        final revision = _pausedRevision;
        _pausedRevision = null;
        if (revision == intentRevision() && canResume() && !isPlaying()) {
          await resume();
        }
      }
    });
    // A failed operation must not prevent future reconciliation.
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}

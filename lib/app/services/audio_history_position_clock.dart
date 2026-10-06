/// Content estimate for history only. Engine anchors and monotonic elapsed time
/// are kept separate from the animation position exposed to Connect and the UI.
class AudioHistoryPositionClock {
  int _anchorMs = 0, _anchorTime = 0, _publishedMs = 0;
  bool _playing = false;
  double _speed = 1;
  int? _durationMs;

  void reset(int positionMs, int monotonicMs) {
    _anchorMs = _publishedMs = positionMs;
    _anchorTime = monotonicMs;
    _playing = false;
  }

  void observe({
    required int positionMs,
    required int monotonicMs,
    required bool playing,
    required double speed,
    int? durationMs,
  }) {
    // A confirmed anchor may lag an extrapolated sample without being a seek.
    // Do not turn that correction into a backwards observation. A backwards
    // ENGINE anchor is different: retain it for the recorder's seek validation.
    if (positionMs < _anchorMs) {
      _publishedMs = positionMs;
    }
    _anchorMs = positionMs;
    _anchorTime = monotonicMs;
    _playing = playing;
    _speed = speed;
    _durationMs = durationMs;
  }

  int sample(int monotonicMs) {
    final elapsed = (monotonicMs - _anchorTime).clamp(0, 1 << 53);
    var next = _anchorMs + (_playing ? (elapsed * _speed).round() : 0);
    if (next < _publishedMs) next = _publishedMs;
    if (_durationMs != null && next > _durationMs!) next = _durationMs!;
    _publishedMs = next;
    return next;
  }
}

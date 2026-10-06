import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/services/audio_history_position_clock.dart';

void main() {
  test('pause and buffering freeze content; reset declares a seek', () {
    final clock = AudioHistoryPositionClock()..reset(0, 0);
    clock.observe(positionMs: 0, monotonicMs: 0, playing: true, speed: 1);
    expect(clock.sample(5000), 5000);
    clock.observe(
      positionMs: 5000,
      monotonicMs: 5000,
      playing: false,
      speed: 1,
    );
    expect(clock.sample(25000), 5000);
    clock.reset(70000, 25000);
    clock.observe(
      positionMs: 70000,
      monotonicMs: 25000,
      playing: true,
      speed: 1,
    );
    expect(clock.sample(26000), 71000);
  });
  test('speed uses monotonic time without changing wall-time clock', () {
    final clock = AudioHistoryPositionClock()..reset(0, 0);
    clock.observe(
      positionMs: 0,
      monotonicMs: 0,
      playing: true,
      speed: 2,
      durationMs: 10000,
    );
    expect(clock.sample(2000), 4000);
    clock.observe(
      positionMs: 4000,
      monotonicMs: 2000,
      playing: true,
      speed: 0.5,
      durationMs: 10000,
    );
    expect(clock.sample(4000), 5000);
    expect(clock.sample(20000), 10000);
  });
}

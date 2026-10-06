import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/services/audio_effect_load_guard.dart';

void main() {
  final equalizerError = PlatformException(
    code: 'Error',
    message:
        "Attempt to invoke 'android.media.audiofx.Equalizer.getNumberOfBands()' on a null object reference",
  );
  test('retries equalizer failure once after disabling effects', () async {
    var loads = 0;
    var disabled = false;
    await loadWithEqualizerFallback(
      equalizerAvailable: true,
      load: () async {
        loads++;
        if (!disabled) throw equalizerError;
      },
      disableEqualizer: () async => disabled = true,
    );
    expect(loads, 2);
    expect(disabled, isTrue);
  });
  test('does not retry unrelated platform errors', () async {
    var loads = 0;
    final error = PlatformException(code: 'file_not_found');
    await expectLater(
      loadWithEqualizerFallback(
        equalizerAvailable: true,
        load: () async {
          loads++;
          throw error;
        },
        disableEqualizer: () async => fail('must not disable'),
      ),
      throwsA(same(error)),
    );
    expect(loads, 1);
  });
  test('second failure propagates without retry loop', () async {
    var loads = 0;
    await expectLater(
      loadWithEqualizerFallback(
        equalizerAvailable: true,
        load: () async {
          loads++;
          throw equalizerError;
        },
        disableEqualizer: () async {},
      ),
      throwsA(same(equalizerError)),
    );
    expect(loads, 2);
  });
}

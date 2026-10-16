import 'package:flutter/services.dart';

/// Retry only a failed native equalizer initialization, never a file/SQL error.
Future<void> loadWithEqualizerFallback({
  required Future<void> Function() load,
  required Future<void> Function() disableEqualizer,
  required bool equalizerAvailable,
}) async {
  try {
    await load();
  } on PlatformException catch (error) {
    final description = '${error.code} ${error.message} ${error.details}';
    if (!equalizerAvailable ||
        !description.contains('android.media.audiofx.Equalizer') ||
        !description.contains('null object reference')) {
      rethrow;
    }
    await disableEqualizer();
    await load();
  }
}

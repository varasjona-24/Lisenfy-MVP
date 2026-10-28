import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _port = 3000;
  static const _prodBase = 'https://back-1-production-e50d.up.railway.app';
  static const _overrideBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_overrideBase.trim().isNotEmpty) {
      return _overrideBase.trim();
    }

    if (kIsWeb) {
      return 'http://localhost:$_port';
    }

    // Native debug builds use the same backend as release builds.
    // Local development remains opt-in through API_BASE_URL.
    return _prodBase;
  }
}

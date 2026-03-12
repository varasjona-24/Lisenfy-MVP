import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _port = 3000;
  static const _devHost = '172.30.5.139';
  static const _prodBase = 'https://back-1-production-e50d.up.railway.app';
  static const _overrideBase =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_overrideBase.trim().isNotEmpty) {
      return _overrideBase.trim();
    }

    if (kIsWeb) {
      return 'http://localhost:$_port';
    }

    if (kDebugMode) {
      if (Platform.isAndroid) {
        // ✅ Android real apuntando al Mac
        return 'http://$_devHost:$_port';
      }

      // ✅ iOS (simulator/real)
      return 'http://$_devHost:$_port';
    }

    // Producción
    return _prodBase;
  }
}

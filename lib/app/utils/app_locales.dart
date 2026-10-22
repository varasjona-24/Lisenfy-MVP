import 'package:flutter/material.dart';

abstract final class AppLocales {
  static const supported = [Locale('es'), Locale('en'), Locale('pt')];
  static const fallback = Locale('es');

  static Locale forDevice(Locale device) => supported.firstWhere(
    (locale) => locale.languageCode == device.languageCode,
    orElse: () => fallback,
  );
}

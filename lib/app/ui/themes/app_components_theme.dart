import 'package:flutter/material.dart';
import 'app_palette.dart'; // para mix()

class AppComponentsTheme {
  static AppBarTheme appBarTheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    final barBg = isDark
        ? mix(scheme.surface, Colors.white, 0.04)
        : mix(scheme.surface, Colors.black, 0.03);

    return AppBarTheme(
      backgroundColor: barBg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
    );
  }

  static IconThemeData iconTheme(ColorScheme scheme) {
    return IconThemeData(color: scheme.onSurface.withValues(alpha: 0.90), size: 22);
  }

  static DividerThemeData dividerTheme(ColorScheme scheme) {
    return DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.9),
      thickness: 1,
      space: 1,
    );
  }
}

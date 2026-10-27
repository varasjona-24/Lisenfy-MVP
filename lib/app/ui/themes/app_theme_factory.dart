import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_text_styles.dart';
import 'app_components_theme.dart';

ThemeData buildTheme({
  required AppPalette palette,
  required Brightness brightness,
}) {
  final isDark = brightness == Brightness.dark;

  // ✅ Base neutro: no negro puro
  final base = isDark
      ? mix(palette.neutral, Colors.black, 0.88)
      : mix(palette.neutral, Colors.white, 0.92);

  // ✅ “vida” en dark: sube un poco lightness al primario/sec/ter
  final primary = isDark
      ? tweakHsl(
          palette.primary,
          lightness: (HSLColor.fromColor(palette.primary).lightness + 0.10)
              .clamp(0, 1),
        )
      : palette.primary;

  final secondary = isDark
      ? tweakHsl(
          palette.secondary,
          lightness: (HSLColor.fromColor(palette.secondary).lightness + 0.10)
              .clamp(0, 1),
        )
      : palette.secondary;

  final tertiary = isDark
      ? tweakHsl(
          palette.accent,
          lightness: (HSLColor.fromColor(palette.accent).lightness + 0.10)
              .clamp(0, 1),
        )
      : palette.accent;

  // ✅ Containers (separación real en light cálidos)
  final surface = mix(base, Colors.white, isDark ? 0.06 : 0.04);
  final surfaceHigh = mix(base, Colors.white, isDark ? 0.09 : 0.07);
  final surfaceHighest = mix(base, Colors.white, isDark ? 0.12 : 0.10);

  final onSurface = isDark
      ? Colors.white.withValues(alpha: 0.92)
      : const Color(0xFF111111);

  final primaryContainer = isDark
      ? mix(primary, Colors.black, 0.55)
      : mix(primary, Colors.white, 0.55);

  final secondaryContainer = isDark
      ? mix(secondary, Colors.black, 0.55)
      : mix(secondary, Colors.white, 0.60);

  final tertiaryContainer = isDark
      ? mix(tertiary, Colors.black, 0.55)
      : mix(tertiary, Colors.white, 0.60);

  final outline = isDark
      ? Colors.white.withValues(alpha: 0.22)
      : Colors.black.withValues(alpha: 0.18);

  final outlineVariant = isDark
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.black.withValues(alpha: 0.10);

  final scheme = ColorScheme(
    brightness: brightness,

    primary: primary,
    onPrimary: onColorFor(primary),

    secondary: secondary,
    onSecondary: onColorFor(secondary),

    tertiary: tertiary,
    onTertiary: onColorFor(tertiary),

    surface: surface,
    onSurface: onSurface,

    primaryContainer: primaryContainer,
    onPrimaryContainer: onColorFor(primaryContainer),

    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onColorFor(secondaryContainer),

    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onColorFor(tertiaryContainer),

    outline: outline,
    outlineVariant: outlineVariant,

    error: isDark ? const Color(0xFFF2B8B5) : const Color(0xFFB3261E),
    onError: isDark ? Colors.black : Colors.white,

    shadow: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
    scrim: Colors.black.withValues(alpha: isDark ? 0.55 : 0.40),
    surfaceTint: primary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: base,

    textTheme: TextTheme(
      titleLarge: AppTextStyles.title.copyWith(color: onSurface),
      titleMedium: AppTextStyles.sectionTitle.copyWith(color: onSurface),
      bodyLarge: AppTextStyles.body.copyWith(color: onSurface),
      bodyMedium: AppTextStyles.body.copyWith(
        color: onSurface.withValues(alpha: isDark ? 0.86 : 0.78),
      ),
      bodySmall: AppTextStyles.caption.copyWith(
        color: onSurface.withValues(alpha: isDark ? 0.62 : 0.55),
      ),
    ),

    appBarTheme: AppComponentsTheme.appBarTheme(scheme),

    iconTheme: AppComponentsTheme.iconTheme(scheme),
    dividerTheme: AppComponentsTheme.dividerTheme(scheme),

    // ✅ Cards “premium” (arregla terracota/sunset en light)
    cardTheme: CardThemeData(
      color: surfaceHigh,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: outlineVariant.withValues(alpha: isDark ? 0.25 : 0.55),
          width: 1,
        ),
      ),
    ),

    // Si tu código usa cardColor:
    cardColor: surfaceHigh,

    chipTheme: ChipThemeData(
      backgroundColor: surfaceHigh,
      selectedColor: scheme.primary,
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: TextStyle(
        color: scheme.onPrimary,
        fontWeight: FontWeight.w600,
      ),
      shape: StadiumBorder(
        side: BorderSide(
          color: scheme.outline.withValues(alpha: isDark ? 0.35 : 0.55),
          width: 1,
        ),
      ),
      showCheckmark: false,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceHighest,
      surfaceTintColor: scheme.surfaceTint,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
  );
}

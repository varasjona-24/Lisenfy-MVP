import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/ui/themes/app_palette.dart';
import '../../app/ui/themes/app_theme_factory.dart';
import '../../app/ui/themes/palette.dart';

class ThemeController extends GetxController {
  /// 🎨 Paleta actual
  final Rx<AppPalette> palette = olivePalette.obs;
  final Rx<ThemeMode> themeMode = ThemeMode.dark.obs;

  /// 🌗 Modo de brillo
  final Rx<Brightness> brightness = Brightness.dark.obs;

  /// 🎨 Cambiar paleta por key
  void setPalette(String key) {
    final selected = palettes[key];
    if (selected == null) return;

    palette.value = selected;
    _applyTheme();
  }

  /// 🌗 Alternar light / dark
  void toggleBrightness() {
    brightness.value = brightness.value == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    themeMode.value =
        brightness.value == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
    _applyTheme();
  }

  /// 🌗 Cambiar modo de brillo
  void setBrightness(Brightness mode) {
    brightness.value = mode;
    themeMode.value =
        mode == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
    _applyTheme();
  }

  /// 🔁 Aplica el theme globalmente
  void _applyTheme() {
    Get.changeTheme(
      buildTheme(palette: palette.value, brightness: brightness.value),
    );
  }

  @override
  void onInit() {
    super.onInit();
    _applyTheme();
  }
}

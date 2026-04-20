import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/ui/themes/app_spacing.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/ui/widgets/branding/animated_listenfy_logo.dart';
import '../../../app/controllers/theme_controller.dart'; // ajusta el path

class HomeEntryPage extends GetView<HomeController> {
  const HomeEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = Get.find<ThemeController>();

    return Obx(() {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final isDark = themeCtrl.brightness.value == Brightness.dark;

      final size = MediaQuery.sizeOf(context);
      final logoSize = (size.shortestSide * 0.25).clamp(140.0, 190.0);

      // ✅ Logo un pelín más "suave" en light para no chocar con el fondo
      final logoColor = isDark
          ? scheme.primary
          : scheme.primary.withOpacity(0.9);

      return Scaffold(
        body: Stack(
          children: [
            // 🎨 Base: neutral (viene de tu paleta) + lavado en light
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.surface
                      : Color.alphaBlend(
                          Colors.white.withOpacity(0.65),
                          scheme.surface,
                        ),
                ),
              ),
            ),

            // ✅ Overlay: SOLO en dark (en light ensucia / apaga)
            if (isDark)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.45),
                        Colors.black.withOpacity(0.10),
                        Colors.black.withOpacity(0.35),
                      ],
                    ),
                  ),
                ),
              ),

            // 🌟 Glow radial: más sutil en light
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, -0.25),
                      radius: 0.9,
                      colors: [
                        scheme.primary.withOpacity(isDark ? 0.20 : 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedListenfyLogo(
                          size: logoSize,
                          color: logoColor, // ✅ usa el logoColor
                        ),
                        const SizedBox(height: 18),

                        Text(
                          'Listenfy',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),

                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            'Escucha, descarga y organiza tu música',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withOpacity(
                                isDark ? 0.72 : 0.60, // ✅ más fino en light
                              ),
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(flex: 3),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: isDark
                              ? const []
                              : [
                                  BoxShadow(
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                    color: Colors.black.withOpacity(0.12),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Get.offAllNamed(AppRoutes.home),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                scheme.primary, // ✅ botón = primary
                            foregroundColor: scheme.onPrimary,
                            elevation:
                                0, // ✅ ya tienes sombra en light con DecoratedBox
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Entrar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'Tu biblioteca, a tu ritmo.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(
                          isDark ? 0.55 : 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

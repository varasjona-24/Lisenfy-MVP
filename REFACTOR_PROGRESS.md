# Refactor Progress Log

Registro incremental de la aplicación de `ARCHITECTURE_MIGRATION.md`.

## Estado actual

- Rama de trabajo: `listenfy-getxrefactor`.
- Decisión arquitectónica: refactor arquitectónico parcial; se mantiene Flutter, GetX y la estructura feature-first.
- Progreso: inicio de Fase 1 — DI global. La Fase 0 se usó para confirmar el baseline mediante análisis y tests existentes.

## 2026-09-29 — Composition root y ownership de dependencias

### Cambios aplicados

- Se creó `lib/app/bootstrap/app_bootstrap.dart`.
  - Contiene la inicialización asíncrona previa a `runApp`:
    - Easy Localization;
    - GetStorage;
    - orientación de pantalla;
    - NotificationService;
    - AudioService y la sesión de audio de background.
  - No registra dependencias GetX.

- Se creó `lib/app/bindings/app_binding.dart`.
  - Es el único owner de registro de dependencias con lifecycle de aplicación.
  - Registra servicios globales, storage, repositorios/stores compartidos, recomendaciones, downloads, deep links y controllers que actualmente tienen consumidores fuera de una única ruta.

- Se simplificó `lib/main.dart`.
  - Ahora coordina `WidgetsFlutterBinding.ensureInitialized()`, `AppBootstrap.initialize()`, `AppBinding.dependencies()` y `runApp`.
  - Ya no contiene el contenedor completo de dependencias GetX.

- Se actualizó `lib/Modules/settings/binding/settings_binding.dart`.
  - Ya no vuelve a registrar `SettingsController`, `PlaybackSettingsController`, `SleepTimerController`, `EqualizerController` ni `NotificationSettingsController`.
  - Mantiene el registro de `BackupRestoreController` y los elementos propios de la feature Settings.

### Decisiones de lifecycle

- `AudioService`, `VideoService`, notificaciones, storage y servicios de background siguen siendo de application lifetime.
- Los controllers de Settings permanecen temporalmente en `AppBinding`, aunque su UI pertenece a Settings. La razón es funcional: `PlaybackSettingsController` se consume desde audio y vídeo, y `SettingsController` se usa para el fondo global de la aplicación.
- Esta es una excepción explícita a la política feature lifetime. Una fase posterior debe extraer las capabilities de reproducción/apariencia necesarias antes de convertir esos controllers en dependencias estrictamente de ruta.
- `SettingsBinding` deja de ser un fallback de infraestructura global: cada dependencia tiene un único owner de registro.

### Validación

- `flutter analyze` no reportó errores nuevos del refactor. Persisten warnings preexistentes de APIs deprecated, `print` en producción y nombres de variables.
- Pasaron los tests focalizados:
  - `test/modules/stats/weekly_listening_summary_test.dart`;
  - `test/modules/local_connect/local_connect_pairing_manager_test.dart`;
  - `test/modules/local_connect/local_connect_security_test.dart`.
- La suite completa mantiene tres fallos preexistentes y no relacionados con esta composición:
  - dos tests de heurística en `test/modules/home/local_recommendation_service_test.dart`;
  - el `test/widget_test.dart` de contador generado por Flutter.

### Pendiente inmediato

1. Documentar de forma verificable el owner, registro, lifecycle, eliminación y recreación de cada dependencia importante.
2. Revisar `permanent`, `fenix`, `lazyPut`, `put`, `putAsync`, `onClose`, workers, timers y subscriptions sin modificar aún módulos funcionales grandes.
3. Empezar el desacoplamiento de History respecto a `HomeController` cuando se complete la revisión de lifecycle.


# Registro de refactor

## 2026-10-05 — Repositorio inicial e idempotencia

- Añadido PlaybackRepository como propietario serializado de comandos tipados para registrar identidad/alias; sin SQL en controllers ni cambios al runtime activo.
- Transacción incluye identidad, alias, applied_command y revisión durable; publicación de stream tras commit. Retry mismo ID/hash devuelve resultado previo; hash diferente produce PlaybackIdempotencyConflict sin reemplazar filas.
- Fault injection en escritura parcial, antes del commit y commit confirmado antes de respuesta; rollback y recuperación por reapertura probados. Son excepciones simuladas, no ensayos de kill del proceso/OS ni fallo eléctrico.
- Verificación final:10 pruebas Flutter (4 opener+6 repositorio) y12 pruebas SQL aprobadas; análisis focalizado sin issues. Se corrigieron3 infos de llaves detectadas inicialmente.
- Alcance parcial de fase2: faltan comandos para variantes/snapshots/sesiones/journal/intervalos/feedback/importación y proyecciones. Idempotencia validada para comando inicial, no se declara cobertura de todos los flujos.
- Sin cutover ni escritura doble; staged del collage y cambios previos de reproductores quedan fuera del commit.

## 2026-10-05 — Fase 1 SQLite: driver y opener staging

- Resueltas dependencias Drift2.35.1/SQLite3.5.2 con Flutter3.44.1 y Dart3.12.1. Targets mobile/desktop/web encontrados, sin asumir soporte release por presencia de carpetas. iOS declara13.0; Android usa SDK mínimo Flutter.
- Añadidos PlaybackDatabase y opener nativo en isolate que carga el asset SQL real, sin segunda copia del DDL. Solo staging: sin registro main/GetX ni cutover.
- foreign_keys=ON, WAL, synchronous=FULL, busy_timeout=5000 y user_version1; rechazo de versión futura/bases incompletas sin borrar datos.
- Verificación:4 pruebas Flutter aprobadas (creación/reapertura/PRAGMA/asset, futuro preservado, traversal e incompletitud);12 pruebas SQL aprobadas. Análisis focalizado sin issues. Pub get advierte plugins existentes sin Swift Package Manager; no se declara análisis global ni builds release móviles verificados.
- Pendientes fases2–12: repository/recorder/importador/activación/consumidores y benchmarks. No se afirma soporte release mobile validado. Política92% aprobada para audio/video con motivo factual separado de clasificación.

## 2026-10-05 — Esquema candidato y contratos previos al cutover

- Revisado schema_v1.sql con applied_command, journal/feedback inmutables, hashes versionados, locator tipado y restricciones de estados/flags.
- Añadido docs/playback/MIGRATION_CONTRACT.md: staging en base por generación, activación mediante manifest, cobertura, timezone, codecs, borrado, artwork y auditoría de incompatibilidades.
- Interpretación del92% comunicada: abandono manual antes92% es skip; desde92% no. Pausa/error/cierre y duración desconocida no generan skip automáticamente. Runtime todavía no cambiado.
- Ejecutadas12 pruebas de invariantes SQL: todas aprobadas; incluyen frontera92%, FK/UNIQUE, rollback, journal inmutable, feedback, estado terminal e intervalos inválidos.
- Esquema preparado para iniciar implementación del repositorio, NO cutover ejecutado. Faltan pruebas Flutter de driver/owner/importador, activación/crash/backup y benchmarks móviles.
- Commit limitado a documentación, esquema y tests de esta preparación; cambios staged de collage y runtime excluidos.

## 2026-10-05 — Revisión arquitectónica SQLite

- Ampliado el diseño en PLAYBACK_SQLITE_ARCHITECTURE.md y añadido DDL de referencia en docs/playback/schema_v1.sql.
- Separados journal, sesiones, intervalos, variantes, snapshots, proyecciones, baseline legacy y feedback; definido propietario único y confirmación postcommit.
- Documentados errores actuales: skip implícito, retención120 días, tiempo ambiguo y contadores no transaccionales. No se consideran resueltos por escribir el diseño.
- No se añadieron dependencias ni se activó SQLite. No se mezcló el contenido staged con esta documentación.
- DDL ejecutado en SQLite3.53.4 temporal: 13 tablas, integrity_check=ok y foreign_key_check sin errores. No sustituye pruebas de constraints con fixtures ni validación en Flutter.
- Validación previa precisa: 9 pruebas stats/recorder aprobadas; suite ampliada23 aprobadas y2 fallos de recomendaciones sin baseline confirmado; permanecen12 infos en video_service.

## 2026-10-05 — Historial de reproducción independiente de las pantallas

- Publicado primero el contenido staged de Atlas: `50a717a` en `origin/main`.
- AudioService y VideoService registran actividad directamente mediante PlaybackHistoryRecorder, sin depender de los controllers de presentación.
- Cada sesión tiene identidad propia: los checkpoints actualizan el mismo evento, los cambios de pista cierran la sesión anterior y las repeticiones completas generan una nueva.
- Se acumula avance efectivo de reproducción y se excluyen saltos de posición y pausas. Los eventos nuevos conservan segundos reproducidos y una copia de los metadatos.
- Se eliminan los escritores y contadores duplicados de los controllers. El recorder actualiza los contadores acumulados de la biblioteca.
- Historial: escrituras serializadas, conservación por 120 días sin el corte de 4.000 eventos, backup/restauración incluyendo sesiones.
- El collage acepta eventos históricos con identificadores antiguos y eventos nuevos de contenidos eliminados de la biblioteca; continúa mostrando la última semana completa.
- La persistencia sigue siendo GetStorage, como el proyecto actual. No se introduce una migración a SQLite.
- Limitación histórica: las reproducciones sin un evento fechado no pueden reconstruirse desde los contadores acumulados.
- Validación: pruebas de cola sin controller, checkpoints sin duplicados, pausa/seek, repetición, snapshots y backup; pruebas del período semanal.

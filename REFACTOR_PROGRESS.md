# Registro de refactor

## 2026-10-06 — Observaciones de historial independientes de UI/Connect

- Log real de Honey mostró401→128ms: la tolerancia250ms no bastaba. just_audio0.10.5 extrapola position con DateTime mientras ready+playing; la UI mezclaba esa estimación con correcciones del motor.
- AudioHistoryPositionClock separa ancla updatePosition del motor y extrapolación con Stopwatch. Una nueva ancla que avanza respecto al ancla anterior, aunque quede detrás de la estimación publicada, no produce un retroceso. Retrocesos reales del ancla siguen visibles para la validación del recorder.
- AudioService alimenta el recorder desde una única entrada coordinada playerEventStream/ticker500ms. Eliminados escritores de historial de playerStateStream, currentIndexStream y _publishPosition. Fuente/índice/variante delimitan ocurrencias; reload y seek restablecen el reloj explícitamente.
- UI, currentPosition, notificación, widget y payloads/progreso de Connect conservan su lógica visual. Los clientes remotos no agregan escritores SQL; sus comandos siguen usando el motor del teléfono. No se implementó aquí contexto connect ni refresco de métricas remotas: pendientes separados.
- Prueba exacta Honey401→128 guarda28s de reloj,27,702s de avance y pausa sin bloquearse. Se añaden pruebas del reloj para pausa/buffering, seek y velocidades. No se reconstruye actividad perdida ni se modifica la base del dispositivo.
- Validación móvil/background real y sincronización de Connect pendientes de repetir con reinicio completo. El avance entre anclas sigue siendo una estimación por estado/velocidad; no se presenta como medición continua exacta del decoder.
- Verificación:89 pruebas Flutter schema/stats/Connect aprobadas y análisis focalizado sin issues. La suite Connect cubre HTTP/WebSocket, permisos y sincronización de metadatos con dobles de audio, no reproducción remota real del plugin. Se captura una observación antes de stop/seek/reload/cambio de velocidad.

## 2026-10-06 — Correcciones pequeñas de posición del motor

- Verificada SQLite real de Honey: baseline31 intacto, posición de restauración28,6s y resume27s, pero sesión abierta sin intervalos. El log del proceso confirma bloqueo por Unreported seek/loop/discontinuity from engine.
- La validación rechazaba cualquier retroceso de posición. Se toleran correcciones de hasta250ms conservando el ancla monotónica de contenido; no se aumenta media_ms por el jitter. Retrocesos mayores y saltos hacia delante imposibles siguen bloqueando el recorder; seek/loop continúan usando señales explícitas.
- Añadido diagnóstico inmediato del primer error con posición previa/observada, tiempo monotónico y velocidad para distinguir jitter de una discontinuidad real. El log antiguo no incluye esos valores, por lo que no se afirma que el jitter sea la única causa posible del fallo observado.
- Pruebas de regresión: reproducción28s con correcciones64ms/100ms, pausa y flush conserva28s de reloj,27,936s de contenido y valid_play; retroceso grande sigue fallando sin inventar intervalos.10 pruebas del recorder aprobadas y análisis focalizado sin issues.
- Verificación ampliada:70 pruebas Flutter schema/stats aprobadas. No se alteró la base del teléfono ni se reconstruyó el intervalo perdido. Requiere reinicio completo con el código nuevo y repetir Honey para confirmar el comportamiento real.

## 2026-10-06 — Restauración de ZIP legacy en debug vacío

- Eliminado el requisito de bundle SQL para ZIP antiguos. Se importa la biblioteca remapeada y listeningEvents al repositorio SQL usando la identidad de instalación actual.
- Hash SHA256 del manifest leído por stream y recibo específico separan esta importación del bootstrap vacío. Reintentar el mismo manifest conserva métricas y sesiones sin duplicarlas; otro baseline sobre historial existente se rechaza antes de restaurar archivos, con texto localizado.
- Importación SQL transaccional con segunda comprobación de destino vacío; no fabrica fechas ni divide métricas ambiguas entre audio/video. Lectura grande conserva el parser por stream, pero acumula el lote de eventos en memoria: no se declara escalabilidad ilimitada.
- Se mantienen archivos, biblioteca, preferencias y relaciones del flujo ZIP existente. El ZIP legacy no contiene un snapshot SQL operativo; no se inventa una cola/posición ausente. Transacción SQL no garantiza rollback global de archivos/metadatos; prueba del ZIP real en dispositivo pendiente.
- Verificación:68 pruebas Flutter schema/stats aprobadas, incluidos destino vacío, retry idempotente y rechazo de baseline superpuesto; análisis focalizado sin issues. Pruebas de repositorio no sustituyen una restauración end-to-end del ZIP real en dispositivo.

## 2026-10-06 — Detección del launcher Android por Flutter

- Flutter 3.44.1 busca MAIN/LAUNCHER en activity y no reconoce los activity-alias usados por los iconos personalizados. El manifest no faltaba.
- Añadido filtro de descubrimiento a MainActivity en el manifest fuente; overlays debug/profile/release lo eliminan del manifest fusionado. LauncherOriginal y los demás aliases siguen gestionando los iconos, sin launcher duplicado.
- Verificadas tareas Gradle processDebugMainManifest, processProfileMainManifest y processReleaseMainManifest. Profile necesitó descargar una dependencia ausente en caché offline; sin compilar ni instalar APK.
- Añadida prueba de descubrimiento y manifests fusionados: comprueba aliases, ausencia de launcher directo y conservación de seis filtros de enlaces/compartir. Arranque físico pendiente de ejecutar flutter run.

## 2026-10-06 — Conexión integral debug SQLite

- Con autorización explícita se integran también los staged relacionados de collage, traducciones y backup. Release y arranque sin flag conservan legacy.
- Bootstrap congela fuente antes de motores, importa hechos legacy y baseline sin inventar fechas, importa restauración y recupera sesiones. Recibos conservan el estado nuevo ante reintentos.
- Audio/video y prompts usan PlaybackStateStorage: proyección operativa síncrona con coalescing y commits SQL; sin escrituras de posiciones nuevas en GetStorage. Repeat también se incluye en SQL. VideoResumePolicy mueve el writer de reanudación al servicio.
- Consumidores del historial pasan a consultas asíncronas SQL. Biblioteca proyecta métricas SQL sin escribirlas a GetStorage; se conserva intacto el baseline legacy para no dañar la rama de prueba. Wrapped separa audio/video conocidos, collage excluye atribución ambigua y semanas usan intervalos recortados sin duplicar sesiones.
- Backup debug incluye journal, baseline y estado. Merge histórico exacto, rollback de conflictos, restauración operativa explícita y rebuild de agregados; backups legacy no se restauran en este modo y se rechazan antes de cambios.
- Recargas internas de fuentes de audio marcan el seek explícitamente y aíslan observaciones transitorias del recorder; pendiente validar el comportamiento del plugin en dispositivo. Una semana con minutos de una sesión iniciada antes del límite conserva el resumen aunque no tenga reproducciones nuevas.
- Verificación retomada:66 pruebas Flutter de schema/stats y12 pruebas SQL aprobadas; análisis focalizado del repositorio y consumidores sin issues. El APK debug NO se compiló porque la solicitud fue rechazada. No hay validación en dispositivo ni aprobación de release.
- docs/playback/DEBUG_SQLITE_TEST.md explica prueba y límites: staging no es manifest productivo, import/backup debug no son streaming de grandes bases, artwork/contexto y fallos de plataforma todavía pendientes. No se declara migración productiva al100%.

## 2026-10-05 — Restauración SQLite: almacenamiento e importación

- Añadido esquema v2 separado del journal: playback_restoration, playback_resume y restoration_import. Upgrade v1 transaccional con validación previa; versiones futuras rechazadas sin reinicializar.
- Repositorio serializado para snapshots audio/video y posiciones por modo, con revisiones postcommit. Los cambios operativos no crean sesiones ni eventos ni minutos.
- Captura legacy congelada y hash SHA256; importación atómica de ambos modos y recibo idempotente. Retry no sobrescribe posiciones nuevas; fuente cambiada genera conflicto y rollback conserva todo.
- Alcance parcial explícito: runtime aún usa GetStorage para restauración. Faltan snapshot durable/bootstrap de migración, activación por manifest, conexión de lectores/escritores/prompts, consumidores y backup. La fuente única SQLite todavía no está activada.
- Detalles y siguiente secuencia en docs/playback/RESTORATION_SQLITE.md. No se borraron datos legacy ni se mezclaron archivos staged ajenos.
- Verificación:52 pruebas Flutter y12 SQL aprobadas. Se corrigió el matcher de rechazo de base incompleta: Drift envuelve la excepción del isolate, por lo que se verifica la causa reportada. También se corrigieron4 infos nuevas de llaves; análisis focalizado final sin issues.

## 2026-10-05 — Adaptador y conexión opt-in a motores

- Añadidos EngineHistoryRecorder y SqliteEngineHistoryRecorder; AudioService/VideoService eligen un único recorder inyectado, legacy por defecto. main solo permite SQLite staging con opt-in debug, sin cutover ni doble escritura.
- Engine states/posición, variante, buffering, fin natural, seek antes/después, motivos manuales y errores reales conectados; autoplay video conserva natural_end separado de manual_next. Repetición audio tiene señal asociada a LoopMode.one, no solo salto de posición.
- Adaptador serializa clocks capturados al observar, abre únicamente ready+playing, checkpoint5s, excluye inactividad/seek y aplica92% por repositorio. Factory de sesión exige mapping canónico provisto por composición/importador, sin inferencia por title/path.
- Error de persistencia se propaga en flush y bloquea recorder; cleanup del motor reporta historyPersistenceFailure sin impedir pause/stop. Falta retry automático del adaptador y validación de plugins/background mobile.
- Conexión opt-in documentada en docs/playback/ENGINE_CONNECTION.md. Composición staging implementada; quedan pendientes importador/manifest y composición de producción, además de discontinuidad temporal y pruebas reales de cola/reload.
- Verificación final:46 pruebas Flutter y12 SQL aprobadas. Análisis focalizado de composición/adapter/tests limpio; análisis ampliado sin errores ni warnings, con12 infos conocidas de video_service (print/network deprecado). Se corrigieron4 infos nuevas de @override. No se han probado plugins en dispositivos reales.
- El commit de conexión incorpora la base legacy del recorder y sus dependencias de eventos/registro en main que estaban pendientes, además de retirar contadores duplicados de los controllers; no incluye staged del collage/traducciones ni backup. Se preserva GetStorage como predeterminado y hay un solo writer por motor.
- Composición debug mediante LISTENFY_SQLITE_STAGING_HISTORY=true (siempre desactivada en release): opener staging, recuperación previa, factory y repositorio compartido. UUID/alias local scoped, variantes locales por hash streaming de bytes, modo real y contexto unknown; sin importar legacy ni activar manifest. UI continúa leyendo legacy en estas pruebas.

## 2026-10-05 — Agregados y recuperación inicial

- Apertura y boundaries refrescan proyección por identidad/modo dentro de su transacción; incluye contadores, wall/media, ratios y recencia. Solo independent/post_cutover son aditivos; legacy y baseline_covered no se suman dos veces.
- rebuildAggregates reconstruye desde materializaciones de sesión sin leer los agregados anteriores. Comparación exacta contra proyección actual probada. Aún no es replay completo de journal ni benchmark de proyección por delta.
- recoverInterruptedSessions se ejecutará antes de conectar motores: usa último evento durable y process_lost, no agrega tiempo desde ese checkpoint al nuevo arranque. Reapertura y segunda recuperación verificadas.
- Se inspeccionaron streams audio y timer video. Conexión efectiva a motores todavía pendiente: recorder legacy no transporta intenciones manuales frente a avance automático, variantes y errores con el contrato SQL. No se activó doble escritura ni cutover.
- Verificación final tras añadir reapertura:33 pruebas Flutter y12 SQL aprobadas; análisis focalizado limpio.
- Este grupo implementa2 de los3 puntos solicitados. Falta el adaptador del recorder y su conexión explícita/opt-in a los motores, más cobertura de recuperación con kills y fallos reales.

## 2026-10-05 — Cierre, intervalos y política v1

- Comandos tipados para checkpoint, pausa/resume, buffering, seek, velocidad y cierre; motivo factual separado de skipped/completed. Next/previous/selección manual antes92% = skip; desde92% = completed sin skip. Duración desconocida no se clasifica arbitrariamente.
- Repositorio registra límites, intervalos, cierre/flags, applied_command y revisión en una transacción. Final natural/skip/error terminal añaden su evento y stop bajo el mismo command; retries no duplican hechos.
- Intervalos parten del último evento playing confirmado: diferencias monotónicas para wall y avance sin seek para media. Inactividad excluida, discontinuidades no marcadas rechazadas. Cobertura regenerada como unión de rangos, con clipping por duración.
- Cierre process_lost produce interrupted terminal; errores/source_lost/stop no se convierten en skip. Pruebas de92%, tiempos2x, seeks ambos sentidos, overlap, pausa, buffering, velocidad, duración desconocida y terminales.
- Pendientes comandos específicos de variantes, loop/recovery/discontinuidad temporal; integración con recorder/motores y agregados incremental/rebuild. Esto no demuestra comportamiento real mobile ni activa cutover.
- Verificación final:31 pruebas Flutter y12 SQL aprobadas, análisis focalizado sin issues. La ampliación detectó un error de orden de helpers en tests que se corrigió y verificó; no se oculta ese fallo intermedio.

## 2026-10-05 — Variantes, snapshots y apertura de sesión

- Añadido comando tipado OpenPlaybackSession: modo/contexto, posiciones, tiempo, variante y snapshot. Solo se enviará cuando el motor esté ready+playing; aún no conectado a servicios.
- Variante/snapshot/sesión/play/applied_command/revisión se confirman conjuntamente; retry devuelve resultado durable, conflictos y FK hacen rollback.
- Sesión abierta inicia final_variant=initial_variant y no cuenta minutos/reproducción válida por sí sola. Audio/video guardan modo real.
- Snapshots deduplicados e inmutables con hash versionado2 de texto exacto. NFC v1 no implementada ni fingida; justificación documentada en contrato.
- Verificación final:18 pruebas Flutter y12 SQL aprobadas; análisis focalizado limpio. Las8 pruebas nuevas cubren apertura/retry, conflicto, audio/video, deduplicación, FK, rollback fault, velocidad inválida y preservación del snapshot anterior.
- Pendientes cierre de sesión, intervalos, proyección de agregados, recorder/importador y cutover. Otros cambios staged excluidos.

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

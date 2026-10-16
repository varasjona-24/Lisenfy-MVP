# Inventario y diseño de migración del historial a SQLite

Fecha: 2026-10-05. Estado: inventario del código y diseño; SQLite todavía no implementado.

Diseño ampliado tras revisión del auditor: `PLAYBACK_SQLITE_ARCHITECTURE.md`.
Esquema SQL de referencia: `docs/playback/schema_v1.sql`. Son propuestas para
revisión, no una migración activada ni dependencias añadidas al proyecto.

Contrato revisado para implementación: `docs/playback/MIGRATION_CONTRACT.md`.
Pruebas del DDL: `python3 -B -m unittest discover -s test/schema -v`.

## Alcance y fuentes revisadas

Se revisaron MediaItem/MediaVariant, LocalLibraryStore, ListeningEventStore,
AudioService/VideoService, ambos controllers de reproducción, main y bindings,
historial, estadísticas/Wrapped, collage, resumen semanal/notificaciones,
recomendaciones/ML/feedback, Atlas, playlists y backup/restauración.
El almacenamiento de este flujo es GetStorage; no hay implementación SQLite
ni dependencia SQLite en pubspec en esta rama. Hive figura como dependencia,
pero no se encontraron usos de Hive/openBox en lib.

## Datos que ya usa la aplicación

| Grupo | Campos actuales | Almacenamiento / consumidores |
|---|---|---|
| Identidad | id local, publicId; fileId derivado | Biblioteca, endpoints, cola, playlists, recomendaciones, historial |
| Metadatos | title, subtitle/crédito de artista, country, source, origin | UI, búsquedas, artistas, Atlas, recomendaciones, collage |
| Portadas | thumbnail remoto, thumbnailLocalPath | UI, notificación, widget, collage |
| Letras | lyrics, lyricsLanguage, translations, timedLyrics; cue text/startMs/endMs | Letras, karaoke y traducción |
| Favorito | isFavorite | Biblioteca y recomendaciones |
| Variante | kind audio/video, format, fileName/URL, localPath, createdAt, size, durationSeconds, role | Reproductores, importación, generación instrumental/8D, estadísticas de biblioteca |
| Duración base | durationSeconds | Fallback de duración, UI y estimaciones |
| Métricas acumuladas | playCount, skipCount, fullListenCount, avgListenProgress, lastPlayedAt, lastCompletedAt | Wrapped, historial reciente, recomendaciones y Atlas |
| Evento antiguo | trackKey, occurredAt, progress, completed, skipped, mode opcional | listening_events_v1; recomendaciones/ML y resúmenes semanales |
| Evento nuevo local aún sin publicar | sessionId, playedSeconds, mediaSnapshot además de campos anteriores | Recorder recién incorporado, checkpoints y collage |
| Sesión de audio | último item/variante; colas y variantes; índice, posición, wasPlaying; shuffle, speed, crossfade | AudioService, controles externos, restauración |
| Reanudación | audio_resume_positions; video_resume_positions; video_resume_watch_ms | Prompts y restauración de posición |
| Sesión de video | último item/variante; video_queue_items, video_queue_index | VideoService/controller |
| Relaciones | artistas/perfiles, país/región, playlists e itemAddedAt, temas y colecciones de sources | Stores separados; no son eventos de reproducción |
| Preferencias derivadas | pesos por artista/género/región/origen, daily sets, mixes, feedback y modelo ML | Stores de recomendaciones; perfiles/mixes son derivados, feedback es decisión del usuario |

Biblioteca: `local_library_items`. Historial de eventos: `listening_events_v1`.
La pantalla de historial actual lee la biblioteca y ordena por lastPlayedAt:
no representa cada sesión ni un historial cronológico completo.
Los contadores de MediaItem no están separados por modo. Si un item tiene
audio y video, asignar el contador entero a ambos duplica o mezcla estadísticas.

## Información que falta registrar o definir

1. Identificador durable de sesión, secuencia y tipo de cada evento; relación entre
   play, pause, resume, seek, complete, skip, stop, error y checkpoint.
2. Modo real y variante exacta utilizada: formato, role y duración del motor.
3. Inicio, final y timestamps UTC; offset local en el momento del evento para
   analizar días y semanas sin reinterpretar viajes/cambios de zona horaria.
4. Tiempo real activo (wall time) separado del avance del contenido (media time).
   El recorder nuevo acumula deltas de posición: playedSeconds aún representa
   avance de contenido, no necesariamente minutos de reloj con speed != 1.
5. Pausas, buffering, seeks y discontinuidades, sin contarlos como escucha.
6. Posición inicial/final y máximo alcanzado; reproducción reanudada y repeticiones.
7. Motivo de cierre explícito; pausar/cerrar la pantalla no implica skip manual.
8. Contexto de origen de la reproducción: biblioteca, playlist, Atlas, recomendaciones,
   Connect, notificación, Android Auto y widget; item/playlist/station de origen cuando exista.
9. Identidad independiente del contenido y sus aliases históricos; snapshots compactos
   de título, artista y portada al reproducir. No copiar letras y todas las variantes
   en cada checkpoint: el snapshot MediaItem completo actual es demasiado grande.
10. Estado counted/completed y reglas comunes de reproducción válida. No mezclar
    el umbral antiguo de audio (20 s) con el nuevo checkpoint (mínimo 3 s) sin una
    política explícita y tests; video tiene una semántica histórica diferente.
11. Proveniencia/calidad de datos: observado, importado, estimado o desconocido.
12. Sesiones que cruzan medianoche o el límite semanal: repartir el tiempo por
    intervalos; un timestamp único de inicio no basta para atribuirlo a cada semana.
13. Contadores e historial de cambios de favoritos, importaciones y feedback solo
    cuando una función requiera su evolución temporal; el estado actual no prueba
    la fecha de una interacción pasada.

## Modelo SQLite propuesto

Una base compartida, sin separar tablas de eventos de audio y video. Un mismo
contenido puede tener varias variantes; cada sesión declara su modo real.

| Tabla | Propósito |
|---|---|
| media_identity | Identidad canónica estable y referencia opcional a biblioteca |
| media_alias | id/publicId históricos; unicidad por namespace y valor |
| playback_session | Inicio/final, modo, variante, contexto, contabilidad y snapshot compacto |
| playback_event | Eventos append-only con event_id único, session_id, secuencia, tipo, UTC, posición y payload versionado |
| playback_interval | Intervalos efectivos con wall_ms y media_ms, velocidad y rangos UTC para consultas semanales |
| playback_aggregate | Proyección por identidad y modo; regenerable desde sesiones/intervalos |
| legacy_metrics | Contadores antiguos y procedencia, conservados sin fabricar sesiones ni fechas |
| migration_state | Versión, identificador de importación y estado completado transaccional |

Índices: events(session_id, sequence), events(occurred_at_utc),
sessions(media_id, mode, started_at_utc), intervals(started_at_utc, ended_at_utc).
Separar journal append-only y sesión/proyección evita contar cada checkpoint como
una reproducción. Los agregados legacy y los nuevos no se suman dos veces.
Eliminar un archivo de biblioteca no debe borrar su historial en cascada.
La eliminación explícita de historial y la política de retención deben tener
un flujo propio. No introducir un tope global silencioso de 4.000 registros.

## Integración con la memoria de la app

SQLite será la fuente persistente. Un repositorio único serializa comandos,
escribe eventos y proyecciones dentro de una transacción, y publica revisiones
solo después del commit. GetX observa esas revisiones y refresca las consultas.
No guardar toda la base indefinidamente en memoria ni mantener GetStorage como
segunda fuente de verdad. Cachés acotadas por identidad/rango y consultas paginadas.

Consumidores a adaptar: recorder del motor, collage, resumen semanal/notificaciones,
historial cronológico, Wrapped, recomendaciones/ML, Atlas y backup/restauración.
LocalLibraryStore tiene readAllSync y revision síncronos: no reemplazarlos
por SQL asíncrono sin adaptar sus consumidores. La primera migración se limita
al historial; biblioteca y configuración pueden continuar en GetStorage.
Los campos acumulados de MediaItem pueden permanecer como proyección compatible
durante la transición, actualizada por un único escritor, nunca como otro historial.

## Migración automática de versiones anteriores

1. Inicializar SQLite y ejecutar migraciones antes de registrar motores/consumidores.
2. Leer GetStorage sin borrar las claves: eventos v1, biblioteca, aliases y estado
   de reanudación necesario para conservar experiencia, no para inventar reproducciones.
3. Importar eventos con sessionId usando ese ID; para legacy generar un ID determinista
   a partir de contenido, fecha, modo, progreso, flags y ocurrencia en el archivo origen.
   No deduplicar eventos diferentes solo por compartir trackKey/fecha.
4. Resolver aliases prefijados p:/i: y claves crudas; si falta mode conservar unknown.
   Un item exclusivamente de audio/video puede permitir inferencia marcada; con ambas
   variantes no atribuirlo automáticamente a audio.
5. Importar métricas acumuladas en legacy_metrics con fecha de importación y modo
   desconocido cuando no se pueda demostrar. Conservar los totales globales.
   No distribuir playCount entre días ni crear N sesiones en lastPlayedAt.
6. Registrar snapshots disponibles; eventos sin biblioteca también se conservan,
   con metadatos desconocidos y enriquecimiento posterior cuando sea posible.
7. Commit atómico con migration_state. Si falla, rollback y reintento al próximo
   arranque. UNIQUE e IDs deterministas impiden duplicados tras cierres y reintentos.
8. Validar conteos y datos antes del cutover. Las claves originales se conservan
   hasta comprobar la migración; los escritores nuevos pasan únicamente al repositorio.
9. Backup incluye versión del esquema/exportación de eventos, legacy y aliases.
   Restaurar backups antiguos atraviesa el mismo importador idempotente, incluidos
   manifiestos grandes leídos por streaming. No reimportar dos veces los mismos totales.

Una semana sin eventos históricos fechados no se puede reconstruir fielmente:
la migración puede preservar los totales, pero no fabricar actividad semanal.

## Validación necesaria antes de publicar

- Primera instalación, actualización legacy, migración interrumpida y reintento.
- Identidades renombradas/aliases, modo unknown, items eliminados, duplicados válidos.
- Cola automática, cambios externos, pausa/reanudación, seeks, buffering,
  velocidades, loop, restauración tras cierre, sesiones simultáneas audio/video.
- Corte semanal/midnight, cambio horario, checkpoint sin reproducción duplicada.
- Igualdad de eventos y totales después de backup/restauración normal y streaming.
- Android/iOS y plataformas desktop/web realmente soportadas por el proyecto:
  elegir driver con base en estos targets, no asumir que un driver móvil cubre web.

Estado de la verificación previa: las 9 pruebas de stats/recorder pasaron. La
ejecución ampliada tuvo 23 aprobadas y 2 fallos en local_recommendation_service_test
(región del artista y heurística de trap/Puerto Rico). No se declara esa suite
limpia ni se atribuyen esos fallos a cambios previos sin reproducir su baseline.
El análisis del trabajo previo no mostró errores/warnings nuevos tras la corrección,
pero mantiene 12 infos de video_service (print y API network deprecada).

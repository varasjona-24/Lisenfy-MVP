# Historial SQLite — propuesta de arquitectura de producción

Fecha: 2026-10-05. Estado: diseño para revisión, NO implementación ni garantía de producción.
Complementa `PLAYBACK_SQLITE_MIGRATION.md`. El SQL de referencia está en
`docs/playback/schema_v1.sql`; aún no es una migración ejecutada por Flutter.

Revisión vigente: `docs/playback/MIGRATION_CONTRACT.md` detalla staging físico,
comandos con múltiples eventos, contratos versionados, borrado y umbral92%.
En caso de discrepancia, prevalece ese contrato: command_id ya no es UNIQUE
en journal y completed incluye abandono manual desde92%, no solo final natural.

## 1. Decisión y límites

Una base compartida para audio y video, con identidad independiente de la
biblioteca. Migrar primero historial y feedback; preferencias y biblioteca
continúan en GetStorage hasta adaptar sus APIs síncronas. No escribir el mismo
historial en ambos sistemas. Ninguna dependencia nueva en esta etapa.

```text
AudioService / VideoService / controles externos
                    ↓ observaciones y comandos tipados
             PlaybackRecorder por motor
                    ↓ comandos idempotentes
        PlaybackRepository — único propietario escritor
                    ↓ transacción SQLite
          sesión + journal + intervalos + proyecciones
                    ↓ COMMIT confirmado
             revisión → consultas → GetX/UI
```

Controllers presentan estado; no cuentan reproducciones. Abrir/cerrar una
ruta no abre/cierra una sesión del motor. Las notificaciones mandan comandos
al motor, no escriben estadísticas. Los procesos/isolates de background deben
conectarse al propietario por mensajes; una cola estática Dart no coordina
isolates. No mantener transacciones abiertas durante IO de archivos/red.

## 2. Entidades y responsabilidad

```text
media_identity ──< media_alias
       │
       ├──< media_variant ─────────────┐
       ├──< legacy_metrics           │
       ├──< playback_aggregate       │
       └──< playback_session >── metadata_snapshot
                     │               │
                     ├──< playback_event
                     └──< playback_interval >── media_variant

migration_state ──< migration_reject
feedback_event → media_identity (opcional)
```

Identidad: UUID aleatorio persistido, no título/path/hash como PK. Alias:
namespace + scope + value único; IDs locales tienen scope de instalación,
IDs públicos el scope del proveedor. Resolver `p:`/`i:` explícitamente; una
clave cruda ambigua queda pendiente, no se une por semejanza de artista/título.
Hash verificado sirve como evidencia de archivo, no prueba de identidad de
canción entre grabaciones. Un archivo sustituido tiene nueva variante; unirlo
al mismo contenido requiere identidad demostrada o decisión del usuario.
Cambiar ruta o metadata conserva UUID. Borrar biblioteca no borra identidad.

Variante: UUID, audio/video/unknown, rol, formato, locator actual opcional,
hash opcional. La sesión conserva variante inicial y final; los intervalos
registran la utilizada exactamente. Audio↔video crea sesión distinta; cambio
normal/instrumental/8D puede continuar la sesión, con evento y límite de intervalo.

Snapshot compacto e inmutable por sesión: título, artista, álbum, referencia
de portada y procedencia. Deduplicar por hash del contenido normalizado del
snapshot, NO usar ese hash como identidad del medio. Sin letras ni listas de
variantes. Para preservar imagen histórica se necesita copia content-addressed
gestionada por backup; una URL mutable o ruta sola no garantiza esa conservación.

Journal: observaciones inmutables. Intervalos: hechos efectivos de tiempo.
Sesión: estado materializado de una reproducción lógica. Aggregate: proyección
regenerable. Legacy: hechos limitados anteriores, nunca eventos inventados.
Migration: checkpoints/verificación de importación. Reject: filas corruptas
preservadas y explicadas. Feedback: decisiones explícitas del usuario, no un
modelo ML regenerable. Sus campos target_kind/target_key también admiten
artista/tag cuando no hay media_id.

## 3. Contrato de campos y tiempo

SQL detalla PK, FK, UNIQUE, CHECK e índices. Todos los sufijos `_ms` son
enteros en milisegundos. `_utc_ms` = Unix UTC; posiciones = tiempo de contenido;
offset = minutos respecto de UTC al observar. Ratios 0..1; speed >0.
NULL significa desconocido, nunca cero artificial. IDs no incluyen metadatos.
El DDL es un contrato de referencia: validación JSON/payload, UUID, transiciones
legales y coherencia entre ratios/tiempos corresponden también al repositorio
y sus tests; no están garantizadas únicamente por estos CHECK. termination_reason,
role y provenance deben tener codecs versionados, no strings libres en callers.

`wall_ms`: tiempo activo observado con reloj monotónico. `media_ms`: avance
efectivamente observado, excluyendo seek. A 2x, 600000 wall puede representar
1200000 media. `coverage_ms` de sesión es unión de rangos reproducidos, no suma
de avances ni máximo alcanzado. Repetir un fragmento aumenta tiempos pero no
su cobertura. Duración/ratio desconocidos permanecen NULL.

Guardar UTC para consultas y reloj monotónico relativo por sesión/epoch para
medir duración. Ante salto del reloj civil, cerrar intervalo y emitir
clock_discontinuity; no transformar un delta negativo en escucha. UTC se
reancla y se marca calidad limitada. Intervalos sin atribución temporal fiable
no participan como exactos en resúmenes fechados.

## 4. Taxonomía y contexto

Eventos: play (primero), pause, resume, seek, buffering_start/end, speed_change,
variant_change, checkpoint, complete (final natural), skip (intención manual),
stop (cierre lógico con reason), error, interruption_start/end,
clock_discontinuity y legacy_import. Payload JSON versionado incluye datos
específicos antes/después; no almacenar campos redundantes masivos.

`event_id` UUID creado ANTES de enviar; secuencia creciente por sesión asignada
por propietario; retry reutiliza ambos. UNIQUE(session_id, sequence) y PK
impiden duplicados. Un conflicto con payload diferente es error de integridad,
no `INSERT OR REPLACE`. Checkpoint no aumenta play_count. Complete y stop
pueden coexistir: natural end y cierre son hechos diferentes.

Contexto inicial enum versionado: library, search, artist, album, playlist,
atlas, recommendations, mix, connect, android_auto, widget, notification,
manual_queue, automatic_queue, unknown; source_id opcional. Contexto inicial
no cambia al pausar desde notificación. Cada comando conserva actor/initiator
en payload. Añadir valores exige migración del CHECK y versión del contrato.

## 5. Apertura, cierre y recorder

1. Seleccionar contenido carga identidad/variante/contexto sin contar escucha.
2. Primer playing realmente ready crea sesión y play transaccionalmente;
   empezar en posición >0 marca resumed. Restaurar una sesión ya finalizada
   abre otra; recuperar un motor aún activo reutiliza su ID confirmado.
3. Observar transiciones del motor y comandos. Cada cambio de estado, seek,
   velocidad, variante o discontinuidad cierra el segmento anterior.
4. Pausa/buffering no suma tiempo y NO finaliza automáticamente la sesión.
5. Fin natural emite complete; siguiente pista cierra y abre otra. Skip solo
   si hubo next/previous/selección manual que abandonó contenido, con razón.
6. Stop explícito, source_lost, error o interrupción terminal cierran con razón
   propia. Cerrar pantalla es irrelevante. Cierre normal de app hace flush;
   kill no permite garantizar callback. Recuperación marca interrupted al último
   checkpoint durable, sin inventar tiempo desde él hasta el nuevo arranque.
7. Loop natural: sesión nueva por repetición completa; seek atrás manual no
   equivale a loop. Confirmar señal natural del motor, no solo caída de posición.

Propuesta de política v1 a aprobar antes del cutover: play válido con ≥20 s
wall, o fin natural de contenido corto con ≥3 s wall. Video también usa esta
política explícita; su semántica anterior queda legacy, no se reinterpreta.
Sesiones más cortas se conservan aunque no cuenten. Completed natural y
coverage_ratio son métricas diferentes; no completar por acumular 90% mediante
fragmentos repetidos. Reglas quedan policy_version y pruebas versionadas.

## 6. Intervalos y reparto semanal

Segmento efectivo = motor ready+playing, sin buffering/interrupción, misma
variante/speed/epoch. Samples monotónicos permiten comparar avance con tiempo
y detectar discontinuidad; si el motor no demuestra reproducción durante una
brecha, registrar calidad estimated/unknown, no asumir todo el hueco activo.

Cerrar segmentos en transiciones y checkpoint inicial cada 15 s; muestreo
puede ser más frecuente sin escribir cada tick. Payload del checkpoint
conserva rangos observados para reconstruir intervalos/proyecciones. Un seek
cierra segmento en la posición PREVIA y abre desde destino solo al reproducir.
No unir segmentos a ambos lados de pausa, seek o speed_change.

Ventanas son [inicio, fin), calculadas con fechas de calendario locales, no
restando 7×24 horas en zonas DST. Política semanal: lunes anterior hasta lunes
actual en zona elegida explícita por reporte. Offset histórico sirve hábitos
locales; zona del reporte sirve límites consistentes. Ambos no deben mezclarse.

Para intervalo de UTC estable, solapamiento = max(0,min(fin,B)-max(inicio,A)).
Repartir wall/media proporcionalmente al solapamiento dentro del segmento de
velocidad estable; redondear con resto para conservar total exacto entre ventanas.
La atribución subsegmento es estimación interpolada, no precisión de muestra
inexistente. Calidad debe llegar a UI. Sesiones se cuentan una vez por inicio
de reproducción válida; minutos se reparten aunque el inicio sea otra semana.
Eventos legacy puntuales permiten contar ocurrencias fechadas, no reconstruir
intervalos: sus minutos estimados van separados, nunca en wall observado.

## 7. Transacción, proyecciones y concurrencia

Comando contiene command/event IDs y estado esperado. En transacción corta:
verificar retry/payload → insertar evento → cerrar intervalos → actualizar sesión
→ aplicar diferencia a aggregate → COMMIT → confirmar recorder → publicar revisión.
Flags counted/completed y secuencia no avanzan en memoria antes de confirmar.
Ante retry de comando confirmado retornar resultado anterior sin reaplicar delta.

Aggregate por identidad+modo: session_count, valid plays, natural completed,
manual skips, wall/media totales, suma de ratios y número de ratios conocidos,
first/last played y last_completed. Promedio = suma/n, no promedio de promedios.
Por variante se consulta intervalos/sesiones; no sumar sesiones varias veces
cuando cambiaron de variante. Datos semanales van por rango, no agregado vitalicio.
Reconstruir en tablas/proyecciones temporales y sustituir en transacción; comparar
resultados con incremental. Journal conserva observaciones y payload suficiente
para regenerar intervalos; sesiones/intervalos verificables, no hashes solamente.

Owner serializa audio/video, preservando independencia de IDs. Usar una revisión
persistente de repositorio al commit y respuesta por comando; un fallo de notificación
no revierte datos. Suscriptores consultan revisión al reconectar. Background obtiene
el mismo owner; si arquitectura real exige múltiples conexiones escritoras, añadir
protocolo de ownership/optimistic locking probado antes de habilitarlo.

## 8. Legacy sin doble contabilidad

Importar eventos disponibles como legacy_import, conservando mode unknown si
ambiguo. Una variante unknown representa modalidad no demostrable, no audio.
No crear play/pause ni intervalos a partir de un único progress/occurredAt.

Legacy_metrics conserva contadores, ratio y timestamps originales, procedencia,
cutover y hash del origen. Eventos históricos ya cubiertos por esos contadores
se marcan baseline_covered. Total vitalicio = baseline + sesiones posteriores
post_cutover; NO baseline + todas las sesiones importadas. Si no se demuestra
cobertura, mostrar histórico conocido separado, no sumar ciegamente.
Baseline unknown se muestra global; jamás asignarlo entero a audio y video.
Si existen eventos pero no baseline, sesiones importadas son independent.
Sesiones abiertas al cutover necesitan reconciliación explícita para evitar
contar dos veces lo ya reflejado en MediaItem.

## 9. Migración y versionado

Inicializar antes de motores. Capturar snapshot estable de GetStorage con
escritores legacy detenidos. Esquema/version, origen de instalación y cutover
persistentes. Importación en staging con chunks y checkpoint migration_state;
NO activar lectores SQL hasta verificación y cambio final transaccional.
Así evitar una transacción gigantesca sin exponer migración parcial.

Eventos con sessionId conservan un mapping al UUID nuevo. Legacy sin ID:
UUID determinista sobre source_id + namespace + posición original + hash de
contenido. Posición distingue duplicados legítimos. No deduplicar por fecha/key.
El mismo origen debe conservar ID/manifest hash en backup. Backups antiguos sin
proveniencia estable se comparan y presentan conflictos; no prometer deduplicación
perfecta entre archivos antiguos independientes.

Cada chunk + checkpoint se confirma conjuntamente; retries reusan IDs.
Filas corruptas se guardan en migration_reject con razón; estado verified_with_rejects
no es verified y requiere reporte/reconciliación. Verificar conteos válidos/rechazos,
aliases, checksums, FK y totales por calidad. Solo entonces cutover.
No borrar claves originales; exportar respaldo verificable antes de limpieza futura.

user_version versiona estructura; migration_state versiona importaciones/datos.
Migraciones futuras tienen SQL probado, checksum, backup y transacción por fase.
Versión más nueva que la app: bloquear escrituras y ofrecer actualización;
no borrar/recrear base. Fallo conserva estado previo y permite reintento informado.

## 10. Configuración y fallos

Native: foreign_keys=ON en cada conexión; WAL en almacenamiento local;
synchronous=FULL inicialmente por prioridad de durabilidad. NORMAL solo tras
decisión explícita sobre pérdida de commits recientes ante fallo eléctrico.
busy_timeout=5000 ms en worker, no bloquear UI; retries limitados para BUSY,
con IDs iguales. SQLITE_FULL/IOERR no son éxito: mantener comando acotado,
avisar con claves i18n y no seguir aumentando contadores confirmados.
Corrupción: cerrar escrituras, preservar archivo y recuperación/backup;
no reinicializar silenciosamente. FK/CHECK conflict es bug o dato rechazado.
[Semántica de los PRAGMA](https://www.sqlite.org/pragma.html).

WAL autocheckpoint inicial 1000 páginas; monitorizar tamaño y lectores largos.
PASSIVE en mantenimiento; TRUNCATE solo sin lectores y nunca cada checkpoint
del recorder. No copiar solamente .db mientras está abierto: commits pueden
estar en WAL. No FULL VACUUM al arrancar; evaluar mantenimiento tras borrado
material y espacio disponible. quick_check tras migración/restauración;
integrity_check completo bajo demanda/mantenimiento.
[Concurrencia y checkpoints WAL](https://www.sqlite.org/wal.html).

## 11. Backup, retención, feedback y rendimiento

Backup lógico versionado por chunks ordenados (keyset), manifiesto con origen,
schema/policy/payload versions, conteos y checksums. Exportar snapshot consistente
con API de backup del driver verificada o snapshot de lectura; evitar lectura
larga que crezca WAL sin control. Incluir identidades, aliases, variantes,
snapshots/portadas, sesiones/events/intervals, legacy y feedback. Agregados son
opcionales: reconstruir/verificar. Biblioteca y paths requieren remapping separado.

Restore a staging, verificar chunks/FK/checksums y merge por IDs estables, no
`REPLACE`; payload distinto con mismo ID es conflicto. Corte de restore conserva
checkpoint. Swap de base exige motores/owner cerrados; no reemplazar archivo vivo.
Backup legacy atraviesa importador anterior, sin sumar otra vez baseline.

Retención inicial ilimitada, sin 120 días ni 4000. Borrado de historial es acción
explícita: eliminar dependientes y reconstruir proyecciones en transacción.
Compactación futura versionada debe demostrar reconstrucción equivalente antes
de borrar journal; no conservar solo promedios. Feedback independiente no desaparece
con una limpieza de historial salvo petición del usuario.

ML consume consultas recientes por rango/modo, coverage/skip, recencia, contexto
y dimensiones actuales/históricas explícitas. Modelos/cachés son derivados; historial
no depende de que termine entrenamiento. Importar feedback actual como baseline
sin inventar fecha pasada de cada decisión.

Historial paginado por (started_at_utc_ms,session_id), límite inicial 50; detalles
journal por (session_id,sequence). Caché LRU acotada, nunca readAll de eventos.
Índices del SQL responden alias, historial global/medio/modo, intervalos temporales
y journal. Usar EXPLAIN QUERY PLAN y medir antes de añadir otros índices.
Checkpoint15 s = hasta240 checkpoints/hora activa; 2h/día≈175200/año, más cambios.
Esto es cálculo, NO benchmark. Medir bytes reales/índices/WAL, latencia p95 y
rebuild con 1M eventos. Pérdida tras kill puede incluir último segmento sin commit;
15 s es objetivo de flush, no garantía si OS suspende callbacks.

## 12. Flutter/GetX y decisión de driver

Repo contiene android/ios/linux/macos/windows/web. Son targets encontrados, NO
prueba de soporte efectivo. `dart:io`/Platform y plugins en main/servicios requieren
auditoría de compilación real; Connect HTML servido no necesita DB del navegador.

Recomendación provisional: Drift + NativeDatabase en isolate para mobile/desktop,
por consultas tipadas, migraciones testeables y separación executor/plataforma.
sqlite3 directo exige implementar esas garantías manualmente; sqflite móvil por
sí solo no cubre desktop/web. Si la app completa web se confirma, evaluar
WasmDatabase y persistencia/quota/browser/private mode por separado; no aplicar
PRAGMA nativos mecánicamente. Confirmar SDK, ABIs, builds release y plugin de
background antes de fijar versión/agregar paquetes.
[Matriz oficial de Drift](https://drift.simonbinder.eu/platforms/).

GetX observa streams paginados y revisiones postcommit. Registro owner inicial
antes de AudioService/VideoService; servicios permanentes conservan reproducción
sin rutas. Biblioteca mantiene API síncrona por ahora; compatibilidad de contadores
es proyección escrita por repositorio, no otro contador incrementado por controller.

## 13. Incompatibilidades encontradas en el código

| Código actual | Cambio necesario antes del cutover |
|---|---|
| PlaybackHistoryRecorder IDs DateTime+secuencia estática | UUID durable, clock monotónico, owner multi-isolate |
| `_counted` antes de persistir | Confirmar flags solo después del commit |
| `skipped: finalize && !_completed` | Skip únicamente intención manual comprobada |
| playedSeconds acumula posición | Separar wall/media/cobertura y calidad |
| Snapshot MediaItem por checkpoint | Snapshot compacto inmutable por sesión |
| ListeningEventStore upsert sessionId | Journal append-only y proyección aparte |
| Retención automática120 días y readAll | Sin poda silenciosa, SQL por rango/paginación |
| Escritura evento y biblioteca separadas | Transacción única para dominio migrado |
| Audio/Video no pasan contexto/variante exacta al recorder | Adaptar todas las entradas, externos incluidos |
| Collage interpreta unknown como audio | Bucket unknown; no inferencia silenciosa |
| Semana basada en timestamp único/progress | Intervalos y estimaciones legacy separadas |
| Wrapped usa contador del item con ambas variantes | Consultas por modo sin duplicación |
| Historial ordena biblioteca lastPlayedAt | Historial de sesiones durable |
| Recomendaciones/ML y Atlas leen acumulados/listas | Adaptadores SQL con baseline/proveniencia |
| Backup JSON completo y paths snapshots | Chunks versionados, identidad y remapping |

Esta tabla identifica cambios pendientes, NO afirma que ya estén resueltos.

## 14. Plan, pruebas y riesgos de salida

1. Aprobar semántica de reproducción válida, semana/zona, unknown y cobertura legacy.
2. Spike driver con targets compilados y background; benchmark/DDL tests.
3. Repository/identidad/importador con datos sintéticos y fixtures reales anonimizados.
4. Recorder de ambos motores y transacciones; todavía sin cutover silencioso.
5. Adaptar collage, historial, Wrapped/notificación; luego recomendaciones/Atlas/ML.
6. Backup/restore versionado y recuperación; activar cutover tras conciliación.

Pruebas exigidas: primera instalación, cada versión legacy, kill por chunk,
duplicados legítimos/retry conflict, corrupt rows, FULL/IOERR/BUSY, identidad
renombrada/ambigua/eliminada, variantes, pausa/buffering/seek/speed/loop,
autoqueue/manual skip, audio/video concurrentes, comandos externos/background,
UTC discontinuity/DST/semana/midnight, short/unknown duration, cobertura solapada,
rebuild igual a incremental, streaming restore repetido/parcial y base futura.
Instrumentación debe verificar contador único y conservación de tiempos en cada caso.

Riesgos abiertos: señales reales de motor/background, snapshots de portadas,
historial antiguo irrecuperable, mezcla baseline sin IDs fiables, costo de disco
y evidencia insuficiente de soporte web/desktop. No declarar «100%» hasta ensayos.
Validación previa: 9 pruebas stats/recorder pasaron; suite ampliada23 aprobadas
y2 fallos de recomendaciones (región/trap-Puerto Rico), baseline no reproducido.
12 infos en video_service permanecen; no se declara suite limpia.

Validación de esta documentación: DDL ejecutado en SQLite3.53.4 en memoria,
13 tablas creadas, integrity_check=ok y foreign_key_check sin errores. Esto
solo verifica creación de estructura vacía, no comportamiento de producción.

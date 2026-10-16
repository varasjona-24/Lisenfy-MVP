# Contrato candidato v1 — revisión de migración

2026-10-05. Sustituye decisiones contradictorias del diseño anterior. Esquema
preparado para implementar y probar el repositorio; cutover NO autorizado todavía.

Actualización 2026-10-06: bootstrap de producción opt-in implementado; contrato
operativo y límites de validación en PRODUCTION_ACTIVATION.md. No implica rollout
público automático ni restauración global por generaciones ya terminada.

## Regla de progreso aprobada para canciones

Interpretación comunicada: abandono manual con progreso <92% = skip; >=92%
no es skip y se considera completada tolerando silencio final. Exactamente92%
pertenece al segundo grupo. Natural end es completed incluso sin alcanzar92%
según duración declarada errónea. Pausa, error, app kill, buffering y cierre de
pantalla NO son skip. Duración desconocida: skipped=0 con resultado desconocido,
no prueba de satisfacción. Legacy conserva flags originales sin reinterpretarlos.

Progreso = clamp(última posición estable ANTES del abandono / duración vigente,
0,1). No usar máximo histórico: escuchar hasta95%, volver a10% y abandonar
representa10% en esta política. No usar coverage como progreso. Un seek al95%
puede eximir skip pero no acredita escucha: valid_play depende de wall activo;
coverage revela lo efectivamente oído. completed y valid_play son independientes;
completed=1, valid_play=0 es posible. La tolerancia mide resultado, no fabrica
minutos. Comparar enteros position_ms*10000 >= duration_ms*9200, evitando fronteras
float; guardar ratio para UI. Política v1 del92% aprobada para audio y video
según aclaración del usuario; hecho y clasificación siguen separados. No modificar recorder
GetStorage ahora: hacerlo al integrar repositorio para no alterar dos contratos.

## 1. Staging físico y activación

Elegida base independiente por generación UUID. Archivo staging/<generation>.db
con el mismo esquema; commits de chunks quedan SOLO en ella. Base activa abierta
únicamente desde manifest activo que referencia generación+schema+checksum.
El opener rechaza directorio staging y generaciones no activadas. Una función de
infraestructura única resuelve rutas, nunca parámetros de path desde controllers.
Manifest de activación y contrato del opener son parte obligatoria de implementación.

Antes del chunk1, congelar snapshot GetStorage en archivo con bytes/hash/origen;
detener escritores antiguos durante captura. Si importación tarda, registrar nuevas
operaciones en cola durable separada, o mantener motores deshabilitados hasta
activar; v1 elige motores deshabilitados durante actualización. No afirmar que
GetStorage permita snapshot transaccional entre múltiples escrituras.
Chunk40/100: filas y cursor40 permanecen en staging, invisible al owner activo.
Retry verifica hash del snapshot y continúa. Source cambiado: nueva generación,
no reutilizar cursor. Abandonar: cerrar staging, ofrecer eliminar esa generación
exacta, conservar origen y active. Sin borrado automático de directorios amplios.

Verificar staging, cerrar conexiones/checkpoint según driver, mover generación
verificada a directorio de generaciones, escribir manifest temporal + flush +
rename atómico soportado por plataforma. Abrir y validar antes de habilitar motores.
Crash antes del manifest: sigue anterior; después: nueva generación completa.
Mantener anterior para recuperación, no decidir por mtime. Durabilidad rename/fsync
de directorio se verifica por plataforma: no la garantiza SQLite por sí solo.
Restore usa mismo protocolo, construyendo generación candidata desde copia coherente
de active para merge; no habilitar escritores durante snapshot/activación ni perder
cambios en medio. Se descartan tablas staging/filas finales etiquetadas porque exigen
filtros de visibilidad en cada consulta y dejan demasiado fácil exponer datos parciales.

## 2–4. Feedback, hashes y locators

Feedback append-only, anti-UPDATE, command FK y event_index únicos, versiones.
media exige media_id y target_key iguales; artist/tag exigen NULL media_id.
bias exige value; like/dislike/hide/unhide prohíben value. Solo legacy_baseline
importado admite y exige timestamp NULL y value con payload que documenta estado
histórico sin fecha. Deshacer crea evento compensatorio, no UPDATE. Repository
valida value finito y semántica de baseline/target, SQL valida combinaciones básicas.

Hash siempre identifica dominio+algoritmo+canonicalization_version+digest.
Snapshot v1: SHA256 sobre UTF8 de array JSON ["snapshot",1,title,artist,album,
artwork_ref,provenance]. NFC Unicode, sin trim ni lowercase; conservar espacios,
case, NULL frente a cadena vacía; escapar JSON determinísticamente (sin whitespace,
Unicode UTF8, sin escapes alternativos). Campos en orden fijo, no map arbitrario.
Snapshot conserva originales; normalización solo hashing. Colisión/hash igual con
contenido distinto es conflicto, no deduplicación silenciosa. Implementar vectors
Dart/Python equivalentes antes de cutover, incluida NFC.

Implementación inicial: snapshots usan canonicalization_version2, mismo array
con marcador2, texto exacto sin NFC/trim/case folding. Motivo concreto: Dart no
provee NFC en esta capa y aún no se validó un normalizador compartido. Así se
evita afirmar equivalencia Unicode no comprobada. Formas Unicode equivalentes
pueden producir snapshots separados, nunca colisiones semánticas o pérdida de
metadata; v1 NFC queda reservada, no se ha emitido desde Flutter. Esta decisión
no cambia identidades ni políticas de conteo.
Archivo variante/artwork: SHA256 bytes sin normalización, hash_version1.
Snapshot migración: SHA256 bytes congelados, canonicalization_version1 significa
raw bytes del formato versionado, NO mismo dominio que snapshot. Backup manifiesto
usa JSON canónico especificado por formato+version y hashes bytes por chunk.
request_hash command: codec version, kind y argumentos normalizados, excluyendo
metadata de retry; futuro algoritmo conserva registros anteriores con versión propia.

Locator tipado: local_path, file_uri, content_uri, http_url, imported_asset.
Resolver por kind en adaptador plataforma, validar esquema URI y permisos.
Mover archivo/restaurar cambia locator sin cambiar variant_id si bytes verificados
coinciden o hay evidencia fiable. Sustitución de bytes genera nueva variante;
missing cambia disponibilidad, nunca elimina historia. Hash NULL = no verificado.
URI con permiso revocado y remoto inaccesible son disponibilidad, no nueva identidad.

## 5–7. Tiempo y máquina de estados

UTC absoluto+offset observado en eventos; timezone_id opcional de sesión y en
eventos donde cambie la zona. quality unknown si plataforma no aporta IANA fiable;
no inventar zona a partir del offset. Hábitos usan UTC+offset del evento. Reportes
usan zona IANA explícita en parámetros/export, versión tzdb cuando disponible.
Viajes no reescriben eventos; restore mantiene zona observada aunque receptor cambie.
DST se calcula por calendario de la zona de reporte. Sin IANA, fallback offset fijo
de reporte etiquetado como limitado, nunca reglas DST inventadas.

```text
NEW → OPEN → CLOSED
          └→ INTERRUPTED
IMPORT → LEGACY
```

CLOSED/INTERRUPTED/LEGACY terminales e inmutables. Interrupted no vuelve OPEN:
resume real inicia nueva sesión ligada en payload. Pausa/buffering son estado del
motor dentro de OPEN, no estados de sesión adicionales. Closed tiene ended/reason;
open ninguno. Legacy conserva fecha final desconocida. Final_variant significa
última variante observada: inicial al abrir y actualizada antes de cerrar, no
predicción futura. Inicial, identidad, modo, snapshot/contexto no cambian en OPEN;
repository lo impone. Cambio audio/video cierra y crea otra sesión. SQL protege
transiciones y terminales; migración de proyecciones futuras necesita protocolo
especial de rebuild versionado, no desactivar triggers durante reproducción.

Termination codec v1: natural_end, manual_next, manual_previous, manual_selection,
explicit_stop, app_shutdown, process_lost, source_lost, engine_error,
external_interruption. Skip requiere evento skip+comando manual y progreso<92%.
completed y skipped mutuamente excluyentes. Natural end emite complete y stop;
abandono>=92% emite complete con evidence=progress_threshold y stop manual.

## 8–10. Codecs, payloads e idempotencia

Un único módulo Dart persistence codecs será dueño de enums y serialización,
sin strings en callers. codec_version en command/event/feedback; schema user_version
para tablas/CHECK; event_version estructura del envelope; payload_version por type;
policy_version significado de conteo; projection_version fórmula materializada.
Nuevo enum protegido por CHECK exige migración SQL; nuevo campo opcional payload
compatible incrementa contrato payload según decoder; cambio semántico exige policy.
Valores futuros se preservan en restore staging y bloquean activación incompatible.

Payload JSON object ≤64KiB UTF8. No depender json_valid hasta validar todos los
executors; repository rechaza JSON inválido/NaN/infinito, duplicados de keys y
types incorrectos. Decode versionado, campos extra permitidos en misma versión;
futura versión desconocida se conserva pero no proyecta ni activa silenciosamente.
Mínimos v1: seek from/to; speed_change from/to; variant_change from/to IDs;
checkpoint samples/ranges y clock epoch; stop reason; skip actor/progress/duration;
complete evidence/duration; error code/terminal; clock_discontinuity old/new anchor;
legacy_import source/ordinal/quality. play/resume/pause/buffering incluyen engine
state y posición. Feedback incluye target/action y origin; baseline estado original.

applied_command → N playback/feedback events, cero si no-op confirmado.
PK command_id, request_hash y result_json inmutables; UNIQUE command/event_index.
Índices de eventos separados por journal, result guarda referencias completas;
no exigir unicidad entre feedback/playback para una misma operación compuesta.
naturalEnd genera complete+stop; audio→video stop vieja+play nueva. Misma transacción
incluye todos los eventos/sesiones/intervalos/agregados y command. Retry hash igual
devuelve result sin escritura; hash distinto mismo ID es conflicto explícito.
No insertar un command duradero pending antes de efectos: commit único confirmado.

## 11–14. Intervalos, cobertura y políticas

Mantener end_position>=start_position. Seek/loop/variant/speed/source cortan antes
del salto. Regresión pequeña del engine se descarta como jitter con calidad;
regresión confirmada cierra en última posición estable y emite discontinuidad.
Nunca crear media negativo ni volver positiva distancia negativa artificialmente.

Cobertura: reunir rangos estables por variante compatible, ordenar (inicio,fin),
merge si siguiente.inicio<=fin actual, sumar longitudes. O(n log n), memoria O(n)
para sesión en rebuild; limitar consulta a esa sesión, no historia completa.
Cuando variante cambia contenido/duración, cobertura no mezcla rangos de distintas
líneas temporales: calcular por variante y escoger ratio final con provenance;
no sumar dos coberturas como si fueran una canción. Para variante equivalente
solo unir tras mapping de timeline explícito; nunca asumir instrumental misma duración.
Duración desconocida permite coverage_ms, ratio NULL. Clipping a [0,duración]
cuando conocida, rangos fuera se señalan anomalía y journal conserva raw observado.
0–60 +30–90 =90 coverage,120 media a1x; wall depende del tiempo real.
Se calcula por checkpoint/cierre y reconstruye desde intervalos, calidad derivada.

Policy histórica se conserva por sesión, no reevaluar silenciosamente92% sobre
legacy. Aggregate v1 combina flags ya evaluados con sus policy_version documentadas;
para evaluar política nueva construir proyección paralela con nombre/versión y
aprobación explícita, sin mutar terminales. projection_version no es policy_version.
Sesión completed no equivale necesariamente coverage>=92%.

Baseline100 +covered20 +post5 =105. Independent20 demostrablemente disjuntas
del baseline +post5 =125. Si cobertura de20 es desconocida, total confirmado105
y20 eventos históricos de cobertura incierta separados; no anunciar125 exacto.
No sumar baselines de backups como si fueran períodos disjuntos; elegir lineage
verificada o conflicto. Aggregate solo independent/post_cutover para total aditivo;
baseline_covered sigue disponible para consultas fechadas históricas.

## 15–17. Borrado, identidad y artwork

Borrado transaccional autorizado, motores correspondientes detenidos: seleccionar
sesiones → borrar intervalos → events → sesiones → legacy si alcance lo incluye
→ reconstruir aggregates afectados → snapshots sin referencias → revision commit.
applied_command conserva tombstone lógico result para no recrear hechos por retry;
un reimport de backup borrado necesita aprobación/version de restauración.
Feedback/biblioteca no se borran. Rango temporal v1 elimina sesiones completas
solapadas y muestra ese alcance antes de confirmar; recortar intervalos cruzados
requiere redaction/version posterior, no mutilar journal sin contrato.
Solo medio: mismos pasos filtrando UUID y aliases resueltos. Todo: mismo orden,
sin CASCADE. No borrar identity/aliases huérfanos automáticamente: protegen mapping
de reimport; purga explícita solo sin ninguna referencia ni biblioteca.

retired indica identidad retirada del catálogo, no archivo missing. Quitar canción
de biblioteca puede marcar retired sin tocar historial; reimport verificado reactiva.
Merge/split futuro usa tabla de resolución/redirección versionada y referencias
originales preservadas, no UPDATE masivo del journal. Conflictos se resuelven por
sesión/variante, no unión heurística. No implementar merge automático en v1.

Artwork content-addressed asset_ref='sha256:<digest>' y archivo inmutable por bytes.
Backup recoge assets referenciados por snapshots y biblioteca, verifica hashes.
Cambio manual de portada genera nuevo asset/snapshot, no actualiza el histórico.
GC mark/sweep de referencias activas+staging+backups gestionados, grace period;
no borrar imagen compartida tras eliminar una sesión. URL mutable sin copia se
marca artwork no preservado. Asset filesystem y commit SQL no son atómicos:
escribir/flush asset primero, referenciar tras verificación; GC recoge orphan después.

## 18–19. Pruebas, benchmark y fronteras

FULL conservador, no decisión definitiva. Benchmark Android/iOS release en dispositivo:
p50/p95/p99 checkpoint/commit, WAL/cold start,100k/1M journal, rebuild/Wrapped/restore,
batería si medible; comparar NORMAL con misma carga. No inventar mediciones desktop
como garantía mobile. Driver/ABIs/browser siguen gate de implementación.

SQL: FK identity/mode/variant, alias y event sequence únicos, command/event index,
feedback combinaciones, journal UPDATE, terminal/state, intervalo regresivo, tamaños.
Repository: UUID/hash correcto, JSON/types, codec futuro, command conflicto y retry,
secuencia completa, pruebas de eventos para flags, intervalos efectivos sin huecos,
calidad temporal, clipping/coverage y legacy reconciliation. Opener: staging invisible,
manifest/crash/source change/restore. Las pruebas SQL no sustituyen estas últimas.

Matriz requerida: FK/UNIQUE/update/feedback/transition/interval inválidos; retry igual
y conflictivo; seek ambos sentidos/loop/speed/variant/jitter/source;0/91.99/92/100%,
duración NULL, manual/pause/error; staging chunk40/source corrupt/source cambiado;
schema futuro; rebuild incremental; delete con RESTRICT; backup streaming/hash/restore
repetido; generación activa tras kill antes/después de manifest. Script actual cubre
invariantes SQL; pruebas Flutter del owner/importador vendrán con implementación.

Auditoría contra Listenfy: recorder todavía usa reloj civil, upsert y flags antes
del commit, umbral distinto y skip al finalize. Audio/Video no entregan commands
idempotentes ni variantes/contextos/zonas al recorder. Stores/consumidores aún
readAll/GetStorage, retención120 días; backup no posee generaciones ni manifest
de activación. Esquema no corrige eso por sí solo. Integración debe adaptar esas
entradas y probar single writer antes de migrar usuarios. Mantener originales.

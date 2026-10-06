# Migración de datos durables de la app

Regla aprobada por el usuario: 2026-10-06.

## Propietarios

- SQLite: biblioteca/variantes, playlists/miembros, artistas, Collections,
  capturas y asociaciones, recomendaciones y feedback, memoria/actividad de Atlas,
  registros de fondos y archivos, trabajos de procesamiento, resultados y estado
  durable. Los archivos físicos siguen en disco, referenciados por registros.
- GetStorage: tema/paleta, preferencias de volumen/EQ/velocidad, idioma cuando
  corresponda al proveedor de localización, ajustes de temporizadores,
  personalización visual, notificaciones y procesamiento. No guardar colecciones
  creadas por el usuario como si fueran preferencias. EasyLocalization conserva
  su proveedor actual hasta revisar explícitamente su propietario de idioma.
- Memoria: progreso instantáneo de un worker, suscripciones, locks, tokens de
  pausa automática y demás estado efímero. No debe ser el único lugar donde
  quede un trabajo que necesita recuperación.
- Caché: datos regenerables y descartables, separados de preferencias y datos
  durables. Descubrimientos, favoritos, feedback y archivos creados no son caché.

No cambia la política de historial ni autoriza reinterpretar métricas legacy.
La velocidad histórica de un intervalo sigue en SQLite aunque la velocidad
preferida se coloque en preferencias. Hay que separar esos campos antes de
cambiar el propietario de la velocidad/crossfade que hoy posee la restauración.

## Bloque implementado: catálogo v3 en SQLite debug

La migración v3 añade library_record/library_variant, playlist_record/
playlist_member, artist_record, catalog_file_reference y catalog_import. Cada
entidad tiene una fila propia; variantes y miembros se almacenan separadamente,
con orden y FK a su padre. Metadata JSON preserva el resto de campos del modelo;
no contiene bytes de archivos. Las claves de miembros pueden ser aliases públicos
o referencias ausentes, por eso no se fuerza FK contra id local.

Eliminar una entidad borra sus variantes/miembros y referencias del catálogo,
no elimina archivos físicos ni evidencia de playback. No se fabrican hashes de
contenido ni se supone que una ruta existente pruebe disponibilidad del archivo.

Antes de construir consumidores en main se congela catalog_source.json mediante
write+flush+rename y se importa en una transacción. El recibo incluye ID y hash
SHA256 de esos bytes. Reintento idéntico no sobrescribe cambios SQL posteriores;
otro hash con igual ID se rechaza. Baseline requiere catálogo vacío. Datos
malformados o identidades duplicadas causan rollback, no descarte silencioso.
Las claves GetStorage originales no se borran.

CatalogStorage es una capa transitoria de compatibilidad con los contratos
síncronos de los tres stores, no un nuevo propietario durable. Mantiene una
proyección del catálogo completo; publica nuevos valores solo después del commit.
No hace fallback a GetStorage para esas claves mientras esté registrado.
Errores de escritura se propagan al caller y flush, y bloquean las escrituras
siguientes. La lectura directa de playlists en Home también usa esta capa.
Se deben reemplazar progresivamente lecturas completas por queries/paginación y
operaciones por entidad; reemplazar listas completas no resuelve concurrencia
de read-modify-write de los contratos antiguos.

Los stores nuevos construidos por bindings, Connect y backup usan la misma
instancia registrada. Export/import mantiene el formato lógico de entidades
existente; no se afirma que un restore completo de todos los módulos sea una
única transacción. Ese protocolo y la activación siguen pendientes.

## Bloque implementado: dominios v4 en SQLite debug

Collections (sources), etiquetas/asociaciones y registro de capturas, fondos,
estado/mixes/modelo/feedback de recomendaciones, memoria/actividad de Atlas y
trabajos instrumental/8D usan DomainStorage registrado antes de sus consumidores.
Las 19 claves declaradas se importan desde una copia congelada con hash y recibo
transaccional. El original GetStorage no se elimina ni se usa como fallback de
lectura cuando SQL es propietario. Preferencias y caché de estaciones se delegan
al proveedor existente; la selección del fondo es preferencia, sus archivos son
registros SQL. Se indexan capturas físicas antiguas aunque no tengan etiquetas.

v4 añade app_domain_state, app_domain_record, app_domain_file y app_domain_import.
Es una transición por registros JSON ordenados, NO la normalización completa de
miembros/relaciones de cada módulo ni un journal inmutable de feedback. Las
relaciones internas se conservan en payloads. La proyección síncrona sigue completa
en memoria; operaciones por entidad, paginación y read-modify-write concurrente
siguen pendientes. Las escrituras/restauraciones se serializan y publican después
del commit; un fallo bloquea escrituras hasta reconstruir el adaptador.

Atlas SQL no aplica el corte legacy de 1.200 eventos. Trabajos terminados SQL no
se purgan automáticamente a las 24 horas; escrituras nuevas omiten progress y
message efímeros, conservando etapa, sesión remota, resultado y referencias.
La recuperación de tareas sigue el ciclo existente; no se promete atomicidad
entre archivos, workers y SQL ni ausencia de pérdida ante cualquier crash.

Backup mantiene el manifiesto lógico existente y añade app_domains_v1.json para
ocho namespaces complementarios (mixes/ML, Atlas, trabajos). Sus rutas de archivo
se exportan como referencias relativas verificadas y se reconstruyen al restaurar;
archivos ausentes no se presentan como disponibles. Se bloquea la restauración
si existen trabajos activos al iniciarla. No hay lease global que impida que un
worker nuevo arranque durante toda la operación. El restore global sigue siendo
varias transacciones y operaciones de disco, NO una transacción única. Backups
antiguos conservan el camino de importación lógico.

Los archivos siguen en disco. Capturas continúan contrastando la carpeta física
con el registro; rename/delete de disco y SQL requieren un protocolo de recuperación
para ser atómicos frente a interrupciones. No se elimina evidencia de playback.

## Estado y orden pendiente

Relaciones de artistas: esquema v5 implementado; ver ARTIST_RELATIONSHIPS.md para
roles persistidos, membresías, ambigüedades, reconstrucción y límites. El catálogo
JSON continúa como entrada de edición compatible; agrupación y detalle de artistas
leen roles SQL cuando la proyección coincide con el crédito original. Nuevos
backups contienen las tablas de relaciones; restore completo admite v4 con backfill.

### Exportación SQL completa (2026-10-06)

Cuando PlaybackRepository está registrado, el ZIP añade sqlite_complete_v1.json:
una transacción de lectura serializada exporta todas las tablas de aplicación
instaladas (no sqlite_*), incluso tablas futuras, sin filtro temporal de historial.
Incluye filas originales y versión real del esquema. Se copian referencias locales
del catálogo/dominios y campos de archivos dentro de payloads JSON, incluidas
portadas históricas; fileLocators relaciona rutas originales y entradas relativas,
missingFiles declara referencias no copiadas. Este contenido incluye variantes
referenciadas aunque la opción legacy excluya instrumentales del manifiesto lógico.

El snapshot SQL es consistente internamente, NO simultáneo con el manifiesto lógico
y todos los archivos. Preferencias mantienen el alcance existente (apariencia/layout),
no se exporta indiscriminadamente GetStorage ni credenciales. Cachés/temporales físicos
no se recorren como contenido durable. Los archivos lógicos anteriores se mantienen
para restaurar archivos/preferencias y para compatibilidad con backups antiguos.
La restauración completa SQL ya está conectada: al encontrar el suplemento se
omite el merge del bundle playback anterior y, después de restaurar el contenido
lógico/archivos, se reemplazan todas las tablas SQL en una transacción. Exige versión
y conjunto de tablas compatibles, columnas completas y FK válidas; ordena borrado
e inserción por dependencias. El fallo de esa transacción revierte el reemplazo SQL.
Se reconstruyen rutas en catálogo, dominios y restauración operativa y se recargan
proyecciones/tareas/recomendaciones. Journal y evidencia hasheada no se reescriben;
sus referencias históricas originales pueden necesitar resolución mediante el
mapa de locators en otro dispositivo. No se afirma que sus portadas históricas
ya funcionen allí. Las etapas lógicas/disco previas siguen fuera de la transacción:
un fallo global no revierte todos los archivos o cambios lógicos anteriores.
La restauración SQL completa reemplaza, no fusiona, datos posteriores al backup.
El protocolo de activación/global recovery sigue pendiente. Release sin
repositorio registrado no genera este suplemento. No se declara backup global
atómico ni recuperación total ya validada en instalación vacía.

1. Biblioteca, playlists y artistas: implementados en SQLite debug, pendientes
   pruebas físicas de importación/edición/exportación/restauración.
2. Collections, capturas/fondos, recomendaciones, Atlas y procesamiento:
   conectados en debug v4; pendientes pruebas físicas, normalización y protocolos
   de concurrencia/recuperación detallados arriba. No se inventan fechas de feedback.
7. Preferencias de reproducción y backup global: revisar propietarios y restaurar
   transaccionalmente cada conjunto consistente, incluyendo backups antiguos.
8. Activación real: manifest/generación verificada según MIGRATION_CONTRACT,
   recuperación tras interrupción y targets soportados. No abrir una migración
   parcial automáticamente en release.

Esta implementación continúa detrás de LISTENFY_SQLITE_STAGING_HISTORY en debug.
Sin flag y en release sigue el propietario legacy. No es una migración global
terminada ni elimina todas las dependencias de GetStorage.

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

## Estado y orden pendiente

1. Biblioteca, playlists y artistas: implementados en SQLite debug, pendientes
   pruebas físicas de importación/edición/exportación/restauración.
2. Collections: migrar fuentes, temas, colecciones, miembros y jerarquía.
3. Capturas y fondos: registrar archivos, asociaciones, etiquetas, selección de
   fondos y referencias; mantener preferencias de carrusel separadas.
4. Recomendaciones: migrar estado durable/feedback, distinguir modelos y mixes
   regenerables. No convertir feedback histórico en eventos con fecha inventada.
5. Atlas: estaciones/cache frente a actividad, descubrimientos y memoria durable.
6. Procesamiento: trabajos/reintentos/resultados SQL; configuración GetStorage;
   progreso efímero en memoria. Referenciar variantes/archivos generados.
7. Preferencias de reproducción y backup global: revisar propietarios y restaurar
   transaccionalmente cada conjunto consistente, incluyendo backups antiguos.
8. Activación real: manifest/generación verificada según MIGRATION_CONTRACT,
   recuperación tras interrupción y targets soportados. No abrir una migración
   parcial automáticamente en release.

Esta implementación continúa detrás de LISTENFY_SQLITE_STAGING_HISTORY en debug.
Sin flag y en release sigue el propietario legacy. No es una migración global
terminada ni elimina todas las dependencias de GetStorage.

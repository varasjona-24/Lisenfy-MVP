# Restauración de reproducción en SQLite

Estado: modelo e importador implementados y probados en staging. No hay cutover
del estado operativo ni del historial de producción en este commit.

## Fuente de verdad prevista

El motor es autoridad del estado vivo. SQLite conserva la restauración; GetX
publica una proyección de sus lecturas y commits, no otra copia persistente.
Preferencias generales y biblioteca pueden permanecer fuera de esta migración.

El esquema v2 añade tres tablas, sin modificar sesiones históricas:

- `playback_restoration`: snapshot operativo por audio/video; cola, variantes,
  índice, posición, intención de reproducción, último contenido y ajustes audio.
- `playback_resume`: posiciones por modo y clave legacy, con watch time de video
  cuando está disponible. No hay tope silencioso de 300 posiciones en SQL.
- `restoration_import`: recibo de importación por fuente congelada y hash SHA256.

El snapshot JSON tiene codec v1. Las listas se copian mediante serialización
en el constructor; modificar una lista original no cambia una escritura pendiente.
Las claves id/publicId antiguas se conservan sin inventar identidades canónicas.
No se reconstruyen ni se crean eventos a partir de una posición de reanudación.

## Importación

`LegacyRestorationSnapshot.capture` lee las claves existentes con motores y
escritores detenidos. Su representación congelada debe persistirse antes de
importar; `fromBytes` permite reutilizar exactamente los mismos bytes en retry.
`PlaybackRepository.importRestoration` importa ambos modos, sus posiciones y el
recibo en una transacción, y notifica revisión solo después del commit.

La importación exige destino operativo vacío. Mismo source_id/hash devuelve
no-op, incluso si después cambió la posición. Source_id con otro hash produce
conflicto; no sobrescribe restauración nueva. Datos inválidos bloquean la
operación, sin recortar índices ni descartar posiciones silenciosamente.
Las claves GetStorage no se eliminan.

## Trabajo restante para activar fuente única

1. Persistir el snapshot de migración y completar importación/reconciliación del
   historial legacy, no solo del estado operativo.
2. Implementar activación por manifest y opener activo conforme a
   MIGRATION_CONTRACT; no convertir el debug staging actual en producción.
3. Adaptar AudioService, VideoService, prompts, controles externos y restauradores
   a estos comandos. Mover los escritores de posición/cola video fuera del
   controller de presentación, con política de reanudación preservada.
4. Adaptar consumidores del historial y backup/restore. No usar fallback a
   GetStorage después de activar, ni leer un store y escribir otro.
5. Verificar arranque, pausa, cierre, background, migración interrumpida y backup
   en dispositivos. La activación se realiza antes de habilitar motores.

Por ahora el runtime conserva los lectores/escritores GetStorage existentes.
Este commit prepara almacenamiento y migración sin afirmar que ya son la fuente
única de la aplicación.

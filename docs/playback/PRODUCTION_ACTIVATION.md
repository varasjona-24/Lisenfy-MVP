# Activación de SQLite en producción

SQLite es el propietario durable por defecto en debug y release por decisión del
usuario (app aún no publicada). Para compilar release ya no hace falta bandera:

```sh
flutter build apk --release
```

Instalar como actualización, con el mismo applicationId y firma, sin desinstalar.
LISTENFY_SQLITE_RELEASE_MIGRATION tiene defaultValue=true. false es únicamente
una salida diagnóstica para instalaciones sin generación activa.
Una vez creado active.json, los siguientes arranques siguen usando SQL aunque se
omita el flag. No hay fallback automático al GetStorage desactualizado.
La activación por defecto no demuestra por sí sola que el backup ZIP ya haya sido
validado físicamente en una instalación vacía. Archivos siguen en disco; SQLite
guarda sus referencias y los datos durables, GetStorage preferencias/cachés.

## Protocolo implementado

- Motores y consumidores durables no se construyen hasta terminar la activación.
- Se congela una fuente de catálogo, historial, reanudación y dominios; SHA256,
  plan persistente y generation UUID identifican el mismo reintento.
- Si existe una instalación SQLite debug, se exportan todas sus tablas en una
  transacción y se conserva esa fuente más reciente, no el GetStorage antiguo.
  La ausencia de su base con scope registrado bloquea la importación obsoleta.
  Se conserva también su scope de aliases de reproducción, independiente del
  nombre de la nueva generación, para no duplicar identidades al reproducir.
- Candidata en staging; importadores idempotentes y transacciones. Integridad,
  claves foráneas y conteos de catálogo/eventos legacy se verifican antes de activarla.
- WAL checkpoint TRUNCATE, cierre, hash de candidata, recibo verificado,
  promoción a generations y publicación de active.json mediante archivo temporal
  con flush y rename. No se borra la fuente anterior ni las claves legacy.
- El opener activo exige el manifest seleccionado y una base existente. El
  bootstrap valida el recibo y abre/verifica la base antes de habilitar motores.
  El hash de base corresponde a la candidata sellada: no se compara contra una
  base activa que ya recibió nuevas escrituras legítimas.
- Interrupción antes del manifest: candidato no activo, mismo plan y reintento.
  Después del manifest: se abre la generación seleccionada, sin reimportar legacy.
- Errores muestran pantalla traducida con reintento; no habilitan motores ni
  cambian de propietario silenciosamente. Datos corruptos requieren diagnóstico,
  no se sobrescriben automáticamente con una fuente vieja.

## Límites y gates pendientes

La pantalla utiliza fases, no un porcentaje ficticio. La importación/exportación
actual materializa datos en memoria: benchmarks de bibliotecas/historiales grandes
y chunking adicional siguen pendientes. No se afirma tolerancia automática a
SQLITE_FULL durante reproducción ni reconstrucción de semanas sin evidencia.

flush de archivo + rename no demuestra fsync del directorio ante pérdida de
energía en cada plataforma; requiere validación de durabilidad Android/iOS.
El lock cubre preparación/activación, no representa un bloqueo de toda la vida del
motor entre procesos independientes. No se soporta alternar builds antiguos que
ignoran active.json: pueden escribir a GetStorage obsoleto.

La restauración ZIP mantiene su reemplazo SQL transaccional existente; no usa
todavía un cambio de generación para todo el conjunto disco/ajustes/base.
No se declara restauración global atómica ni se elimina el origen legacy.

Antes de publicar: actualizar desde versión legacy poblada; reintentar después de
kill durante importación y activación; comprobar nuevas importaciones, renombrado,
homónimos/fusión, audio/video, Connect/background; backup completo y restauración
en instalación vacía; repetir arranque sin flag; validar firma, targets y rendimiento.
No se instala ni se modifica el teléfono como parte de las pruebas unitarias.

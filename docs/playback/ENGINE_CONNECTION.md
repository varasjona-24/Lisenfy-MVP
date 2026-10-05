# Conexión de motores al historial SQLite

Conexión opt-in implementada mediante EngineHistoryRecorder. AudioService y
VideoService aceptan historyRecorder en constructor; null crea únicamente el
legacy. No registrar ambos recorders para un motor ni realizar shadow writes
en la fuente activa. main conserva legacy por defecto y SIEMPRE en release.
Modo debug opt-in: `flutter run --dart-define=LISTENFY_SQLITE_STAGING_HISTORY=true`.
Abre generación debug por instalación, recupera antes de crear motores e inyecta
dos recorders con UN repositorio. No activa manifest ni importa historial legacy.
Las pantallas aún consultan legacy: este modo es prueba de conexión, no rollout.

Para pruebas de integración: abrir generación staging, recuperar sesiones antes
de iniciar motores, crear UN PlaybackRepository compartido y un
SqliteEngineHistoryRecorder por motor; inyectarlos en los constructores. Cada
recorder recibe EngineSessionFactory y commandIdFactory. La composición de
migración debe suministrar identidad/variante UUID y alias durable de su importador,
snapshot y contexto real; factory no puede cambiar posición, clocks, velocidad o
modo observados. No inferir identidad desde título/path. Esta composición final
depende del importador y manifest de activación. La composición staging ya existe
en main: UUID de identidad+alias local scoped por instalación; variante UUIDv5
con dominio/version/media/modo/rol/formato y SHA256 de bytes locales (streaming).
Mover/renombrar archivo con mismos bytes conserva variante; remoto se identifica
por locator sin fingir verificación de bytes. Contexto unknown hasta adaptar
las entradas de producto, snapshot sin portada histórica hasta implementar assets.
No unir publicId a proveedores/instalaciones sin evidencia del importador.

Audio: estados/posición de just_audio, variante actual, buffering, completed,
intenciones next/previous/selección, seek explícito y errores errorStream.
Loop se distingue con LoopMode.one y regresión cerca del final, excluyendo seek
manual; eventos extraños no declarados fallan cerrados, nunca inventan intervalos.
Video: timer real500ms, isBuffering/isCompleted/hasError, variante y comandos.
Controller transmite motivo de autoplay frente a manual_next/manual_previous.
Cambiar variante termina la ocurrencia del source anterior y abre otra al ready;
no mezcla coberturas de timelines distintas. No implementa aún cambio de variante
dentro de una misma sesión conservando una timeline equivalente.

El adaptador serializa observaciones con UTC/monotónico capturados al recibirlas.
Abre solo ready+playing, checkpoint objetivo5s (sin ajustar frecuencia), pausa y
buffering cierran intervalos. Seek pausa la contabilidad, registra from/to y
reanuda tras respuesta del motor si sigue ready+playing: ni salto ni espera
cuentan como escucha. Última posición observada limita precisión; no se afirma
que haya muestras de audio/video durante huecos no observados.

Motivos factuales y clasificación92% permanecen separados. Cerrar UI no cierra
servicio permanente. onClose del servicio registra app_shutdown; lifecycle solo
flush, pues reproducción en background es deseada. Kill se recupera por owner
al último commit. Engine error no es skip. Fallos de persistencia detienen ese
recorder y son visibles por flush; no continúan incrementando flags. Los motores
exponen historyPersistenceFailure y sus operaciones de cleanup no quedan
bloqueadas por un fallo de historial.

Pendientes de rollout, no ocultos: mapping/importador de identidad y contexto,
activación, pruebas de canales/plugins y background Android/iOS, retries del
adaptador ante errores transitorios (el repositorio ya soporta idempotencia),
clock discontinuity y validación de reconstrucciones estructurales de cola.
El adaptador fail-closed exige recuperación/recreación controlada tras un fallo;
no se declara recuperación automática de SQLITE_FULL dentro de los motores.

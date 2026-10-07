# Registro de refactor

## 2026-10-07 — Continuar viendo integrado al orden de Home

- Retirada la tarjeta de Collections y del encabezado fijo de Home; ahora el widget continueWatching del orden editable renderiza la tarjeta de sesión existente sin reemplazar su cola. Sigue exclusivo del Home en modo video y se oculta cuando no hay sesión disponible.
- Continúa debajo de Favoritos en el orden predeterminado; normalización inserta el widget ausente tras Favoritos en diseños antiguos y conserva posiciones personalizadas sin duplicados.
- Eliminado el control de quitar para este widget y protegido el guardado/restauración de activación. Se puede reordenar, pero no desactivar ni cambiar su diseño fijo.
- Validación: cinco pruebas de layout/tarjeta aprobadas; análisis focalizado sin errores ni warnings, con 18 infos de estilo. El test de tarjeta conserva aviso de traducción por su fixture sin catálogo; el JSON real tiene la clave. Sin build ni instalación en este paso.

## 2026-10-06 — Recuperación ante fallo nativo del ecualizador

- ADB confirmó un PlatformException al activar AndroidEqualizer: getNumberOfBands sobre referencia nula; la carga de Te amare quedaba bloqueada antes de reproducir. No se atribuye este fallo a SQLite ni a corrupción del archivo.
- AudioService reintenta una vez la misma cola/índice/posición tras retirar los efectos del pipeline y detener el motor nativo fallido. Conserva el mismo player y subscriptions; eqSupported queda deshabilitado durante esa sesión. Solo se aplica al error nativo de Equalizer observado, no a archivos o SQL.
- Los fallos de carga limpian los indicadores y estado loading; la apertura por ruta captura el error y muestra un mensaje propio traducido ES/EN.
- Corregido el uso incorrecto de .tr() en el controller, que usa tr(key) de easy_localization. Análisis focalizado sin issues; análisis global: cero errores, cero warnings y 132 infos de estilo/deprecaciones. Seis pruebas aprobadas (fallback y reloj de historial); no constituyen validación nativa en el teléfono.
- Compilación anterior detenida; no se generó ni instaló un nuevo APK con este cambio. Pendiente compilar y validar reproducción real y ecualizador en release.

## 2026-10-06 — Retirada del paquete temporal de restauración

- Eliminados los flags SANDBOX/INSPECT, el sufijo .restoretest y la firma debug condicional. Release utiliza com.jv24dev.listenfy, nombre Listenfy, firma release y isDebuggable=false.
- Retirado el override debuggable del manifest; se conservan los fixes de launcher, SQLite, restauración, artistas y aislamiento del modo de Home. El procedimiento temporal queda documentado como histórico.
- Validación: cuatro pruebas de launcher aprobadas y flutter build apk --release exitoso (104.5 MB). Inspección del APK confirma paquete/nombre originales y snapshot AOT arm64; apksigner verify aprobado.
- No se instaló ni desinstaló ninguna app. La prueba física del release y restauración queda pendiente; conservar el backup fuera de los datos privados antes de resolver cualquier conflicto de firmas con debug.

## 2026-10-06 — Modo de Home aislado de navegación y filtros externos

- openMedia no consulta HomeMode: recibe una preferencia explícita (audio por defecto), verifica variantes válidas y filtra la cola al tipo elegido conservando el elemento seleccionado. Audio-only/video-only usan su reproductor real incluso si la pantalla prefiere el otro tipo.
- openHomeMedia conserva la preferencia local de Home; callbacks de sus widgets usan esa entrada. Secciones abiertas capturan el tipo mediante su presentación y búsqueda recibe un contexto explícito en lugar de seguir el modo global.
- Artists y otros callers externos dejan de heredar Home; Collections elige video sin modificar HomeMode. SourceLibraryPage tiene selector local. Historial e imports eliminan workers/dependencia de Home en controllers/bindings y usan su filtro propio para reproducir.
- Validación: cinco tests de resolución audio/video y accesos de artistas aprobados. Análisis focalizado sin errores/warnings, mantiene cinco infos avoid_print en HomeController; análisis ampliado de vistas conserva infos de estilo existentes. No se modificó SQLite ni se instaló APK: prueba física de Honey pendiente de recompilar.

## 2026-10-06 — Accesos de artistas del inicio compatibles con SQLite

- Home agrupaba por nombre normalizado y buscaba perfiles por esa misma clave, mientras los perfiles restaurados ya usan IDs estables: accesos/portadas podían perder su asociación. Playlists usan IDs y no cambian.
- Las opciones de artistas ahora utilizan los IDs de créditos SQL y enlazan perfiles por ID; fallback legacy mediante ArtistStore. Los accesos guardados por nombre se resuelven únicamente si hay una coincidencia no ambigua; IDs explícitos se conservan para homónimos.
- La selección de canciones de secciones de artistas consulta créditos SQL y soporta varios targets, en vez de comparar un ID o lista de IDs con nombres de subtítulos.
- Validación: dos tests aprobados (accesos legacy/IDs y homónimos); análisis sin errores/warnings, conserva cinco infos avoid_print en HomeController. Pendiente recompilar y verificar visualmente los accesos tras restaurar; no se modificaron datos del teléfono.

## 2026-10-06 — Progreso de restauración sin retrocesos periódicos

- Eliminado i % 500: la fase de biblioteca avanza entre 40–70% con el total real de elementos del manifest en memoria. El porcentaje se actualiza después de restaurar cada elemento.
- Manifest por streaming sin total: barra indeterminada y contador existente, con texto ES/EN propio; no se inventa porcentaje ni se añade una lectura completa para contar. Al finalizar la fase se retoma el rango de las etapas siguientes.
- Reabrir el diálogo tras confirmar la inspección conserva el progreso, sin reiniciarlo a cero. Una operación nueva sí reinicia sus indicadores.
- Validación: tres pruebas aprobadas, incluyendo monotonicidad con 10.000 elementos, streaming y límites; análisis focalizado sin issues. No se compiló/instaló APK ni se interrumpió la restauración del teléfono.

## 2026-10-06 — Restauración ZIP sin extracción/verificación repetida

- restoreFile comparte una pasada por ruta relativa validada durante cada importación. Biblioteca, portadas, capturas/fondos y locators del snapshot SQLite reutilizan el archivo extraído y verificado en esa misma operación.
- Se conservan validación de rutas, presencia de archivos completos, tamaño/hash disponibles y validación transaccional SQLite. No se omite integridad ni se reutiliza caché entre ZIPs; fallos no se memorizan como éxitos y referencias concurrentes esperan la misma operación.
- Validación: tres pruebas aprobadas (una extracción/verificación por ruta, fallo/reintento y concurrencia); análisis focalizado limpio. No se recompiló/instaló APK ni se repitió la restauración física de 5,33 GB en este paso.

## 2026-10-06 — Reanudación y recuperación de escrituras operativas

- Corregido un camino que podía persistir índice/posición desde callbacks del motor antes de guardar la cola nueva. Audio compara revisión de cola persistida y escribe el snapshot estructural completo antes del estado incremental.
- PlaybackStateStorage ya no rechaza toda escritura posterior al primer fallo ni envuelve recursivamente el error. Cada nuevo lote intenta su transacción; solo un commit correcto limpia failure. Flush sigue informando fallos pendientes y SQLite continúa siendo la única fuente durable.
- Regresión: índice inválido con cola vacía revierte; un lote válido posterior recupera audio/video y conserva un punto de reanudación sintético de Honey. No se relajan validaciones ni se borran posiciones para evitar el error.
- Validación: 36 pruebas de integración/restauración/política video/reloj audio/recorder aprobadas; análisis de AudioService y adapter sin issues. Persisten advertencias Drift de múltiples instancias en tests de reapertura.
- Build release temporal aprobado y actualizado mediante ADB -r únicamente en .restoretest, conservando datos. Reanudación física del video y Honey pendiente del usuario; no se declara probada solo por compilar/instalar.

## 2026-10-06 — Arranque release temporal e identidad tras restauración

- Causa física del cierre: runtime Flutter AOT sin snapshot precompilado al marcar buildTypes.release.isDebuggable. Inspección pasa a placeholder Android separado; release mantiene assets AOT, debug conserva su flag. APK verificado con libapp.so y paquete .restoretest.
- Asociación por library_id exacto, nunca por nombre/artista: agrega alias del scope nuevo a la identidad existente. Al arrancar repara únicamente aliases faltantes/duplicados. La factory usa la misma resolución después de restaurar sin reinicio.
- Unificación transaccional de referencias en variantes, sesiones, intervalos, aliases, legacy y feedback; agregados regenerados. Identidades anteriores quedan como tombstones sin library_id para conservar recibos de comandos. Journal/snapshots y métricas históricas no se reescriben.
- Mantenimiento de referencias de sesiones terminales: suspende y restaura solo los triggers de actualización de sesión/feedback dentro de la transacción; rollback conserva también las protecciones. Pruebas cubren sesión interrumpida, fallo antes de commit, triggers restaurados e idempotencia.
- Validación: 57 pruebas Flutter focalizadas y 4 tests Android aprobados; análisis de repository/factory/bootstrap sin issues. Build release autorizado actualizado -r solo en .restoretest, sin desinstalar ni borrar datos.
- Verificación física final: app abierta y estable (pantalla Imports); DB integrity_check=ok, foreign_key_check sin filas, 639 items/16 sesiones/378 eventos/49 intervalos conservados. Te amare tiene una identidad activa d966bca9-1034-50b2-b998-47d770957480, dos sesiones y una reproducción válida; no quedan library_id duplicados. App original no modificada.

## 2026-10-06 — Pantalla de preparación coherente con Listenfy

- Startup SQLite usa la paleta y brillo guardados, tema compartido, AppGradientBackground, tarjeta y logo SVG tintado. No inicializa settings ni consulta fondos SQLite antes de terminar la migración.
- UI extraída a StorageStartupPage, adaptable con scroll y ancho limitado; fases traducidas conservadas, anuncio accesible del estado y reintento existente sin cambios en persistencia.
- Validación: análisis de main y pantalla sin issues; prueba widget aprobada para progreso y acción de reintento. Sin build ni instalación en teléfono en este paso.

## 2026-10-06 — Inspección excepcional del release temporal

- Usuario autoriza por esta vez actualizar .restoretest para consultar su SQLite después de restaurar y reproducir Te amare. LISTENFY_RESTORE_INSPECT=1 habilita debuggable Android solo junto a SANDBOX; Flutter se compila en release.
- Misma firma/paquete y actualización -r, sin desinstalar ni borrar datos; app original fuera de alcance. Builds normales y temporales sin INSPECT conservan inspección desactivada.
- Verificación: build aprobado, tres tests launcher aprobados y actualización ADB sin desinstalar. La copia flutter-apk estaba obsoleta; se instaló el APK nuevo de outputs/apk/release y run-as confirmó acceso. Copia local DB+WAL: integrity_check=ok y foreign_key_check sin filas; 639 items, 10 playlists, 16 sesiones, 378 eventos y 49 intervalos.
- Te amare / Huey Dunbar: una reproducción válida, 26.698 ms de contenido y 27.152 ms de reloj en la sesión principal; una segunda sesión corta no válida. Detectadas dos identidades para el mismo library_id: alias restaurado del scope anterior y alias nuevo de la instalación temporal. No se modificaron datos para fusionarlas: corrección pendiente de autorización.

## 2026-10-06 — Release temporal para restauración aislada

- Variable opt-in LISTENFY_RESTORE_SANDBOX=1: paquete com.jv24dev.listenfy.restoretest, launcher Listenfy Restore Test y firma debug en APK release. Sin variable se conserva ID/nombre/firma normal.
- Labels de aplicación/aliases comparten placeholder; artwork usa authority por applicationId y widgets mantienen broadcasts explícitos privados. SQLite/GetStorage/archivos privados quedan separados por paquete.
- Procedimiento en docs/playback/TEMPORARY_RESTORE_TEST.md. No se desinstaló la app original ni se restauró el ZIP; retiro posterior de la temporal requiere autorización.
- Verificación: build release temporal aprobado (104.5 MB), tres pruebas launcher/provider aprobadas y aapt confirma paquete .restoretest/nombre distintivo. APK separado listenfy-restore-test-release.apk; instalación ADB paralela completada con Success. Restauración y comparación de datos pendientes del usuario.

## 2026-10-06 — SQLite predeterminado en debug y release

- Por autorización del usuario, el bootstrap de producción pasa a ser el camino normal: no requiere dart-define al compilar release. Biblioteca, playlists/artistas, historial/restauración y dominios conectados usan sus owners SQL; preferencias/cachés siguen en GetStorage y archivos físicos en disco.
- LISTENFY_SQLITE_RELEASE_MIGRATION defaultValue=true; false solo sirve para diagnóstico sin manifest. Una generación activa siempre gana para no regresar a datos legacy obsoletos.
- Regresión de selección predeterminada y protección de owner activo ante flag=false. No se borraron claves legacy, se instaló APK ni se restauró un backup en el teléfono. Prueba física de ZIP en instalación vacía sigue pendiente.
- Validación: 151 pruebas schema/stats/Connect/Atlas/recommendations aprobadas y análisis focalizado sin issues. No se generó un build release en este paso.

## 2026-10-06 — Bootstrap de producción y activación verificada opt-in

- Añadido PlaybackProductionBootstrap: fuente congelada/hash, plan persistente, generación candidata, verificación, checkpoint/cierre y manifest activo publicado con flush/rename. Reintento antes/después de activación sin reimportar GetStorage obsoleto; origen conservado.
- Si hay SQLite debug, se conserva su snapshot completo como fuente actual. Opener activo exige selección por manifest y rechaza bases ausentes; catálogo/dominios cargan SQL sin ejecutar importadores legacy al reabrir.
- main conecta la generación activa antes de motores/consumidores. Pantalla ES/EN de fases y errores con reintento. Bandera explícita LISTENFY_SQLITE_RELEASE_MIGRATION para pruebas; rollout público no activado por defecto. Manifest existente mantiene el owner SQL aunque se omita flag.
- Pruebas de activación, interrupción durante importación y antes/después del manifest, fuente corrupta, generación ausente/no seleccionada y preservación de SQLite debug frente a legacy obsoleto.
- Conservado el scope de aliases de reproducción al adoptar debug, sin confundirlo con el ID de generación. Se verifican también conteos de sesiones legacy; 150 pruebas focalizadas aprobadas y análisis de seis targets limpio.
- Pendientes: validación física release/firmas/targets, durabilidad fsync de directorio, benchmarks y restore ZIP por generaciones. No se declara atomicidad global archivos+SQL ni se borra GetStorage. Instrucciones en docs/playback/PRODUCTION_ACTIVATION.md.

## 2026-10-06 — Corrección del arranque con perfiles legacy sin identidad

- Confirmado por ADB: FOREIGN KEY constraint failed al insertar el alias no doubt con la clave antigua; excepción antes de runApp dejaba pantalla negra.
- La reconstrucción canoniza primero los perfiles antiguos y sus referencias de archivos/integrantes dentro de la transacción. La migración v6 incorpora identidades de perfiles no materializados antes de mapear sus claves.
- Regresión con No Doubt sin identidad, portada y miembro: FK válidas, referencias conservadas e idempotencia. Fixture de upgrade v4→v6 ampliado con perfil preexistente sin identidad.
- Validación: 142 pruebas schema/stats/Connect/Atlas/recommendations aprobadas y análisis focalizado de los tres archivos Dart sin issues; arranque físico pendiente del reinicio del usuario.
- No se borraron datos ni se escribió en la base del teléfono. Para ejecutar la corrección se necesita reiniciar el arranque de Flutter, no solo hot reload.

## 2026-10-06 — Identidad estable y edición atómica de artistas SQL v6

- IDs independientes del nombre, aliases no únicos y redirects de fusiones; upgrade automático v5→v6 y compatibilidad de snapshots completos v4/v5/v6.
- Renombrado y fusión explícita serializados en una transacción: perfiles, créditos, membresías y referencias. Caché publicada después del commit; rollback probado. Renombrar no cambia el ID ni fusiona homónimos automáticamente.
- UI traducida para mantener separado/fusionar y resolver créditos ambiguos eligiendo una identidad o creando otra. Asociaciones confirmadas sobreviven a reconstrucciones y nuevas importaciones; país/región de recomendaciones y Atlas se resuelve por ID.
- Backup completo conserva las tablas nuevas y restauración evita superponer perfiles por nombre antes del snapshot SQL. Archivos y preferencias no forman una transacción global con SQLite.
- Validación: 141 pruebas schema/stats/Connect/Atlas/recommendations aprobadas, incluidos IDs tras renombrado, LiSA/LISA separadas, alias/importación, fusión, rollback y roundtrip de backup. Análisis focalizado limpio. Persisten avisos de fixtures de traducción/plugins; no se declara validación física ni suite global.
- Solo SQLite debug con LISTENFY_SQLITE_STAGING_HISTORY; sin cutover release ni modificaciones en el teléfono. Parser principal/invitado y features lexicales ML mantienen su contrato; sin editor de coprincipales. Contrato actualizado en docs/playback/ARTIST_RELATIONSHIPS.md.

## 2026-10-06 — Créditos e integrantes materializados en SQL v5

- Revisadas agrupación, categorías propias/invitados/solistas de integrantes, edición/renombrado, parser y serialización artist/subtitle. Contrato en docs/playback/ARTIST_RELATIONSHIPS.md. No se transfiere autoría del solista al grupo ni del grupo a cada integrante.
- Añadidas identidades de artista, crédito original/interpretación, roles principal/invitado ordenados y membresías explícitas con FK. Los créditos ambiguos sin ft/feat no se separan; se marcan sin inventar coprotagonistas. Identidades mínimas preservan referencias sin fabricar biografías.
- Migración v4→v5 y reconstrucción desde catálogo SQL; writes de catálogo actualizan relaciones en la misma transacción. Agrupación/detalle consultan proyección persistida, con parser legacy/edición no guardada. Backup completo incluye tablas nuevas y restaura ZIP v4 con backfill.
- Alcance transitorio: JSON actual es entrada de edición y roles/membresías son materialización; sin editor de coprincipales ni fechas biográficas. Claves siguen normalizadas por nombre, reconstrucción completa, renombrados multientidad y corte release pendientes. No se instaló ni modificó la base del teléfono.
- Verificación final: 137 pruebas schema/stats/Connect/Atlas/recommendations aprobadas y análisis focalizado de 12 targets limpio. Pruebas nuevas cubren roles, ambigüedad, no transferencia grupo/integrante, edición/eliminación, upgrade v4→v5 y restore completo v4. Una ejecución previa tuvo un MissingPluginException asíncrono en fixture de Atlas/path_provider; se registró y la repetición completa pasó. Persisten avisos de plugins/traducciones. Validación física de actualización pendiente.

## 2026-10-06 — Restauración del snapshot SQL completo

- Conectado sqlite_complete_v1.json al restore ZIP. Sustituye el merge playback previo cuando está presente; reemplaza todas las tablas en una transacción, con validación de formato/esquema/cobertura/columnas y FK, orden de dependencias y rollback SQL. Restore completo reemplaza datos, no los fusiona.
- Rebase de rutas disponibles en catálogo/dominios/restauración operativa; journal y evidencia hasheada permanecen originales. Recarga de CatalogStorage, DomainStorage, restauración, tareas y recomendaciones tras commit. Backups sin suplemento conservan flujo anterior.
- Cobertura de igualdad de todas las tablas, reintento y rollback ante FK inválida/tabla faltante. Limitación: manifiesto/disco previos no son parte de la transacción global; referencias históricas originales requieren resolver locators en otro dispositivo. No hay lease global ni validación física de instalación vacía; preferencias completas y cutover release pendientes.
- Verificación: 134 pruebas schema/stats/Connect/Atlas/recommendations aprobadas, análisis focalizado de cinco archivos sin issues y diff sin errores de whitespace. Avisos conocidos de plugins/traducciones persisten; no se ejecutó restauración sobre datos del teléfono.

## 2026-10-06 — Exportación de todas las tablas SQLite

- ZIP incorpora sqlite_complete_v1.json cuando SQL está registrado: snapshot transaccional serializado de todas las tablas de aplicación, sin whitelist de módulos ni corte temporal. Se conserva la exportación lógica anterior para compatibilidad.
- Inventario adicional copia referencias de catálogo/dominios y archivos de payloads JSON, incluidas portadas históricas. Rutas originales se mapean a entradas relativas; referencias ausentes se declaran en missingFiles. La copia completa incluye instrumentales referenciados aunque el manifiesto legacy los excluya.
- Prueba compara cobertura contra sqlite_master y confirma inclusión automática de una tabla futura. Pendiente restore íntegro de este suplemento, preferencias completas y snapshot global coordinado con archivos; el restore actual continúa por los formatos lógicos anteriores. Solo SQL debug registrado; no cutover release.
- Verificación: 133 pruebas schema/stats/Connect/Atlas/recommendations aprobadas; análisis focalizado de tres archivos sin issues y diff sin errores de whitespace. Persisten avisos conocidos de plugins/traducciones; exportación física y restauración en teléfono pendientes.

## 2026-10-06 — Dominios durables SQL v4 y backup complementario

- Conectados Collections/sources, capturas/fondos, recomendaciones, Atlas y trabajos instrumental/8D mediante DomainStorage. Preferencias y caché de estaciones siguen en GetStorage; archivos físicos en disco y referencias SQL. Bootstrap carga la proyección antes de Settings y motores.
- Migración automática debug desde snapshot congelado, hash y recibo atómico; originales preservados, rollback ante datos inválidos, sin fallback legacy. Actualización v1/v2/v3 a v4 conserva datos existentes. Escrituras y restore del adaptador serializados, cache publicada después del commit y fallos bloquean nuevas escrituras hasta recuperación.
- Registro inicial de capturas sin etiquetas y actualización al crear/renombrar/eliminar; fondos registrados por rutas. Atlas SQL sin tope de 1.200 eventos y trabajos terminales sin purga legacy de 24 horas. Escrituras nuevas de tareas excluyen progress/message efímeros; resultados/variantes conservan el owner del catálogo.
- Backup añade ocho dominios complementarios, copia/reconstruye rutas relativas de archivos, actualiza inventario/hashes y evita recopia inconsistente. Restauración rechaza trabajos activos al inicio y recarga tareas durables sin lanzarlas automáticamente. Texto nuevo de bloqueo traducido en ES/EN.
- Verificación final: 132 pruebas schema/stats/Connect/Atlas/recommendations aprobadas; análisis focalizado de 19 targets sin issues y diff sin errores de whitespace. Incluye actualización v3→v4, rollback/recuperación fail-closed, capturas, más de 1.200 eventos de Atlas y codec de backup. Persisten avisos de plugins y traducciones en fixtures sin catálogo. No se declara suite global ni validación en teléfono.
- Alcance transitorio: registros JSON por entidad, relaciones internas sin normalización completa, proyección síncrona completa y concurrencia read-modify-write pendiente. Disco+SQL y backup global NO atómicos; falta lease global de restauración, pruebas físicas y cutover. Solo debug con LISTENFY_SQLITE_STAGING_HISTORY; release/default legacy sin cambio.

## 2026-10-06 — Regla global de datos y primer catálogo SQL v3

- Criterio aprobado documentado en docs/playback/APP_DATA_MIGRATION.md: datos durables y registros de archivos en SQLite; archivos físicos en disco; preferencias en GetStorage; estado efímero en memoria. Procesamiento sigue la misma regla: trabajos/estado recuperable/resultados SQL, preferencias GetStorage y progreso instantáneo en memoria.
- Primer bloque implementado: biblioteca, variantes, playlists/miembros, artistas y referencias de archivos en tablas v3. Importación congelada, hash y recibo transaccional; rollback ante datos inválidos; reintento no pisa cambios posteriores. Los datos originales no se borran y los archivos ausentes se conservan como referencias sin inventar disponibilidad.
- CatalogStorage adapta los contratos síncronos existentes a una proyección cargada desde SQL; publica tras commit y bloquea escrituras tras fallo. Stores construidos en bindings/Connect/backup reutilizan ese owner. Corregida la lectura directa de playlists del Home para no consultar el snapshot legacy.
- La actualización v1/v2→v3 conserva historial/restauración. Exportación del subset playback conserva formato v2 y declara por separado versión real de DB y alcance; backup lógico del catálogo sigue usando los modelos existentes. No se declara restore global transaccional ni cutover activo completo.
- Verificación final: 111 pruebas schema/stats/Connect aprobadas (6 nuevas de catálogo y una de actualización v2); análisis focalizado de 12 archivos sin issues y diff sin errores de whitespace. Persisten avisos conocidos de plugins y traducciones de tests. Pruebas físicas de importación/edición/exportación/restauración del catálogo pendientes.
- Alcance todavía incompleto: Collections, capturas/fondos, recomendaciones, Atlas y trabajos de procesamiento siguen pendientes. También paginación/operaciones por entidad para retirar proyección completa y resolver read-modify-write concurrente, separación de preferencias de reproducción y protocolo global de backup/activación. Solo está conectado en SQLite debug con flag; release y modo legacy permanecen sin cambio.

## 2026-10-06 — Pausa temporal y visibilidad por contexto de video

- NavigationController centraliza contexto: Home video (incluidas sus listas), todas las rutas Sources/Collections y reproductor/cola de video ocultan audio y pausan el motor sin stop ni eliminación de sesión. Home sincroniza su modo al iniciar y alternarlo.
- AudioContextPolicy serializa transiciones y recuerda únicamente una pausa automática. Retorna a audio solo si conserva la intención anterior y una fuente cargada; pausa previa del usuario, stop, cierre o selección nueva invalidan esa reanudación. Mientras video esté reproduciéndose mantiene la pausa; al cesar se vuelve a evaluar la ruta. El token es temporal en memoria, no una nueva fuente persistente ni una promesa de autorreanudar tras reiniciar la app.
- AudioService distingue pauseForVideoContext de órdenes de usuario mediante revisión de intención. No se borra cola, posición ni historial al cambiar de contexto. El motor y sus recorders existentes siguen siendo los escritores; no se agrega un recorder de navegación.
- PlaybackNavigationObserver mantiene la pila de páginas y popups (push/pop/remove/replace), reemplazando indicadores Get no reactivos para visibilidad modal. Edición, creación, capturas y listas compartidas heredan contexto si se abren desde video/Collections. Overlays manuales tienen profundidad para no liberarse al cerrar solo una ventana anidada.
- Verificación: suite schema/stats/Connect de 104 pruebas aprobada; tras cubrir pantallas compartidas se repitieron las 8 pruebas de política/navegación, todas aprobadas. Análisis focalizado de nuevos componentes/test limpio; análisis ampliado sin errores/warnings, con 5 infos avoid_print del Home. Persisten avisos de traducción en tests sin catálogo y compatibilidad Swift Package Manager de plugins. Validación real de transiciones, controles externos y audio/video en teléfono pendiente.

## 2026-10-06 — Tarjeta Continuar viendo compartida

- Sustituido el acceso básico por ContinueVideoCard: portada local/remota con fallback, título, acción de reproducción y colores de ColorScheme. La tarjeta reactiva desaparece sin último video y no modifica el estado del motor.
- Integrada únicamente en Home en modo video y en la pantalla principal Collections (SourcesPage). La navegación sigue sin argumentos de cola, conservando el camino de restauración existente. Sin cambios en otros módulos de música.
- Etiqueta propia traducida a Continuar viendo / Continue watching. Componente compartido para evitar duplicar presentación y navegación.
- Verificación: 11 pruebas de integración SQLite y 2 de widget aprobadas. Análisis del componente/test sin issues; Home/Collections sin errores ni warnings, con los 13 infos del Home ya registrados. El test de widget sin catálogo cargado avisa de la clave traducida; los JSON de producción contienen la clave. Aviso Drift en tests de reapertura persiste. Validación de aspecto/navegación en teléfono pendiente.

## 2026-10-06 — Mini reproductor oculto en Home video

- MiniPlayerBar observa el modo de Home y se oculta únicamente en la ruta Home cuando el modo es video. Volver a audio restituye su visibilidad conforme a las condiciones existentes.
- Cambio exclusivamente visual: no pausa, detiene, descarta ni modifica la sesión o persistencia de audio.
- Análisis focalizado sin issues y diff sin errores de whitespace. Comprobación visual del cambio de modo pendiente en teléfono.

## 2026-10-06 — Acceso para retomar video desde Home

- Home en modo video muestra Continuar video y el título actual cuando VideoService conserva un último item. La acción abre videoPlayer sin argumentos: reutiliza la sesión o restaura la cola/índice persistidos mediante el binding, sin sustituirlos por Últimas importaciones.
- La selección de un archivo en Home mantiene su comportamiento de iniciar la lista de esa sección. No se modifica la política existente de reanudación de posición ni se añade un segundo escritor de estado.
- Texto propio home.actions.resume_video en español e inglés. El acceso observa currentItem y desaparece si no hay item disponible.
- Verificación: 11 pruebas de integración SQLite aprobadas; diff sin errores de whitespace. Análisis del Home sin errores/warnings, con 13 infos fuera del bloque añadido. Tests emiten aviso Drift de múltiples instancias durante escenarios de reapertura. El nuevo acceso visual y su navegación requieren comprobación en teléfono; estas pruebas verifican la persistencia, no el tap de UI.

## 2026-10-06 — Cola de video y crossfade sin bypass legacy

- VideoPlayerBinding resuelve playbackStateStorage durante dependencies, en vez de inyectar GetStorage directo al restaurar cola/índice sin argumentos. SQLite debug pasa a ser la fuente de ese camino; release/sin flag mantienen el fallback legacy.
- PlaybackSettingsController usa la misma fachada que AudioService. Carga inicial, cambios y reset de audio_crossfade_seconds van a SQL cuando está activo; ya no sobrescriben el crossfade SQL con un valor legacy diferente.
- Volumen predeterminado, autoplay, descarga/datos y etiquetas siguen delegándose a preferencias GetStorage porque no son claves operativas SQL. No se amplió la migración a esas preferencias.
- Regresiones comparan crossfade SQL8 frente a legacy1, aplicación al motor (doble sin plugin), cambio4/reset0 conservando legacy1; cola video SQL frente a snapshot legacy distinto y autoplay delegándose a preferencias. Verificación en dispositivo de navegación de video/ajustes pendiente.
- Verificación final: 94 pruebas Flutter de schema/stats/Connect aprobadas y análisis focalizado de los dos archivos de producción y su test sin issues. La prueba de Connect emite un aviso de traducción ausente; no se amplió este cambio a traducciones ni a compatibilidad Swift Package Manager.

## 2026-10-06 — Reconciliación conservadora de anclas de audio

- Prueba real posterior guardó5 intervalos, pero el log mostró17.177→24.660ms en447ms y se bloqueó otra vez. Se conserva el hallazgo: el arreglo previo no estaba validado en dispositivo.
- Anclas idénticas con mismo estado/velocidad ya no reinician el origen monotónico; reset limpia duración anterior. Se evita que una posición stale repetida congele o retrase artificialmente la estimación.
- El adaptador identifica discontinuidades fuera del presupuesto temporal y solicita reconcileEnginePosition. Se cierra en la última observación confiable, se escribe seek técnico con seekReason=engine_anchor_correction y se continúa en el instante actual; el salto y el hueco incierto no se suman como escucha. No se simula un seek manual ni se clasifica como skip.
- Nuevo campo opcional de procedencia en comando/payload, sin cambiar esquema SQL. Canonical de comandos previos sin procedencia se mantiene; errores SQL continúan bloqueando el recorder y propagándose en flush. Reconciliar observaciones no borra ni reescribe journal anterior.
- Seek explícito, reload, cambio de ocurrencia y loop limpian el presupuesto del adaptador para no reconciliar dos veces una transición declarada. UI/Connect mantienen su posición y protocolo; no se añade un writer remoto.
- Regresiones: anclas stale repetidas, ajuste tardío exacto de Honey con447ms excluidos, retroceso durante pausa/reanudación. El caso15s conserva valid_play=0 según umbral20s existente; se corrigió la expectativa del test, no la política.
- Verificación final:92 pruebas Flutter schema/stats/Connect y12 invariantes SQL aprobadas; análisis focalizado de8 grupos sin issues. Connect se valida con dobles del motor, no como reproducción remota física.
- Reinicio y repetición en teléfono/Connect siguen pendientes; no se declara blindaje absoluto ni recuperación de segundos perdidos. Las discontinuidades reducen conservadoramente el tiempo registrado en vez de inventarlo.

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

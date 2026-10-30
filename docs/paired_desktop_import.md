# Importar mediante mi ordenador (experimental)

La función se distribuye en `play-store` como cliente móvil y en `desktop` como ordenador acompañante. `main` conserva su flujo conectado al servidor. No restaura el descargador del teléfono ni sus endpoints remotos.
La solicitud viaja por la sesión LAN TLS existente, aprobada por ambos usuarios y con pin del certificado.
El ordenador macOS ejecuta yt-dlp y FFmpeg y envía el resultado usando el protocolo de archivos existente.
El teléfono verifica el archivo, lo importa y confirma la importación antes de mostrar éxito.

## Probar

1. Preparar las herramientas del ordenador con `python3 tool/macos/prepare_download_tools.py`.
2. Ejecutar esta rama en macOS (`flutter run -d macos`) y en Android. Ambos necesitan esta versión.
3. Abrir Imports → Transferir archivos. En macOS generar la invitación LAN.
4. En Android elegir Red local y escanear el QR o introducir el código. Comparar la verificación y aceptar en ambos equipos.
5. Una vez emparejados, usar «Importar mediante mi ordenador» en Android.
6. Introducir un enlace HTTPS de un elemento individual de un sitio compatible con yt-dlp y elegir MP3, M4A o MP4.
7. Autorizar la URL y formato en macOS. El teléfono muestra la descarga y después la transferencia/importación.

El ordenador debe permanecer despierto y ambos equipos en la misma red local.
No usa el backend de descargas. Las herramientas se empaquetan y firman con la configuración de escritorio existente.
Los binarios preparados no se versionan.

## Límites

- Una tarea por sesión y autorización en macOS para cada enlace.
- Enlaces HTTPS de sitios públicos compatibles con yt-dlp. Se conservan los parámetros del enlace; las playlists se rechazan tras resolver los metadatos.
- No se aceptan rutas, comandos, ejecutables, opciones de yt-dlp ni formatos arbitrarios desde el teléfono.
- No se aceptan directos; si la fuente informa duración, se rechazan elementos de más de una hora. yt-dlp tiene un límite de tamaño de 512 MiB por descarga.
- La desconexión invalida la solicitud y detiene el proceso nativo; los temporales se eliminan.
- Las solicitudes repetidas no se ejecutan de nuevo. Los estados están asociados al ID y a la sesión autenticada.
- Se usa `listenfy.lan.v2`: no es compatible con clientes LAN anteriores.
- No hay cola persistente, reanudación ni historial de trabajos. Las transferencias usan su historial existente.
- La integración en la rama Play Store no garantiza su aceptación para publicación en Google Play.

## Validación

Pruebas de contrato de solicitudes, aprobación/rechazo, una tarea por sesión, repetición, estados ajenos,
invalidación al desconectar, cancelación nativa y mensajes sobre TLS real de loopback.
Se confirmó el flujo entre teléfono físico y ordenador. Ambos equipos necesitan una versión con este protocolo. La portada de la fuente todavía no se obtiene en este flujo.

La compatibilidad depende del extractor de yt-dlp y del acceso público al contenido. No se añade autenticación ni gestión de cookies desde el teléfono. La validación DNS comprueba el destino inicial; no constituye un aislamiento de red para todas las conexiones o redirecciones del extractor. Solo deben autorizarse enlaces de confianza.

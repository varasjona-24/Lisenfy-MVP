# Herramientas del ordenador acompañante

En esta rama experimental, el motor local se utiliza exclusivamente desde las solicitudes
que autoriza el usuario en una sesión LAN emparejada. No se restaura el descargador del teléfono.
El flujo y sus límites se describen en [paired_desktop_import.md](paired_desktop_import.md).

## macOS

Preparar las herramientas desde la raíz del proyecto:

```sh
python3 tool/macos/prepare_download_tools.py
flutter run -d macos
```

El script prepara yt-dlp con versión y checksum fijados, FFmpeg, ffprobe y Deno para la
arquitectura del equipo. FFmpeg y Deno deben estar instalados en el ordenador de preparación.
Los binarios y sus dependencias se guardan en `.desktop-tools/macos`, excluida de Git.
La fase de Xcode `embed_download_tools.py` copia y firma los helpers dentro del bundle.
Los helpers heredan el sandbox; no se desactiva el sandbox de la app.
Deno se ejecuta sin JIT dentro de la aplicación macOS.

Ambos equipos necesitan esta rama para usar el nuevo protocolo LAN.
La ausencia de herramientas o errores de la fuente se comunican como una importación fallida;
no se usa un backend como alternativa.

## Verificación

```sh
flutter test test/app/downloads/desktop_download_engine_test.dart
flutter test test/modules/nearby_transfer
```

El motor conserva la invocación sin shell, validación de formato y argumentos separados.
La sesión acepta únicamente enlaces HTTPS de un elemento individual de un sitio compatible con yt-dlp y solicita
confirmación antes de ejecutar el motor. Si la sesión se cierra, se solicita la terminación
del proceso; se descarta el resultado y se limpian los temporales.

La compatibilidad depende del extractor de yt-dlp y del acceso público al contenido. No se añade autenticación ni gestión de cookies desde el teléfono. La validación DNS comprueba el destino inicial; no constituye un aislamiento de red para todas las conexiones o redirecciones del extractor. Solo deben autorizarse enlaces de confianza.

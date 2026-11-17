# Adaptación funcional de escritorio

Objetivo: una implementación común para macOS y Windows cuando sea posible,
con integración nativa y validación específica en cada sistema.

0. Reproducción Windows: integrados just_audio_media_kit, video_player_media_kit y bibliotecas nativas de video/audio Windows; inicialización antes de crear reproductores. audio_service_win conecta controles del sistema. Pendiente compilación y prueba real Windows.
1. Metadatos locales y portada incrustada: integrado con FFprobe/FFmpeg; pendiente validación física Windows.
2. Capturas y miniaturas de video: integrado con FFmpeg preservando proporción; pendiente prueba UI y Windows.
3. Portadas en controles multimedia del sistema: corregidas URI locales para escritorio; content:// queda solo en Android. Pendiente prueba real del panel multimedia.
4. Pantalla completa nativa: pendiente implementación de ventana en ambos sistemas.
5. Notificaciones: pendiente inicialización, permisos y registro Windows/macOS.
6. Limpieza de silencios: pendiente análisis/render con FFmpeg.
7. Salidas de audio: pendiente detección nativa y actualización al conectar dispositivos.
8. Ecualizador y efectos en vivo: pendiente motor compatible; no confundir con variantes preprocesadas.
9. Importación emparejada: pendiente portadas y lotes de playlists; habilitar ordenador anfitrión Windows y adaptar certificados.
10. Integración con sistema: pendiente enlaces listenfy://, abrir con y arrastre externo.
11. Distribución: pendiente empaquetado Windows, firma/notarización macOS, pruebas Intel/ARM y equipos limpios.

## Herramientas compartidas

`DesktopMediaTools` busca FFmpeg y FFprobe sin exigir yt-dlp/Deno.
Windows: colocar `ffmpeg.exe` y `ffprobe.exe` en `download-tools/bin`
junto al ejecutable de la aplicación. macOS usa `Contents/Resources/download-tools/bin`.
También se aceptan LISTENFY_FFMPEG_PATH y LISTENFY_FFPROBE_PATH.
Fuera del bundle macOS se permite PATH para desarrollo.
No se utiliza shell para ejecutar rutas o fuentes.

## Validación

Prueba de integración con herramientas reales y archivos generados localmente:

```
flutter test --dart-define=RUN_DESKTOP_MEDIA_TOOLS=true test/app/downloads/desktop_media_tools_test.dart
```

Comprueba etiquetas Unicode, portada MP3 incrustada, rutas con espacios,
fotograma vertical con proporción conservada y archivo corrupto.
La ejecución en Mac no sustituye validación en Windows.

Resultado de la primera tanda en macOS: dos pruebas aprobadas, incluida la integración real; análisis de los cuatro archivos sin incidencias. No se ejecutó la app en Windows ni se validó una distribución instalada.

## Verificación de reproducción Windows

En Windows con Flutter y Visual Studio (Desktop development with C++):

```
flutter pub get
flutter run -d windows
```

El motor usa las bibliotecas Windows de Media Kit para audio y video;
macOS conserva los motores nativos actuales. No añadir simultáneamente
media_kit_libs_windows_audio: la biblioteca de video ya incluye audio.
El build descarga las bibliotecas nativas; requiere conexión en la primera compilación.

Comprobar MP3/M4A y MP4 locales (incluidas rutas con espacios), fuentes HTTP/HTTPS,
pausa, seek, volumen, velocidad, siguiente/anterior, repetición y cola aleatoria.
Abrir los controles multimedia de Windows y probar título, artista, portada y teclas
multimedia. El adaptador audio_service_win expone controles básicos, pero no una
lista navegable de la cola del sistema ni una implementación completa de su timeline.
La cola dentro de Listenfy sigue siendo la existente.
Validar también cambio audio/video y liberación de los reproductores al cerrar.
No se ha ejecutado compilación Windows desde esta Mac.

# Adaptación funcional de escritorio

Objetivo: una implementación común para macOS y Windows cuando sea posible,
con integración nativa y validación específica en cada sistema.

0. Reproducción Windows: integrados just_audio_media_kit, video_player_media_kit y bibliotecas nativas de video/audio Windows; inicialización antes de crear reproductores. audio_service_win conecta controles del sistema. Pendiente compilación y prueba real Windows.
1. Metadatos locales y portada incrustada: integrado con FFprobe/FFmpeg; pendiente validación física Windows.
2. Capturas y miniaturas de video: integrado con FFmpeg preservando proporción; pendiente prueba UI y Windows.
3. Portadas en controles multimedia del sistema: corregidas URI locales para escritorio; content:// queda solo en Android. Pendiente prueba real del panel multimedia.
4. Pantalla completa nativa: integrada con window_manager para macOS/Windows; botón, doble clic y atajos usan la ventana real. Sincroniza eventos nativos y restaura el modo inicial al salir del video. Pendiente prueba manual Windows.
5. Notificaciones: integrados registro Windows, permiso macOS solicitado desde Ajustes, presentación de avisos y navegación con foco de ventana. Pendiente validación manual en ambos sistemas.
6. Limpieza de silencios: integrado PCM mediante FFmpeg, análisis RMS en isolate y salida M4A/AAC con reemplazo opcional del original. Conserva selección de intervalos y fades en las uniones. Pendiente prueba manual Windows.
7. Salidas de audio: integradas enumeración nativa macOS/Windows, salida predeterminada y actualización cada 2 segundos mientras el panel está activo. Acceso a los ajustes de sonido. Pendiente prueba real Windows.
8. Ecualizador y efectos en vivo: se mantienen exclusivos de Android por decisión de producto. Controles ocultos en escritorio; sin migración de motores. Instrumental y variantes 8D generadas siguen disponibles.
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

## Notificaciones de escritorio

Activar el interruptor general en Ajustes y las categorías deseadas.
macOS solicita permisos en ese momento, no al iniciar. Los permisos revocados
impiden publicar y no consumen el ciclo de recomendaciones.
Windows registra Listenfy con identidad y GUID estables; no tiene diálogo de
permiso en la app. Ajustes del sistema y No molestar pueden ocultar los avisos.
Las notificaciones usan los mismos eventos y preferencias de móvil; no se han
creado alarmas nuevas ni tareas que ejecuten Listenfy estando cerrado.
Los resúmenes semanales se comprueban al iniciar/reanudar, dentro del periodo
ya definido; no son una alarma garantizada con el programa cerrado.

Probar importación correcta/fallida, instrumental/8D, Connect y temporizadores;
comprobar clic con ventana minimizada y arranque desde una notificación.
La recuperación de avisos antiguos y cancelación en Windows requiere identidad
de paquete (MSIX); fuera de MSIX la biblioteca no cancela avisos ya mostrados.
La app sigue impidiendo nuevas publicaciones cuando se desactiva la categoría.

## Limpieza de silencios

El editor conserva su selección de intervalos. En escritorio, FFmpeg decodifica
la pista de audio a PCM temporal. El cálculo RMS por ventanas y la copia de los
fragmentos se ejecutan en un isolate, por bloques, sin cargar todo el audio en RAM.
La duración mínima predeterminada sigue siendo 4 segundos y el umbral -35 dB.
Los parámetros y niveles medios son compatibles con el análisis de Android.

Solo se quitan intervalos seleccionados; los solapados se unen y los límites se
ajustan a la duración real. Se impide borrar todo el audio. Las uniones aplican
fades de 20 ms por defecto (máximo 80 ms) sin cambiar la duración conservada.
Se crea una variante M4A/AAC a 256 kbps en Documents/downloads/cleaned_audio
(del contenedor de la aplicación cuando hay sandbox). Se comprueban el códec,
la duración, los canales, la frecuencia y la decodificación completa antes de
registrarla. El panel permite reemplazar el audio original o conservar ambos.
El reemplazo guarda primero la biblioteca y solo después borra el archivo viejo.
Si está en uso o compartido, conserva ambos y muestra un aviso. Los PCM temporales se eliminan al terminar o al fallar.
Se necesita espacio temporal para la decodificación sin comprimir.

Validación local con FFmpeg y FFprobe:

```
flutter test --dart-define=RUN_DESKTOP_MEDIA_TOOLS=true test/app/downloads/desktop_audio_cleanup_test.dart
```

Pendiente validar manualmente el flujo del editor y ejecutarlo en Windows.

## Salidas de audio

macOS consulta Core Audio y Windows enumera endpoints de reproducción activos
con IMMDeviceEnumerator. La etiqueta predeterminada corresponde a la salida
multimedia del sistema, no a una medición de la ruta de cada proceso.
El panel se actualiza cada dos segundos, deja de consultar al pausar la app y
cancela el temporizador al desmontarse. El botón abre los ajustes de sonido.
No cambia automáticamente la salida ni modifica los dispositivos emparejados.
No se inventan niveles de batería: solo aparecen cuando el sistema los proporciona.
En Windows el tipo USB/Bluetooth depende de la información del adaptador; si no
está disponible, se muestra el tipo físico o un tipo genérico.
Probar conectar/desconectar auriculares, USB/HDMI y cambiar el dispositivo
predeterminado desde el sistema. La enumeración Windows requiere prueba nativa.

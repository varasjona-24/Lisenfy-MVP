# Descargas locales de escritorio

macOS, Windows y Linux utilizan `DesktopDownloadEngine`; Android e iOS conservan
las peticiones al backend. No se inicia un servidor HTTP local ni se incorpora Node
para ejecutar el backend: Flutter lanza yt-dlp con argumentos separados y FFmpeg
convierte o combina el archivo. Deno/Node solo proporciona el runtime de extracción.

## Flujo

1. Resolver metadatos con `--dump-single-json --skip-download`.
2. Reutilizar variantes locales existentes y no vacías.
3. Descargar a un directorio temporal privado dentro de downloads.
4. Convertir MP3/M4A o combinar MP4 H.264 + M4A, con la calidad del backend.
5. Publicar únicamente el archivo final no vacío; eliminar parciales al fallar.
6. Descargar la portada directamente de su URL y persistir metadatos y variante en
   `LocalLibraryStore`, respetando los datos editados de elementos existentes.

La identidad nueva se deriva de extractor e identificador; si se recibe `mediaId`
se conserva. Una URL importada antes mediante un UUID arbitrario del backend puede
necesitar su `mediaId` para asociarse al registro anterior: no se deduplica por título.

La vista previa de playlists usa extracción plana y un límite de elementos. La
importación procesa las URLs seleccionadas secuencialmente, registra fallos por
entrada y devuelve el contrato existente para crear la playlist local.

No hay retorno automático al backend al fallar el motor local. Instrumental, 8D,
letras y otros servicios del backend no se migran con este cambio. Las fuentes que
necesitan adaptadores propios del backend (por ejemplo Mega) requieren validación
separada; solo se ejecutan los extractores disponibles en yt-dlp.

## Herramientas

Se requieren yt-dlp actualizado, FFmpeg (con ffprobe junto a él) y Deno o Node
compatible con la versión de yt-dlp, incluido su componente EJS cuando corresponda.
Se buscan primero rutas explícitas, después herramientas empaquetadas y finalmente
Homebrew/PATH para desarrollo:

- `LISTENFY_YTDLP_PATH`
- `LISTENFY_FFMPEG_PATH`
- `LISTENFY_DENO_PATH` o `LISTENFY_NODE_PATH`
- `LISTENFY_YTDLP_COOKIES`: archivo local opcional; no se copian cookies del servidor.

Comprobar desde el repositorio:

```sh
dart run tool/check_desktop_downloads.dart
flutter test test/app/downloads
flutter test test/app/downloads/desktop_download_tools_test.dart --dart-define=RUN_DESKTOP_DOWNLOAD_TOOLS=true
```

Las pruebas normales no necesitan herramientas externas. La última genera un MP4,
lo sirve por HTTP en loopback y prueba yt-dlp + conversión MP3 con herramientas
reales; no contacta YouTube ni el backend.

## Preparación y empaquetado en macOS

El yt-dlp de Homebrew es un script que depende de Python fuera del bundle. No se
puede utilizar como helper de la app sandboxed: puede fallar al iniciar con
`Operation not permitted`. La app utiliza la distribución nativa autocontenida.

Antes de la primera compilación en cada equipo:

```sh
python3 tool/macos/prepare_download_tools.py
flutter run -d macos
```

La preparación descarga **yt-dlp 2026.10.26** desde su repositorio oficial y verifica
el SHA-256 fijado en el script. Usa su distribución onedir para poder firmar las
bibliotecas de Python individualmente. Copia FFmpeg, ffprobe y Deno instalados en
el equipo y sus bibliotecas no pertenecientes al sistema, reescribiendo referencias
para que sean relativas al bundle. No modifica Homebrew ni las herramientas originales.
Los binarios, archivos comprimidos y dependencias quedan en `.desktop-tools/`,
excluido de Git. Las licencias que acompañan las dependencias Homebrew se copian en
el paquete para su revisión antes de distribuirlo.

La fase de build de Xcode copia las herramientas a
`Listenfy.app/Contents/Resources/download-tools/`, firma primero las bibliotecas y
luego los ejecutables con la identidad de la app. Los helpers heredan el sandbox;
Deno recibe además el permiso de JIT. El helper Python recibe el permiso de
memoria ejecutable necesario para `ctypes`/libffi en Intel. Con firma ad hoc de
desarrollo, solo los helpers desactivan library validation porque sus bibliotecas
ad hoc no tienen Team ID; al firmar con una identidad real se conserva esa
validación. No se desactiva App Sandbox ni se amplían los permisos de la app principal. El build no
instala herramientas ni descarga archivos de Internet: si falta la preparación,
falla con una instrucción explícita. El paquete preparado debe coincidir con la
arquitectura del build; no se declara universal un paquete preparado en un solo equipo.

Se puede suministrar un paquete ya preparado mediante
`LISTENFY_MACOS_DOWNLOAD_TOOLS_DIR` durante el build. El descubrimiento en ejecución
prioriza las herramientas empaquetadas sobre Homebrew/PATH.

Prueba con un entrypoint independiente que se ejecuta dentro del sandbox real,
genera un video temporal, lo sirve en loopback y lo convierte con los helpers:

```sh
flutter run -d macos -t tool/probe_desktop_download_app.dart
# Opcional: añadir una URL para probar también un video real de YouTube
flutter run -d macos -t tool/probe_desktop_download_app.dart --dart-define=LISTENFY_PROBE_URL=https://youtu.be/O8BLUzAxNmQ
```

La prueba termina automáticamente y elimina los archivos temporales. Para regresar
al reproductor normal, ejecutar `flutter run -d macos` sin el target de prueba.

Windows/Linux siguen utilizando las rutas explícitas o las herramientas instaladas.
Su empaquetado y distribución requieren una validación independiente. No se añaden
cookies del servidor ni un proveedor de PO Tokens con este cambio.

## Límites y gestión

- Metadatos: máximo 2 minutos; proceso de descarga: máximo 30 minutos.
- Se leen stdout y stderr durante la ejecución; se conserva una cola acotada de
  diagnóstico en stderr. El progreso refleja los bytes de yt-dlp, no una copia desde
  el backend; puede reiniciarse entre pistas de una descarga de video.
- No se permite reconfigurar yt-dlp desde archivos de usuario (`--ignore-config`).
- Se pasan URL y rutas sin shell; solo se aceptan URLs HTTP(S), MP3/M4A y MP4.
- El timeout solicita terminar yt-dlp. La cancelación explícita desde UI y la gestión
  completa del árbol de procesos de conversión aún no están implementadas.
- No se añadió un proveedor local de PO Tokens ni una interfaz de cookies; fuentes
  que los requieran pueden fallar aunque la descarga del archivo de prueba funcione.

## Comprobaciones realizadas en desarrollo

- Descarga HTTP de un MP4 generado y conversión a MP3 con herramientas reales.
- Descarga de ese mismo archivo como MP4.
- Extracción y conversión MP3 de la URL pública `https://www.youtube.com/watch?v=jNQXAC9IVRw`
  desde Dart, sin backend; archivo temporal eliminado al terminar.
- Herramientas del equipo de prueba: yt-dlp 2026.03.17, FFmpeg 9.0.1, Deno 2.8.1.
- El video estándar `BaW_jenozKc` devolvió no disponible y no se usó para afirmar éxito.
- Prueba real en la aplicación macOS debug con sandbox activado: arranque de yt-dlp
  2026.10.26, generación de un MP4 y descarga/conversión a MP3 con FFmpeg, más
  arranque de Deno. Resultado: `SANDBOX_PROBE SUCCESS`.
- La distribución firmada con Developer ID/notarizada y otras arquitecturas siguen
  requiriendo validación independiente.

Para repetir una descarga explícita en un temporal sin modificar la biblioteca:

```sh
dart run tool/probe_desktop_download.dart 'https://www.youtube.com/watch?v=jNQXAC9IVRw'
```

## Validación del fallo de sandbox corregido

En este Mac Intel se reprodujo `Operation not permitted` al ejecutar el script de
Homebrew desde la app. Los helpers incluidos y firmados corrigen ese arranque.
Python/ctypes requiere memoria ejecutable en Intel; la excepción se limita al
helper Python. Con firmas ad hoc, los helpers admiten sus dependencias sin Team ID.
La aplicación principal conserva sus entitlements y App Sandbox.

Deno/V8 2.8.1 falla al ejecutar JavaScript con JIT en este entorno sandboxed. Los
procesos iniciados desde el bundle reciben `DENO_V8_FLAGS=--jitless` y una caché
bajo el temporal de la app. La extracción de YouTube funciona en modo intérprete;
no se desactiva el sandbox del sistema ni el de la aplicación.

Se verificó la ejecución JavaScript (`console.log(42)`) y la descarga de video de
`https://youtu.be/O8BLUzAxNmQ` desde el entrypoint macOS sandboxed. Marcadores:
`SANDBOX_PROBE JAVASCRIPT SUCCESS`, `SANDBOX_PROBE YOUTUBE VIDEO SUCCESS` y
`SANDBOX_PROBE SUCCESS`. El archivo se eliminó al terminar. El requisito para
probar la app normal después de este cambio es detener la sesión anterior y
recompilar; hot reload no incorpora los helpers ni sus firmas.

# Listenfy

Listenfy es un gestor multimedia local para Android construido con Flutter. Su foco es privacidad, organizacion manual y herramientas avanzadas para administrar musica y videos dentro de la app.

No intenta ser solo un reproductor. Funciona mas como una biblioteca personal: importa contenido, guarda metadatos, permite crear listas, organizar por regiones o tematicas, generar variantes de audio y compartir archivos en red local u offline.

## Estado del proyecto

Version analizada: MVP, abril-mayo de 2026.

La app es funcional, pero sigue en desarrollo activo. La reproduccion local, listas, imports, respaldo, Sources, Atlas, inicio editable, Listenfy Connect y transferencia P2P existen y son usables. Las areas que todavia necesitan mejora son rendimiento con bibliotecas grandes, compresion de respaldos, documentacion interna y algunas diferencias entre la experiencia de audio y video.

## Que hace Listenfy

### Musica

- Reproduccion local con cola y miniplayer.
- Listas de reproduccion manuales e inteligentes.
- Favoritos e historial.
- Editor de metadatos, artista, portada y relaciones.
- Editor de letras con sincronizacion manual.
- Modo 8D mediante backend externo.
- Extraccion vocal/instrumental mediante backend externo.
- Sonido limpio para recortar silencios largos.
- Atlas regional para organizar musica por continente, pais o region.

### Video

- Reproduccion local de videos.
- Cola con reordenamiento por arrastre.
- Picture-in-Picture en Android.
- Gestos de reproduccion: doble toque, volumen, velocidad y saltos.
- Captura de pantalla desde el reproductor.
- Orientacion vertical u horizontal.
- Editor de metadatos basico.

### Organizacion

- Sources para organizar videos por Collections.
- Atlas para organizar musica por region.
- Relaciones entre artistas, bandas, integrantes y colaboraciones.
- Portadas locales o buscadas desde la web.
- Inicio editable con widgets activables/desactivables por usuario.

### Red e imports

- Importacion por URL usando herramientas compatibles con `yt-dlp`.
- Importacion por compartir desde otras apps.
- Listenfy Connect: servidor HTTP local para control remoto en la misma red.
- Transferencia P2P offline con QR, WiFi Direct/Bluetooth segun disponibilidad.

### Respaldo

- Exportacion ZIP de biblioteca, metadatos, listas y variantes.
- Restauracion ZIP.
- Opcion para incluir variantes generadas como 8D o instrumental.

Importante: Listenfy guarda la biblioteca dentro del almacenamiento privado de la app. Si desinstalas sin respaldo, puedes perder contenido y metadatos.

## Arquitectura

| Componente | Ubicacion | Funcion |
| --- | --- | --- |
| App Flutter | `lib/` | UI, reproductores, biblioteca local y controladores GetX |
| Datos multimedia | Carpeta privada de la app | Archivos importados y variantes generadas |
| Base local | SQLite/Hive/GetStorage segun modulo | Metadatos, preferencias, historial, listas y relaciones |
| Backend opcional | Repo `Back` externo | Procesos pesados como 8D, Demucs e integraciones futuras |
| Listenfy Connect | Servidor HTTP embebido | Control remoto LAN |
| P2P | Nearby transfer | Transferencia offline con QR |

## Uso rapido

### Primeros pasos

1. Importa musica o video desde archivos locales, URLs o el menu Compartir de Android.
2. Revisa permisos de almacenamiento, notificaciones y bateria para que el player funcione en segundo plano.
3. Crea un respaldo ZIP periodicamente desde Ajustes > Datos y descargas.

### Inicio editable

La pantalla de inicio permite personalizar que secciones aparecen. En Home toca el icono de editar inicio en la barra superior para abrir el editor en una ventana aparte.

Desde ese editor puedes:

- Activar o desactivar Mis favoritos, Para ti hoy, Mas reproducido, Reproducciones recientes, Destacado, Ultimos imports, Por escuchar y Mix aleatorio.
- Reordenar los widgets principales.
- Cambiar entre vista de cards y vista de lista en los widgets compatibles.
- Agregar secciones conjuntas de Artistas y Listas de reproduccion.
- Quitar secciones personalizadas o cambiar su modo de vista.

El editor muestra el modo elegido antes de aplicar los cambios. Toca **Guardar** para confirmar o **Restablecer** para volver al layout por defecto dentro del editor. La configuracion se guarda localmente con `GetStorage`, por lo que se conserva al cerrar y volver a abrir la app. En modo video, los widgets que solo aplican a audio, como **Para ti hoy**, se ocultan automaticamente.

### Organizar musica para Atlas

Edita un artista y define:

- Region principal.
- Pais, si aplica.
- Tipo: solista, banda u otro.
- Integrantes o relaciones.

Atlas depende de esos metadatos. Si no etiquetas artistas o regiones, la vista no puede organizar automaticamente la biblioteca.

### Colaboraciones

Para que una colaboracion se detecte bien, usa el campo Artista con patrones como:

```text
Artista principal ft. Invitado1, Invitado2 & Invitado3
```

Tambien se aceptan variantes como `feat.`, `featuring` o `with`. Separar invitados con coma, `&` o `x` ayuda a que la app relacione mejor los artistas.

### Sonido limpio

Sonido limpio recorta silencios largos. La funcion detecta silencios mayores a varios segundos y permite seleccionar cuales procesar. El resultado puede ocupar mas espacio, especialmente si se guarda como WAV.

### Modo 8D e instrumental

Estas funciones requieren el backend externo. La app envia el archivo al backend, espera el procesamiento y guarda una variante independiente. Una vez guardada, esa variante puede usarse offline.

### Sources

Sources organiza videos por Collections:

1. Crea una Collection.
2. Entra en la Collection y crea Collections hijas si necesitas mas niveles.
3. Agrega videos a cada vista.
4. Usa buscador y orden para navegar bibliotecas grandes.

### Listenfy Connect

Desde el reproductor puedes abrir Listenfy Connect y compartir una URL o QR. Otro dispositivo en la misma red puede controlar la sesion local desde el navegador.

### Respaldo y migracion

El respaldo ZIP incluye biblioteca, metadatos, listas, portadas y variantes si marcas esa opcion. En bibliotecas grandes puede tardar bastante. Restaurar suele ser mas rapido que exportar.

## Limitaciones conocidas


### Rendimiento

- Bibliotecas de mas de 400-500 items pueden hacer mas lenta la UI si una vista carga demasiados elementos de golpe.
- Exportar ZIP con muchos archivos puede tardar mucho porque procesa una biblioteca completa.


### Documentacion

- Algunas funciones avanzadas aun necesitan textos dentro de la app.
- Los tiempos reales de 8D, instrumental y respaldo dependen del dispositivo, archivo y backend.

## Roadmap sugerido

### Corto plazo

- Mejorar editor de video para ocultar opciones solo de audio.
- Ampliar el inicio editable con tamanos de widgets.
- Optimizar respaldo ZIP con modo almacenamiento sin compresion o procesamiento por lotes.
- Virtualizar vistas grandes para mejorar rendimiento con bibliotecas grandes.
- Mejorar historial de imports con vista por fecha/calendario.

### Medio plazo

- Documentar todas las funciones desde Ajustes > Guia rapida.
- Mejorar recomendaciones locales y base de Listenfy Atlas.
- Hacer mas consistente la UI entre Sources, artistas, imports y playlists.

### Largo plazo

- Extraer audio de video a MP3.
- Sincronizacion automatica de letras con API opcional.
- Modo offline ligero para efectos de audio sin backend.
- Cliente de escritorio compatible con el formato de respaldo ZIP.

## Desarrollo

### Requisitos

- Flutter SDK compatible con el proyecto.
- Android Studio y SDK de Android.
- Backend externo opcional para 8D, instrumental y procesos pesados.

### Comandos basicos

```bash
flutter pub get
flutter analyze
flutter build apk --debug
```

## Licencia

MIT. Ver [LICENSE](./LICENSE).

## Creditos

- Desarrollo: varasjona-24.
- Auditoria comunitaria: usuario avanzado de Listenfy, mayo 2026.

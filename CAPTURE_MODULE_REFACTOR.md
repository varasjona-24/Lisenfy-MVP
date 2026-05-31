# Refactor del modulo de capturas siguiendo la arquitectura de Sources

Este documento reemplaza la idea de usar BLoC para capturas. El modulo debe seguir el estilo real que ya usa `lib/Modules/sources`: GetX como controller/binding del modulo, carpetas separadas por responsabilidad y widgets reutilizables en `ui/`.

La meta no es introducir otra arquitectura paralela, sino ordenar capturas con el mismo lenguaje del proyecto.

## Arquitectura de referencia: Sources

`sources` esta organizado asi:

```text
lib/Modules/sources/
  binding/
    sources_binding.dart
  controller/
    sources_controller.dart
    source_theme_topic_playlist_controller.dart
    source_theme_topic_playlist_logic.dart
  data/
    source_theme_pill_store.dart
    source_theme_topic_store.dart
    source_theme_topic_playlist_store.dart
  domain/
    source_origin.dart
    source_theme.dart
    source_theme_topic.dart
    source_theme_topic_playlist.dart
  ui/
    source_add_items_sheet.dart
    source_collection_card.dart
    source_collection_grid.dart
    source_filter_toolbar.dart
    source_playlist_card.dart
  view/
    sources_page.dart
    source_library_page.dart
    source_theme_topic_page.dart
    source_theme_topic_playlist_page.dart
```

El modulo de capturas debe copiar esa idea:

- `binding/`: registra dependencias con GetX.
- `controller/`: estado y acciones del modulo.
- `data/`: persistencia local, lectura de archivos, tags y adaptadores a stores existentes.
- `domain/`: entidades, enums y modelos puros del modulo.
- `services/`: operaciones de aplicacion que coordinan integraciones externas sin ensuciar el controller.
- `ui/`: widgets, sheets, dialogs y cards reutilizables.
- `view/`: paginas completas.

## Estructura objetivo para Captures

```text
lib/Modules/captures/
  binding/
    capture_gallery_binding.dart

  controller/
    capture_gallery_controller.dart
    capture_gallery_logic.dart
    capture_gallery_selection_controller.dart
    capture_gallery_cover_controller.dart

  data/
    capture_gallery_store.dart

  domain/
    capture_item.dart
    capture_cover_target.dart
    capture_gallery_sort.dart

  services/
    capture_cover_service.dart
    capture_share_service.dart

  ui/
    capture_action_sheet.dart
    capture_cover_target_sheet.dart
    capture_empty_state.dart
    capture_grid.dart
    capture_preview_page.dart
    capture_rename_dialog.dart
    capture_search_bar.dart
    capture_sort_sheet.dart
    capture_tag_dialog.dart
    capture_tile.dart

  view/
    capture_gallery_page.dart
```

## Regla de responsabilidades

### binding/

Debe registrar dependencias y nada mas.

Responsabilidades:

- Registrar `GetStorage` si hace falta.
- Registrar stores y services del modulo.
- Registrar `CaptureGalleryController`.
- No ejecutar logica de negocio.

Ejemplo esperado:

```dart
class CaptureGalleryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<GetStorage>()) {
      Get.put(GetStorage(), permanent: true);
    }
    Get.lazyPut(() => CaptureGalleryStore(Get.find<GetStorage>()));
    Get.lazyPut(() => CaptureCoverService());
    Get.lazyPut(() => CaptureShareService());
    Get.put(CaptureGalleryController());
  }
}
```

### controller/

Debe manejar el estado y coordinar acciones. Es el equivalente a `SourcesController`, pero limitado al modulo de capturas.

El controller principal no debe crecer demasiado. Si empieza a mezclar demasiadas responsabilidades, debe dividirse en subsecciones/controles pequenos, siguiendo la idea de `settings`, donde existen controllers separados como `settings_controller.dart`, `playback_settings_controller.dart`, `equalizer_controller.dart`, `sleep_timer_controller.dart` y `backup_restore_controller.dart`.

Para capturas, la division recomendada si el archivo crece es:

- `capture_gallery_controller.dart`: estado general, carga, busqueda y orden.
- `capture_gallery_selection_controller.dart`: seleccion multiple y limite de 20.
- `capture_gallery_cover_controller.dart`: targets y aplicacion de portada.
- `capture_gallery_logic.dart`: funciones puras de filtro, orden y normalizacion.

Responsabilidades:

- Cargar capturas.
- Exponer `RxList<CaptureItem> captures`.
- Exponer busqueda, orden y seleccion.
- Renombrar y eliminar.
- Editar tags.
- Compartir hasta 20 imagenes.
- Cargar targets para usar una captura como portada.
- Aplicar captura como portada de video o collection.
- Mantener la vista libre de logica de negocio.

No debe:

- Construir widgets.
- Mostrar dialogs.
- Depender de `BuildContext`.
- Tener UI dentro de metodos.

### controller/capture_gallery_logic.dart

Archivo para reducir longitud del controller. Debe contener logica pura o casi pura:

- Filtrar por nombre o etiqueta.
- Ordenar por fecha, peso o nombre.
- Normalizar tags.
- Validar limite de seleccion.
- Calcular labels simples de orden.

Esto evita que `capture_gallery_controller.dart` crezca demasiado.

### data/

Debe contener la implementacion concreta de almacenamiento local y persistencia.

`capture_gallery_store.dart`:

- Leer la carpeta `ListenfyCaptures`.
- Guardar bytes de captura.
- Renombrar archivo.
- Eliminar archivo.
- Leer/escribir tags en `GetStorage`.
- Exportar/importar metadata de capturas para backup.

Data no debe construir widgets ni mostrar mensajes. Tampoco debe depender de la page.

### domain/

Debe contener objetos simples del modulo.

`capture_item.dart`:

- `path`
- `name`
- `modifiedAt`
- `size`
- `tags`
- `fromJson`
- `toJson`

`capture_cover_target.dart`:

- `id`
- `label`
- `subtitle`
- `type`
- referencia minima necesaria para aplicar portada

`capture_gallery_sort.dart`:

- enum de orden:
  - `date`
  - `size`
  - `name`

Domain no debe depender de widgets ni pages. Si se necesita icono, la UI decide el icono segun `type`.

### services/

Debe contener operaciones de aplicacion que coordinan stores, plugins o modulos existentes.

Se diferencia de `data/` asi:

- `data/` guarda y lee informacion.
- `services/` ejecuta acciones de aplicacion con esa informacion.
- `controller/` llama services/stores y expone estado.
- `ui/` solo renderiza.

`capture_cover_service.dart`:

- Leer videos desde `LocalLibraryStore`.
- Leer topics y playlists desde `SourcesController` o stores de sources.
- Construir targets para seleccionar portada.
- Aplicar `thumbnailLocalPath` a videos.
- Aplicar `coverLocalPath` a collections.

`capture_share_service.dart`:

- Encapsular `share_plus`.
- Preparar `XFile`.
- Compartir maximo 20 imagenes.
- No decidir UI ni mostrar mensajes.

### ui/

Widgets reutilizables, sin acceso directo a stores.

Debe contener:

- `CaptureTile`
- `CaptureGrid`
- `CaptureSearchBar`
- `CaptureSortSheet`
- `CaptureActionSheet`
- `CaptureTagDialog`
- `CaptureRenameDialog`
- `CaptureCoverTargetSheet`
- `CaptureEmptyState`
- `CapturePreviewPage`

Estos widgets reciben datos y callbacks desde la page/controller.

### view/

La page debe ser delgada.

Responsabilidades:

- Resolver controller con `Get.find<CaptureGalleryController>()`.
- Usar `Obx` para renderizar estado del controller.
- Abrir dialogs/sheets de UI.
- Enviar acciones al controller.

No debe:

- Filtrar listas.
- Ordenar listas.
- Buscar targets.
- Llamar `share_plus`.
- Llamar `LocalLibraryStore`.
- Llamar `SourcesController`.
- Manipular archivos directamente.

## Comportamiento que debe conservarse

El refactor debe mantener:

- Galeria local de capturas.
- Busqueda por nombre.
- Busqueda por etiqueta.
- Edicion de etiquetas por captura.
- Seleccion multiple.
- Limite de 20 imagenes al compartir.
- Compartir por hoja del sistema, incluyendo Bluetooth si el sistema lo ofrece.
- Renombrar capturas.
- Eliminar capturas.
- Usar captura como portada de video.
- Usar captura como portada de collection o subcollection.
- Guardar tags en backup zip.
- Restaurar tags desde backup zip.

## Estado actual del modulo de capturas

Actualmente hay una separacion inicial:

```text
lib/Modules/captures/
  binding/
  controller/
  domain/
  services/
  view/
```

Pero para alinearlo con `sources`, hay que corregir:

- Mantener `services/`, pero dejar ahi solo acciones de aplicacion como compartir y aplicar portada.
- Crear `data/` para persistencia local de capturas y tags.
- Mover `CaptureGalleryService` desde `lib/app/services/` al modulo de capturas.
- Crear `ui/` para sacar widgets privados de `capture_gallery_page.dart`.
- Reducir `capture_gallery_page.dart`.
- Dividir el controller si crece demasiado, usando archivos por responsabilidad como en `settings`.
- Evitar que `domain` tenga dependencias de Flutter como `IconData`.

## Plan de migracion recomendado

1. Crear `data/` y `ui/` en `lib/Modules/captures`.
2. Mover `CaptureGalleryService` a `data/capture_gallery_store.dart`.
3. Renombrar `ListenfyCapture` a `CaptureItem` y moverlo a `domain/capture_item.dart`.
4. Crear `domain/capture_cover_target.dart` sin `IconData`.
5. Crear `domain/capture_gallery_sort.dart`.
6. Mantener share externo en `services/capture_share_service.dart`, sin UI ni mensajes.
7. Mantener targets de portada en `services/capture_cover_service.dart`, usando stores existentes.
8. Mantener `CaptureGalleryController` como unico estado GetX del modulo.
9. Extraer filtro/orden/tags a `controller/capture_gallery_logic.dart`.
10. Si el controller queda extenso, separar seleccion y portadas en controllers auxiliares.
11. Extraer widgets privados de la page a `ui/`.
12. Dejar `capture_gallery_page.dart` solo como composicion de UI y conexion con controller.
13. Actualizar imports de backup/restore para usar el nuevo store/model.
14. Actualizar `app_pages.dart` para mantener `CaptureGalleryBinding`.
15. Correr `dart format`.
16. Correr `flutter analyze` y validar que no haya errores nuevos.

## Criterios de calidad

- Mismo comportamiento visible.
- Menos codigo en la page.
- Controller legible y con responsabilidades claras.
- Controller principal corto; si crece, dividir en controllers auxiliares por responsabilidad.
- Data aislando plugins y almacenamiento.
- Domain sin Flutter.
- UI reutilizable.
- GetX usado igual que en `sources`: binding, controller y reactividad del modulo.
- Sin BLoC, sin `flutter_bloc`, sin arquitectura paralela.

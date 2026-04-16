# Reutilizacion de widgets

## Objetivo

La interfaz de Listenfy debe construirse con widgets reutilizables siempre que sea razonable. La meta es evitar que cada pantalla resuelva el mismo problema visual o de interaccion de una forma distinta.

Un widget reutilizable permite:

- Mantener una experiencia visual consistente entre modulos.
- Reducir duplicacion de codigo.
- Corregir bugs una sola vez y que el arreglo impacte todas las pantallas que usan ese componente.
- Evolucionar la UI sin reescribir cada modulo.
- Mantener separada la logica de negocio de la presentacion.

## Regla principal

Antes de crear un widget nuevo, revisar si ya existe un widget equivalente en:

- `lib/app/ui/widgets/`
- `lib/Modules/<modulo>/ui/`
- `lib/Modules/<modulo>/presentation/widgets/`
- `lib/Modules/<modulo>/view/widgets/`

Si el comportamiento o layout se repite en mas de una pantalla, debe convertirse en widget reutilizable.

## Ubicacion de widgets

### Widgets usados por una sola pantalla

Si un widget solo se usa en una pantalla especifica, debe vivir dentro del modulo correspondiente, en una subcarpeta llamada `ui`.

Ejemplo:

```text
lib/Modules/artists/ui/artist_song_grid_tile.dart
lib/Modules/playlists/ui/playlist_track_tile.dart
lib/Modules/sources/ui/source_library_grid_tile.dart
```

Tambien es valido mantener widgets privados dentro del mismo archivo de la vista cuando son pequenos y no tienen valor fuera de esa pantalla. Si crecen o empiezan a repetirse, deben moverse a `ui`.

### Widgets usados por varias pantallas del mismo modulo

Si un widget se reutiliza entre varias pantallas de un mismo modulo, debe vivir en:

```text
lib/Modules/<modulo>/ui/
```

Ejemplo:

```text
lib/Modules/downloads/ui/download_media_grid.dart
lib/Modules/artists/ui/artist_avatar.dart
```

### Widgets usados por varios modulos

Si un widget se usa en mas de un modulo, debe vivir en la carpeta global de widgets bajo su clasificacion correspondiente:

```text
lib/app/ui/widgets/<categoria>/
```

Ejemplos:

```text
lib/app/ui/widgets/media/media_thumb.dart
lib/app/ui/widgets/media/media_history_group_section.dart
lib/app/ui/widgets/list/media_horizontal_list.dart
lib/app/ui/widgets/navigation/app_top_bar.dart
lib/app/ui/widgets/cards/empty_state.dart
```

## Clasificacion sugerida para widgets globales

Usar una carpeta segun el rol del widget:

- `branding`: logos, marca, elementos visuales de identidad.
- `cards`: tarjetas reutilizables.
- `dialogs`: dialogos y bottom sheets compartidos.
- `layout`: fondos, scaffolds, containers estructurales.
- `list`: listas horizontales, verticales o secciones genericas.
- `media`: thumbnails, tiles, grids y componentes relacionados con `MediaItem`.
- `navigation`: barras superiores, bottom nav, acciones de navegacion.

Si no existe una categoria adecuada, crear una nueva solo si el widget realmente sera compartido.

## Criterios para decidir si un widget debe ser reutilizable

Convertir a widget reutilizable cuando:

- Aparece en dos o mas pantallas.
- Tiene reglas de interaccion compartidas.
- Renderiza el mismo tipo de entidad, por ejemplo `MediaItem`, artista, playlist o source.
- Tiene variantes visuales pequenas que pueden resolverse con parametros.
- Depende de callbacks externos en lugar de controlar directamente la navegacion o estado.

Mantenerlo local cuando:

- Solo existe para una pantalla.
- Depende fuertemente del layout especifico de esa pantalla.
- Es muy pequeno y no aporta claridad moverlo.
- Su reutilizacion obligaria a crear parametros artificiales o complejos.

## Reglas de diseno para widgets reutilizables

Un widget reutilizable debe:

- Recibir datos ya preparados.
- Exponer callbacks como `onTap`, `onLongPress`, `onMore`, `onSelected`.
- Evitar llamar directamente a `Get.toNamed`, repositorios o controllers, salvo que sea un widget de navegacion global.
- Tener nombres claros y orientados al dominio visual.
- Mantener configuracion por parametros simples.
- Evitar duplicar logica de seleccion, eliminacion, reproduccion o filtrado.

Ejemplo correcto:

```dart
MediaGridTile(
  item: item,
  selected: selectedIds.contains(item.id),
  onTap: () => onItemTap(item),
  onMore: () => onItemActions(item),
)
```

Ejemplo a evitar:

```dart
MediaGridTile(
  item: item,
)
// Internamente busca controllers, abre rutas y elimina archivos.
```

## Regla para grids y listas de media

Las pantallas que muestran `MediaItem` deben reutilizar widgets comunes siempre que sea posible.

Casos esperados:

- Biblioteca de canciones.
- Secciones de Home.
- Historial.
- Historial de imports.
- Detalle de artista.
- Detalle de playlist.
- Sources/bibliotecas.

Las pantallas de queue pueden tener widgets propios si requieren comportamiento especial como reorder, estado activo de reproduccion o sincronizacion con el player.

## Regla para seleccion multiple

La seleccion multiple debe centralizarse. Si varias pantallas permiten seleccionar y eliminar items, no deben implementar su propio modo de seleccion desde cero.

El flujo recomendado es reutilizar una pantalla/widget comun de seleccion, con callbacks externos para:

- Tap de item.
- Long press.
- Eliminar seleccionados.
- Item inicial seleccionado.
- Modo inicial de seleccion.

Esto evita inconsistencias entre Home, imports, historial, artistas, playlists y sources.

## Checklist antes de agregar un widget

Antes de crear un widget nuevo:

- Buscar si ya existe un componente similar.
- Definir si sera local de modulo o global.
- Evitar acoplarlo a controllers si puede recibir callbacks.
- Confirmar que el nombre describe su rol visual.
- Confirmar que no duplica estilos o interacciones existentes.
- Si se reutiliza en dos pantallas, moverlo fuera del archivo de la vista.

## Decision por defecto

Si hay duda razonable entre duplicar y reutilizar, preferir reutilizar.

La excepcion es cuando abstraer demasiado haga el widget mas dificil de entender que duplicar una pequena pieza local. En ese caso, mantenerlo local, pero documentar implicitamente la decision con nombres claros y codigo simple.

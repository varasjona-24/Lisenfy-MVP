# Architecture Audit & Migration Plan

## 1. Executive Summary

Listenfy tiene una arquitectura Flutter/GetX funcional y modular, pero híbrida: combina composición global en `main.dart`, bindings por ruta, controllers reactivos, stores con `GetStorage`, servicios técnicos y algunos módulos con separación domain/data/application. El proyecto contiene aproximadamente 282 archivos Dart en `lib/` (213 dentro de `lib/Modules`).

La arquitectura actual es suficientemente buena para continuar desarrollando. No se justifica una reescritura ni una migración profunda. La decisión recomendada es **B. Refactor arquitectónico parcial**, enfocado en cuatro problemas reales: registros duplicados de GetX, lifecycle demasiado permanente, dependencias ocultas entre features y archivos con responsabilidades excesivas.

Fortalezas principales: feature-first, rutas centralizadas, bindings, servicios multimedia separados, módulos de recomendaciones/history/downloads/world mode con buena separación, y tests de reglas importantes. Deuda principal: DI distribuida, `Get.find` abundante, dependencia de varias features en `HomeController`, settings/backup demasiado transversal y cobertura insuficiente de lifecycle.

## 2. Current Architecture

El flujo más común es:

```text
GetPage → Binding → GetX Controller/Service → UseCase/Repository/Store/Service
       → Dio/GetStorage/filesystem/plugins de audio, vídeo o plataforma
```

También existen accesos directos:

```text
View → Get.find<Controller>()
Controller → Get.find<Service/Repository/Controller>()
Controller → GetStorage()
```

`lib/main.dart` actúa como composition root parcial: registra tema, navegación, notificaciones, audio/video, storage, stores, recomendaciones, downloads y deep links. Los bindings vuelven a registrar dependencias específicas y, en varios casos, infraestructura global como fallback.

La evolución propuesta conserva ese rol, pero separa responsabilidades: el **bootstrap** hace únicamente inicialización previa a `runApp` que requiera `await` o configuración de plataforma; un **AppBinding** registra exclusivamente las dependencias GetX cuyo lifecycle pertenece a toda la aplicación; y cada **Feature Binding** registra dependencias de su feature o ruta. `main.dart` no debe convertirse en un contenedor gigante de DI.

La aplicación no sigue Clean Architecture estricta. Es una arquitectura feature-first híbrida, con capas más completas en `recommendations`, `downloads`, `history`, `stats` y `world_mode`, y flujos más directos en Home, Player, Settings, Edit y Nearby Transfer.

## 3. Module Map

| Módulo | Responsabilidad real |
|---|---|
| `Home` | Home, secciones, búsqueda, layout y coordinación de recomendaciones |
| `player/audio` | Playback, cola, controles, portada y widgets del reproductor |
| `player/Video` | Playback de vídeo, cola, letras y preferencias relacionadas |
| `sources` | Fuentes locales, temas, topics y playlists de fuentes |
| `downloads` | Descargas, historial de imports, estados, repository/use cases y UI |
| `history` | Carga y presentación del historial mediante repository/use case |
| `stats` | Estadísticas, entidades, resumen semanal y dashboard |
| `artists` / `playlists` | Stores, controllers y vistas de colecciones/detalle |
| `captures` | Galería, tags, store, portadas y compartir |
| `settings` | Configuración, playback, sleep timer, EQ, notificaciones y backup/restore |
| `local_connect` | Servidor HTTP/WebSocket local, pairing, sincronización y web UI |
| `nearby_transfer` | Discovery, advertising, peers, transferencias y QR |
| `recommendations` | Stores, feedback, rankers y casos de uso de recomendaciones |
| `world_mode` | Datasource, repository, afinidad, radio planner y playback facade |
| `app/` | Servicios, red, storage, modelos, controllers globales y widgets comunes |

## 4. Dependency Flow

La dirección razonable aparece en:

```text
View → Controller → UseCase/Application → Repository contract
     → Repository implementation/Store → Storage/API/plugin
```

Evidencia: `downloads/domain` con `downloads/data/repositories`, `history/domain` con `history/data/repositories`, `world_mode/domain` con datasource/repository y `recommendations/domain` con `application` y stores.

Pero también existe:

```text
View → Get.find<HomeController>()
Controller → Get.find<MediaRepository>()
Service → Get.find<AudioService>()
```

Esto no es incorrecto por sí mismo en GetX, pero oculta dependencias y dificulta pruebas y lifecycle.

## 5. GetX Usage Analysis

### Correcto

- `GetPage` y bindings están centralizados en `lib/app/routes/app_pages.dart`.
- `GetView<T>` se usa en varias páginas de feature.
- `Obx` cubre de forma consistente player, downloads, sources, artists, settings, history, stats, world mode y local connect.
- `LocalConnectServerService` usa `GetxService` para una capacidad de larga vida.
- `LocalConnectServerService.onClose()` libera su `Worker` y detiene el servidor.
- `Get.lazyPut` y `fenix` se usan en varias dependencias recreables.

### Problemas reales

#### Registro duplicado de Settings — crítico

`lib/main.dart:85-89` registra permanentemente `SettingsController`, `PlaybackSettingsController`, `SleepTimerController`, `EqualizerController` y `NotificationSettingsController`. Después `lib/Modules/settings/binding/settings_binding.dart:56-75` vuelve a registrar varios con `Get.lazyPut(..., fenix: true)`.

Debe existir un único owner del registro. La duplicación puede producir instancias, estado o lifecycle inconsistentes.

#### `permanent` excesivo — alto

`lib/Modules/player/audio/binding/audio_player_binding.dart:12-15` registra `AudioPlayerController` como permanente aunque pertenece a una ruta. También hay permanencia en bindings de downloads, world mode y edit.

Audio/video service, storage, notificaciones y servicios background sí pueden ser globales. Controllers de pantalla no deben ser permanentes por defecto. El **playback engine** (`AudioService` o `VideoService`) no es el mismo objeto que un controller de presentación: el engine puede sobrevivir a una pantalla para mantener cola, sesión multimedia y background playback; el controller coordina botones, UI y estado específico de la ruta. La misma separación debe aplicarse a vídeo antes de modificar su lifecycle.

#### Service locator oculto — medio/alto

Ejemplos concretos: `lib/Modules/settings/controller/notification_settings_controller.dart:9`, `artists/controller/artists_controller.dart:58-60`, `local_connect/controller/local_connect_controller.dart:9` y varias views que hacen `Get.find`.

Las dependencias esenciales deberían pasar por constructor en controllers, services y repositories. No hace falta eliminar todos los `Get.find`, especialmente en UI interna. La regla operativa es: cada dependencia GetX tiene un único owner de registro y debe poder responderse quién la registra, dónde, cuándo, cuánto vive, quién la elimina y si puede recrearse.

#### Domain contaminado — medio

`lib/Modules/stats/domain/entities/listening_stats_entities.dart` importa Flutter. `lib/Modules/Home/domain/home_layout_models.dart` también usa tipos Flutter. Si son conceptos de UI, deben vivir en presentación; si son dominio, deben usar tipos Dart puros.

#### Workers y lifecycle

Local Connect está bien resuelto. Audio, video, nearby transfer, downloads y sleep timer requieren verificar streams, timers, workers y subscriptions en `onClose`.

### Política de lifecycle propuesta

| Tipo | Ejemplos | Registro/lifecycle recomendado |
|---|---|---|
| Application lifetime | `AudioService`, `VideoService`, `NotificationService`, storage y servicios de background | `AppBinding`; pueden justificar `permanent: true` si deben vivir durante toda la ejecución |
| Feature lifetime | `SettingsController`, `HistoryController`, `ArtistsController`, `AudioPlayerController` y controllers de ruta | Feature Binding; no `permanent` por defecto; se eliminan al abandonar la feature salvo razón funcional documentada |
| Recreatable | Repositorios, stores o colaboradoras sin estado de sesión que puedan reconstruirse | `Get.lazyPut(..., fenix: true)` solo cuando la recreación sea necesaria y segura |

No es una regla dogmática: una excepción requiere justificar qué comportamiento necesita sobrevivir, qué owner lo controla y cómo se valida su cierre o recreación.

## 6. Module-by-Module Analysis

| Módulo | Evaluación | Recomendación |
|---|---|---|
| Home | Funcional, pero controller/view grandes | Separar layout, carga y coordinación gradualmente |
| Audio player | Servicio global correcto; controller permanente discutible | Mantener servicio global y revisar lifecycle del controller |
| Video player | Mezcla reproducción, storage y UI | Extraer preferencias/cola fuera de la vista |
| Sources | Cohesión razonable | Mantener estructura; mejorar contratos solo si aparecen implementaciones múltiples |
| Downloads | Mejor separación interna | Mantener y reducir dependencia de Home |
| History | Repository/use case/controller claros | Eliminar dependencia directa de Home |
| Artists/Playlists | Funcionales, stores persistentes | Extraer capacidades compartidas en vez de usar controllers de Home |
| Captures | Relativamente aislado | Mantener; inyectar store progresivamente |
| Settings | Muy transversal; backup enorme | Separar export/import/coordinación |
| Local Connect | Separación parcial buena; servicio grande | Dividir servidor, pairing, streams y notificación |
| Nearby Transfer | Controller de 1519 líneas | Separar discovery, peers, transfer y estado |
| Recommendations | Mejor ejemplo de capas | Mantener sin añadir boilerplate |
| World Mode | Domain/data/application razonables | Revisar permanencia del binding |
| Stats | Estructura adecuada | Retirar Flutter del dominio |
| Edit | View de 4021 líneas y controller grande | Dividir por flujos de edición reales |

## 7. Reusability Analysis

`MediaItem`, `MediaRepository`, stores de biblioteca, `MediaActionsController` y servicios de audio/video ya son conceptos compartidos. No conviene crear todavía un módulo `media` grande solo para mover archivos.

La persistencia común está dispersa entre `GetStorage()` directo, stores y `LocalLibraryStore`. Además, downloads, history y artists reutilizan `HomeController`, lo que es reutilización del estado equivocado: deberían consumir una capability de biblioteca, selección o acciones de media.

Una **capability** no es una capa ni una interfaz obligatoria. Es una responsabilidad que varias features necesitan sin depender de Home, por ejemplo `MediaLibrary`, `MediaActions`, `MediaSelection`, `PlaybackAccess`, `Favorites` o `LibraryRefresh`. Su forma debe elegirse por la responsabilidad existente: service, repository, store, facade o clase de aplicación. No se deben crear use cases o interfaces de una línea solo para cumplir un patrón.

Los widgets globales de `lib/app/ui/widgets` son una buena base. `cover_art.dart`, `turntable_needle.dart`, `mini_player_bar.dart` y algunos widgets de player podrían recibir datos/callbacks por constructor si se necesitan fuera del player. Los widgets internos de una feature pueden seguir usando GetX.

## 8. Coupling & Dependency Problems

| Severidad | Evidencia | Problema | Impacto |
|---|---|---|---|
| Crítico | `main.dart:85-89` + `settings_binding.dart:56-75` | Doble registro de settings | Instancias y estados inconsistentes |
| Alto | `audio_player_binding.dart:12-15` | Controller de ruta permanente | Retención y lifecycle incorrecto |
| Alto | `settings/controller/backup_restore_controller.dart` | Coordina storage, stores y muchas features | Cambios y tests de alto riesgo |
| Alto | `nearby_transfer/controller/nearby_transfer_controller.dart` | Discovery, peers, transferencia y UI en una clase | Baja cohesión |
| Medio | `downloads`, `history`, `artists` → `HomeController` | Dependencia feature → feature | Home se vuelve servicio global implícito |
| Medio | `player/Video/view/video_player_page.dart` → captures store | UI de player acoplada a persistencia de captures | Límites menos claros |
| Medio | Bindings crean infraestructura global como fallback | Composición distribuida | Orden difícil de razonar |
| Bajo | `view`, `presentation`, `ui`, `Controller` mezclados | Convenciones inconsistentes | Mayor coste de navegación |

No se encontró evidencia suficiente de un ciclo de imports directo completo. Sí existe acoplamiento transversal alrededor de Home, media, storage y settings.

## 9. State Management Analysis

El estado se crea en controllers/services como `Rx`, se persiste en stores/GetStorage y se observa mediante `Obx`.

Estado global justificado: playback, tema, navegación, notificaciones, storage, downloads activos y Local Connect activo.

Estado probablemente demasiado global: controllers de settings registrados permanentemente y controllers de pantalla registrados como permanentes desde bindings.

La configuración tiene riesgo de múltiples fuentes de verdad: Rx de controllers, valores de `GetStorage` y servicios que vuelven a sincronizar. Cada propiedad debe tener un owner claro. La dirección deseable es `source of truth → controller/selector/computed → UI`; un controller puede reflejar o derivar estado, pero no debe crear otra fuente independiente si el service o store ya es owner. En contraste, `LocalConnectController` delega el estado al service sin duplicar los Rx; ese patrón es preferible.

## 10. Services / Repositories / Use Cases

Para este proyecto:

- **Service**: capability técnica, plugin, proceso de larga vida o infraestructura (`AudioService`, `VideoService`, `NotificationService`).
- **Repository**: abstracción para obtener/persistir información (`HistoryRepository`, `DownloadsRepository`, `WorldModeRepository`).
- **Store**: persistencia local concreta de una colección/agregado (`ArtistStore`, `PlaylistStore`, `RecommendationStore`).
- **Use case**: acción de negocio con reglas, múltiples pasos o valor de test independiente.
- **Controller**: estado de presentación y coordinación de UI.

Las mezclas más importantes están en `BackupRestoreController`, `HomeController`, `AudioService` y `LocalConnectServerService`. No se deben extraer capas por método: operaciones técnicas simples pueden usar directamente un service, repository o capability. Una interfaz se justifica por una frontera de capas, infraestructura intercambiable, múltiples implementaciones, necesidad de test o variación razonable; una implementación única sin beneficio concreto no exige abstracción.

## 11. UI & Widget Architecture

La aplicación usa `Obx` de forma consistente. El problema no es el mecanismo reactivo sino el acoplamiento de algunos widgets al service locator:

- `lib/Modules/player/audio/widgets/cover_art.dart` obtiene `AudioPlayerController`;
- `lib/Modules/player/audio/widgets/turntable_needle.dart` obtiene `AudioPlayerController`;
- `lib/app/ui/widgets/player/mini_player_bar.dart` obtiene controllers globales;
- varias vistas de artists/downloads/settings obtienen controllers directamente.

Desacoplar solo widgets que se reutilicen o que se quieran probar aisladamente. No hace falta hacer toda la UI independiente de GetX.

## 12. Technical Debt

| Área | Problema | Severidad | Impacto | Recomendación |
|---|---|---|---|---|
| DI | Settings registrado en dos lugares | Crítica | Estado duplicado | Un único owner |
| DI | Muchos `permanent` en bindings | Alta | Memoria/lifecycle | Revisar cada caso |
| Acoplamiento | Features dependen de Home | Alta | Cambios propagados | Extraer capability compartida |
| Tamaño | `backup_restore_controller.dart` 2822 líneas | Alta | Tests/cambios peligrosos | Separar export, import y coordinación |
| Tamaño | `nearby_transfer_controller.dart` 1519 líneas | Alta | Estado/transporte mezclados | Separar discovery y transfer |
| Tamaño | `edit_entity_page.dart` 4021 líneas | Alta | UI difícil de mantener | Dividir por flujo |
| Tamaño | `home_page.dart` 3416 líneas | Alta | Alto coste visual | Extraer secciones |
| Dominio | Entities importan Flutter | Media | Menor testabilidad | Usar Dart puro |
| Persistencia | `GetStorage()` directo en controllers | Media | Fuentes dispersas | Encapsular configuración |
| Testing | Pocos tests de controller/UI/lifecycle | Alta | Regresiones | Añadir tests antes de DI |

`flutter analyze` reportó 132 issues, principalmente `withOpacity`, `print`, APIs deprecated y nombres. Es deuda de mantenimiento, no motivo de migración arquitectónica.

## 13. What Is Already Good

- Organización por features.
- Rutas centralizadas y bindings.
- Servicios de audio/video separados.
- Separación razonable en recommendations, downloads, history, stats y world mode.
- Local Connect divide pairing, política HTTP y sincronización en piezas.
- Tests para recomendaciones, local connect, stats, world mode y lyrics.
- Widgets comunes bajo `lib/app/ui/widgets`.
- Manejo correcto de worker y cierre en `LocalConnectServerService`.
- No hay evidencia que justifique reescribir la aplicación.

## 14. Architecture Decision

**B. Refactor arquitectónico parcial.**

Mantener la arquitectura feature-first y GetX. Corregir composición DI, lifecycle, acoplamiento a Home y archivos grandes. Una migración profunda aumentaría el riesgo sobre audio, vídeo, background services, almacenamiento y navegación sin beneficio proporcional.

## Architectural Principles

1. Feature-first antes que layer-first global.
2. Un único owner por dependencia GetX.
3. Application lifetime y feature lifetime son distintos.
4. Un servicio global no implica un controller global.
5. Home es una feature, no infraestructura ni un service locator.
6. Extraer capabilities, no carpetas por estética.
7. No crear abstracciones sin beneficio concreto.
8. No dividir archivos únicamente por número de líneas.
9. La UI puede conocer GetX; el dominio y la lógica reutilizable no deberían necesitarlo.
10. Cada dato importante tiene una única fuente de verdad.
11. La arquitectura crece según una necesidad real.
12. La simplicidad tiene prioridad sobre la pureza arquitectónica.

## 15. Target Architecture

```text
View/widgets → Feature controller → Use case/application (si existe lógica real)
             → Repository contract/capability → implementation/store/service
             → Dio, GetStorage, filesystem o plugin
```

GetX permanece para presentación, navegación y composición. El dominio no debe depender de GetX, Flutter, Dio ni GetStorage. La composición objetivo es:

```text
main.dart → bootstrap asíncrono/pre-runApp → AppBinding → GetMaterialApp
                                            ↓
                                     Feature Bindings por ruta
```

`AppBinding` es owner de servicios e infraestructura cuyo lifecycle pertenece a toda la aplicación. Los Feature Bindings son owner de controllers y colaboradoras de una ruta. Ninguna feature debe volver a registrar infraestructura global como fallback.

## 16. Proposed Folder Structure

No se recomienda renombrar todo de una vez. La estructura objetivo progresiva conserva `app/` como espacio compartido existente:

```text
lib/
├── app/
│   ├── routes/
│   ├── controllers/       # estado verdaderamente global
│   ├── services/
│   ├── data/
│   ├── models/
│   └── ui/widgets/
├── Modules/               # mantener legado y migrar al tocarlo
│   ├── player/
│   ├── downloads/
│   ├── history/
│   ├── recommendations/
│   ├── settings/
│   └── ...
└── main.dart
```

No crear `core/` en esta migración. Solo podría justificarse más adelante si se define una responsabilidad concreta distinta de `app/`, sus consumidores inter-feature y la razón por la que `app/` ya no resulta suficiente. Hasta entonces, no se realizarán movimientos cosméticos.

## 17. File Migration Map

| Archivo actual | Destino/responsabilidad propuesta | Motivo |
|---|---|---|
| `settings/controller/backup_restore_controller.dart` | Controller delgado + `settings/application/` | Separar presentación de coordinación |
| `settings/controller/backup_restore_controller.dart` | `settings/data/backup/` | Aislar serializers/importers |
| `nearby_transfer/controller/nearby_transfer_controller.dart` | `nearby_transfer/application/` + `state/` | Separar casos de uso y Rx state |
| `Home/Controller/home_controller.dart` | `Home/application/` + `state/` | Separar carga/layout/UI |
| `Home/view/home_page.dart` | `Home/view/sections/` | Dividir por responsabilidad visual |
| `edit/view/edit_entity_page.dart` | `edit/view/flows/` + `widgets/` | Separar creación, edición y metadata |
| `local_connect/service/local_connect_server_service.dart` | `local_connect/data/server/` + coordinador | Separar servidor, pairing y sync |
| `stats/domain/entities/listening_stats_entities.dart` | Domain Dart puro + modelos de presentación | Evitar Flutter en dominio |

Son destinos de responsabilidades, no movimientos obligatorios inmediatos.

## 18. Migration Phases

### Fase 0 — Baseline y protección

Documentar el mapa de registros GetX y lifecycle actual; añadir tests críticos y fijar comportamiento de rutas, persistencia, playback y background.

### Fase 1 — DI global

Resolver registros duplicados y owner único; separar bootstrap de `AppBinding`; clasificar dependencias globales frente a feature dependencies; dejar bindings pequeños.

### Fase 2 — Lifecycle

Revisar `permanent`, `fenix`, `lazyPut`, `put`, `putAsync`, `onClose`, workers, timers, streams y subscriptions. No cambiar todavía arquitectura funcional grande.

### Fase 3 — Desacoplamiento de Home

Extraer capabilities reales y migrar en este orden: History, Downloads, Artists y Playlists. Home deja de ser owner accidental de biblioteca, selección, acciones y refresh transversal.

### Fase 4 — Home

Reevaluar `HomeController` y `home_page.dart` después de retirar sus consumidores externos. Esto evita refactorizar Home, extraer capabilities después y tener que refactorizarlo una segunda vez.

### Fase 5 — Backup / Restore

Separar presentación, coordinación, exportación, importación, serializers y acceso a stores, manteniendo compatibilidad funcional.

### Fase 6 — Nearby Transfer

Separar discovery, advertising, peers, transfer session, protocolo/transporte y presentación/state.

### Fase 7 — Edit

Dividir vista y controller por flujos funcionales reales: creación, edición, metadata, artwork u otros que estén presentes.

### Fase 8 — Audio / Video

Actuar al final por riesgo operativo. Diferenciar engine global, controller de presentación, queue, preferences, media session y widgets sin alterar reproducción.

### Fase 9 — Limpieza

Eliminar adaptadores temporales, registros antiguos, fallbacks de bindings, imports cruzados innecesarios y APIs deprecated que puedan cambiarse con seguridad.

## 19. Module Migration Order

1. Baseline y protección.
2. DI global y lifecycle.
3. History.
4. Downloads.
5. Artists.
6. Playlists.
7. Home, una vez desacopladas sus dependencias externas.
8. Backup/Restore.
9. Nearby Transfer.
10. Edit.
11. Audio/video al final, por su riesgo operativo.

Captures, recommendations, stats y buena parte de world mode requieren solo ajustes puntuales.

## 20. Risks

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Dos instancias de un controller global | Alta | Alto | Tests de identidad/registro |
| Romper reproducción por lifecycle | Media | Crítico | Tests queue, background y dispose |
| Perder settings persistidos | Media | Alto | Tests de migración y round-trip |
| Romper rutas/argumentos GetX | Media | Alto | Smoke tests por ruta |
| Cerrar Local Connect prematuramente | Media | Alto | Tests de servidor, sockets y pairing |
| Añadir abstracciones inútiles | Media | Medio | Extraer solo con beneficio testeable |
| Regresión visual | Media | Medio | Widget/golden tests selectivos |

## 21. Testing Strategy

Antes de cambiar DI/lifecycle deben existir tests para:

- audio queue/playback y background;
- video queue/controller recreation;
- settings persistence;
- backup export/import;
- local connect pairing/security;
- download state;
- navegación y bindings.

Usar unit tests para stores, entidades, mappers y serializers; controller tests para estado/coordinación; repository/service tests para infraestructura; widget tests para mini player, controles y estados loading/error/empty; integration tests para startup, navegación, playback y restore.

Los tests existentes en `test/modules/recommendations`, `test/modules/local_connect`, `test/modules/stats`, `test/modules/world_mode` y `test/app/services` son una base válida.

## 22. Quick Wins

- Eliminar el doble registro de los controllers de settings.
- Crear una lista explícita de dependencias globales frente a dependencias de ruta.
- Definir el owner, registro, lifecycle, eliminación y recreación de cada dependencia importante.
- Diseñar `AppBinding` sin mover todavía servicios ni crear `core/`.
- Revisar y justificar cada `permanent: true`.
- Añadir tests de `onClose` para workers/timers.
- Encapsular `GetStorage()` de configuración.
- Evitar nuevas vistas que importen controllers de otra feature.
- Mover tipos Flutter fuera de `stats/domain` y `Home/domain` cuando sean UI.
- Desacoplar `cover_art` y controles genéricos mediante datos/callbacks si se reutilizan.
- Estandarizar nuevos módulos sin renombrar todo el legado.

## 23. Success Criteria

- Cada dependencia global tiene un único registro y owner.
- `main.dart` no funciona como contenedor gigante de DI: bootstrap, `AppBinding` y Feature Bindings tienen límites claros.
- Ninguna feature registra infraestructura global como fallback.
- Controllers de ruta tienen lifecycle verificable.
- Controllers de pantalla no son permanentes sin justificación explícita.
- Audio, video, background y Local Connect conservan comportamiento.
- El playback engine puede sobrevivir independientemente de la pantalla de player.
- Las features no necesitan `HomeController` para capacidades compartidas.
- Home deja de actuar como capability global o service locator.
- `app/` continúa como espacio compartido hasta que exista una razón concreta para crear `core/`.
- El dominio no depende de Flutter/GetX/Dio/GetStorage.
- No se introducen interfaces, use cases ni capas sin beneficio concreto.
- GetX sigue siendo el sistema de estado, navegación y composición principal.
- Controllers grandes delegan responsabilidades testeables.
- Widgets reutilizables no dependen innecesariamente del service locator.
- No aparecen ciclos de imports nuevos.
- Settings, backup, downloads y playback tienen regresiones cubiertas.

## 24. Final Recommendations

1. No reescribir la aplicación ni imponer Clean Architecture estricta.
2. Corregir primero el doble registro de settings y la política de `permanent`.
3. Mantener `main.dart` delgado: bootstrap antes de `runApp`, `AppBinding` para application lifetime y Feature Bindings para lifecycle de ruta.
4. Sustituir gradualmente dependencias a `HomeController` por capabilities.
5. Priorizar backup/restore, nearby transfer, Home, Edit y sus tests.
6. Usar recommendations, stats, captures y world mode como referencias internas, sin copiar capas innecesarias.
7. Tratar audio/video/background como zonas protegidas.
8. Mantener `app/` como espacio compartido; no introducir `core/` sin una frontera y consumidores concretos.
9. Revisar los 132 warnings de `flutter analyze` por separado de la migración.

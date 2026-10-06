# Créditos e integrantes: contrato SQL v6

## Semántica existente preservada

El campo JSON artist corresponde a MediaItem.subtitle. El parser identifica el
principal antes de ft/feat/featuring/with y los invitados posteriores, separados
por coma, & o x. Sin marcador, no se divide el nombre: Judy & Mary puede ser un
grupo. No se infieren nacionalidad, pertenencia o coprotagonismo por texto.

Artistas agrupa una canción bajo cada crédito explícito. Detalle mantiene propias
y colaboraciones separadas. Para grupos, canciones solistas y colaboraciones de
integrantes se muestran en categorías separadas; no se asignan créditos del grupo
a esas canciones ni se expande una canción del grupo a todos sus integrantes.
Un integrante puede estar registrado en varios grupos. No hay fechas históricas
de pertenencia y no se inventan. memberKeys es asociación registrada, no validación
biográfica externa.

## Persistencia y lectura

v5 añade catalog_artist_identity, library_credit_state, library_artist_credit y
artist_membership. FK protegen referencias a identidades y biblioteca. Roles
primary/featured preservan propias/invitados; créditos originales e interpretación
legacy_parsed/ambiguous/empty quedan guardados. Ambiguous conserva atribución legacy,
no adivina roles co_primary. No se ha creado un editor de coprotagonistas.

Las identidades usan IDs estables independientes del nombre. Un
crédito sin perfil crea identidad mínima sin inventar país/región. Perfiles pueden
eliminarse sin borrar créditos ni evidencia de playback. Las identidades antiguas
no se purgan automáticamente. Integrante vacío/unknown, duplicado o self se omite
en la proyección válida; el JSON fuente del perfil conserva el contenido original.

Este bloque materializa relaciones desde los contratos actuales: JSON de créditos
y memberKeys sigue siendo la entrada de edición/importación. Cada replaceCatalog
actualiza la proyección SQL dentro de su transacción. No se permite editar roles
SQL independientes y reconstruirlos luego desde un JSON desactualizado.
CatalogStorage carga roles SQL y memberships; agrupación/detalle usan el resolver
persistido cuando coincide con el crédito original. Legacy y ediciones sin guardar
mantienen el parser. La reconstrucción completa y lecturas completas son transitorias;
las operaciones generales aún reconstruyen la proyección completa. Renombrado y
fusión SQL usan un comando serializado y una transacción multientidad; la caché se
publica después del commit. La ruta legacy conserva su implementación anterior.

## Upgrade y backup

Opener instala v6 preservando versiones anteriores; al abrir CatalogStorage se reconstruyen relaciones
desde el catálogo SQL actual, sin reimportar cambios viejos de GetStorage. Nuevos
backups completos incluyen identidades, créditos, membresías, aliases y redirects.
Restore completo v4 crea relaciones y v5 adapta sus claves a IDs estables; v6
conserva sus IDs. Bundle playback histórico mantiene
su formato. Solo está activo con SQLite debug, no cutover release.

## Identidad, homónimos y edición atómica

artist_name_alias admite varios IDs por nombre: LiSA y LISA pueden permanecer
separadas. Un nombre ambiguo en una importación no asigna un artista al azar;
la pantalla permite elegir una identidad o crear otra. Los créditos previamente
confirmados mantienen sus IDs y procedencia cuando se reconstruye la proyección.
Renombrar a un nombre ya usado ofrece mantener separado o fusionar explícitamente.
No existe fusión automática basada en igualdad del nombre ni en nacionalidad.

La transacción de edición actualiza perfil, créditos originales afectados,
aliases, membresías y referencias de archivos. Una fusión conserva el ID destino,
remapea referencias, elimina duplicados y registra el redirect del ID anterior.
No permite fusionar perfiles de grupo y cantante. No reescribe la evidencia histórica
de playback. Un fallo revierte toda la escritura SQL, sin publicar una caché parcial.
Los pesos del modelo basados en nombres mantienen su contrato anterior; la resolución
de país/región en recomendaciones y Atlas usa los IDs, evitando mezclar homónimos.

La restauración completa toma los perfiles del snapshot SQL, no los superpone
primero mediante una importación por nombre. Los archivos físicos y los ajustes del
ZIP siguen su flujo separado: no se afirma atomicidad global entre disco y SQLite.
El parser de texto conserva principal/invitado y no distingue dos personas con el
mismo nombre literal dentro de un único crédito; no se añade editor de coprincipales.

# Créditos e integrantes: contrato SQL v5

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

Las identidades usan las claves normalizadas existentes, NO UUID nuevos. Un
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
faltan comandos por entidad, IDs independientes de nombre y rename multientidad
atómico. Renombrado existente actualiza canciones/perfiles en varias operaciones.

## Upgrade y backup

Opener instala v5 preservando v4; al abrir CatalogStorage se reconstruyen relaciones
desde el catálogo SQL actual, sin reimportar cambios viejos de GetStorage. Nuevos
backups completos incluyen las cuatro tablas. Restore completo v4 crea relaciones
desde los datos importados; v5 conserva sus filas. Bundle playback histórico mantiene
su formato. Solo está activo con SQLite debug, no cutover release.

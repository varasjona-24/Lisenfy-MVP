# Plan de migración GetX por módulos

## Estado actual
- Base de arquitectura creada en `app/core`.
- Módulo `history` migrado a `data/domain/presentation`.
- Paths legacy de `history` mantenidos con `export` para compatibilidad.

## Orden recomendado
1. `home`
2. `downloads`
3. `artists`
4. `playlists`
5. `sources`
6. `player/audio`
7. `player/video`
8. `nearby_transfer`
9. `settings`
10. `edit`

## Checklist por módulo
- [ ] Crear `domain/contracts`.
- [ ] Mover lógica de negocio a `domain/usecases`.
- [ ] Implementar `data/repositories`.
- [ ] Crear `state` (inmutable + `copyWith`).
- [ ] Refactor de `controller` para depender de `usecases`.
- [ ] Mantener wrapper legacy temporal (`export`) si aplica.
- [ ] Validar rutas/bindings y ciclo de vida en GetX.

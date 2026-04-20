# Arquitectura GetX (sin BLoC)

## Objetivo
Separar cada módulo en `data`, `domain` y `presentation`, usando GetX solo para:
- DI (`Bindings`)
- Navegación (`Get.toNamed`, `Get.offNamed`, etc.)
- Reactividad en UI (`Obx`)

## Estructura por módulo
```text
Modules/<modulo>/
  binding/
  controller/
  data/
    repositories/
  domain/
    contracts/
    entities/
    usecases/
  state/
  presentation/
    views/
    widgets/
```

## Reglas
1. `Controller` depende de `usecases`, no de `Dio`/`GetStorage` directos.
2. `Repository` de `data` implementa un `contract` de `domain`.
3. El estado de pantalla vive en `state/*_state.dart`.
4. `Get.find()` se concentra en `Bindings` y composición de app.
5. Para compatibilidad temporal, los paths antiguos pueden exportar los nuevos.

## Estado base
- `ViewStatus`: `idle`, `loading`, `success`, `failure`.
- `GetxStateController<S>`: controlador base para `Rx<S>`.

## Módulo piloto aplicado
- `history` ya está migrado a esta estructura.

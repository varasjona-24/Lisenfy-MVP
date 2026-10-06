# Prueba integral SQLite en debug

Estado del código: conexión debug implementada; pruebas de repositorio y
consumidores aprobadas. No se ha validado el build Android ni un dispositivo.
La solicitud de compilar el APK debug no fue autorizada, por lo que no se ejecutó.

```sh
flutter run --debug --dart-define=LISTENFY_SQLITE_STAGING_HISTORY=true
```

Usar una copia de prueba de los datos y conservar un respaldo anterior.
El flag está protegido por kDebugMode; release nunca activa este bootstrap.

## Flujo al arrancar

1. Congela GetStorage en playback/debug-migration-<scope>/source.json, mediante
   archivo temporal, flush y rename. Captura antes de crear motores; no borra origen.
2. Abre staging/debug-<scope>.db e importa eventos, baseline y restauración.
   Recibos impiden duplicar o sobrescribir posiciones nuevas tras reabrir.
3. Recupera sesiones interrumpidas solo hasta el último dato confirmado.
4. Escribe verified.json, carga la proyección operativa e inicia motores con SQL.
   Este archivo es una marca debug, NO el manifest de activación de producción.

La consola muestra `SQLite DEBUG: legacy imported, restoration loaded...`.
Si la migración falla, no crea motores ni cambia silenciosamente a otro store.

## Qué probar en dispositivo

- Audio y video: reproducir, pausa/resume, seek adelante/atrás, next/previous,
  fin natural y repetición. Verificar la frontera del92% y que error no sea skip.
- Cola, shuffle, velocidad, crossfade/repeat audio y prompts de reanudación.
- Salir de la ruta video y reabrirla: la política de posición pertenece al servicio.
- Audio en background, notificación, widget y controles externos.
- Cerrar el proceso y reabrir con EL MISMO flag: posición restaurada, historial sin
  duplicados ni tiempo inventado entre el último checkpoint y el nuevo arranque.
- Wrapped, recomendaciones, resumen semanal y collage: SQL, modos separados y
  minutos repartidos por intervalos al cruzar el límite semanal.
- Exportar backup debug y restaurarlo: incluye playback_sqlite_debug.json con
  journal, baseline y estado operativo. Hechos incompatibles hacen rollback SQL.

## Límites explícitos

- Cambiar a release o quitar el flag vuelve al store legacy: NO incorpora lo
  escuchado en debug a GetStorage. Biblioteca/metadatos y preferencias generales
  siguen compartidos; usar copia de prueba para modificaciones y restores.
- Los totales legacy no tienen fechas demostrables: se conservan como baseline,
  no se convierten en sesiones semanales inventadas. Modo ambiguo permanece
  unknown; el collage no lo atribuye automáticamente a audio o video.
- Restore debug acepta backups SQLite debug. Backups legacy se rechazan antes
  de modificar datos; su historial se importa desde GetStorage en el primer
  bootstrap. Restauración cross-device, merge de lineages y activación segura por
  generación siguen siendo gates de producción, no se declaran implementados.
- El importador y backup debug usan memoria por lote completo; no demuestran
  streaming/chunks de grandes bases ni benchmarks de100k/1M eventos.
- Portadas usan locators: todavía no son assets históricos inmutables. Contexto
  de reproducción permanece unknown donde la entrada aún no lo suministra.
- SQLITE_FULL, retries transitorios, discontinuidad de reloj, plugins/background
  reales y durabilidad de rename por plataforma requieren validación adicional.
- No borrar staging ni source.json para “arreglar” una migración: conservar el
  error y los datos para diagnóstico. No hay limpieza destructiva automática.

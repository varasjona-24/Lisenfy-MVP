# Prueba temporal de restauración release

```sh
LISTENFY_RESTORE_SANDBOX=1 flutter build apk --release
```

APK release, firmado con clave debug solo para esta prueba. Paquete:
com.jv24dev.listenfy.restoretest. Nombre: Listenfy Restore Test.
Sin la variable, builds normales mantienen ID, nombre y firma habituales.
Namespace Kotlin no cambia; el provider artwork ya usa applicationId.
Widgets tienen broadcasts explícitos y privados. Datos privados de los dos
paquetes quedan separados; no se desinstala ni se cambia la base original.

Instalar la temporal junto a la original, comprobar su nombre, restaurar el ZIP
desde Ajustes y revisar archivos reproducibles, biblioteca, playlists, relaciones
de artistas, historial, recomendaciones, Atlas y posiciones. Cerrar y reabrir.
El backup debe estar fuera de ambas apps y hay que disponer de espacio para el
ZIP y sus archivos descomprimidos. No mantener dos servidores Connect activos;
deep links listenfy pueden ofrecer selector entre las dos aplicaciones.

Los builds comparten el nombre app-release.apk: verificar su applicationId antes
de instalar; no confundir la temporal con el APK definitivo. Después de validar,
retirar el soporte temporal mediante un cambio aparte y desinstalar únicamente
com.jv24dev.listenfy.restoretest con aprobación. Eso borra sus datos privados,
no los de la app original. No eliminar el ZIP ni desinstalar la app original.

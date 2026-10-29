# Transferencia Android ↔ macOS por red local

Primera versión en `desktop`: el Mac abre la invitación; después ambos
dispositivos pueden enviar archivos de su biblioteca, sin ZIP ni servidor externo.
Wi-Fi Direct entre Android se conserva como un transporte separado.

## Prueba manual

1. Compilar esta rama tanto para Mac como para Android. Una instalación Android
   anterior al modo LAN no puede conectarse a estas invitaciones.
2. Conectar ambos al mismo Wi-Fi o al mismo hotspot. No hace falta Internet.
3. En Mac: Imports → Transferir entre dispositivos → Mostrar QR y código.
4. En Android: Imports → Transferir entre dispositivos. Elegir
   «Red local · Android y Mac» e introducir el código de siete caracteres, o
   escanear el QR del Mac (el QR selecciona LAN automáticamente).
5. Comparar los tres grupos de verificación que aparecen en ambas pantallas.
   Rechazar si difieren. Aceptar en ambas pantallas para asociarse.
6. Desde cualquiera: Enviar archivos → seleccionar → revisar → confirmar.
   Verificar archivos recibidos/enviados y su aparición en la biblioteca.
7. Cerrar conexión explícitamente; al perder el socket también se cierra.

El descubrimiento por código usa broadcast UDP 39474. Algunas redes de invitados
bloquean el tráfico entre clientes; si el broadcast está bloqueado, probar el QR.
Si también se bloquea la conexión directa entre clientes, usar otro Wi-Fi/hotspot.
Permitir red local/firewall en el Mac cuando el sistema lo solicite. TLS usa un
puerto TCP disponible, indicado en la invitación, sin abrir puertos del router.

## Seguridad y recursos

- El anfitrión Mac genera un certificado RSA efímero usando `/usr/bin/openssl`
  del sistema. El cliente verifica su huella SHA-256. No hay claves incluidas
  en el repositorio ni certificados persistentes.
- El código corto solo descubre la invitación. No es la contraseña. La aprobación
  vincula huella, sesión y nonces aleatorios de ambos dispositivos mediante una
  verificación de 48 bits que el usuario debe comparar antes de aceptar.
- No se permiten archivos antes de ambas aprobaciones. Rechazar conserva la
  invitación del Mac hasta su vencimiento de cinco minutos.
- Solo direcciones IPv4 privadas, locales o loopback; no destinos de Internet.
- Tramas acotadas, streaming de archivos con contrapresión, SHA-256 y adjuntos
  originales de portada. Límites: multimedia 1 GiB por archivo/selección,
  portada 64 MiB adicional, encabezado 256 KiB.
- El ACK de éxito se envía después de importar y guardar el historial mediante
  el repositorio SQLite existente. No representa simplemente llegar al 100%.
- Credenciales efímeras no se guardan en el historial. Se limpian archivos
  temporales al cerrar; no se sobrescriben los originales del emisor.
- Sin reanudación de envíos interrumpidos, sin transferencia de biblioteca entera
  ni sincronización completa de estadísticas. Se transfieren archivos y sus
  metadatos como en el flujo Android existente.

## Alcance de la validación

Las pruebas automatizadas usan TLS real y sockets loopback: asociación,
verificación coincidente, pin incorrecto, rechazo/reintento, envío simultáneo,
portada de 3 MiB sin modificación, confirmación y desconexión.
No sustituyen la prueba física Android ↔ Mac ni prueban todos los firewalls,
interfaces VPN o versiones de permisos de red local de macOS.

La app macOS se compila como debug. Queda comprobar desde la app sandboxed el
flujo completo (incluida la creación del certificado) y los diálogos del sistema.
Los avisos de plugins/targets antiguos de Xcode no se consideran corregidos por
esta implementación.

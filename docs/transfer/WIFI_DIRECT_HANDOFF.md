# Transferencia Nearby → Wi-Fi Direct

Estado: implementación integrada y validación automatizada; pendiente de prueba
de extremo a extremo con dos teléfonos físicos compatibles. No se declara
compatibilidad universal ni velocidad garantizada.

## Flujo

1. Imports abre el puente de conexión; nunca activa la cámara automáticamente.
2. El anfitrión genera QR y código alfanumérico de 7 caracteres, válidos 5 minutos.
3. El receptor descubre la invitación mediante Nearby. Ambos usuarios aceptan
   la asociación y comparan el código de autenticación mostrado por Nearby.
4. El canal cifrado de Nearby intercambia oferta, confirmación y orden de traspaso.
   La oferta identifica la sesión completa e incluye credenciales temporales del
   grupo Wi-Fi Direct y huella del certificado TLS. El código corto no autentica.
5. Se detiene Nearby y se establece un grupo propio Wi-Fi Direct. La sesión solo
   se habilita después de comprobar la huella TLS, el secreto y la identidad de
   sesión. No existe envío de archivos por Nearby ni fallback Bluetooth.
6. Ambos dispositivos pueden elegir archivos, confirmar la selección y enviar.
   No se envía nada automáticamente al asociarse. El receptor verifica tamaño y
   SHA-256, importa en la biblioteca y guarda el historial antes de confirmar.
7. El emisor muestra éxito solo tras recibir esa confirmación. Las transferencias
   en curso se marcan fallidas al cerrar o perder la conexión; no hay reanudación
   automática de archivos parciales en esta primera implementación.

## Persistencia y límites

- SQLite: namespace `nearby_transfer_history_v1`, incluido en el backup completo.
  Conserva dirección, sesión, archivo, tamaño, estado y referencia al item recibido.
- Las credenciales y el certificado de sesión no se guardan en ese historial.
- Archivos físicamente en disco; la biblioteca conserva sus referencias SQLite.
- Límite: 1 GiB por selección y por archivo, metadatos acotados a 256 KiB.
  Las portadas locales PNG/JPEG/GIF/WebP viajan como adjuntos binarios originales,
  separados del JSON, con SHA-256 y límite de 64 MiB. No se redimensionan ni
  recomprimen. Una portada ausente, ilegible o fuera de esos límites se omite,
  sin impedir el envío del audio/video. El receptor verifica y copia el adjunto
  a disco; SQLite conserva la ruta. No se transfieren estadísticas de escucha.
  El frame de portada precede a su archivo multimedia y se confirma junto con
  su importación, sin crear una canción o entrada de historial adicional.
  Protocolo de asociación v3/control v2: actualizar ambos dispositivos; no es
  compatible con receptores antiguos que solo admitían portadas Base64.
- La sesión permanece al navegar por la app. Cerrar conexión es explícito;
  la pérdida de Wi-Fi Direct o del socket autenticado la cierra automáticamente.
  La pérdida de Internet por sí sola no la cierra.

## Plataforma y validación física obligatoria

Android 10+ con soporte Wi-Fi Direct, permisos y radios disponibles. Android puede
mostrar confirmaciones adicionales. Se rechazan grupos ya existentes para no
desconectar conexiones ajenas. La asociación y el traspaso pueden variar entre
fabricantes; no se ha validado todavía su funcionamiento real entre dos teléfonos.

Probar QR y código, rechazo sin salir, aceptación en ambos lados, envío en ambas
direcciones y simultáneo, 500 MiB, portadas, cancelación, desconexión, repetición
de sesión, WiFi sin Internet, denegación de permisos y restauración del backup.
Comprobar que no se borran archivos completos al cerrar, no se duplican éxitos ni
se confunden eventos de una sesión anterior. Las versiones anteriores del flujo
Nearby no son compatibles con este protocolo v2.

## Verificación automatizada de esta entrega

### Compatibilidad de la identidad TLS con Android Keystore

En una prueba física el grupo Wi-Fi Direct se creó y el segundo teléfono se
conectó, pero Conscrypt falló durante `startHandshake()` con `Incompatible digest`
y `RSA/ECB/NoPadding`. La clave RSA efímera ahora autoriza `DIGEST_NONE` y
`ENCRYPTION_PADDING_NONE`, necesarios cuando TLS prepara el hash y el padding
antes de solicitar la operación RSA al Keystore. Se conservan las autorizaciones
SHA-256/384/512, las firmas PKCS#1/PSS y la comprobación de la huella del certificado.
Referencia: https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec.Builder

La corrección requiere volver a instalar el APK y repetir el emparejamiento entre
dos teléfonos; compilar no demuestra que el handshake ni la transferencia pasen.

- 42 pruebas aprobadas: protocolo, controlador, selección visual, traducciones,
  persistencia del historial y backup/restauración de dominios SQLite.
- Análisis dirigido de Dart sin incidencias.
- Kotlin ARM64 compilado con `./gradlew :app:compileDebugKotlin --offline
  -Ptarget-platform=android-arm64 -x :app:compileFlutterBuildDebug --console=plain
  --quiet` desde `android`. Esta comprobación no genera ni instala un APK completo.
- Pendiente: radio, permisos, emparejamiento TLS y transferencia efectiva entre
  dos teléfonos. Las pruebas con dobles de transporte no sustituyen esa validación.

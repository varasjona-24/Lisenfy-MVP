import 'package:flutter/material.dart';

class GuideSection extends StatelessWidget {
  const GuideSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topics = _guideTopics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Guía rápida',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: .12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manual de uso',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Puntos clave para cuidar tu biblioteca, organizar contenido y usar funciones avanzadas.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                for (int i = 0; i < topics.length; i++) ...[
                  _GuideTopicTile(topic: topics[i]),
                  if (i != topics.length - 1) ...[
                    const SizedBox(height: 8),
                    Divider(color: theme.dividerColor.withValues(alpha: .12)),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideTopicTile extends StatelessWidget {
  const _GuideTopicTile({required this.topic});

  final _GuideTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(topic.icon),
        title: Text(
          topic.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(topic.subtitle, style: theme.textTheme.bodySmall),
        children: [
          const SizedBox(height: 4),
          for (final tip in topic.tips)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4, bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideTopic {
  const _GuideTopic({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tips,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> tips;
}

const List<_GuideTopic> _guideTopics = [
  _GuideTopic(
    icon: Icons.security_rounded,
    title: 'Biblioteca y respaldo',
    subtitle: 'Donde vive tu contenido y como evitar perdidas.',
    tips: [
      'Listenfy guarda archivos, portadas, listas y metadata dentro del almacenamiento privado de la app.',
      'Antes de desinstalar o limpiar datos, crea un respaldo ZIP desde Datos y descargas.',
      'El respaldo completo puede tardar bastante en bibliotecas grandes porque incluye archivos y metadata.',
      'Si marcas incluir variantes, tambien se guardan versiones como 8D, instrumental o archivos procesados.',
    ],
  ),
  _GuideTopic(
    icon: Icons.headphones_rounded,
    title: 'Musica',
    subtitle: 'Reproduccion, cola y extras de audio.',
    tips: [
      'El player de audio mantiene cola, miniplayer, favoritos, repeticion y reproduccion aleatoria.',
      'Si cierras el miniplayer mientras suena una cancion, Listenfy conserva la cola para continuar despues; si pausas primero y luego lo cierras, esa sesion no se restaura al volver a abrir la app.',
      'En el reproductor completo puedes tocar atras o deslizar hacia abajo para minimizar y volver al miniplayer.',
      'Si notas latencia o un corte breve al cambiar de cancion, pausa primero y luego elige la siguiente pista; ayuda especialmente con colas grandes, archivos pesados o Connect activo.',
      'El crossfade, ecualizador, temporizador de apagado y volumen por defecto viven en Configuracion > Audio.',
      'Sonido limpio detecta silencios largos y permite recortar solo los segmentos que elijas; conserva la metadata principal de la cancion original.',
      'Modo 8D e instrumental requieren el backend externo; cuando terminan, se guardan como variantes reutilizables offline.',
    ],
  ),
  _GuideTopic(
    icon: Icons.dashboard_customize_rounded,
    title: 'Inicio editable',
    subtitle: 'Personaliza que widgets aparecen en la home.',
    tips: [
      'En Home toca el icono de editar inicio en la barra superior para abrir el editor en una ventana aparte.',
      'Puedes activar, desactivar y reordenar Mis favoritos, Para ti hoy, Mas reproducido, Reproducciones recientes, Destacado, Ultimos imports, Por escuchar y Mix aleatorio.',
      'Los widgets compatibles permiten alternar entre vista de cards y lista; el editor muestra el modo elegido antes de guardar.',
      'Tambien puedes agregar secciones conjuntas de Artistas y Listas de reproduccion; cada una conserva su modo de vista.',
      'En las secciones conjuntas de Artistas y Listas de reproduccion, manten presionado un item para quitarlo sin rehacer todo el widget.',
      'Las vistas ampliadas de los widgets muestran el boton de ordenar junto al cambio grid/lista; Inicio se mantiene limpio y solo abre la seccion.',
      'Al mantener presionado un audio o video dentro de un widget editable, Seleccionar varios abre la vista ampliada del modulo con el primer item ya marcado.',
      'En la vista ampliada puedes borrar, compartir por apps externas o enviar por transferencia Listenfy sin salir del flujo del widget.',
      'El orden se guarda por widget: Ultimos imports, Mas reproducido y Reproducciones recientes usan su criterio propio; Favoritos, Destacado y Para ti hoy permiten mas parametros.',
      'Toca Guardar para aplicar los cambios. Restablecer vuelve al layout por defecto dentro del editor.',
      'En modo video se ocultan automaticamente los widgets que solo aplican a audio, como Para ti hoy.',
    ],
  ),
  _GuideTopic(
    icon: Icons.query_stats_rounded,
    title: 'Wrapped y estadisticas',
    subtitle: 'Resumen de escucha, imports y tendencias locales.',
    tips: [
      'Desde Datos y descargas puedes abrir Revisa tus estadisticas para ver tu resumen tipo Wrapped.',
      'Las metricas de musica separan canciones, favoritos, artistas, regiones de Atlas, completadas y saltadas temprano.',
      'Las metricas de imports separan canciones y videos, muestran artistas mas descargados, top de imports, mes fuerte y semana fuerte.',
      'Las regiones dependen de la metadata de pais y region usada por Atlas; mientras mas consistente sea, mejor sera el resumen.',
      'Al exportar y restaurar el ZIP tambien se conserva la metadata que alimenta estas estadisticas.',
    ],
  ),
  _GuideTopic(
    icon: Icons.edit_note_rounded,
    title: 'Artistas y colaboraciones',
    subtitle: 'Metadata necesaria para Atlas y relaciones.',
    tips: [
      'Desde Artistas puedes abrir Listenfly Atlas.',
      'Atlas funciona mejor cuando editas artistas y defines region principal, pais y tipo de artista.',
      'Las portadas de canciones, artistas, playlists y listas tematicas pueden venir de archivo local o busqueda web.',
      'Si una colaboracion debe contarse para varios artistas, escribela en Artista con patrones como ft., feat., featuring o with.',
      'Despues del marcador de colaboracion, separa invitados con coma, x o &: Artista ft. Invitado1, Invitado2 & Invitado3.',
      'Si el titulo sugiere feat o ft pero el campo Artista no lo refleja, al guardar se muestra una advertencia para corregirlo.',
      'En cada pagina de artista puedes ordenar sus canciones por nombre, artista, tiempo añadido, tamaño, reproducciones, duracion o ultima reproduccion.',
    ],
  ),
  _GuideTopic(
    icon: Icons.public_rounded,
    title: 'Atlas',
    subtitle: 'Mapa regional integrado en Artistas.',
    tips: [
      'Abre Atlas desde la tarjeta Listenfly Atlas dentro de Artistas.',
      'Atlas no adivina todo por si solo: depende de la region y pais que tengas en artistas y canciones.',
      'Si cierras el miniplayer, Continuar debe intentar retomar la estacion, cancion y posicion guardadas localmente.',
      'Si se borran datos de la app, cookies o almacenamiento interno, las sesiones guardadas pueden perderse.',
      'Las recomendaciones locales mejoran mientras mas metadata consistente tenga tu biblioteca.',
    ],
  ),
  _GuideTopic(
    icon: Icons.category_rounded,
    title: 'Collections',
    subtitle: 'Collections, videos y capturas.',
    tips: [
      'Collections organiza videos con portada y color propio.',
      'Desde Collections puedes abrir Capturas; ya no necesitas buscar esa funcion como modulo separado.',
      'Usa buscador y orden cuando una Collection crece demasiado.',
      'Una buena estructura es Collection > Collection hija > videos, por ejemplo Peliculas y series > Anime > Temporada 1.',
      'Las Collections son manuales: si un video no aparece, agregalo a la Collection correspondiente.',
    ],
  ),
  _GuideTopic(
    icon: Icons.folder_special_rounded,
    title: 'Capturas',
    subtitle: 'Fotogramas, etiquetas y carpetas visuales.',
    tips: [
      'Las capturas tomadas desde el reproductor de video aparecen en Capturas, dentro de Collections.',
      'Cada captura conserva nombre, peso, fecha de captura, etiqueta opcional y fuente, es decir, el video desde donde se genero.',
      'El menu de cada captura usa el mismo flujo que audio y video: Editar abre la pagina comun de datos para cambiar nombre y varias etiquetas.',
      'Al usar una captura como portada, el selector muestra videos y Collections con busqueda, chips y seleccion visual como el flujo de agregar items.',
      'Al crear una etiqueta, Listenfy la trata como una coleccion: puede tener nombre, color y thumbnail propio.',
      'Las carpetas de etiquetas tambien usan la pagina comun de edicion, con nombre, contenido, color y thumbnail elegido desde sus capturas.',
      'El color y thumbnail se guardan por etiqueta: si usas la misma etiqueta en varias capturas, todas comparten la misma coleccion visual.',
      'El boton de carpetas abre la vista de etiquetas, donde cada etiqueta se muestra como carpeta estilo Finder con contador, portada y punto de color.',
      'Al tocar una carpeta de etiqueta, Capturas se abre filtrada por esa etiqueta.',
    ],
  ),
  _GuideTopic(
    icon: Icons.ondemand_video_rounded,
    title: 'Video',
    subtitle: 'Gestos y utilidades del reproductor de video.',
    tips: [
      'Doble toque en la mitad izquierda o derecha del video retrocede o adelanta segundos.',
      'Arrastre vertical con un dedo cambia el volumen; con dos dedos cambia la velocidad.',
      'Doble toque con dos dedos alterna entre play y pausa.',
      'Al mover la barra de progreso puede aparecer previsualizacion; tambien puedes guardar una captura desde el icono de camara.',
      'En Android, si el video sigue reproduciendose al salir, puede entrar en PiP automaticamente.',
      'Las tarjetas de video pueden mostrar etiquetas de estado como Pendiente, Seguir viendo, Visto o Completado segun el progreso guardado.',
      'Desde Configuracion > Video puedes ocultar esas etiquetas en todos los videos o solo en videos cortos de 13 minutos o menos.',
      'Ocultar etiquetas solo cambia la vista: no borra progreso, posiciones guardadas ni estadisticas.',
    ],
  ),
  _GuideTopic(
    icon: Icons.cast_connected_rounded,
    title: 'Connect y transferencias',
    subtitle: 'Control remoto, imports y compartir offline.',
    tips: [
      'Listenfy Connect abre una URL o QR para controlar la reproduccion desde otro dispositivo en la misma red.',
      'Con colas muy grandes, Connect puede sentirse mas lento porque debe sincronizar mas estado.',
      'Si un cambio de pista remoto se siente retrasado, pausa desde el telefono o desde Connect antes de elegir otra cancion.',
      'Puedes importar URLs o archivos desde el menu Compartir de Android.',
      'La seleccion multiple de audio o video permite compartir varios archivos por apps externas hasta 300 MB en total.',
      'La seleccion multiple tambien puede enviarse por transferencia interna Listenfy con metadata y limite de 1 GB en total.',
      'Si una seleccion supera el limite permitido, Listenfy conserva la seleccion y muestra el aviso antes de iniciar el envio.',
      'La transferencia P2P usa QR para enviar archivos y metadata sin depender de internet cuando el dispositivo lo permite.',
      'La transferencia de datos entre canciones mueve titulo, artista, portada, letras, favoritos, estadisticas y playlists hacia otra version sin cambiar el archivo destino.',
      'Despues de transferir datos puedes eliminar la version anterior de la biblioteca o conservarla.',
    ],
  ),
  _GuideTopic(
    icon: Icons.warning_amber_rounded,
    title: 'Limites conocidos',
    subtitle: 'Comportamientos que todavia se estan puliendo.',
    tips: [
      'Bibliotecas de mas de 400 o 500 items pueden hacer mas lenta una pantalla si se cargan todos los elementos a la vez.',
      'Exportar ZIP puede tardar mucho; restaurar normalmente es mas rapido.',
      'Algunos videos pueden no reportar duracion correcta si su metadata viene incompleta.',
      'Si ciertas descargas fallan, actualiza cookies.txt desde Datos y descargas.',
    ],
  ),
];

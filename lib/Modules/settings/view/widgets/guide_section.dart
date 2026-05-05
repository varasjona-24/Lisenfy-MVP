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
      'El crossfade, ecualizador, temporizador de apagado y volumen por defecto viven en Configuracion > Audio.',
      'Sonido limpio detecta silencios largos y permite recortar solo los segmentos que elijas.',
      'Modo 8D e instrumental requieren el backend externo; cuando terminan, se guardan como variantes reutilizables offline.',
    ],
  ),
  _GuideTopic(
    icon: Icons.edit_note_rounded,
    title: 'Artistas y colaboraciones',
    subtitle: 'Metadata necesaria para Atlas y relaciones.',
    tips: [
      'Atlas funciona mejor cuando editas artistas y defines region principal, pais y tipo de artista.',
      'Las portadas de canciones, artistas, playlists y listas tematicas pueden venir de archivo local o busqueda web.',
      'Si una colaboracion debe contarse para varios artistas, escribela en Artista con patrones como ft., feat., featuring o with.',
      'Despues del marcador de colaboracion, separa invitados con coma, x o &: Artista ft. Invitado1, Invitado2 & Invitado3.',
      'Si el titulo sugiere feat o ft pero el campo Artista no lo refleja, al guardar se muestra una advertencia para corregirlo.',
    ],
  ),
  _GuideTopic(
    icon: Icons.public_rounded,
    title: 'Atlas',
    subtitle: 'Organizacion regional de tu musica.',
    tips: [
      'Atlas no adivina todo por si solo: depende de la region y pais que tengas en artistas y canciones.',
      'Si cierras el miniplayer, Continuar debe intentar retomar la estacion, cancion y posicion guardadas localmente.',
      'Si se borran datos de la app, cookies o almacenamiento interno, las sesiones guardadas pueden perderse.',
      'Las recomendaciones locales mejoran mientras mas metadata consistente tenga tu biblioteca.',
    ],
  ),
  _GuideTopic(
    icon: Icons.category_rounded,
    title: 'Sources',
    subtitle: 'Tematicas, carpetas y subcarpetas para videos.',
    tips: [
      'Sources organiza videos por tematicas; dentro puedes crear carpetas y subcarpetas con portada propia.',
      'Usa buscador y orden cuando una tematica crece demasiado.',
      'Una buena estructura es tematica > carpeta > subcarpeta > videos, por ejemplo Peliculas y series > Anime > Temporada 1.',
      'Las vistas de carpetas son manuales: si un video no aparece, agregalo a la carpeta correspondiente.',
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
    ],
  ),
  _GuideTopic(
    icon: Icons.cast_connected_rounded,
    title: 'Connect y transferencias',
    subtitle: 'Control remoto, imports y compartir offline.',
    tips: [
      'Listenfy Connect abre una URL o QR para controlar la reproduccion desde otro dispositivo en la misma red.',
      'Con colas muy grandes, Connect puede sentirse mas lento porque debe sincronizar mas estado.',
      'Puedes importar URLs o archivos desde el menu Compartir de Android.',
      'La transferencia P2P usa QR para enviar archivos y metadata sin depender de internet cuando el dispositivo lo permite.',
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

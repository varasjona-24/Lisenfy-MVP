import 'package:easy_localization/easy_localization.dart';
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
                tr('settings.guide.title'),
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
                  tr('settings.guide.manual_title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('settings.guide.manual_subtitle'),
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

  factory _GuideTopic.i18n({
    required IconData icon,
    required String key,
    required int tipsCount,
  }) {
    return _GuideTopic(
      icon: icon,
      title: tr('settings.guide.topics.$key.title'),
      subtitle: tr('settings.guide.topics.$key.subtitle'),
      tips: List.generate(
        tipsCount,
        (index) => tr('settings.guide.topics.$key.tips.${index + 1}'),
      ),
    );
  }

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> tips;
}

List<_GuideTopic> get _guideTopics => [
  _GuideTopic.i18n(icon: Icons.security_rounded, key: 'library', tipsCount: 4),
  _GuideTopic.i18n(icon: Icons.headphones_rounded, key: 'music', tipsCount: 7),
  _GuideTopic.i18n(
    icon: Icons.dashboard_customize_rounded,
    key: 'editable_home',
    tipsCount: 11,
  ),
  _GuideTopic.i18n(
    icon: Icons.query_stats_rounded,
    key: 'wrapped',
    tipsCount: 5,
  ),
  _GuideTopic.i18n(icon: Icons.edit_note_rounded, key: 'artists', tipsCount: 7),
  _GuideTopic.i18n(icon: Icons.public_rounded, key: 'atlas', tipsCount: 5),
  _GuideTopic.i18n(
    icon: Icons.category_rounded,
    key: 'collections',
    tipsCount: 5,
  ),
  _GuideTopic.i18n(
    icon: Icons.folder_special_rounded,
    key: 'captures',
    tipsCount: 9,
  ),
  _GuideTopic.i18n(
    icon: Icons.ondemand_video_rounded,
    key: 'video',
    tipsCount: 8,
  ),
  _GuideTopic.i18n(
    icon: Icons.cast_connected_rounded,
    key: 'connect',
    tipsCount: 10,
  ),
  _GuideTopic.i18n(
    icon: Icons.warning_amber_rounded,
    key: 'limits',
    tipsCount: 4,
  ),
];

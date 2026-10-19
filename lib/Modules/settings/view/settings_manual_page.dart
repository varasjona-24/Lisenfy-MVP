import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';

class SettingsManualPage extends StatefulWidget {
  const SettingsManualPage({super.key});
  @override
  State<SettingsManualPage> createState() => _SettingsManualPageState();
}

class _SettingsManualPageState extends State<SettingsManualPage> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _search.text.trim().toLowerCase();
    final topics = _guideTopics
        .where(
          (topic) => [
            topic.title,
            topic.subtitle,
            ...topic.tips,
          ].any((text) => text.toLowerCase().contains(query)),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings.guide.manual_title'))),
      body: AppGradientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_stories_rounded,
                          size: 40,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('settings.guide.manual_title'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('settings.guide.manual_subtitle'),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: tr('settings.guide.search_hint'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: tr('settings.guide.clear_search'),
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(_search.clear),
                            ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      tr(
                        'settings.guide.topic_count',
                        namedArgs: {'count': topics.length.toString()},
                      ),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (topics.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        tr('settings.guide.no_results'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final topic in topics)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      color: theme.colorScheme.surface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _GuideTopicTile(
                        key: ValueKey('${topic.title}:$query'),
                        topic: topic,
                        expanded: query.isNotEmpty,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideTopicTile extends StatelessWidget {
  const _GuideTopicTile({
    super.key,
    required this.topic,
    required this.expanded,
  });
  final bool expanded;

  final _GuideTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: expanded,
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: topic.isListenfyConnect
            ? SvgPicture.asset(
                'assets/logo/listenfy_connect.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  IconTheme.of(context).color ?? theme.colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              )
            : Icon(topic.icon),
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
    this.isListenfyConnect = false,
  });

  factory _GuideTopic.i18n({
    required IconData icon,
    required String key,
    required int tipsCount,
    bool isListenfyConnect = false,
  }) {
    return _GuideTopic(
      icon: icon,
      title: tr('settings.guide.topics.$key.title'),
      subtitle: tr('settings.guide.topics.$key.subtitle'),
      isListenfyConnect: isListenfyConnect,
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
  final bool isListenfyConnect;
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
    tipsCount: 7,
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
    tipsCount: 11,
  ),
  _GuideTopic.i18n(
    icon: Icons.cast_connected_rounded,
    key: 'connect',
    tipsCount: 8,
    isListenfyConnect: true,
  ),
];

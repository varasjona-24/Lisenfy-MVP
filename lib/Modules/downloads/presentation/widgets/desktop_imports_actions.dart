import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Desktop entry points reuse the mobile import flows without extra actions.
class DesktopImportsActions extends StatelessWidget {
  const DesktopImportsActions({
    super.key,
    required this.onUrl,
    required this.onLocal,
    required this.onQr,
  });
  final VoidCallback onUrl, onLocal, onQr;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 20) / columns;
        Widget action(
          IconData icon,
          String title,
          String subtitle,
          VoidCallback onTap, {
          bool primary = false,
        }) => SizedBox(
          width: width,
          child: _ImportCard(
            icon: icon,
            title: tr(title),
            subtitle: tr(subtitle),
            onTap: onTap,
            primary: primary,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 20,
              children: [
                action(
                  Icons.link_rounded,
                  'downloads.url_import_title',
                  'downloads.url_import_subtitle',
                  onUrl,
                  primary: true,
                ),
                action(
                  Icons.folder_open_rounded,
                  'downloads.local_import_title',
                  'downloads.local_import_subtitle',
                  onLocal,
                  primary: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            action(
              Icons.qr_code_scanner_rounded,
              'downloads.scan_qr_title',
              'downloads.scan_qr_subtitle',
              onQr,
              primary: true,
            ),
          ],
        );
      },
    );
  }
}

class _ImportCard extends StatelessWidget {
  const _ImportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.primary,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final emblem = Container(
      padding: EdgeInsets.all(primary ? 14 : 12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: scheme.primary, size: primary ? 30 : 24),
    );
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: scheme.primary.withValues(alpha: .06),
        child: Padding(
          padding: EdgeInsets.all(primary ? 26 : 20),
          child: primary
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        emblem,
                        const Spacer(),
                        Icon(
                          Icons.north_east_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    emblem,
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

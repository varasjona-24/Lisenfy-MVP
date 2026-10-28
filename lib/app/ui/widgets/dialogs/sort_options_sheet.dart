import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import '../navigation/app_bottom_nav.dart';

/// Keeps sorting controls centered on desktop and in a sheet on mobile.
Future<T?> showAdaptiveSortMenu<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = true,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  if (!AppBottomNav.desktopSidebarEnabled) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      shape: shape,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height - 64,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: builder(context),
        ),
      ),
    ),
  );
}

class SortSheetOption {
  const SortSheetOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.sublabel,
    this.ascending,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? sublabel;
  final bool? ascending;
}

Future<void> showSortOptionsSheet({
  required BuildContext context,
  required String title,
  required List<SortSheetOption> Function() optionsBuilder,
  VoidCallback? onOpened,
  VoidCallback? onClosed,
}) async {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  onOpened?.call();
  await showAdaptiveSortMenu<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, modalSetState) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final option in optionsBuilder()) ...[
                    SortOptionTile(
                      icon: option.icon,
                      label: option.label,
                      sublabel: option.sublabel,
                      selected: option.selected,
                      ascending: option.ascending,
                      onTap: () {
                        option.onTap();
                        modalSetState(() {});
                      },
                    ),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(tr('common.accept')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() => onClosed?.call());
}

class SortOptionTile extends StatelessWidget {
  const SortOptionTile({
    super.key,
    this.icon,
    required this.label,
    this.sublabel,
    required this.selected,
    required this.onTap,
    this.ascending,
  });

  final IconData? icon;
  final String label;
  final String? sublabel;
  final bool selected;
  final VoidCallback onTap;
  final bool? ascending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon ?? Icons.sort_rounded,
              size: 19,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: sublabel == null
                  ? Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected ? scheme.primary : scheme.onSurface,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selected ? scheme.primary : scheme.onSurface,
                          ),
                        ),
                        Text(
                          sublabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
            ),
            if (selected)
              Icon(
                ascending == null
                    ? Icons.check_circle_rounded
                    : ascending == true
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 18,
                color: scheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

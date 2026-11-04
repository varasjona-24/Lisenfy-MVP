import 'package:flutter/material.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';

/// Capture tools use a centered dialog on desktop and a sheet on mobile.
Future<T?> showCapturePanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 640,
  bool isScrollControlled = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (!AppBottomNav.desktopSidebarEnabled) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: isScrollControlled,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.all(32),
      backgroundColor: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - 64,
        ),
        child: SizedBox(width: width, child: builder(context)),
      ),
    ),
  );
}

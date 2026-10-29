import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

/// Bounded player tools with an explicit close action for desktop windows.
class PlayerDesktopDialog extends StatelessWidget {
  const PlayerDesktopDialog({
    super.key,
    required this.child,
    this.reading = false,
    this.maxWidth,
  });

  final Widget child;
  final bool reading;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final available = MediaQuery.sizeOf(context).height - 48;
    final content = reading ? child : SingleChildScrollView(child: child);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? (reading ? 840 : 620),
          maxHeight: available.clamp(0, double.infinity),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: IconButton(
                  tooltip: tr('common.close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
            if (reading)
              Flexible(
                child: SizedBox(height: available * .85, child: content),
              )
            else
              Flexible(child: content),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Indeterminate progress: saving includes persistence and dependent refreshes.
class EditSaveButton extends StatelessWidget {
  const EditSaveButton({
    super.key,
    required this.busy,
    required this.label,
    required this.busyLabel,
    this.onPressed,
  });
  final bool busy;
  final String label;
  final String busyLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(busy ? busyLabel : label)),
      ],
    ),
  );
}

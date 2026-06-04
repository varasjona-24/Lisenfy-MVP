import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/capture_item.dart';

class CaptureTile extends StatelessWidget {
  const CaptureTile({
    super.key,
    required this.capture,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onOptions,
    this.tagColorBuilder,
  });

  final CaptureItem capture;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOptions;
  final int Function(String tag)? tagColorBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: selected ? onLongPress : onTap,
      onLongPress: onLongPress,
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: .62),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: .3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(capture.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, size: 32),
                      ),
                    ),
                  ),
                  if (selected)
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: scheme.primary,
                          child: Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              child: Row(
                children: [
                  if (capture.tags.isNotEmpty) ...[
                    _CaptureTagDots(
                      tags: capture.tags,
                      tagColorBuilder: tagColorBuilder,
                    ),
                    const SizedBox(width: 7),
                  ],
                  Expanded(
                    child: Text(
                      capture.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onOptions,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureTagDots extends StatelessWidget {
  const _CaptureTagDots({required this.tags, this.tagColorBuilder});

  final List<String> tags;
  final int Function(String tag)? tagColorBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = tags.take(3).toList(growable: false);

    return SizedBox(
      width: visible.length == 1 ? 12 : 10.0 + (visible.length * 8),
      height: 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * 8,
              top: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(
                    tagColorBuilder?.call(visible[i]) ??
                        scheme.primary.toARGB32(),
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
                child: const SizedBox(width: 12, height: 12),
              ),
            ),
        ],
      ),
    );
  }
}

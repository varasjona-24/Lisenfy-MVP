import 'package:flutter/material.dart';

Duration appMotionDuration(BuildContext context, [int milliseconds = 180]) =>
    MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// Outgoing content must never keep obsolete controls interactive or semantic.
class AppMotionSwap extends StatelessWidget {
  const AppMotionSwap({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
  });
  final Widget child;
  final AlignmentGeometry alignment;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: appMotionDuration(context),
    reverseDuration: appMotionDuration(context, 120),
    switchInCurve: Curves.easeOutCubic,
    transitionBuilder: (child, animation) =>
        FadeTransition(opacity: animation, child: child),
    layoutBuilder: (current, previous) => Stack(
      alignment: alignment,
      children: [
        for (final child in previous)
          ExcludeSemantics(child: IgnorePointer(child: child)),
        if (current != null) current,
      ],
    ),
    child: child,
  );
}

class AppMotionEntrance extends StatelessWidget {
  const AppMotionEntrance({
    super.key,
    required this.child,
    this.scaleFrom = .97,
  });
  final Widget child;
  final double scaleFrom;
  @override
  Widget build(BuildContext context) {
    if (appMotionDuration(context) == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: scaleFrom, end: 1),
      duration: appMotionDuration(context, 240),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
    );
  }
}

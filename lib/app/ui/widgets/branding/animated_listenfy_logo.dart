import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AnimatedListenfyLogo extends StatefulWidget {
  static const double _visualScale = 0.54;

  final double size;
  final Color? color;
  final Duration duration;

  const AnimatedListenfyLogo({
    super.key,
    this.size = 96,
    this.color,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<AnimatedListenfyLogo> createState() => _AnimatedListenfyLogoState();
}

class _AnimatedListenfyLogoState extends State<AnimatedListenfyLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration);

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.color ?? Theme.of(context).colorScheme.primary;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: SizedBox.square(
            dimension: widget.size,
            child: Center(
              child: SvgPicture.asset(
                'assets/logo/listenfy_logo.svg',
                width: widget.size * AnimatedListenfyLogo._visualScale,
                height: widget.size * AnimatedListenfyLogo._visualScale,
                colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

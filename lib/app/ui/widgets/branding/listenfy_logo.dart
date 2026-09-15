import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ListenfyLogo extends StatelessWidget {
  static const double _visualScale = 0.54;

  final double size;
  final bool showText;
  final Color? color;

  const ListenfyLogo({
    super.key,
    this.size = 32,
    this.showText = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size,
          child: Center(
            child: SvgPicture.asset(
              'assets/logo/listenfy_logo.svg',
              width: size * _visualScale,
              height: size * _visualScale,
              colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            'Listenfy',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: c,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

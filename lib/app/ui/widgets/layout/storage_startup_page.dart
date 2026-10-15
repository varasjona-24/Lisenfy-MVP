import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_gradient_background.dart';
import '../motion/app_motion.dart';

/// Presentation only: bootstrap owns progress, errors and retry lifecycle.
class StorageStartupPage extends StatefulWidget {
  const StorageStartupPage({
    super.key,
    required this.title,
    required this.stage,
    required this.failed,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String stage;
  final bool failed;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  State<StorageStartupPage> createState() => _StorageStartupPageState();
}

class _StorageStartupPageState extends State<StorageStartupPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  void _syncMotion() {
    if (!widget.failed &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant StorageStartupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 1, end: 1.045)
                            .chain(CurveTween(curve: Curves.easeInOut))
                            .animate(_pulse),
                        child: SvgPicture.asset(
                          'assets/logo/listenfy_logo.svg',
                          width: 88,
                          height: 88,
                          colorFilter: ColorFilter.mode(
                            colors.primary,
                            BlendMode.srcIn,
                          ),
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Listenfy', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 28),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: AppMotionSwap(
                          child: Text(
                            widget.stage,
                            key: ValueKey(widget.stage),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (widget.failed)
                        FilledButton.icon(
                          onPressed: widget.onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(widget.retryLabel),
                        )
                      else if (MediaQuery.disableAnimationsOf(context))
                        Icon(
                          Icons.hourglass_empty_rounded,
                          color: colors.primary,
                        )
                      else
                        SizedBox(
                          width: 160,
                          child: LinearProgressIndicator(
                            borderRadius: BorderRadius.circular(8),
                            minHeight: 3,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

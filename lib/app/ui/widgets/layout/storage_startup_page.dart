import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_gradient_background.dart';

/// Presentation only: bootstrap owns progress, errors and retry lifecycle.
class StorageStartupPage extends StatelessWidget {
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
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/logo/listenfy_logo.svg',
                          width: 64,
                          height: 64,
                          colorFilter: ColorFilter.mode(
                            colors.primary,
                            BlendMode.srcIn,
                          ),
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(height: 16),
                        Text('Listenfy', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 28),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            stage,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (failed)
                          FilledButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(retryLabel),
                          )
                        else
                          const LinearProgressIndicator(),
                      ],
                    ),
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

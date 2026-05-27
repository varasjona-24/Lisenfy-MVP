import 'package:flutter/material.dart';

import '../../../app/ui/themes/app_grid_theme.dart';

class SourceCollectionGrid extends StatelessWidget {
  const SourceCollectionGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: AppGridTheme.getCollectionCrossAxisCount(
              constraints.maxWidth,
            ),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

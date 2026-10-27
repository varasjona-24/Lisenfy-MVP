import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class HomeMoveSection {
  const HomeMoveSection({
    required this.id,
    required this.title,
    required this.child,
  });
  final String id, title;
  final Widget child;
}

/// The header opts into movement; media long presses keep their normal meaning.
class HomeMoveScope extends InheritedWidget {
  const HomeMoveScope({super.key, required this.start, required super.child});
  final VoidCallback start;
  static HomeMoveScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeMoveScope>();
  @override
  bool updateShouldNotify(HomeMoveScope oldWidget) => start != oldWidget.start;
}

/// Sliver surface: uses the Home's existing scrollable for edge auto-scrolling.
class HomeSectionMoveSurface extends StatefulWidget {
  const HomeSectionMoveSurface({
    super.key,
    required this.sections,
    required this.onCommit,
    this.footer,
  });
  final List<HomeMoveSection> sections;
  final ValueChanged<List<String>> onCommit;
  final Widget? footer;
  @override
  State<HomeSectionMoveSurface> createState() => _HomeSectionMoveSurfaceState();
}

class _HomeSectionMoveSurfaceState extends State<HomeSectionMoveSurface>
    with SingleTickerProviderStateMixin {
  List<String>? _draft;
  int? _dragging;
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  bool get _reduced =>
      MediaQuery.disableAnimationsOf(context) ||
      !TickerMode.valuesOf(context).enabled;
  void _syncMotion() {
    if (_draft != null && !_reduced) {
      if (!_wiggle.isAnimating) _wiggle.repeat();
    } else {
      _wiggle.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  void _start() {
    if (_draft != null) return;
    setState(
      () => _draft = widget.sections.map((section) => section.id).toList(),
    );
    _syncMotion();
  }

  void _finish(bool save) {
    final ids = _ordered.map((section) => section.id).toList();
    setState(() {
      _draft = null;
      _dragging = null;
    });
    _syncMotion();
    if (save) widget.onCommit(ids);
  }

  List<HomeMoveSection> get _ordered {
    if (_draft == null) return widget.sections;
    final byId = {for (final section in widget.sections) section.id: section};
    return [
      for (final id in _draft!)
        if (byId.containsKey(id)) byId[id]!,
      for (final section in widget.sections)
        if (!_draft!.contains(section.id)) section,
    ];
  }

  void _move(int from, int to) {
    final items = _ordered.toList();
    if (from < 0 ||
        to < 0 ||
        from >= items.length ||
        to >= items.length ||
        from == to) {
      return;
    }
    items.insert(to, items.removeAt(from));
    setState(() => _draft = items.map((section) => section.id).toList());
  }

  Widget _section(HomeMoveSection section, int index) {
    final active = _draft != null;
    return AnimatedBuilder(
      key: ValueKey(section.id),
      animation: _wiggle,
      builder: (_, child) => Transform.rotate(
        angle: !active || _reduced || _dragging == index
            ? 0
            : math.sin(_wiggle.value * math.pi * 2 + index) * .006,
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: HomeMoveScope(
          start: _start,
          child: Stack(
            children: [
              ExcludeSemantics(
                excluding: active,
                child: IgnorePointer(ignoring: active, child: section.child),
              ),
              if (active)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ReorderableDragStartListener(
                    key: ValueKey('home-drag-${section.id}'),
                    index: index,
                    child: Semantics(
                      label: tr('home.move.drag', args: [section.title]),
                      customSemanticsActions: {
                        if (index > 0)
                          CustomSemanticsAction(
                            label: tr('home.move.up'),
                          ): () =>
                              _move(index, index - 1),
                        if (index < _ordered.length - 1)
                          CustomSemanticsAction(
                            label: tr('home.move.down'),
                          ): () =>
                              _move(index, index + 1),
                      },
                      child: const ColoredBox(
                        color: Colors.transparent,
                        child: SizedBox(height: 56),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered;
    return PopScope(
      canPop: _draft == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _draft != null) _finish(false);
      },
      child: SliverMainAxisGroup(
        slivers: [
          if (_draft != null)
            PinnedHeaderSliver(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          tr('home.move.title'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(tr('home.move.hint')),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _dragging == null
                                  ? () => _finish(false)
                                  : null,
                              child: Text(tr('common.cancel')),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: _dragging == null
                                  ? () => _finish(true)
                                  : null,
                              child: Text(tr('home.move.done')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SliverReorderableList(
            key: const ValueKey('home-section-list'),
            itemCount: ordered.length,
            itemBuilder: (_, index) => _section(ordered[index], index),
            onReorderItem: _move,
            onReorderStart: (index) {
              setState(() => _dragging = index);
            },
            onReorderEnd: (_) {
              if (mounted) setState(() => _dragging = null);
            },
            proxyDecorator: (child, _, animation) =>
                Material(color: Colors.transparent, child: child),
          ),
          if (widget.footer != null)
            SliverToBoxAdapter(
              child: IgnorePointer(
                ignoring: _draft != null,
                child: widget.footer!,
              ),
            ),
        ],
      ),
    );
  }
}

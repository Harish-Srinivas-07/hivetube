/// Shared inherited widget that tells scrollable tabs how much bottom padding
/// to add so the last items scroll clear of the floating mini-player card.
library;

import 'package:flutter/widgets.dart';

class MiniPlayerInset extends InheritedWidget {
  const MiniPlayerInset({
    super.key,
    required this.bottom,
    required super.child,
  });

  /// Total inset in logical pixels: mini-card height + its vertical margins.
  /// Zero when no video is playing or the panel is fully expanded.
  final double bottom;

  static MiniPlayerInset? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MiniPlayerInset>();

  /// Returns 0 if no ancestor exists (safe default).
  static double of(BuildContext context) =>
      maybeOf(context)?.bottom ?? 0.0;

  @override
  bool updateShouldNotify(MiniPlayerInset oldWidget) =>
      bottom != oldWidget.bottom;
}

class SliverBottomInset extends StatelessWidget {
  const SliverBottomInset({super.key, this.extra = 0.0});
  final double extra;

  @override
  Widget build(BuildContext context) {
    final bottom = MiniPlayerInset.of(context) + extra;
    if (bottom <= 0) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(child: SizedBox(height: bottom));
  }
}

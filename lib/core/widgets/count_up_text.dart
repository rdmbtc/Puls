import 'package:flutter/material.dart';

/// Animates a numeric value from 0 up to [value] the first time it appears,
/// and smoothly tweens between values on change. Reformats every frame via
/// [builder], so callers keep full control of prefixes/suffixes/styling.
///
/// Premium "count-up" feel for headline numbers (balances, P&L, counters)
/// without any business logic — purely presentational.
class CountUpText extends StatelessWidget {
  const CountUpText(
    this.value, {
    required this.builder,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
    super.key,
  });

  /// The target value to animate to.
  final double value;

  /// Builds the widget for the current (animating) value.
  final Widget Function(BuildContext context, double value) builder;

  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (context, v, _) => builder(context, v),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Smoothly rolls a number from its previous value to the new one whenever
/// [value] changes — so prices, odds and earnings feel *alive* instead of
/// snapping. Uses tabular figures so the width never jitters mid-tween.
///
/// Example:
/// ```dart
/// AnimatedCount(
///   value: market.yesProbability * 100,
///   formatter: (v) => '${v.toStringAsFixed(0)}%',
/// )
/// ```
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
    super.key,
  });

  /// The target value to animate toward.
  final double value;

  /// Turns the in-between animated value into display text (e.g. `'$42'`).
  final String Function(double value) formatter;

  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? const TextStyle()).copyWith(
      fontFeatures: PulsColors.tabularFigures,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: duration,
      curve: curve,
      builder: (context, v, _) => Text(
        formatter(v),
        style: base,
        textAlign: textAlign,
      ),
    );
  }
}

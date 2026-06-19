import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme/app_theme.dart';

/// On-brand loading indicator. Replaces bare grey `CircularProgressIndicator`s
/// so spinners pick up the brand color and an optional label — and, crucially,
/// stop spinning under reduce-motion (a spinning ring is exactly the kind of
/// perpetual motion the setting asks us to avoid), falling back to a calm
/// static dot + label.
class PulsLoader extends StatelessWidget {
  const PulsLoader({
    super.key,
    this.label,
    this.size = 22,
    this.strokeWidth = 2.6,
    this.color,
    this.center = true,
  });

  /// Optional text shown beneath the indicator (e.g. "Loading markets…").
  final String? label;
  final double size;
  final double strokeWidth;

  /// Indicator color; defaults to brand.
  final Color? color;

  /// Wrap in a [Center] (default) — set false when already centered/aligned.
  final bool center;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final c = color ?? t.brand;

    final Widget indicator = context.reduceMotion
        ? Container(
            width: size * 0.55,
            height: size * 0.55,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c),
          )
        : SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(c),
            ),
          );

    final content = label == null
        ? indicator
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              indicator,
              const SizedBox(height: 12),
              Text(
                label!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: t.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          );

    final semantic = Semantics(
      label: label ?? 'Loading',
      liveRegion: true,
      child: content,
    );

    return center ? Center(child: semantic) : semantic;
  }
}

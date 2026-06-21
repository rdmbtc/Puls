import 'package:flutter/material.dart';

import '../motion.dart';

/// Paints [text] with the brand mint→pink gradient that slowly *flows*
/// horizontally — the signature Puls accent. Collapses to a static gradient
/// under reduce-motion. App-wide reusable (landing, headers, hero numbers…).
class AnimatedGradientText extends StatefulWidget {
  const AnimatedGradientText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.animate = true,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool animate;

  @override
  State<AnimatedGradientText> createState() => _AnimatedGradientTextState();
}

class _AnimatedGradientTextState extends State<AnimatedGradientText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // Repeated mint→pink→mint so the sweep loops seamlessly.
  static const _colors = [
    Color(0xFF34E5C0),
    Color(0xFFF65FA9),
    Color(0xFF34E5C0),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 5));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion || !widget.animate;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (r) => LinearGradient(
            colors: _colors,
            tileMode: TileMode.mirror,
            transform: _SlideGradient(reduce ? 0.0 : _c.value),
          ).createShader(r),
          child: child,
        );
      },
      child: Text(
        widget.text,
        textAlign: widget.textAlign,
        style: (widget.style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}

/// Horizontal translation transform so a [LinearGradient] appears to flow.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);
  final double t; // 0..1

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(-bounds.width * t, 0.0, 0.0);
  }
}

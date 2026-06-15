import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Claude-style "reasoning" indicator: a muted text label with a brighter
/// highlight band that sweeps across it, optionally cycling through a list of
/// phrases describing what the AI is doing right now.
///
/// Use this anywhere an AI is "thinking" instead of a bare spinner.
class ShimmerText extends StatefulWidget {
  const ShimmerText({
    super.key,
    required this.phrases,
    this.style,
    this.baseColor,
    this.highlightColor,
    this.sweep = const Duration(milliseconds: 1400),
    this.cycle = const Duration(milliseconds: 2200),
    this.leadingDot = true,
  }) : assert(phrases.length > 0, 'phrases must not be empty');

  /// One or more phrases. If more than one, they cross-fade on [cycle].
  final List<String> phrases;
  final TextStyle? style;
  final Color? baseColor;
  final Color? highlightColor;

  /// How long one shimmer sweep takes.
  final Duration sweep;

  /// How long each phrase stays before switching to the next.
  final Duration cycle;

  /// Show a small pulsing dot before the text.
  final bool leadingDot;

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with TickerProviderStateMixin {
  late final AnimationController _shimmer;
  int _idx = 0;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: widget.sweep)
      ..addListener(_onTick)
      ..repeat();
  }

  // Advance the phrase index off the shimmer ticker so we don't spin up a
  // second controller just for timing.
  void _onTick() {
    if (widget.phrases.length < 2) return;
    _elapsed += const Duration(milliseconds: 16);
    if (_elapsed >= widget.cycle) {
      _elapsed = Duration.zero;
      setState(() => _idx = (_idx + 1) % widget.phrases.length);
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final base = widget.baseColor ?? t.textSubtle;
    final highlight = widget.highlightColor ?? t.text;
    final style = (widget.style ??
            TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ))
        .copyWith(color: base);

    final label = AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        final x = _shimmer.value * 2 - 1; // -1 .. 1
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(x - 0.6, 0),
            end: Alignment(x + 0.6, 0),
            colors: [base, highlight, base],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(rect),
          child: child,
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (c, anim) => FadeTransition(
          opacity: anim,
          child: SizeTransition(
            sizeFactor: anim,
            axis: Axis.horizontal,
            axisAlignment: -1,
            child: c,
          ),
        ),
        child: Text(
          widget.phrases[_idx],
          key: ValueKey(_idx),
          style: style,
        ),
      ),
    );

    if (!widget.leadingDot) return label;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulseDot(color: highlight),
        const SizedBox(width: 8),
        Flexible(child: label),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final a = 0.35 + _c.value * 0.65;
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: a),
          ),
        );
      },
    );
  }
}

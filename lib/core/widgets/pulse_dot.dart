import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme/app_theme.dart';

/// A small "live" dot that emits a soft expanding halo — the visual heartbeat
/// of Puls. Use next to live counts, open markets, or the brand mark.
///
/// The pulse rate can be nudged via [period]; faster = more "active market".
class PulseDot extends StatefulWidget {
  const PulseDot({
    this.size = 8,
    this.color,
    this.period = const Duration(milliseconds: 1600),
    super.key,
  });

  final double size;

  /// Core dot color. Defaults to the brand pink from the theme.
  final Color? color;

  /// One full pulse cycle. Shorter = livelier.
  final Duration period;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.puls.brand;
    final s = widget.size;
    if (context.reduceMotion) {
      // Just the solid core dot, no expanding halo, same footprint.
      return SizedBox(
        width: s * 3,
        height: s * 3,
        child: Center(
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      );
    }
    return SizedBox(
      width: s * 3,
      height: s * 3,
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final t = _ctrl.value; // 0..1
            return Stack(
              alignment: Alignment.center,
              children: [
                // Expanding halo that fades out.
                Container(
                  width: s + (s * 2 * t),
                  height: s + (s * 2 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: (1 - t) * 0.35),
                  ),
                ),
                child!,
              ],
            );
          },
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      ),
    );
  }
}

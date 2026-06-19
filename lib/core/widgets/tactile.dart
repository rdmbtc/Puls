import 'package:flutter/material.dart';

import '../motion.dart';

/// A wrapper widget that gives a tap target satisfying, premium feedback:
///
///  • **Press** — scales the child down slightly (`pressedScale`) so taps feel
///    physical and responsive on every platform.
///  • **Hover** — on desktop / web pointers, optionally lifts the child a touch
///    (`hoverScale`) and shows the click cursor, so the whole app feels alive
///    under a mouse — not just dedicated buttons.
///
/// Honors the platform *reduce motion* setting: when on, the scale feedback
/// collapses to its resting state (no animation), matching the rest of the
/// design system (see [PulsMotion]). The tap itself always works.
class Tactile extends StatefulWidget {
  const Tactile({
    required this.child,
    required this.onTap,
    this.behavior = HitTestBehavior.deferToChild,
    this.pressedScale = 0.95,
    this.hoverScale = 1.0,
    this.cursor = SystemMouseCursors.click,
    super.key,
  });

  final Widget child;

  /// Tap callback. When `null` the target is inert — no press/hover feedback
  /// and no click cursor — matching [GestureDetector] semantics.
  final VoidCallback? onTap;
  final HitTestBehavior behavior;

  /// Scale applied while pressed. Set to `1.0` to disable press feedback.
  final double pressedScale;

  /// Scale applied while hovered by a desktop / web pointer. Defaults to `1.0`
  /// (no hover-lift) so existing call sites are unchanged; pass e.g. `1.02` to
  /// opt a card or row into the subtle desktop lift.
  final double hoverScale;

  /// Pointer cursor shown over the target. Defaults to the click cursor.
  final MouseCursor cursor;

  @override
  State<Tactile> createState() => _TactileState();
}

class _TactileState extends State<Tactile> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduce = context.reduceMotion;
    final double scale = (reduce || !enabled)
        ? 1.0
        : _pressed
            ? widget.pressedScale
            : (_hovered ? widget.hoverScale : 1.0);
    final hoverable = enabled && widget.hoverScale != 1.0;

    return MouseRegion(
      cursor: enabled ? widget.cursor : MouseCursor.defer,
      onEnter: hoverable ? (_) => setState(() => _hovered = true) : null,
      onExit: hoverable ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

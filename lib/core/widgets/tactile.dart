import 'package:flutter/material.dart';

/// A wrapper widget that scales down its child slightly on press to provide satisfying,
/// tactile visual feedback.
class Tactile extends StatefulWidget {
  const Tactile({
    required this.child,
    required this.onTap,
    this.behavior = HitTestBehavior.deferToChild,
    super.key,
  });

  final Widget child;
  final VoidCallback onTap;
  final HitTestBehavior behavior;

  @override
  State<Tactile> createState() => _TactileState();
}

class _TactileState extends State<Tactile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A one-shot confetti burst, no external dependencies.
/// Place in a [Stack] and set [play] to true to fire.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.play, this.particleCount = 64});
  final bool play;
  final int particleCount;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late List<_Particle> _particles;
  bool _fired = false;

  static const _palette = [
    Color(0xFF4F46E5), // indigo
    Color(0xFF10B981), // green
    Color(0xFFF59E0B), // amber
    Color(0xFF0EA5E9), // sky
    Color(0xFFEC4899), // pink
    Color(0xFF8B5CF6), // violet
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    _particles = _generate();
    if (widget.play) _fire();
  }

  List<_Particle> _generate() {
    final rnd = math.Random();
    return List.generate(widget.particleCount, (_) {
      // Upward cone: -90° ± 65°
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * (math.pi * 0.72);
      final speed = 220 + rnd.nextDouble() * 320;
      return _Particle(
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        color: _palette[rnd.nextInt(_palette.length)],
        size: 5 + rnd.nextDouble() * 5,
        spin: (rnd.nextDouble() - 0.5) * 14,
        isRect: rnd.nextBool(),
        drift: (rnd.nextDouble() - 0.5) * 60,
      );
    });
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play) _fire();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          if (_ctrl.value == 0 || _ctrl.isCompleted) {
            return const SizedBox.expand();
          }
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_particles, _ctrl.value),
          );
        },
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.spin,
    required this.isRect,
    required this.drift,
  });
  final double vx, vy, size, spin, drift;
  final Color color;
  final bool isRect;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t; // 0..1

  static const _gravity = 640.0;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.42);
    final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
    final secs = t * 1.9;

    for (final p in particles) {
      final x = origin.dx + p.vx * secs + p.drift * secs * secs;
      final y = origin.dy + p.vy * secs + 0.5 * _gravity * secs * secs;
      if (y > size.height + 20) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: fade)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * secs);
      if (p.isRect) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.55),
            const Radius.circular(1.5),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2.4, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

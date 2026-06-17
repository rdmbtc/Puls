import 'dart:math';
import 'package:flutter/material.dart';

/// Particle shape animation that cycles through Prediction/Swipe/Win shapes.
class ParticleShapes extends StatefulWidget {
  const ParticleShapes({super.key, required this.isDark, required this.shapeIndex});
  final bool isDark;
  final int shapeIndex;

  @override
  State<ParticleShapes> createState() => _ParticleShapesState();
}

class _ParticleShapesState extends State<ParticleShapes> with TickerProviderStateMixin {
  late AnimationController _morphCtrl;
  late AnimationController _breatheCtrl;
  List<_Particle> _particles = [];
  final _rand = Random(42);
  static const _morphDuration = Duration(milliseconds: 1800);
  int _prevIndex = 0;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.shapeIndex;
    _morphCtrl = AnimationController(vsync: this, duration: _morphDuration);
    _breatheCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ParticleShapes old) {
    super.didUpdateWidget(old);
    if (old.shapeIndex != widget.shapeIndex) {
      _prevIndex = old.shapeIndex;
      _morphCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _morphCtrl.dispose();
    _breatheCtrl.dispose();
    super.dispose();
  }

  void _initParticles(Size size) {
    if (_particles.isNotEmpty) return;
    final targets = _getShapePoints(widget.shapeIndex, size);
    _particles = List.generate(targets.length, (i) {
      final angle = _rand.nextDouble() * pi * 2;
      final radius = max(size.width, size.height) * (0.6 + _rand.nextDouble() * 0.6);
      return _Particle(
        x: size.width / 2 + cos(angle) * radius,
        y: size.height / 2 + sin(angle) * radius,
        targetX: targets[i].dx,
        targetY: targets[i].dy,
        delay: _rand.nextDouble() * 0.4,
        flickerPhase: _rand.nextDouble() * pi * 2,
        flickerSpeed: 0.5 + _rand.nextDouble() * 1.5,
      );
    });
    _morphCtrl.forward();
  }

  List<Offset> _getShapePoints(int index, Size size) {
    switch (index) {
      case 0: return _predictionShape(size);
      case 1: return _swipeShape(size);
      case 2: return _winShape(size);
      default: return _predictionShape(size);
    }
  }

  // Crystal ball / chart shape for "Prediction"
  List<Offset> _predictionShape(Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = min(size.width, size.height) * 0.28;
    final points = <Offset>[];
    final spacing = r / 12;

    // Circle (crystal ball)
    for (double y = -r; y <= r; y += spacing) {
      final halfW = sqrt(r * r - y * y);
      for (double x = -halfW; x <= halfW; x += spacing) {
        points.add(Offset(cx + x, cy + y - r * 0.15));
      }
    }
    // Base stand
    for (double x = -r * 0.4; x <= r * 0.4; x += spacing) {
      for (double y = r * 0.85; y <= r * 1.1; y += spacing) {
        points.add(Offset(cx + x, cy + y));
      }
    }
    return points;
  }

  // Swipe gesture shape
  List<Offset> _swipeShape(Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = min(size.width, size.height) * 0.28;
    final points = <Offset>[];
    final spacing = r / 12;

    // Hand/finger shape - rounded rectangle
    final fingerW = r * 0.25, fingerH = r * 1.2;
    for (double y = -fingerH / 2; y <= fingerH / 2; y += spacing) {
      final w = fingerW * (1 - pow((y / (fingerH / 2)).abs(), 4) * 0.3);
      for (double x = -w; x <= w; x += spacing) {
        points.add(Offset(cx + x, cy + y));
      }
    }
    // Arrow trails (motion lines)
    for (int i = 0; i < 3; i++) {
      final offsetX = r * (0.5 + i * 0.25);
      final lineH = r * (0.6 - i * 0.15);
      for (double y = -lineH / 2; y <= lineH / 2; y += spacing) {
        points.add(Offset(cx + offsetX, cy + y));
        points.add(Offset(cx + offsetX + spacing, cy + y));
      }
    }
    // Arrow head
    for (double i = 0; i < r * 0.4; i += spacing) {
      final tipX = cx + r * 1.2;
      points.add(Offset(tipX - i, cy - i * 0.6));
      points.add(Offset(tipX - i, cy + i * 0.6));
    }
    return points;
  }

  // Trophy shape for "Win"
  List<Offset> _winShape(Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = min(size.width, size.height) * 0.28;
    final points = <Offset>[];
    final spacing = r / 12;

    // Cup body (U shape)
    for (double y = -r * 0.8; y <= r * 0.4; y += spacing) {
      final progress = ((y + r * 0.8) / (r * 1.2)).clamp(0.0, 1.0);
      final w = r * 0.6 * (1 - progress * progress * 0.5);
      for (double x = -w; x <= w; x += spacing) {
        // Only fill the outline for top, fill bottom
        if (y < -r * 0.5 && x.abs() < w - spacing * 2) continue;
        points.add(Offset(cx + x, cy + y));
      }
    }
    // Handles
    for (double angle = -0.8; angle <= 0.8; angle += 0.08) {
      final hx = cx + r * 0.75 * cos(angle - pi / 2 + 0.3);
      final hy = cy - r * 0.3 + r * 0.35 * sin(angle);
      points.add(Offset(hx, hy));
      points.add(Offset(cx * 2 - hx, hy)); // mirror
    }
    // Stem
    for (double y = r * 0.4; y <= r * 0.7; y += spacing) {
      for (double x = -spacing; x <= spacing; x += spacing) {
        points.add(Offset(cx + x, cy + y));
      }
    }
    // Base
    for (double x = -r * 0.35; x <= r * 0.35; x += spacing) {
      for (double y = r * 0.7; y <= r * 0.85; y += spacing) {
        points.add(Offset(cx + x, cy + y));
      }
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      _initParticles(size);

      return AnimatedBuilder(
        animation: Listenable.merge([_morphCtrl, _breatheCtrl]),
        builder: (context, _) {
          final targets = _getShapePoints(widget.shapeIndex, size);
          final prevTargets = _getShapePoints(_prevIndex, size);
          return CustomPaint(
            size: size,
            painter: _ParticlePainter(
              particles: _particles,
              targets: targets,
              prevTargets: prevTargets,
              morphProgress: _morphCtrl.value,
              breathe: _breatheCtrl.value,
              isDark: widget.isDark,
            ),
          );
        },
      );
    });
  }
}

class _Particle {
  double x, y, targetX, targetY;
  final double delay, flickerPhase, flickerSpeed;

  _Particle({
    required this.x, required this.y,
    required this.targetX, required this.targetY,
    required this.delay, required this.flickerPhase, required this.flickerSpeed,
  });
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.targets,
    required this.prevTargets,
    required this.morphProgress,
    required this.breathe,
    required this.isDark,
  });

  final List<_Particle> particles;
  final List<Offset> targets;
  final List<Offset> prevTargets;
  final double morphProgress;
  final double breathe;
  final bool isDark;

  double _easeOutQuart(double t) => 1 - pow(1 - t, 4).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final count = min(particles.length, targets.length);
    final prevCount = prevTargets.length;
    final eased = _easeOutQuart(morphProgress);

    final points = <Offset>[];
    final colors = <Color>[];
    final baseColor = isDark ? const Color(0xFFF472B6) : const Color(0xFFEC4899);

    for (int i = 0; i < count; i++) {
      final p = particles[i];
      final target = targets[i];

      // Previous target (wrap around if fewer points)
      final prevTarget = prevCount > 0 ? prevTargets[i % prevCount] : Offset(p.x, p.y);

      // Interpolate from previous to current target
      final tx = prevTarget.dx + (target.dx - prevTarget.dx) * eased;
      final ty = prevTarget.dy + (target.dy - prevTarget.dy) * eased;

      // Smooth movement toward target
      p.x += (tx - p.x) * 0.08;
      p.y += (ty - p.y) * 0.08;

      // Breathing effect
      final breatheOffset = sin(breathe * pi * 2 + p.flickerPhase) * 1.5;
      final px = p.x + breatheOffset * cos(p.flickerPhase);
      final py = p.y + breatheOffset * sin(p.flickerPhase);

      // Alpha with flicker - higher base for visibility
      final flicker = sin(morphProgress * pi * 4 + p.flickerPhase * p.flickerSpeed);
      final alpha = (0.7 + breathe * 0.15 + flicker * 0.1).clamp(0.5, 1.0);

      points.add(Offset(px, py));
      colors.add(baseColor.withValues(alpha: alpha));
    }

    // Draw all particles as dots
    final paint = Paint();
    const dotSize = 2.5;
    for (int i = 0; i < points.length; i++) {
      paint.color = colors[i];
      canvas.drawCircle(points[i], dotSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// Standalone showcase page — NOT integrated into the app shell.
/// View at: Navigator.push(context, MaterialPageRoute(builder: (_) => const UIShowcase()))
class UIShowcase extends StatelessWidget {
  const UIShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0A1A),
      appBar: AppBar(
        title: const Text('UI Showcase', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('🌊 Swipe Trade — Color Wave'),
          const SizedBox(height: 8),
          const _SwipeTradeShowcase(),
          const SizedBox(height: 32),
          _sectionTitle('🏆 Leaderboard — 3D Podium'),
          const SizedBox(height: 8),
          const _PodiumShowcase(),
          const SizedBox(height: 32),
          _sectionTitle('🔥 Live Pulse — Heartbeat'),
          const SizedBox(height: 8),
          const _PulseShowcase(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. SWIPE TRADE — COLOR WAVE
// ─────────────────────────────────────────────────────────────────────────────

class _SwipeTradeShowcase extends StatefulWidget {
  const _SwipeTradeShowcase();
  @override
  State<_SwipeTradeShowcase> createState() => _SwipeTradeShowcaseState();
}

class _SwipeTradeShowcaseState extends State<_SwipeTradeShowcase>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  double _waveProgress = 0; // 0 = neutral, -1 = full NO, 1 = full YES
  bool _triggered = false;
  late AnimationController _resetCtrl;

  @override
  void initState() {
    super.initState();
    _resetCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _resetCtrl.addListener(() {
      setState(() {
        _dragX *= (1 - _resetCtrl.value * 0.15);
        _waveProgress *= (1 - _resetCtrl.value * 0.15);
      });
    });
  }

  @override
  void dispose() {
    _resetCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragX += d.delta.dx;
      _waveProgress = (_dragX / 150).clamp(-1.0, 1.0);
    });
    if (!_triggered && _waveProgress.abs() > 0.7) {
      _triggered = true;
      Haptics.light();
    }
  }

  void _onDragEnd(DragEndDetails d) {
    _triggered = false;
    _resetCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isYes = _waveProgress > 0;
    final intensity = _waveProgress.abs();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            // Color wave from bottom
            AnimatedPositioned(
              duration: const Duration(milliseconds: 50),
              left: 0, right: 0, bottom: 0,
              height: 220 * intensity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      (isYes ? const Color(0xFF2D8A56) : const Color(0xFFC0392B))
                          .withValues(alpha: 0.6 * intensity),
                      (isYes ? const Color(0xFF2D8A56) : const Color(0xFFC0392B))
                          .withValues(alpha: 0.1 * intensity),
                    ],
                  ),
                ),
              ),
            ),
            // Card
            GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: Transform.translate(
                offset: Offset(_dragX * 0.3, 0),
                child: Transform.rotate(
                  angle: _dragX * 0.0005,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131127),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: intensity > 0.3
                            ? (isYes ? const Color(0xFF2D8A56) : const Color(0xFFC0392B))
                                .withValues(alpha: intensity * 0.6)
                            : Colors.white.withValues(alpha: 0.1),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isYes ? const Color(0xFF2D8A56) : const Color(0xFFC0392B))
                              .withValues(alpha: intensity * 0.3),
                          blurRadius: 30 * intensity,
                          offset: Offset(_dragX * 0.1, 0),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D8A56).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('YES 62¢', style: TextStyle(
                                color: Color(0xFF2D8A56), fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC0392B).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('NO 38¢', style: TextStyle(
                                color: Color(0xFFC0392B), fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Will Bitcoin hit \$150K by end of 2026?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Swipe right for YES, left for NO',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Side labels
            if (intensity > 0.2)
              Positioned(
                left: 20,
                top: 0, bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: (!isYes ? intensity : 0).clamp(0.0, 1.0),
                    child: const Text('NO', style: TextStyle(
                      color: Color(0xFFC0392B), fontSize: 28, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            if (intensity > 0.2)
              Positioned(
                right: 20,
                top: 0, bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: (isYes ? intensity : 0).clamp(0.0, 1.0),
                    child: const Text('YES', style: TextStyle(
                      color: Color(0xFF2D8A56), fontSize: 28, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. 3D PODIUM — LEADERBOARD
// ─────────────────────────────────────────────────────────────────────────────

class _PodiumShowcase extends StatelessWidget {
  const _PodiumShowcase();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _podiumPlace(rank: 2, name: '0xa1a6…c856', winRate: '100%', height: 140,
            color: const Color(0xFF94A3B8), avatar: '🦊'),
          const SizedBox(width: 8),
          _podiumPlace(rank: 1, name: 'Pulse 🤖', winRate: '92.3%', height: 190,
            color: const Color(0xFFFBBF24), avatar: '🤖', isCrown: true),
          const SizedBox(width: 8),
          _podiumPlace(rank: 3, name: 'C784', winRate: '90.7%', height: 110,
            color: const Color(0xFFD97706), avatar: '👤'),
        ],
      ),
    );
  }

  Widget _podiumPlace({
    required int rank,
    required String name,
    required String winRate,
    required double height,
    required Color color,
    required String avatar,
    bool isCrown = false,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isCrown)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 28),
          ),
        // Avatar with 3D tilt
        Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateX(-0.15),
          alignment: Alignment.center,
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(avatar, style: const TextStyle(fontSize: 24)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(name, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w700)),
        Text(winRate, style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        // Podium block with 3D perspective
        Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(0.08)
            ..rotateY(rank == 1 ? 0 : (rank == 2 ? -0.05 : 0.05)),
          alignment: Alignment.center,
          child: Container(
            width: 80,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.35),
                  color.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                top: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
                left: BorderSide(color: color.withValues(alpha: 0.2)),
                right: BorderSide(color: color.withValues(alpha: 0.2)),
              ),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. LIVE PULSE — HEARTBEAT ANIMATION
// ─────────────────────────────────────────────────────────────────────────────

class _PulseShowcase extends StatefulWidget {
  const _PulseShowcase();
  @override
  State<_PulseShowcase> createState() => _PulseShowcaseState();
}

class _PulseShowcaseState extends State<_PulseShowcase>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _random = math.Random();
  double _amplitude = 0.6;
  Color _lineColor = const Color(0xFF2D8A56);
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _ctrl.addListener(() => setState(() => _phase = _ctrl.value));
    // Simulate market movement
    _simulateMarket();
  }

  void _simulateMarket() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _amplitude = 0.3 + _random.nextDouble() * 0.7;
        _lineColor = _random.nextBool()
            ? const Color(0xFF2D8A56)
            : const Color(0xFFC0392B);
      });
      _simulateMarket();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF131127),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: CustomPaint(
          size: const Size(double.infinity, 120),
          painter: _PulsePainter(
            phase: _phase,
            amplitude: _amplitude,
            color: _lineColor,
          ),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.phase,
    required this.amplitude,
    required this.color,
  });

  final double phase;
  final double amplitude;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Glow layer
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();
    final glowPath = Path();
    final mid = size.height / 2;
    final w = size.width;

    for (double x = 0; x < w; x += 1) {
      final t = (x / w) + phase;
      final normX = (t % 1.0);

      // Heartbeat waveform: flat → spike → flat → small dip → repeat
      double y;
      if (normX < 0.1) {
        y = 0; // flat
      } else if (normX < 0.15) {
        y = -0.3 * amplitude * ((normX - 0.1) / 0.05); // small up
      } else if (normX < 0.2) {
        y = -0.3 * amplitude + 0.3 * amplitude * ((normX - 0.15) / 0.05);
      } else if (normX < 0.25) {
        y = 0; // flat
      } else if (normX < 0.3) {
        y = -amplitude * ((normX - 0.25) / 0.05); // BIG spike up
      } else if (normX < 0.35) {
        y = -amplitude + amplitude * 1.5 * ((normX - 0.3) / 0.05); // spike down
      } else if (normX < 0.4) {
        y = 0.5 * amplitude - 0.5 * amplitude * ((normX - 0.35) / 0.05); // recovery
      } else if (normX < 0.55) {
        y = 0; // flat
      } else if (normX < 0.6) {
        y = -0.2 * amplitude * ((normX - 0.55) / 0.05); // small bump
      } else if (normX < 0.65) {
        y = -0.2 * amplitude + 0.2 * amplitude * ((normX - 0.6) / 0.05);
      } else {
        y = 0; // flat
      }

      // Add noise
      y += (math.sin(t * 47) * 0.02 + math.sin(t * 123) * 0.01) * amplitude;

      final py = mid + y * (size.height * 0.4);
      if (x == 0) {
        path.moveTo(x, py);
        glowPath.moveTo(x, py);
      } else {
        path.lineTo(x, py);
        glowPath.lineTo(x, py);
      }
    }

    // Draw glow
    glowPaint.color = color.withValues(alpha: 0.3);
    canvas.drawPath(glowPath, glowPaint);

    // Draw main line
    paint.color = color;
    canvas.drawPath(path, paint);

    // Draw leading dot
    final dotX = w * 0.85;
    final dotT = (dotX / w + phase) % 1.0;
    double dotY = 0;
    if (dotT < 0.1) dotY = 0;
    else if (dotT < 0.15) dotY = -0.3 * amplitude * ((dotT - 0.1) / 0.05);
    else if (dotT < 0.2) dotY = -0.3 * amplitude + 0.3 * amplitude * ((dotT - 0.15) / 0.05);
    else if (dotT < 0.25) dotY = 0;
    else if (dotT < 0.3) dotY = -amplitude * ((dotT - 0.25) / 0.05);
    else if (dotT < 0.35) dotY = -amplitude + amplitude * 1.5 * ((dotT - 0.3) / 0.05);
    else if (dotT < 0.4) dotY = 0.5 * amplitude - 0.5 * amplitude * ((dotT - 0.35) / 0.05);
    else if (dotT < 0.55) dotY = 0;
    else if (dotT < 0.6) dotY = -0.2 * amplitude * ((dotT - 0.55) / 0.05);
    else if (dotT < 0.65) dotY = -0.2 * amplitude + 0.2 * amplitude * ((dotT - 0.6) / 0.05);
    else dotY = 0;

    final dotPY = mid + dotY * (size.height * 0.4);

    // Dot glow
    canvas.drawCircle(Offset(dotX, dotPY), 8, Paint()..color = color.withValues(alpha: 0.3));
    canvas.drawCircle(Offset(dotX, dotPY), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) =>
      old.phase != phase || old.amplitude != amplitude || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Haptics helper (standalone, no dependency)
// ─────────────────────────────────────────────────────────────────────────────

class Haptics {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
}

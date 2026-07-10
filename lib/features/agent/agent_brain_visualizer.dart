import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum DecisionSide { yes, no }

class AgentSource {
  const AgentSource({required this.title, required this.url});
  final String title;
  final String url;
}

class AgentDecision {
  const AgentDecision({
    required this.question,
    required this.sources,
    required this.reasoning,
    required this.side,
    this.amountUsdc = 0,
  });

  final String question;
  final List<AgentSource> sources;
  final String reasoning;
  final DecisionSide side;
  final double amountUsdc;
}

class _Brain {
  static const bg = Color(0xFF0D0F12);
  static const brand = Color(0xFF00FF88);
  static const no = Color(0xFFFF3B5C);
  static const dim = Color(0xFF1A1E24);
  static const text = Color(0xFFE8FFF2);
  static const mono = 'monospace';
}

class AgentBrainVisualizer extends StatefulWidget {
  const AgentBrainVisualizer({
    super.key,
    required this.decision,
    this.autoPlay = true,
    this.onComplete,
  });

  final AgentDecision decision;
  final bool autoPlay;
  final VoidCallback? onComplete;

  @override
  State<AgentBrainVisualizer> createState() => _AgentBrainVisualizerState();
}

class _AgentBrainVisualizerState extends State<AgentBrainVisualizer>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _master.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete?.call();
    });

    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _master.forward());
    }
  }

  @override
  void didUpdateWidget(AgentBrainVisualizer old) {
    super.didUpdateWidget(old);
    if (old.decision != widget.decision) {
      _master.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _master.dispose();
    _pulse.dispose();
    super.dispose();
  }

  double get _progress => _master.value;
  double get _ingestProgress => (_progress / 0.3).clamp(0, 1);
  double get _processProgress => ((_progress - 0.3) / 0.4).clamp(0, 1);
  double get _flashProgress => ((_progress - 0.7) / 0.3).clamp(0, 1);

  bool get _isYes => widget.decision.side == DecisionSide.yes;
  Color get _verdictColor => _isYes ? _Brain.brand : _Brain.no;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_master, _pulse]),
      builder: (context, _) {
        final d = widget.decision;
        final flash = Curves.easeOutExpo.transform(_flashProgress);

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _Brain.bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Color.lerp(
                  _Brain.brand.withValues(alpha: 0.15),
                  _verdictColor.withValues(alpha: 0.8),
                  flash,
                )!,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _verdictColor.withValues(alpha: 0.35 * flash),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            // The canvas takes the FULL background for an immersive visualizer.
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FullCanvasPainter(
                      sources: d.sources,
                      ingestion: _ingestProgress,
                      pulse: _pulse.value,
                      processing: _processProgress,
                      flash: flash,
                      verdictColor: _verdictColor,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(d),
                      // Flexible space to allow the background animation to be visible
                      const SizedBox(height: 220),
                      _reasoningTerminal(d),
                      const SizedBox(height: 16),
                      // Slide up animation without clipping limits
                      Opacity(
                        opacity: flash,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - flash)),
                          child: _verdict(d, flash),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(AgentDecision d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.psychology, color: _Brain.brand, size: 16),
            const SizedBox(width: 8),
            Text(
              'AGENT NEURAL NET',
              style: TextStyle(
                fontFamily: _Brain.mono,
                color: _Brain.brand.withValues(alpha: 0.8),
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          d.question,
          style: const TextStyle(
            color: _Brain.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _reasoningTerminal(AgentDecision d) {
    final chars = (d.reasoning.length * Curves.easeInOut.transform(_processProgress)).floor();
    final visible = d.reasoning.substring(0, chars.clamp(0, d.reasoning.length));
    final cursorOn = _processProgress > 0 && _processProgress < 1 && (_pulse.value * 2) % 1 < 0.6;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Brain.brand.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal_rounded, color: _Brain.brand.withValues(alpha: 0.7), size: 14),
                  const SizedBox(width: 8),
                  const Text(
                    'reasoning.log',
                    style: TextStyle(fontFamily: _Brain.mono, color: Colors.white70, fontSize: 11, letterSpacing: 1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontFamily: _Brain.mono, color: _Brain.text, fontSize: 13, height: 1.5),
                    children: [
                      TextSpan(text: visible),
                      TextSpan(
                        text: cursorOn ? '▊' : ' ',
                        style: const TextStyle(color: _Brain.brand),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _verdict(AgentDecision d, double flash) {
    final color = _verdictColor;
    final label = _isYes ? 'YES' : 'NO';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3 * flash),
            blurRadius: 30,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _isYes ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color,
            size: 26,
          ),
          const SizedBox(width: 12),
          Text(
            'BUY $label',
            style: TextStyle(
              fontFamily: _Brain.mono,
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
            ),
          ),
          const Spacer(),
          if (d.amountUsdc > 0)
            Text(
              '\$${d.amountUsdc.toStringAsFixed(2)} USDC',
              style: TextStyle(
                fontFamily: _Brain.mono,
                color: _Brain.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _FullCanvasPainter extends CustomPainter {
  _FullCanvasPainter({
    required this.sources,
    required this.ingestion,
    required this.pulse,
    required this.processing,
    required this.flash,
    required this.verdictColor,
  });

  final List<AgentSource> sources;
  final double ingestion;
  final double pulse;
  final double processing;
  final double flash;
  final Color verdictColor;

  static const _brand = _Brain.brand;

  @override
  void paint(Canvas canvas, Size size) {
    // The visualizer is positioned in the center of the free space above the terminal
    final center = Offset(size.width / 2, size.height * 0.35);
    final coreColor = Color.lerp(_brand, verdictColor, flash)!;

    final n = sources.length.clamp(1, 8);
    final radius = size.width * 0.35;

    // Draw grid background
    _drawGrid(canvas, size);

    // Draw Source Nodes and Data Streams
    for (var i = 0; i < n; i++) {
      final stagger = i / (n * 1.5);
      final localIn = ((ingestion - stagger) / (1 - stagger)).clamp(0.0, 1.0);
      if (localIn <= 0) continue;
      
      final easeIn = Curves.easeOutBack.transform(localIn);
      final angle = (i / n) * math.pi * 2 - math.pi / 2;
      
      final target = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final start = center + Offset(math.cos(angle), math.sin(angle)) * (radius * 2);
      final pos = Offset.lerp(start, target, easeIn)!;

      // Draw Connection Wire
      if (localIn > 0.4) {
        final wireT = Curves.easeInOut.transform(((localIn - 0.4) / 0.6).clamp(0, 1));
        final end = Offset.lerp(pos, center, wireT)!;
        
        final wirePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..shader = LinearGradient(
            colors: [_brand.withValues(alpha: 0.6), _brand.withValues(alpha: 0.1)],
          ).createShader(Rect.fromPoints(pos, center));
          
        canvas.drawLine(pos, end, wirePaint);

        // Draw data pulses along the wire during processing
        if (processing > 0 && processing < 1) {
          final pulsePos = (pulse + i * 0.3) % 1.0;
          final dotPos = Offset.lerp(pos, center, pulsePos)!;
          
          canvas.drawCircle(
            dotPos, 
            3, 
            Paint()..color = _brand.withValues(alpha: 0.8)
                   ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          );
        }
      }

      // Draw Source Node
      canvas.drawCircle(
        pos,
        6,
        Paint()
          ..color = _brand.withValues(alpha: 0.8 * easeIn)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(pos, 3, Paint()..color = Colors.white);
    }

    // Draw Central Core
    if (ingestion > 0.8) {
      final coreSize = 25.0 + 15.0 * pulse + 20.0 * flash;
      
      // Outer glow
      canvas.drawCircle(
        center,
        coreSize * 1.5,
        Paint()
          ..color = coreColor.withValues(alpha: 0.2 + 0.3 * flash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
      
      // Inner core
      canvas.drawCircle(
        center,
        coreSize * 0.6,
        Paint()..color = coreColor,
      );
      
      // Data rings exploding outward during flash
      if (flash > 0) {
        final ringRadius = coreSize + (80 * flash);
        canvas.drawCircle(
          center,
          ringRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * (1 - flash)
            ..color = coreColor.withValues(alpha: 1 - flash),
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
      
    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FullCanvasPainter old) => true;
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Agent Brain Visualizer — cyberpunk visualization of how a Puls AI agent
/// makes a trading decision.
///
/// Three animated phases driven by ONE master AnimationController:
///   Phase 1 (0.00 → 0.35)  Ingestion  — source nodes fly in and wire into a
///                                       central brain core.
///   Phase 2 (0.35 → 0.80)  Processing — typewriter reveal of the reasoning.
///   Phase 3 (0.80 → 1.00)  Decision   — smooth green/red flash + verdict.
///
/// ```dart
/// AgentBrainVisualizer(
///   decision: AgentDecision(
///     question: 'Will BTC close above \$100k this month?',
///     sources: [
///       AgentSource(title: 'CoinDesk — BTC momentum', url: 'coindesk.com'),
///       AgentSource(title: 'Fed minutes summary', url: 'reuters.com'),
///       AgentSource(title: 'On-chain flows', url: 'glassnode.com'),
///     ],
///     reasoning: 'ETF inflows accelerating. Funding rates neutral. '
///         'Macro tailwind from rate-cut odds. Momentum favors upside.',
///     side: DecisionSide.yes,
///     amountUsdc: 42.50,
///   ),
/// )
/// ```
/// ─────────────────────────────────────────────────────────────────────────────

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

/// ── Palette (cyberpunk, per spec) ────────────────────────────────────────────
class _Brain {
  static const bg = Color(0xFF0D0F12);
  static const brand = Color(0xFF00FF88);
  static const no = Color(0xFFFF3B5C);
  static const dim = Color(0xFF1A1E24);
  static const text = Color(0xFFE8FFF2);
  static const textDim = Color(0xFF6B7A72);
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
  /// Master timeline. Phase boundaries at 0.35 / 0.80.
  late final AnimationController _master;

  /// Ambient pulse for the brain core (loops forever, cheap).
  late final AnimationController _pulse;

  /// Decision flash intensity: ramps up then settles, via TweenSequence.
  late final Animation<double> _flash;

  static const _phase1End = 0.35;
  static const _phase2End = 0.80;

  @override
  void initState() {
    super.initState();
    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Flash: 0 → 1 fast, hold, then relax to a steady glow.
    _flash = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutExpo)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.45)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(_phase2End, 1.0),
      ),
    );

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

  void replay() => _master.forward(from: 0);

  double get _ingestion =>
      Curves.easeOutCubic.transform(
          (_master.value / _phase1End).clamp(0.0, 1.0));

  double get _processing => ((_master.value - _phase1End) /
          (_phase2End - _phase1End))
      .clamp(0.0, 1.0);

  bool get _isYes => widget.decision.side == DecisionSide.yes;
  Color get _verdictColor => _isYes ? _Brain.brand : _Brain.no;

  @override
  Widget build(BuildContext context) {
    final d = widget.decision;

    return AnimatedBuilder(
      animation: Listenable.merge([_master, _pulse]),
      builder: (context, _) {
        final flash = _flash.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
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
            child: Stack(
              children: [
                // Decision flash wash over the whole widget.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            _verdictColor.withValues(alpha: 0.16 * flash),
                            _verdictColor.withValues(alpha: 0.03 * flash),
                          ],
                        ),
                      ),
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
                      const SizedBox(height: 16),
                      // Phase 1: neural ingestion canvas.
                      SizedBox(
                        height: 190,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _NeuralPainter(
                            sources: d.sources,
                            ingestion: _ingestion,
                            pulse: _pulse.value,
                            processing: _processing,
                            flash: flash,
                            verdictColor: _verdictColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Phase 2: reasoning terminal.
                      _reasoningTerminal(d),
                      // Phase 3: verdict.
                      ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor:
                              Curves.easeOutCubic.transform(flash.clamp(0, 1)),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _verdict(d, flash),
                          ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _Brain.brand,
            boxShadow: [
              BoxShadow(
                color: _Brain.brand.withValues(
                    alpha: 0.4 + 0.4 * _pulse.value),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AGENT BRAIN // LIVE ANALYSIS',
                style: TextStyle(
                  fontFamily: _Brain.mono,
                  color: _Brain.brand,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                d.question,
                style: const TextStyle(
                  color: _Brain.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reasoningTerminal(AgentDecision d) {
    // Typewriter: reveal N characters of reasoning based on processing phase.
    final chars =
        (d.reasoning.length * Curves.easeInOut.transform(_processing))
            .floor();
    final visible = d.reasoning.substring(0, chars.clamp(0, d.reasoning.length));
    final cursorOn = _processing > 0 &&
        _processing < 1 &&
        (_pulse.value * 2) % 1 < 0.6;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _Brain.brand.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal_rounded,
                      color: _Brain.brand.withValues(alpha: 0.7), size: 13),
                  const SizedBox(width: 6),
                  const Text(
                    'reasoning.log',
                    style: TextStyle(
                      fontFamily: _Brain.mono,
                      color: _Brain.textDim,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fixed min height avoids layout jump while typing.
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: _Brain.mono,
                      color: _Brain.text,
                      fontSize: 12.5,
                      height: 1.55,
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25 * flash),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _isYes
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            'BUY $label',
            style: TextStyle(
              fontFamily: _Brain.mono,
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          if (d.amountUsdc > 0)
            Text(
              '\$${d.amountUsdc.toStringAsFixed(2)} USDC',
              style: TextStyle(
                fontFamily: _Brain.mono,
                color: _Brain.text.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

/// ── Phase 1 painter: sources → brain neural graph ───────────────────────────
class _NeuralPainter extends CustomPainter {
  _NeuralPainter({
    required this.sources,
    required this.ingestion, // 0..1 phase 1 progress
    required this.pulse, // 0..1 ambient loop
    required this.processing, // 0..1 phase 2 progress
    required this.flash, // 0..1 phase 3 intensity
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
    final center = Offset(size.width / 2, size.height / 2);
    final coreColor = Color.lerp(_brand, verdictColor, flash)!;

    // ── Source nodes orbiting positions ──
    final n = sources.length.clamp(1, 8);
    final radius = math.min(size.width, size.height) * 0.42;

    for (var i = 0; i < n; i++) {
      // Per-node staggered entrance within phase 1.
      final stagger = i / (n * 1.6);
      final local =
          ((ingestion - stagger) / (1 - stagger)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final ease = Curves.easeOutBack.transform(local);

      final angle = (i / n) * math.pi * 2 - math.pi / 2;
      // Nodes fly in from beyond the edge toward their orbit slot.
      final target = center +
          Offset(math.cos(angle), math.sin(angle)) * radius;
      final start = center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * 1.9);
      final pos = Offset.lerp(start, target, ease)!;

      // Connection: draws itself from node toward brain once node lands.
      if (local > 0.55) {
        final wireT =
            Curves.easeInOut.transform(((local - 0.55) / 0.45).clamp(0, 1));
        final end = Offset.lerp(pos, center, wireT)!;
        final wire = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = LinearGradient(
            colors: [
              _brand.withValues(alpha: 0.55),
              _brand.withValues(alpha: 0.08),
            ],
          ).createShader(Rect.fromPoints(pos, center));
        canvas.drawLine(pos, end, wire);

        // Data packet traveling along the wire while processing.
        if (processing > 0 && processing < 1) {
          final packetT = ((processing * 3 + i * 0.37) % 1);
          final packet = Offset.lerp(pos, center, packetT)!;
          canvas.drawCircle(
            packet,
            2,
            Paint()
              ..color = _brand.withValues(alpha: 0.9)
              ..maskFilter =
                  const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }

      // Node glow + dot.
      final nodeAlpha = (0.5 + 0.5 * local) *
          (1 - flash * 0.6); // fade slightly during verdict
      canvas.drawCircle(
        pos,
        9,
        Paint()
          ..color = _brand.withValues(alpha: 0.18 * nodeAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        pos,
        3.5,
        Paint()..color = _brand.withValues(alpha: nodeAlpha),
      );

      // Source label (truncated).
      final label = sources[i].title;
      final tp = TextPainter(
        text: TextSpan(
          text: label.length > 18 ? '${label.substring(0, 17)}…' : label,
          style: TextStyle(
            fontFamily: _Brain.mono,
            color: _Brain.textDim.withValues(alpha: nodeAlpha),
            fontSize: 8.5,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 90);
      final labelOffset = pos +
          Offset(
            pos.dx > center.dx ? 8 : -tp.width - 8,
            -tp.height / 2,
          );
      tp.paint(canvas, labelOffset);
    }

    // ── Brain core ──
    final coreVis = Curves.easeOut.transform(ingestion.clamp(0, 1));
    final breathe = 1 + 0.08 * math.sin(pulse * math.pi);
    final coreR = (16 + 6 * processing) * breathe * coreVis;

    // Outer halo.
    canvas.drawCircle(
      center,
      coreR * 2.4,
      Paint()
        ..color = coreColor.withValues(
            alpha: (0.10 + 0.18 * processing + 0.25 * flash) * coreVis)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    // Ring.
    canvas.drawCircle(
      center,
      coreR * 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = coreColor.withValues(alpha: 0.4 * coreVis),
    );
    // Core.
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            coreColor.withValues(alpha: 0.95),
            coreColor.withValues(alpha: 0.25),
          ],
        ).createShader(
            Rect.fromCircle(center: center, radius: coreR)),
    );

    // Brain glyph.
    if (coreVis > 0.5) {
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.psychology_rounded.codePoint),
          style: TextStyle(
            fontFamily: Icons.psychology_rounded.fontFamily,
            fontSize: coreR * 1.1,
            color: _Brain.bg.withValues(alpha: 0.9),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        center - Offset(iconPainter.width / 2, iconPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_NeuralPainter old) =>
      old.ingestion != ingestion ||
      old.pulse != pulse ||
      old.processing != processing ||
      old.flash != flash ||
      old.verdictColor != verdictColor ||
      old.sources != sources;
}

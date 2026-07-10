import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion.dart';
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

class AgentBrainVisualizer extends StatefulWidget {
  const AgentBrainVisualizer({
    required this.decision,
    this.autoPlay = true,
    this.showActions = true,
    this.onDecision,
    this.onComplete,
    super.key,
  });

  final AgentDecision decision;
  final bool autoPlay;
  final bool showActions;
  final ValueChanged<DecisionSide>? onDecision;
  final VoidCallback? onComplete;

  @override
  State<AgentBrainVisualizer> createState() => _AgentBrainVisualizerState();
}

class _AgentBrainVisualizerState extends State<AgentBrainVisualizer>
    with TickerProviderStateMixin {
  static const _background = Color(0xFF030405);
  static const _surface = Color(0xFF0B0D10);
  static const _line = Color(0xFF20242B);
  static const _mint = Color(0xFF31F5B0);
  static const _red = Color(0xFFFF4968);
  static const _text = Color(0xFFF2F7F5);
  static const _muted = Color(0xFF7E8985);

  late final AnimationController _sequence;
  late final AnimationController _pulse;
  late final Animation<double> _decisionReveal;
  bool? _reduceMotion;

  Color get _decisionColor =>
      widget.decision.side == DecisionSide.yes ? _mint : _red;

  @override
  void initState() {
    super.initState();
    _sequence = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..addStatusListener(_handleSequenceStatus);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _decisionReveal = CurvedAnimation(
      parent: _sequence,
      curve: const Interval(0.72, 1, curve: Curves.easeOutBack),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = context.reduceMotion;
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _sequence.value = 1;
      _pulse
        ..stop()
        ..value = 0.5;
    } else {
      _pulse.repeat();
      if (widget.autoPlay && _sequence.isDismissed) {
        _sequence.forward();
      }
    }
  }

  @override
  void didUpdateWidget(AgentBrainVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.decision != widget.decision) {
      if (context.reduceMotion) {
        _sequence.value = 1;
      } else if (widget.autoPlay) {
        _sequence.forward(from: 0);
      }
    }
    if (!oldWidget.autoPlay && widget.autoPlay && _sequence.isDismissed) {
      _sequence.forward();
    }
  }

  void _handleSequenceStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    _sequence
      ..removeStatusListener(_handleSequenceStatus)
      ..dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compact = width < 360;
        final visualHeight = (width * 0.62).clamp(210.0, 310.0).toDouble();

        return RepaintBoundary(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 24,
                    22,
                    compact ? 18 : 24,
                    8,
                  ),
                  child: _header(),
                ),
                SizedBox(
                  height: visualHeight,
                  width: double.infinity,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _BrainPainter(
                        sequence: _sequence,
                        pulse: _pulse,
                        sourceCount: widget.decision.sources.length,
                        decisionSide: widget.decision.side,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 14 : 20,
                    0,
                    compact ? 14 : 20,
                    compact ? 14 : 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _reasoning(),
                      if (widget.showActions) ...[
                        const SizedBox(height: 12),
                        FadeTransition(
                          opacity: _decisionReveal,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.16),
                              end: Offset.zero,
                            ).animate(_decisionReveal),
                            child: _actions(compact),
                          ),
                        ),
                      ],
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

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _mint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 9),
            const Text(
              'AGENT NEURAL ACTIVITY',
              style: TextStyle(
                color: _mint,
                fontFamily: PulsColors.fontSans,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: _sequence,
              builder: (context, child) {
                final complete = _sequence.value >= 0.99;
                return Text(
                  complete ? 'RESOLVED' : 'THINKING',
                  style: TextStyle(
                    color: complete ? _decisionColor : _muted,
                    fontFamily: PulsColors.fontSans,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          widget.decision.question,
          style: const TextStyle(
            color: _text,
            fontFamily: PulsColors.fontSans,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.3,
            letterSpacing: -0.25,
          ),
        ),
      ],
    );
  }

  Widget _reasoning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_sequence, _pulse]),
        builder: (context, _) {
          final process = _unit((_sequence.value - 0.26) / 0.48);
          final count = (widget.decision.reasoning.length *
                  Curves.easeInOutCubic.transform(process))
              .floor()
              .clamp(0, widget.decision.reasoning.length);
          final cursorVisible =
              process > 0 && process < 1 && _pulse.value < 0.62;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'REASONING TRACE',
                style: TextStyle(
                  color: _muted,
                  fontFamily: PulsColors.fontSans,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: widget.decision.reasoning.substring(0, count),
                    ),
                    TextSpan(
                      text: cursorVisible ? '  ▌' : '',
                      style: const TextStyle(color: _mint),
                    ),
                  ],
                ),
                style: const TextStyle(
                  color: _text,
                  fontFamily: PulsColors.fontSans,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.48,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _actions(bool compact) {
    final yes = _decisionButton(DecisionSide.yes);
    final no = _decisionButton(DecisionSide.no);
    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          yes,
          const SizedBox(height: 10),
          no,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: yes),
        const SizedBox(width: 10),
        Expanded(child: no),
      ],
    );
  }

  Widget _decisionButton(DecisionSide side) {
    final selected = widget.decision.side == side;
    final color = side == DecisionSide.yes ? _mint : _red;
    final amount = selected && widget.decision.amountUsdc > 0
        ? ' · \$${widget.decision.amountUsdc.toStringAsFixed(2)}'
        : '';
    return Semantics(
      button: true,
      selected: selected,
      label: '${side.name.toUpperCase()} decision$amount',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDecision == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onDecision?.call(side);
              },
        child: AnimatedContainer(
          duration: context.motionDuration(const Duration(milliseconds: 220)),
          curve: Curves.easeOutCubic,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? color : _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : _line,
              width: selected ? 0 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                side == DecisionSide.yes
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 18,
                color: selected ? _background : color,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${side.name.toUpperCase()}$amount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _background : color,
                    fontFamily: PulsColors.fontSans,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontFeatures: PulsColors.tabularFigures,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrainPainter extends CustomPainter {
  _BrainPainter({
    required this.sequence,
    required this.pulse,
    required this.sourceCount,
    required this.decisionSide,
  }) : super(repaint: Listenable.merge([sequence, pulse]));

  final Animation<double> sequence;
  final Animation<double> pulse;
  final int sourceCount;
  final DecisionSide decisionSide;

  static const _mint = Color(0xFF31F5B0);
  static const _red = Color(0xFFFF4968);
  static const _line = Color(0xFF20242B);

  @override
  void paint(Canvas canvas, Size size) {
    final ingest = _unit(sequence.value / 0.34);
    final process = _unit((sequence.value - 0.24) / 0.5);
    final reveal = _unit((sequence.value - 0.72) / 0.28);
    final decisionColor = decisionSide == DecisionSide.yes ? _mint : _red;
    final coreColor = Color.lerp(_mint, decisionColor, reveal)!;
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final shortest = math.min(size.width, size.height);
    final orbitRadius = shortest * 0.37;
    final nodes = sourceCount.clamp(5, 8);

    _drawOrbit(canvas, center, orbitRadius, process);

    for (var index = 0; index < nodes; index++) {
      final delay = index / nodes * 0.28;
      final entry = _unit((ingest - delay) / (1 - delay));
      if (entry == 0) continue;

      final angle = -math.pi / 2 + index * math.pi * 2 / nodes;
      final wobble = math.sin(pulse.value * math.pi * 2 + index) * 4;
      final node = center +
          Offset(math.cos(angle), math.sin(angle)) * (orbitRadius + wobble);
      final tangent = Offset(-math.sin(angle), math.cos(angle));
      final controlA = Offset.lerp(node, center, 0.34)! + tangent * 24;
      final controlB = Offset.lerp(node, center, 0.68)! - tangent * 18;
      final path = Path()
        ..moveTo(node.dx, node.dy)
        ..cubicTo(
          controlA.dx,
          controlA.dy,
          controlB.dx,
          controlB.dy,
          center.dx,
          center.dy,
        );

      final connectionProgress =
          Curves.easeOutCubic.transform(_unit((entry - 0.28) / 0.72));
      if (connectionProgress > 0) {
        final segment = connectionProgress >= 0.999
            ? path
            : () {
                final metric = path.computeMetrics().first;
                return metric.extractPath(
                  0,
                  metric.length * connectionProgress,
                );
              }();
        final connectionPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              _mint.withValues(alpha: 0.16),
              _mint.withValues(alpha: 0.72),
            ],
          ).createShader(Rect.fromPoints(node, center));
        canvas.drawPath(segment, connectionPaint);

        if (process > 0) {
          for (var particle = 0; particle < 2; particle++) {
            final travel = (pulse.value + index * 0.127 + particle * 0.48) % 1;
            final position = _cubicPoint(
              node,
              controlA,
              controlB,
              center,
              travel,
            );
            final radius = particle == 0 ? 2.6 : 1.7;
            canvas.drawCircle(
              position,
              radius + pulse.value * 0.5,
              Paint()..color = _mint.withValues(alpha: 0.9),
            );
          }
        }
      }

      final scale = Curves.easeOutBack.transform(entry);
      _drawOrganicNode(
        canvas,
        node,
        6.5 * scale,
        index + pulse.value,
        _mint,
      );
    }

    final coreRadius = shortest * 0.085 * (0.92 + pulse.value * 0.13);
    final glowRect = Rect.fromCircle(center: center, radius: coreRadius * 3.4);
    canvas.drawCircle(
      center,
      coreRadius * 3.4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            coreColor.withValues(alpha: 0.28 + reveal * 0.12),
            coreColor.withValues(alpha: 0),
          ],
        ).createShader(glowRect),
    );

    for (var ring = 2; ring >= 0; ring--) {
      _drawOrganicNode(
        canvas,
        center,
        coreRadius * (1 + ring * 0.38),
        pulse.value * 2 + ring,
        Color.lerp(coreColor, Colors.white, ring == 0 ? 0.28 : 0)!,
        fillAlpha: ring == 0 ? 1 : 0.12,
        strokeOnly: ring != 0,
      );
    }

    if (reveal > 0) {
      final ringRadius = coreRadius * (1.4 + reveal * 3.2);
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * (1 - reveal)
          ..color = decisionColor.withValues(alpha: 1 - reveal),
      );
    }
  }

  void _drawOrbit(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _line.withValues(alpha: 0.74);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.68),
      math.pi / 2,
      -math.pi * 1.4 * progress,
      false,
      paint..color = _line.withValues(alpha: 0.42),
    );
  }

  void _drawOrganicNode(
    Canvas canvas,
    Offset center,
    double radius,
    double phase,
    Color color, {
    double fillAlpha = 0.9,
    bool strokeOnly = false,
  }) {
    const points = 10;
    final path = Path();
    for (var index = 0; index < points; index++) {
      final angle = index * math.pi * 2 / points;
      final variance = 1 + math.sin(angle * 3 + phase * math.pi) * 0.09;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * variance;
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = strokeOnly ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: fillAlpha),
    );
  }

  Offset _cubicPoint(
    Offset start,
    Offset controlA,
    Offset controlB,
    Offset end,
    double t,
  ) {
    final inverse = 1 - t;
    return start * (inverse * inverse * inverse) +
        controlA * (3 * inverse * inverse * t) +
        controlB * (3 * inverse * t * t) +
        end * (t * t * t);
  }

  @override
  bool shouldRepaint(covariant _BrainPainter oldDelegate) {
    return oldDelegate.sourceCount != sourceCount ||
        oldDelegate.decisionSide != decisionSide ||
        oldDelegate.sequence != sequence ||
        oldDelegate.pulse != pulse;
  }
}

double _unit(double value) => value.clamp(0.0, 1.0).toDouble();

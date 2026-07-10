import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion.dart';
import '../../core/rendering/fast_trig.dart';
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
  final _renderCache = _BrainRenderCache();
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
                        cache: _renderCache,
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
        animation: _sequence,
        builder: (context, _) {
          final process = _unit((_sequence.value - 0.26) / 0.48);
          final count = (widget.decision.reasoning.length *
                  Curves.easeInOutCubic.transform(process))
              .floor()
              .clamp(0, widget.decision.reasoning.length);
          final cursorVisible = process > 0 && process < 1;
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
    required this.cache,
  }) : super(repaint: Listenable.merge([sequence, pulse]));

  final Animation<double> sequence;
  final Animation<double> pulse;
  final int sourceCount;
  final DecisionSide decisionSide;
  final _BrainRenderCache cache;

  static const _mint = Color(0xFF31F5B0);
  static const _red = Color(0xFFFF4968);
  static const _line = Color(0xFF20242B);

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = sourceCount.clamp(5, 8);
    cache.ensureGeometry(size, nodes);
    final ingest = _unit(sequence.value / 0.34);
    final process = _unit((sequence.value - 0.24) / 0.5);
    final reveal = _unit((sequence.value - 0.72) / 0.28);
    final decisionColor = decisionSide == DecisionSide.yes ? _mint : _red;
    final coreColor = Color.lerp(_mint, decisionColor, reveal)!;

    _drawOrbit(canvas, process);

    var largeParticleCount = 0;
    var smallParticleCount = 0;
    for (var index = 0; index < nodes; index++) {
      final delay = index / nodes * 0.28;
      final entry = _unit((ingest - delay) / (1 - delay));
      if (entry == 0) continue;
      final connection = cache.connections[index];

      final connectionProgress =
          Curves.easeOutCubic.transform(_unit((entry - 0.28) / 0.72));
      if (connectionProgress > 0) {
        final segment = connectionProgress >= 0.999
            ? connection.path
            : connection.metric.extractPath(
                0,
                connection.metric.length * connectionProgress,
              );
        cache.connectionPaint.shader = connection.shader;
        canvas.drawPath(segment, cache.connectionPaint);

        if (process > 0) {
          for (var particle = 0; particle < 2; particle++) {
            final travel = (pulse.value + index * 0.127 + particle * 0.48) % 1;
            final inverse = 1 - travel;
            final inverse2 = inverse * inverse;
            final travel2 = travel * travel;
            final x = connection.start.dx * inverse2 * inverse +
                connection.controlA.dx * 3 * inverse2 * travel +
                connection.controlB.dx * 3 * inverse * travel2 +
                cache.center.dx * travel2 * travel;
            final y = connection.start.dy * inverse2 * inverse +
                connection.controlA.dy * 3 * inverse2 * travel +
                connection.controlB.dy * 3 * inverse * travel2 +
                cache.center.dy * travel2 * travel;
            final target = particle == 0
                ? cache.largeParticlePoints
                : cache.smallParticlePoints;
            final pointIndex =
                particle == 0 ? largeParticleCount++ : smallParticleCount++;
            target[pointIndex * 2] = x;
            target[pointIndex * 2 + 1] = y;
          }
        }
      }

      final nodePulse =
          1 + FastTrig.sinRadians(pulse.value * math.pi * 2 + index) * 0.08;
      final scale = Curves.easeOutBack.transform(entry);
      _drawOrganicNode(
        canvas,
        connection.start,
        6.5 * scale * nodePulse,
        index + pulse.value,
        _mint,
      );
    }

    if (largeParticleCount > 0) {
      final points = largeParticleCount == nodes
          ? cache.largeParticlePoints
          : Float32List.sublistView(
              cache.largeParticlePoints,
              0,
              largeParticleCount * 2,
            );
      canvas.drawRawPoints(
        ui.PointMode.points,
        points,
        cache.largeParticlePaint..strokeWidth = (2.6 + pulse.value * 0.5) * 2,
      );
    }
    if (smallParticleCount > 0) {
      final points = smallParticleCount == nodes
          ? cache.smallParticlePoints
          : Float32List.sublistView(
              cache.smallParticlePoints,
              0,
              smallParticleCount * 2,
            );
      canvas.drawRawPoints(
        ui.PointMode.points,
        points,
        cache.smallParticlePaint..strokeWidth = (1.7 + pulse.value * 0.5) * 2,
      );
    }

    final coreRadius = cache.shortest * 0.085 * (0.92 + pulse.value * 0.13);
    cache.glowPaint.color = coreColor.withValues(alpha: 0.09 + reveal * 0.04);
    for (var glow = 3; glow >= 1; glow--) {
      canvas.drawCircle(
        cache.center,
        coreRadius * (1.2 + glow * 0.72),
        cache.glowPaint
          ..color = coreColor.withValues(
            alpha: (0.055 + reveal * 0.025) * (4 - glow),
          ),
      );
    }

    for (var ring = 2; ring >= 0; ring--) {
      _drawOrganicNode(
        canvas,
        cache.center,
        coreRadius * (1 + ring * 0.38),
        pulse.value * 2 + ring,
        Color.lerp(coreColor, Colors.white, ring == 0 ? 0.28 : 0)!,
        fillAlpha: ring == 0 ? 1 : 0.12,
        strokeOnly: ring != 0,
      );
    }

    if (reveal > 0) {
      final ringRadius = coreRadius * (1.4 + reveal * 3.2);
      cache.revealPaint
        ..strokeWidth = 1.5 * (1 - reveal)
        ..color = decisionColor.withValues(alpha: 1 - reveal);
      canvas.drawCircle(cache.center, ringRadius, cache.revealPaint);
    }
  }

  void _drawOrbit(Canvas canvas, double progress) {
    cache.orbitPaint.color = _line.withValues(alpha: 0.74);
    canvas.drawArc(
      cache.outerOrbit,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      cache.orbitPaint,
    );
    cache.orbitPaint.color = _line.withValues(alpha: 0.42);
    canvas.drawArc(
      cache.innerOrbit,
      math.pi / 2,
      -math.pi * 1.4 * progress,
      false,
      cache.orbitPaint,
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
    final phaseSin = FastTrig.sinRadians(phase * math.pi);
    final phaseCos = FastTrig.cosRadians(phase * math.pi);
    final path = cache.organicPath..reset();
    for (var index = 0; index < _BrainRenderCache.organicPoints; index++) {
      final variance = 1 +
          (cache.harmonicSin[index] * phaseCos +
                  cache.harmonicCos[index] * phaseSin) *
              0.09;
      final pointX = center.dx + cache.unitX[index] * radius * variance;
      final pointY = center.dy + cache.unitY[index] * radius * variance;
      if (index == 0) {
        path.moveTo(pointX, pointY);
      } else {
        path.lineTo(pointX, pointY);
      }
    }
    path.close();
    cache.organicPaint
      ..style = strokeOnly ? PaintingStyle.stroke : PaintingStyle.fill
      ..color = color.withValues(alpha: fillAlpha);
    canvas.drawPath(path, cache.organicPaint);
  }

  @override
  bool shouldRepaint(covariant _BrainPainter oldDelegate) {
    return oldDelegate.sourceCount != sourceCount ||
        oldDelegate.decisionSide != decisionSide ||
        oldDelegate.cache != cache ||
        oldDelegate.sequence != sequence ||
        oldDelegate.pulse != pulse;
  }
}

class _BrainRenderCache {
  static const organicPoints = 10;

  final Float32List unitX = Float32List(organicPoints);
  final Float32List unitY = Float32List(organicPoints);
  final Float32List harmonicSin = Float32List(organicPoints);
  final Float32List harmonicCos = Float32List(organicPoints);
  Float32List largeParticlePoints = Float32List(0);
  Float32List smallParticlePoints = Float32List(0);
  final Path organicPath = Path();
  final Paint connectionPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  final Paint orbitPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint organicPaint = Paint()..strokeWidth = 1.2;
  final Paint glowPaint = Paint();
  final Paint revealPaint = Paint()..style = PaintingStyle.stroke;
  final Paint largeParticlePaint = Paint()
    ..color = _BrainPainter._mint.withValues(alpha: 0.9)
    ..strokeCap = StrokeCap.round;
  final Paint smallParticlePaint = Paint()
    ..color = _BrainPainter._mint.withValues(alpha: 0.9)
    ..strokeCap = StrokeCap.round;

  List<_BrainConnection> connections = const [];
  Size _size = Size.zero;
  int _nodes = 0;
  Offset center = Offset.zero;
  double shortest = 0;
  Rect outerOrbit = Rect.zero;
  Rect innerOrbit = Rect.zero;

  _BrainRenderCache() {
    for (var index = 0; index < organicPoints; index++) {
      final angle = index * math.pi * 2 / organicPoints;
      unitX[index] = FastTrig.cosRadians(angle);
      unitY[index] = FastTrig.sinRadians(angle);
      harmonicSin[index] = FastTrig.sinRadians(angle * 3);
      harmonicCos[index] = FastTrig.cosRadians(angle * 3);
    }
  }

  void ensureGeometry(Size size, int nodes) {
    if (_size == size && _nodes == nodes) return;
    _size = size;
    _nodes = nodes;
    largeParticlePoints = Float32List(nodes * 2);
    smallParticlePoints = Float32List(nodes * 2);
    center = Offset(size.width * 0.5, size.height * 0.5);
    shortest = math.min(size.width, size.height);
    final orbitRadius = shortest * 0.37;
    outerOrbit = Rect.fromCircle(center: center, radius: orbitRadius);
    innerOrbit = Rect.fromCircle(center: center, radius: orbitRadius * 0.68);
    connections = List<_BrainConnection>.generate(
      nodes,
      (index) {
        final angle = -math.pi / 2 + index * math.pi * 2 / nodes;
        final angleCos = FastTrig.cosRadians(angle);
        final angleSin = FastTrig.sinRadians(angle);
        final start = Offset(
          center.dx + angleCos * orbitRadius,
          center.dy + angleSin * orbitRadius,
        );
        final tangentX = -angleSin;
        final tangentY = angleCos;
        final controlA = Offset(
          start.dx + (center.dx - start.dx) * 0.34 + tangentX * 24,
          start.dy + (center.dy - start.dy) * 0.34 + tangentY * 24,
        );
        final controlB = Offset(
          start.dx + (center.dx - start.dx) * 0.68 - tangentX * 18,
          start.dy + (center.dy - start.dy) * 0.68 - tangentY * 18,
        );
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(
            controlA.dx,
            controlA.dy,
            controlB.dx,
            controlB.dy,
            center.dx,
            center.dy,
          );
        return _BrainConnection(
          start: start,
          controlA: controlA,
          controlB: controlB,
          path: path,
          metric: path.computeMetrics().first,
          shader: LinearGradient(
            colors: [
              _BrainPainter._mint.withValues(alpha: 0.16),
              _BrainPainter._mint.withValues(alpha: 0.72),
            ],
          ).createShader(Rect.fromPoints(start, center)),
        );
      },
      growable: false,
    );
  }
}

class _BrainConnection {
  const _BrainConnection({
    required this.start,
    required this.controlA,
    required this.controlB,
    required this.path,
    required this.metric,
    required this.shader,
  });

  final Offset start;
  final Offset controlA;
  final Offset controlB;
  final Path path;
  final ui.PathMetric metric;
  final Shader shader;
}

double _unit(double value) => value.clamp(0.0, 1.0).toDouble();

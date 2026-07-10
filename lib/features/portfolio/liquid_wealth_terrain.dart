import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/count_up_text.dart';

class LiquidWealthTerrain extends StatefulWidget {
  const LiquidWealthTerrain({
    required this.pnlUsdc,
    this.portfolioHistory = const [],
    this.pnlRange = 100,
    this.height = 360,
    this.title = 'LIQUID WEALTH',
    this.positiveColor = const Color(0xFF31F5B0),
    this.negativeColor = const Color(0xFFFF4968),
    super.key,
  });

  final double pnlUsdc;
  final List<double> portfolioHistory;
  final double pnlRange;
  final double height;
  final String title;
  final Color positiveColor;
  final Color negativeColor;

  @override
  State<LiquidWealthTerrain> createState() => _LiquidWealthTerrainState();
}

class _LiquidWealthTerrainState extends State<LiquidWealthTerrain>
    with TickerProviderStateMixin {
  static const _background = Color(0xFF030405);
  static const _surface = Color(0xFF090B0D);
  static const _line = Color(0xFF20252C);
  static const _muted = Color(0xFF7F8986);

  final _interaction = _TerrainInteraction();
  final _clock = Stopwatch()..start();
  late final AnimationController _time;
  late final AnimationController _pnlTransition;
  late final AnimationController _inertia;
  double _fromPnl = 0;
  double _targetPnl = 0;
  double _inertiaStartYaw = 0;
  double _inertiaStartPitch = 0;
  double _inertiaEndYaw = 0;
  double _inertiaEndPitch = 0;
  Offset? _lastRipplePosition;
  Size _viewport = Size.zero;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _targetPnl = widget.pnlUsdc;
    _time = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _pnlTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..value = 1;
    _inertia = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    )..addListener(_applyInertia);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = context.reduceMotion;
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _time
        ..stop()
        ..value = 0.35;
      _pnlTransition.value = 1;
      _inertia.stop();
    } else {
      _time.repeat();
    }
  }

  @override
  void didUpdateWidget(LiquidWealthTerrain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pnlUsdc != widget.pnlUsdc) {
      final transition = Curves.easeInOutCubic.transform(_pnlTransition.value);
      _fromPnl = _lerp(_fromPnl, _targetPnl, transition);
      _targetPnl = widget.pnlUsdc;
      if (context.reduceMotion) {
        _pnlTransition.value = 1;
      } else {
        _pnlTransition.forward(from: 0);
      }
    }
  }

  void _applyInertia() {
    final t = Curves.easeOutCubic.transform(_inertia.value);
    _interaction
      ..yaw = _lerp(_inertiaStartYaw, _inertiaEndYaw, t)
      ..pitch = _lerp(_inertiaStartPitch, _inertiaEndPitch, t);
  }

  void _panStart(DragStartDetails details) {
    _inertia.stop();
    _lastRipplePosition = details.localPosition;
    _addRipple(details.localPosition);
  }

  void _panUpdate(DragUpdateDetails details) {
    _interaction
      ..yaw += details.delta.dx * 0.007
      ..pitch = (_interaction.pitch + details.delta.dy * 0.004)
          .clamp(-1.08, -0.24)
          .toDouble()
      ..notify();

    final previous = _lastRipplePosition;
    if (previous == null ||
        (details.localPosition - previous).distanceSquared > 324) {
      _lastRipplePosition = details.localPosition;
      _addRipple(details.localPosition);
    }
  }

  void _panEnd(DragEndDetails details) {
    _lastRipplePosition = null;
    if (context.reduceMotion) return;
    final velocity = details.velocity.pixelsPerSecond;
    _inertiaStartYaw = _interaction.yaw;
    _inertiaStartPitch = _interaction.pitch;
    _inertiaEndYaw = _interaction.yaw + velocity.dx * 0.00024;
    _inertiaEndPitch =
        (_interaction.pitch + velocity.dy * 0.00009).clamp(-1.08, -0.24);
    _inertia.forward(from: 0);
  }

  void _addRipple(Offset position) {
    if (_viewport.isEmpty) return;
    _interaction.addRipple(
      _TerrainRipple(
        x: (position.dx / _viewport.width * 2 - 1).clamp(-1.0, 1.0),
        z: (position.dy / _viewport.height * 2 - 1).clamp(-1.0, 1.0),
        bornAt: _clock.elapsedMicroseconds / Duration.microsecondsPerSecond,
      ),
      _clock.elapsedMicroseconds / Duration.microsecondsPerSecond,
    );
  }

  @override
  void dispose() {
    _time.dispose();
    _pnlTransition.dispose();
    _inertia
      ..removeListener(_applyInertia)
      ..dispose();
    _interaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final positive = widget.pnlUsdc >= 0;
    final pnlColor = positive ? widget.positiveColor : widget.negativeColor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        _viewport = Size(width, widget.height);
        return RepaintBoundary(
          child: Semantics(
            label:
                '${widget.title}, portfolio PNL ${widget.pnlUsdc.toStringAsFixed(2)} USDC. Swipe to rotate.',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _panStart,
              onPanUpdate: _panUpdate,
              onPanEnd: _panEnd,
              child: Container(
                width: double.infinity,
                height: widget.height,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _background,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _line),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _TerrainPainter(
                            time: _time,
                            pnlTransition: _pnlTransition,
                            inertia: _inertia,
                            interaction: _interaction,
                            clock: _clock,
                            fromPnl: _fromPnl,
                            targetPnl: _targetPnl,
                            pnlRange: widget.pnlRange,
                            history: widget.portfolioHistory,
                            positiveColor: widget.positiveColor,
                            negativeColor: widget.negativeColor,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 18,
                      right: 20,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontFamily: PulsColors.fontSans,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                CountUpText(
                                  widget.pnlUsdc,
                                  duration: context.motionDuration(
                                    const Duration(milliseconds: 760),
                                  ),
                                  builder: (context, value) => Text(
                                    '${value >= 0 ? '+' : '−'}\$${value.abs().toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: pnlColor,
                                      fontFamily: PulsColors.fontSans,
                                      fontSize: 27,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.8,
                                      fontFeatures: PulsColors.tabularFigures,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: _line),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  positive
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  color: pnlColor,
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  positive ? 'PROFIT' : 'DRAWDOWN',
                                  style: TextStyle(
                                    color: pnlColor,
                                    fontFamily: PulsColors.fontSans,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      left: 20,
                      bottom: 17,
                      child: Row(
                        children: [
                          Icon(
                            Icons.swipe_rounded,
                            size: 14,
                            color: _muted,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'SWIPE TO SHAPE THE FIELD',
                            style: TextStyle(
                              color: _muted,
                              fontFamily: PulsColors.fontSans,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TerrainPainter extends CustomPainter {
  _TerrainPainter({
    required this.time,
    required this.pnlTransition,
    required this.inertia,
    required this.interaction,
    required this.clock,
    required this.fromPnl,
    required this.targetPnl,
    required this.pnlRange,
    required this.history,
    required this.positiveColor,
    required this.negativeColor,
  }) : super(
          repaint: Listenable.merge([
            time,
            pnlTransition,
            inertia,
            interaction,
          ]),
        );

  static const _columns = 28;
  static const _rows = 18;
  static const _neutral = Color(0xFF5E6972);
  static const _grid = Color(0xFF273039);

  final Animation<double> time;
  final Animation<double> pnlTransition;
  final Animation<double> inertia;
  final _TerrainInteraction interaction;
  final Stopwatch clock;
  final double fromPnl;
  final double targetPnl;
  final double pnlRange;
  final List<double> history;
  final Color positiveColor;
  final Color negativeColor;
  late final double _historyMagnitude =
      history.fold<double>(0, (max, value) => math.max(max, value.abs()));
  final List<Offset> _points =
      List<Offset>.filled(_columns * _rows, Offset.zero);

  @override
  void paint(Canvas canvas, Size size) {
    final transition = Curves.easeInOutCubic.transform(pnlTransition.value);
    final pnl = _lerp(fromPnl, targetPnl, transition);
    final normalizedPnl =
        pnlRange <= 0 ? 0.0 : (pnl / pnlRange).clamp(-1.0, 1.0).toDouble();
    final magnitude = normalizedPnl.abs();
    final accent = normalizedPnl >= 0
        ? Color.lerp(_neutral, positiveColor, magnitude)!
        : Color.lerp(_neutral, negativeColor, magnitude)!;
    final phase = time.value * math.pi * 2;
    final now = clock.elapsedMicroseconds / Duration.microsecondsPerSecond;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.2, -0.1),
          radius: 1.2,
          colors: [
            accent.withValues(alpha: 0.13),
            const Color(0xFF030405),
          ],
        ).createShader(Offset.zero & size),
    );

    final cosYaw = math.cos(interaction.yaw);
    final sinYaw = math.sin(interaction.yaw);
    final cosPitch = math.cos(interaction.pitch);
    final sinPitch = math.sin(interaction.pitch);

    for (var row = 0; row < _rows; row++) {
      final z = -1 + row * 2 / (_rows - 1);
      for (var column = 0; column < _columns; column++) {
        final x = -1 + column * 2 / (_columns - 1);
        final height = _heightAt(
          x,
          z,
          phase,
          normalizedPnl,
          now,
        );
        _points[row * _columns + column] = _project(
          x,
          height,
          z,
          size,
          cosYaw,
          sinYaw,
          cosPitch,
          sinPitch,
        );
      }
    }

    for (var row = 0; row < _rows - 1; row++) {
      final strip = Path()
        ..moveTo(
          _points[row * _columns].dx,
          _points[row * _columns].dy,
        );
      for (var column = 1; column < _columns; column++) {
        final point = _points[row * _columns + column];
        strip.lineTo(point.dx, point.dy);
      }
      for (var column = _columns - 1; column >= 0; column--) {
        final point = _points[(row + 1) * _columns + column];
        strip.lineTo(point.dx, point.dy);
      }
      strip.close();
      canvas.drawPath(
        strip,
        Paint()
          ..color = accent.withValues(
            alpha: 0.018 + row / _rows * 0.055,
          ),
      );
    }

    final horizontalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent.withValues(alpha: 0.38);
    for (var row = 0; row < _rows; row++) {
      final path = Path();
      for (var column = 0; column < _columns; column++) {
        final point = _points[row * _columns + column];
        if (column == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, horizontalPaint);
    }

    final verticalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _grid.withValues(alpha: 0.76);
    for (var column = 0; column < _columns; column += 2) {
      final path = Path();
      for (var row = 0; row < _rows; row++) {
        final point = _points[row * _columns + column];
        if (row == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, verticalPaint);
    }

    final ridgeRow = (_rows * 0.54).round().clamp(0, _rows - 1);
    final ridge = Path();
    for (var column = 0; column < _columns; column++) {
      final point = _points[ridgeRow * _columns + column];
      if (column == 0) {
        ridge.moveTo(point.dx, point.dy);
      } else {
        ridge.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      ridge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.95),
    );
  }

  double _heightAt(
    double x,
    double z,
    double phase,
    double normalizedPnl,
    double now,
  ) {
    final amplitude = 0.07 + normalizedPnl.abs() * 0.065;
    final primary = math.sin(x * math.pi * 2.1 + phase + z * 1.6) * amplitude;
    final secondary =
        math.cos(z * math.pi * 2.4 - phase * 0.72 + x) * amplitude * 0.58;
    final historyLift = _historyAt((x + 1) * 0.5) * 0.13;
    var rippleHeight = 0.0;
    for (final ripple in interaction.ripples) {
      final age = now - ripple.bornAt;
      if (age < 0 || age > 2.6) continue;
      final dx = x - ripple.x;
      final dz = z - ripple.z;
      final distance = math.sqrt(dx * dx + dz * dz);
      rippleHeight += math.sin(distance * 18 - age * 10) *
          math.exp(-distance * 2.3) *
          math.exp(-age * 1.55) *
          0.13;
    }
    return primary +
        secondary +
        historyLift +
        normalizedPnl * 0.16 +
        rippleHeight;
  }

  double _historyAt(double position) {
    if (history.isEmpty) return 0;
    if (history.length == 1) return history.first.sign;
    if (_historyMagnitude == 0) return 0;
    final scaled = position.clamp(0.0, 1.0) * (history.length - 1);
    final left = scaled.floor();
    final right = math.min(history.length - 1, left + 1);
    final t = scaled - left;
    return _lerp(history[left], history[right], t) / _historyMagnitude;
  }

  Offset _project(
    double x,
    double y,
    double z,
    Size size,
    double cosYaw,
    double sinYaw,
    double cosPitch,
    double sinPitch,
  ) {
    final rotatedX = x * cosYaw - z * sinYaw;
    final yawDepth = x * sinYaw + z * cosYaw;
    final rotatedY = y * cosPitch - yawDepth * sinPitch;
    final depth = y * sinPitch + yawDepth * cosPitch;
    final perspective = 1.28 / (3.25 + depth);
    return Offset(
      size.width * 0.5 + rotatedX * size.width * 0.94 * perspective,
      size.height * 0.58 - rotatedY * size.height * 1.42 * perspective,
    );
  }

  @override
  bool shouldRepaint(covariant _TerrainPainter oldDelegate) {
    return oldDelegate.fromPnl != fromPnl ||
        oldDelegate.targetPnl != targetPnl ||
        oldDelegate.pnlRange != pnlRange ||
        oldDelegate.history != history ||
        oldDelegate.positiveColor != positiveColor ||
        oldDelegate.negativeColor != negativeColor ||
        oldDelegate.time != time ||
        oldDelegate.pnlTransition != pnlTransition ||
        oldDelegate.inertia != inertia ||
        oldDelegate.interaction != interaction;
  }
}

class _TerrainInteraction extends ChangeNotifier {
  double yaw = -0.18;
  double pitch = -0.64;
  final List<_TerrainRipple> ripples = [];

  void addRipple(_TerrainRipple ripple, double now) {
    ripples
      ..removeWhere((item) => now - item.bornAt > 2.6)
      ..add(ripple);
    if (ripples.length > 8) {
      ripples.removeRange(0, ripples.length - 8);
    }
    notifyListeners();
  }

  void notify() => notifyListeners();
}

class _TerrainRipple {
  const _TerrainRipple({
    required this.x,
    required this.z,
    required this.bornAt,
  });

  final double x;
  final double z;
  final double bornAt;
}

double _lerp(double start, double end, double t) => start + (end - start) * t;

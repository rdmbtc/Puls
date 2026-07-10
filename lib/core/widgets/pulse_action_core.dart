import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion.dart';
import '../rendering/fast_trig.dart';
import '../theme/app_theme.dart';

@immutable
class PulseQuickAction {
  const PulseQuickAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final Color? color;
}

class PulseActionCore extends StatefulWidget {
  const PulseActionCore({
    required this.onPulse,
    this.actions = const [],
    this.icon = Icons.bolt_rounded,
    this.semanticLabel = 'Pulse action',
    this.orbSize = 76,
    this.maxExpandedWidth = 340,
    super.key,
  });

  final VoidCallback onPulse;
  final List<PulseQuickAction> actions;
  final IconData icon;
  final String semanticLabel;
  final double orbSize;
  final double maxExpandedWidth;

  @override
  State<PulseActionCore> createState() => _PulseActionCoreState();
}

class _PulseActionCoreState extends State<PulseActionCore>
    with TickerProviderStateMixin {
  static const _background = Color(0xFF030405);
  static const _mint = Color(0xFF31F5B0);
  static const _pink = Color(0xFFFF4FA3);
  static const _text = Color(0xFFF8FAF9);

  late final AnimationController _breath;
  late final AnimationController _morph;
  late final AnimationController _particles;
  late final Animation<double> _morphCurve;
  late final List<_ParticleSeed> _particleSeeds;
  late final Listenable _coreListenable;
  final _interaction = _PulseInteraction();
  bool? _reduceMotion;
  double _panelWidth = 0;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _particles = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _morphCurve = CurvedAnimation(
      parent: _morph,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _coreListenable = Listenable.merge([_breath, _morph, _interaction]);
    final random = math.Random(41);
    _particleSeeds = List.generate(
      24,
      (_) {
        final angle = -math.pi + random.nextDouble() * math.pi * 2;
        final radius = 1.4 + random.nextDouble() * 2.5;
        return _ParticleSeed(
          directionX: math.cos(angle),
          directionY: math.sin(angle),
          speed: 36 + random.nextDouble() * 82,
          spin: random.nextDouble() * math.pi * 2,
          shape: RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: radius * 2.4,
              height: radius,
            ),
            Radius.circular(radius),
          ),
          color: Color.lerp(_mint, _pink, random.nextDouble())!,
        );
      },
      growable: false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = context.reduceMotion;
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _breath
        ..stop()
        ..value = 0.5;
    } else if (!_interaction.expanded) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseActionCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activeAction = _interaction.activeAction;
    if (activeAction != null && activeAction >= widget.actions.length) {
      _interaction.setActiveAction(null);
    }
  }

  void _tapDown(TapDownDetails details) {
    _interaction.setPressed(true);
  }

  void _tapUp(TapUpDetails details) {
    _interaction.setPressed(false);
  }

  void _tapCancel() => _interaction.setPressed(false);

  void _tap() {
    HapticFeedback.lightImpact();
    widget.onPulse();
  }

  void _longPressStart(LongPressStartDetails details) {
    if (widget.actions.isEmpty) return;
    HapticFeedback.mediumImpact();
    _interaction.expand();
    _breath.stop();
    if (context.reduceMotion) {
      _morph.value = 1;
    } else {
      _morph.forward();
    }
  }

  void _longPressMove(LongPressMoveUpdateDetails details) {
    if (!_interaction.expanded || widget.actions.isEmpty || _panelWidth <= 0) {
      return;
    }
    final normalized =
        (details.localPosition.dx / _panelWidth).clamp(0.0, 0.9999);
    final index = (normalized * widget.actions.length).floor();
    if (index == _interaction.activeAction) return;
    HapticFeedback.selectionClick();
    _interaction.setActiveAction(index);
  }

  void _longPressEnd(LongPressEndDetails details) {
    if (!_interaction.expanded) return;
    final selected = _interaction.activeAction;
    final particleOriginX = selected == null
        ? 0.5
        : (selected + 0.5) / math.max(1, widget.actions.length);
    _interaction.setParticleOrigin(particleOriginX);
    HapticFeedback.heavyImpact();
    if (selected != null && selected < widget.actions.length) {
      widget.actions[selected].onSelected();
    }
    if (!context.reduceMotion) {
      _particles.forward(from: 0);
    }
    _collapse();
  }

  void _longPressCancel() {
    if (!_interaction.expanded) return;
    _collapse();
  }

  void _collapse() {
    _interaction.collapse();
    if (context.reduceMotion) {
      _morph.value = 0;
    } else {
      _morph.reverse();
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _morph.dispose();
    _particles.dispose();
    _interaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : widget.maxExpandedWidth;
        final actionWidth = math
            .max(widget.orbSize, widget.actions.length * 84 + 24)
            .toDouble();
        final expandedWidth = math
            .min(
              widget.maxExpandedWidth,
              math.min(availableWidth, actionWidth),
            )
            .toDouble();
        _panelWidth = expandedWidth;

        return SizedBox(
          width: expandedWidth,
          height: widget.orbSize + 74,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _ParticlePainter(
                        progress: _particles,
                        seeds: _particleSeeds,
                        interaction: _interaction,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _tapDown,
                onTapUp: _tapUp,
                onTapCancel: _tapCancel,
                onTap: _tap,
                onLongPressStart:
                    widget.actions.isEmpty ? null : _longPressStart,
                onLongPressMoveUpdate:
                    widget.actions.isEmpty ? null : _longPressMove,
                onLongPressEnd: widget.actions.isEmpty ? null : _longPressEnd,
                onLongPressCancel:
                    widget.actions.isEmpty ? null : _longPressCancel,
                child: AnimatedBuilder(
                  animation: _coreListenable,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _CoreShapePainter(
                        morph: _morphCurve,
                        breath: _breath,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FadeTransition(
                            opacity: ReverseAnimation(_morphCurve),
                            child: Center(
                              child: Icon(
                                widget.icon,
                                color: _background,
                                size: widget.orbSize * 0.38,
                              ),
                            ),
                          ),
                          FadeTransition(
                            opacity: _morphCurve,
                            child: AnimatedBuilder(
                              animation: _interaction,
                              builder: (context, child) => _actionPanel(
                                _interaction.activeAction,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  builder: (context, child) {
                    final breath =
                        Curves.easeInOutSine.transform(_breath.value);
                    final pressedScale = _interaction.pressed ? 0.92 : 1.0;
                    final scale = pressedScale *
                        (1 + (1 - _morph.value) * breath * 0.035);
                    final width = _lerp(
                      widget.orbSize,
                      expandedWidth,
                      _morphCurve.value,
                    );
                    return Semantics(
                      button: true,
                      expanded: _interaction.expanded,
                      label: widget.semanticLabel,
                      child: Transform.scale(
                        scale: context.reduceMotion ? 1 : scale,
                        child: SizedBox(
                          width: width,
                          height: widget.orbSize,
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionPanel(int? activeAction) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          for (var index = 0; index < widget.actions.length; index++)
            Expanded(
              child: AnimatedContainer(
                duration:
                    context.motionDuration(const Duration(milliseconds: 120)),
                curve: Curves.easeOutCubic,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: activeAction == index
                      ? _background.withValues(alpha: 0.92)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.actions[index].icon,
                      size: 19,
                      color: activeAction == index
                          ? (widget.actions[index].color ?? _mint)
                          : _background,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.actions[index].label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: activeAction == index ? _text : _background,
                        fontFamily: PulsColors.fontSans,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoreShapePainter extends CustomPainter {
  _CoreShapePainter({
    required this.morph,
    required this.breath,
  }) : super(repaint: Listenable.merge([morph, breath]));

  final Animation<double> morph;
  final Animation<double> breath;

  static const _mint = Color(0xFF31F5B0);
  static const _pink = Color(0xFFFF4FA3);
  final Path _path = Path();
  final Paint _fillPaint = Paint();
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Colors.white.withValues(alpha: 0.34);
  Size _shaderSize = Size.zero;

  @override
  void paint(Canvas canvas, Size size) {
    final t = morph.value;
    final undulation = FastTrig.sinTurns(breath.value) * (1 - t) * 1.6;
    final radius = size.height * 0.5;
    final corner = _lerp(radius, 24, t);
    const left = 0.0;
    final right = size.width;
    const top = 0.0;
    final bottom = size.height;
    final shoulder = _lerp(radius * 0.56, corner * 0.62, t);

    _path
      ..reset()
      ..moveTo(left + corner, top + undulation)
      ..cubicTo(
        left + shoulder,
        top - undulation,
        right - shoulder,
        top + undulation,
        right - corner,
        top,
      )
      ..quadraticBezierTo(right, top, right, top + corner)
      ..cubicTo(
        right + undulation,
        top + radius * 0.72,
        right - undulation,
        bottom - radius * 0.72,
        right,
        bottom - corner,
      )
      ..quadraticBezierTo(right, bottom, right - corner, bottom)
      ..cubicTo(
        right - shoulder,
        bottom + undulation,
        left + shoulder,
        bottom - undulation,
        left + corner,
        bottom,
      )
      ..quadraticBezierTo(left, bottom, left, bottom - corner)
      ..cubicTo(
        left - undulation,
        bottom - radius * 0.72,
        left + undulation,
        top + radius * 0.72,
        left,
        top + corner,
      )
      ..quadraticBezierTo(left, top, left + corner, top + undulation)
      ..close();

    final breathValue = Curves.easeInOutSine.transform(breath.value);
    canvas.drawShadow(
      _path,
      _mint.withValues(alpha: 0.2 + breathValue * 0.14),
      12 + breathValue * 8,
      true,
    );
    canvas.drawShadow(
      _path,
      _pink.withValues(alpha: 0.12 + breathValue * 0.08),
      18 + breathValue * 6,
      true,
    );
    if (_shaderSize != size) {
      _shaderSize = size;
      _fillPaint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_mint, Color(0xFF76FFD1), _pink],
        stops: [0, 0.54, 1],
      ).createShader(Offset.zero & size);
    }
    canvas
      ..drawPath(_path, _fillPaint)
      ..drawPath(_path, _strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CoreShapePainter oldDelegate) {
    return oldDelegate.morph != morph || oldDelegate.breath != breath;
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.progress,
    required this.seeds,
    required this.interaction,
  }) : super(repaint: Listenable.merge([progress, interaction]));

  final Animation<double> progress;
  final List<_ParticleSeed> seeds;
  final _PulseInteraction interaction;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (progress.value == 0 || progress.value == 1) return;
    final t = Curves.easeOutCubic.transform(progress.value);
    final originX = size.width * interaction.particleOriginX;
    final originY = size.height * 0.5;
    final gravity = 34 * progress.value * progress.value;
    final fade = (1 - progress.value).clamp(0.0, 1.0).toDouble();
    for (final seed in seeds) {
      final distance = seed.speed * t;
      _paint.color = seed.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(
        originX + seed.directionX * distance,
        originY + seed.directionY * distance + gravity,
      );
      canvas.rotate(seed.spin * t);
      canvas.drawRRect(seed.shape, _paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.seeds != seeds ||
        oldDelegate.interaction != interaction;
  }
}

class _ParticleSeed {
  const _ParticleSeed({
    required this.directionX,
    required this.directionY,
    required this.speed,
    required this.spin,
    required this.shape,
    required this.color,
  });

  final double directionX;
  final double directionY;
  final double speed;
  final double spin;
  final RRect shape;
  final Color color;
}

class _PulseInteraction extends ChangeNotifier {
  bool pressed = false;
  bool expanded = false;
  int? activeAction;
  double particleOriginX = 0.5;

  void setPressed(bool value) {
    if (pressed == value) return;
    pressed = value;
    notifyListeners();
  }

  void expand() {
    pressed = false;
    expanded = true;
    activeAction = null;
    notifyListeners();
  }

  void collapse() {
    expanded = false;
    activeAction = null;
    notifyListeners();
  }

  void setActiveAction(int? value) {
    if (activeAction == value) return;
    activeAction = value;
    notifyListeners();
  }

  void setParticleOrigin(double value) {
    if (particleOriginX == value) return;
    particleOriginX = value;
    notifyListeners();
  }
}

double _lerp(double start, double end, double t) => start + (end - start) * t;

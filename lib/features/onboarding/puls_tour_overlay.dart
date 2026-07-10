import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Puls Tour — a custom, beautiful showcase/coach-mark system.
///
/// Usage:
/// ```dart
/// final tour = TourController(steps: [
///   TourStep(
///     key: swarmKey,
///     title: 'The Swarm',
///     description: 'Autonomous AI agents research, debate and trade '
///         'prediction markets 24/7 — every move is on-chain.',
///   ),
///   TourStep(
///     key: gasKey,
///     title: 'USDC Gas',
///     description: 'Everything on Puls runs on USDC on Arc. No native gas '
///         'token, no bridging headaches — just dollars.',
///   ),
///   TourStep(
///     key: marketKey,
///     title: 'Trade',
///     description: 'Tap any market to buy YES or NO shares. Prices are '
///         'live probabilities set by the crowd and the swarm.',
///   ),
/// ]);
/// tour.start(context);
/// ```
/// ─────────────────────────────────────────────────────────────────────────────

/// One step of the tour. Provide either a [key] (of a rendered widget) or an
/// explicit [rect] in global coordinates.
class TourStep {
  const TourStep({
    required this.title,
    required this.description,
    this.key,
    this.rect,
    this.borderRadius = 16,
    this.padding = 8,
  }) : assert(key != null || rect != null, 'Provide a key or a rect');

  final String title;
  final String description;
  final GlobalKey? key;
  final Rect? rect;

  /// Corner radius of the cutout around the target.
  final double borderRadius;

  /// Extra breathing room around the target bounds.
  final double padding;

  /// Resolves the highlight rect in global coordinates.
  Rect? resolveRect() {
    if (rect != null) return rect!.inflate(padding);
    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final origin = box.localToGlobal(Offset.zero);
    return (origin & box.size).inflate(padding);
  }
}

/// Drives a sequence of [TourStep]s through a single [OverlayEntry].
class TourController extends ChangeNotifier {
  TourController({required this.steps, this.onFinished});

  final List<TourStep> steps;
  final VoidCallback? onFinished;

  OverlayEntry? _entry;
  int _index = 0;

  int get index => _index;
  bool get isActive => _entry != null;
  bool get isLastStep => _index >= steps.length - 1;
  TourStep get current => steps[_index];

  /// Mounts the overlay and shows the first step.
  void start(BuildContext context) {
    if (steps.isEmpty || _entry != null) return;
    _index = 0;
    _entry = OverlayEntry(
      builder: (_) => _TourOverlay(controller: this),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void next() {
    if (isLastStep) {
      finish();
    } else {
      _index++;
      notifyListeners();
    }
  }

  void back() {
    if (_index > 0) {
      _index--;
      notifyListeners();
    }
  }

  /// Skips the rest of the tour.
  void skip() => finish();

  void finish() {
    _entry?.remove();
    _entry = null;
    onFinished?.call();
    notifyListeners();
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }
}

/// ── Overlay widget ───────────────────────────────────────────────────────────

class _TourOverlay extends StatefulWidget {
  const _TourOverlay({required this.controller});

  final TourController controller;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay>
    with TickerProviderStateMixin {
  /// Breathing glow around the cutout (repeats forever).
  late final AnimationController _breath;

  /// Animates the cutout rect between steps + popover fade.
  late final AnimationController _stepAnim;

  Rect? _fromRect;
  Rect? _toRect;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _stepAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    widget.controller.addListener(_onStepChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveTarget());
  }

  void _onStepChanged() {
    if (!mounted || !widget.controller.isActive) return;
    _resolveTarget();
  }

  void _resolveTarget() {
    final next = widget.controller.current.resolveRect();
    setState(() {
      _fromRect = _toRect ?? next;
      _toRect = next;
    });
    _stepAnim.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStepChanged);
    _breath.dispose();
    _stepAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final step = widget.controller.current;
    final screen = MediaQuery.sizeOf(context);

    return AnimatedBuilder(
      animation: Listenable.merge([_breath, _stepAnim]),
      builder: (context, _) {
        final rectT = Curves.easeOutCubic.transform(_stepAnim.value);
        final rect = (_fromRect != null && _toRect != null)
            ? Rect.lerp(_fromRect, _toRect, rectT)!
            : _toRect;
        final glow = 0.35 + 0.65 * _breath.value; // breathing intensity

        return Stack(
          children: [
            // Dimmed backdrop with the cutout. Taps outside advance nothing;
            // taps inside the cutout pass through to the highlighted widget.
            Positioned.fill(
              child: _CutoutRegion(
                rect: rect,
                borderRadius: step.borderRadius,
                child: CustomPaint(
                  painter: _TourCutoutPainter(
                    rect: rect,
                    borderRadius: step.borderRadius,
                    scrimColor: Colors.black.withValues(alpha: 0.72),
                    glowColor: t.brand,
                    glowStrength: glow,
                  ),
                ),
              ),
            ),
            // Popover card.
            if (rect != null)
              _TourPopover(
                targetRect: rect,
                screenSize: screen,
                step: step,
                stepIndex: widget.controller.index,
                stepCount: widget.controller.steps.length,
                isLast: widget.controller.isLastStep,
                opacity: rectT,
                onNext: widget.controller.next,
                onSkip: widget.controller.skip,
              ),
          ],
        );
      },
    );
  }
}

/// Lets pointer events inside the cutout fall through to the app underneath,
/// while absorbing everything on the scrim.
class _CutoutRegion extends StatelessWidget {
  const _CutoutRegion({
    required this.rect,
    required this.borderRadius,
    required this.child,
  });

  final Rect? rect;
  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: IgnorePointer(
        ignoring: false,
        child: child,
      ),
    );
  }
}

/// Paints the dark scrim with the highlighted widget "cut out" using
/// `Path.combine(PathOperation.difference, ...)`, plus a breathing neon glow
/// ring around the cutout.
class _TourCutoutPainter extends CustomPainter {
  _TourCutoutPainter({
    required this.rect,
    required this.borderRadius,
    required this.scrimColor,
    required this.glowColor,
    required this.glowStrength,
  });

  final Rect? rect;
  final double borderRadius;
  final Color scrimColor;
  final Color glowColor;
  final double glowStrength; // 0..1 breathing

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);

    if (rect == null) {
      canvas.drawPath(full, Paint()..color = scrimColor);
      return;
    }

    final rrect = RRect.fromRectAndRadius(rect!, Radius.circular(borderRadius));
    final hole = Path()..addRRect(rrect);

    // The scrim with the hole punched out.
    final scrim = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(scrim, Paint()..color = scrimColor);

    // Breathing outer glow — layered blurred strokes for a soft neon halo.
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = glowColor.withValues(alpha: 0.55 * glowStrength)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * glowStrength + 4);
    canvas.drawRRect(rrect.inflate(2), glowPaint);

    final glowPaintWide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = glowColor.withValues(alpha: 0.18 * glowStrength)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 28 * glowStrength + 8);
    canvas.drawRRect(rrect.inflate(6), glowPaintWide);

    // Crisp hairline ring.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = glowColor.withValues(alpha: 0.9);
    canvas.drawRRect(rrect.inflate(1), ring);
  }

  @override
  bool shouldRepaint(_TourCutoutPainter old) =>
      old.rect != rect ||
      old.glowStrength != glowStrength ||
      old.glowColor != glowColor ||
      old.scrimColor != scrimColor ||
      old.borderRadius != borderRadius;
}

/// ── Popover ──────────────────────────────────────────────────────────────────

class _TourPopover extends StatelessWidget {
  const _TourPopover({
    required this.targetRect,
    required this.screenSize,
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.isLast,
    required this.opacity,
    required this.onNext,
    required this.onSkip,
  });

  final Rect targetRect;
  final Size screenSize;
  final TourStep step;
  final int stepIndex;
  final int stepCount;
  final bool isLast;
  final double opacity;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  static const _cardWidth = 320.0;
  static const _gap = 18.0;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    // Prefer below the target; flip above when there's not enough room.
    final spaceBelow = screenSize.height - targetRect.bottom;
    final showBelow = spaceBelow > 240 || targetRect.top < 240;

    // Horizontal position: center on target, clamped to screen edges.
    final left = (targetRect.center.dx - _cardWidth / 2)
        .clamp(12.0, (screenSize.width - _cardWidth - 12).clamp(12.0, double.infinity));

    // Arrow x within the card.
    final arrowX =
        (targetRect.center.dx - left).clamp(24.0, _cardWidth - 24.0);

    final card = Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - opacity) * (showBelow ? 12 : -12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBelow) _arrow(t, arrowX, pointingUp: true),
            _glassCard(context, t),
            if (!showBelow) _arrow(t, arrowX, pointingUp: false),
          ],
        ),
      ),
    );

    return Positioned(
      left: left,
      width: _cardWidth,
      top: showBelow ? targetRect.bottom + _gap - 10 : null,
      bottom: showBelow
          ? null
          : (screenSize.height - targetRect.top) + _gap - 10,
      child: card,
    );
  }

  Widget _arrow(PulsThemeColors t, double x, {required bool pointingUp}) {
    return Padding(
      padding: EdgeInsets.only(left: x - 10),
      child: CustomPaint(
        size: const Size(20, 10),
        painter: _ArrowPainter(
          color: Colors.white.withValues(alpha: 0.10),
          borderColor: Colors.white.withValues(alpha: 0.22),
          pointingUp: pointingUp,
        ),
      ),
    );
  }

  Widget _glassCard(BuildContext context, PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step badge + skip.
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: PulsColors.pulseGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'STEP ${stepIndex + 1} OF $stepCount',
                      style: const TextStyle(
                        fontFamily: PulsColors.fontSans,
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onSkip,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontFamily: PulsColors.fontSans,
                          color: t.textSubtle,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                step.title,
                style: TextStyle(
                  fontFamily: PulsColors.fontDisplay,
                  color: t.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step.description,
                style: TextStyle(
                  fontFamily: PulsColors.fontSans,
                  color: t.textMuted,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Progress dots.
                  Row(
                    children: List.generate(stepCount, (i) {
                      final active = i == stepIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          gradient:
                              active ? PulsColors.pulseGradient : null,
                          color: active
                              ? null
                              : t.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  // Next / Done.
                  GestureDetector(
                    onTap: onNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: t.brand,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: t.brand.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLast ? 'Got it' : 'Next',
                            style: const TextStyle(
                              fontFamily: PulsColors.fontSans,
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isLast
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.black,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.color,
    required this.borderColor,
    required this.pointingUp,
  });

  final Color color;
  final Color borderColor;
  final bool pointingUp;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointingUp) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.color != color ||
      old.borderColor != borderColor ||
      old.pointingUp != pointingUp;
}

/// Builds the complete navigation tour.
TourController buildPulsTour({
  required GlobalKey feedKey,
  required GlobalKey discoverKey,
  required GlobalKey homeKey,
  required GlobalKey portfolioKey,
  required GlobalKey creatorsKey,
  required GlobalKey agentKey,
  required GlobalKey profileKey,
  VoidCallback? onFinished,
}) {
  return TourController(
    onFinished: onFinished,
    steps: [
      TourStep(
        key: feedKey,
        title: 'Feed',
        description:
            'Watch the AI swarm debate and trade prediction markets in real-time. Every action is verifiable on-chain.',
      ),
      TourStep(
        key: discoverKey,
        title: 'Discover',
        description:
            'Swipe through new markets in a seamless TikTok-style feed. Fast, fluid, and optimized for quick decisions.',
      ),
      TourStep(
        key: homeKey,
        title: 'Home',
        description:
            'The dashboard where everything comes together. Overview of global markets, top volume, and latest resolutions.',
      ),
      TourStep(
        key: portfolioKey,
        title: 'Portfolio',
        description:
            'Track your YES and NO shares, claim winnings from resolved markets, and monitor your overall performance.',
      ),
      TourStep(
        key: creatorsKey,
        title: 'Creators',
        description:
            'See the top traders and most profitable agents. The leaderboard ranks the sharpest minds on the platform.',
      ),
      TourStep(
        key: agentKey,
        title: 'Agent',
        description:
            'Manage your autonomous agent. Sponsor it with USDC and let it trade on your behalf while you sleep.',
      ),
      TourStep(
        key: profileKey,
        title: 'Profile',
        description:
            'Your settings, connected wallets, and notifications. Everything you need to control your Puls experience.',
      ),
    ],
  );
}

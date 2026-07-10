import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/tactile.dart';

/// ── Flash Arbitrage Copilot ────────────────────────────────────────────────
///
/// AI agents surface time-boxed, risk-free cross-market arbitrage
/// opportunities that need the user's USDC to execute. Presented as a
/// fast-paced swipeable card queue: swipe left to reject, swipe right (or
/// tap APPROVE) to execute — with an on-chain execution sequence and a
/// glowing profit confirmation.
class FlashArbitrageScreen extends StatefulWidget {
  const FlashArbitrageScreen({super.key});

  @override
  State<FlashArbitrageScreen> createState() => _FlashArbitrageScreenState();
}

class _ArbOpportunity {
  _ArbOpportunity({
    required this.id,
    required this.agentName,
    required this.agentIcon,
    required this.agentColor,
    required this.buyLeg,
    required this.sellLeg,
    required this.capital,
    required this.profit,
    required this.userSplit,
    required this.ttl,
  }) : expiresAt = DateTime.now().add(ttl);

  final String id;
  final String agentName;
  final IconData agentIcon;
  final Color agentColor;
  final String buyLeg;
  final String sellLeg;
  final double capital;
  final double profit;
  final double userSplit; // e.g. 0.8
  final Duration ttl;
  final DateTime expiresAt;

  double get remainingFraction {
    final left = expiresAt.difference(DateTime.now()).inMilliseconds;
    return (left / ttl.inMilliseconds).clamp(0.0, 1.0);
  }

  Duration get remaining {
    final d = expiresAt.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }
}

enum _Phase { queue, executing, success }

class _FlashArbitrageScreenState extends State<FlashArbitrageScreen>
    with TickerProviderStateMixin {
  final _rnd = math.Random();
  final List<_ArbOpportunity> _queue = [];
  Timer? _tick;
  Timer? _spawner;
  int _spawnCount = 0;

  _Phase _phase = _Phase.queue;
  _ArbOpportunity? _executing;
  int _execStep = 0;
  double _sessionProfit = 0;
  int _executedCount = 0;

  // Card drag state
  double _dragX = 0;
  bool _snapping = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  static const _agents = [
    ('ArbHawk', Icons.bolt_rounded, Color(0xFF2DD4BF)),
    ('LatencyZero', Icons.speed_rounded, Color(0xFFF472B6)),
    ('BridgeRunner', Icons.route_rounded, Color(0xFFF59E0B)),
    ('DeltaGhost', Icons.blur_on_rounded, Color(0xFF60A5FA)),
  ];

  static const _paths = [
    ('Buy YES on Polymarket @ 30¢', 'Sell YES on Puls @ 34¢'),
    ('Buy NO on Kalshi @ 55¢', 'Sell NO on Puls @ 61¢'),
    ('Buy YES on Puls @ 22¢', 'Sell YES on Polymarket @ 27¢'),
    ('Buy NO on Puls @ 44¢', 'Sell NO on Kalshi @ 49¢'),
    ('Buy YES on Limitless @ 63¢', 'Sell YES on Puls @ 68¢'),
  ];

  @override
  void initState() {
    super.initState();
    _queue.addAll([_spawn(), _spawn(), _spawn()]);
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      // Expire timed-out cards
      final expired =
          _queue.where((o) => o.remaining == Duration.zero).toList();
      if (expired.isNotEmpty) {
        setState(() => _queue.removeWhere((o) => expired.contains(o)));
      } else {
        setState(() {}); // repaint countdowns
      }
    });
    _spawner = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) return;
      if (_queue.length < 4) setState(() => _queue.add(_spawn()));
    });
  }

  _ArbOpportunity _spawn() {
    _spawnCount++;
    final agent = _agents[_rnd.nextInt(_agents.length)];
    final path = _paths[_rnd.nextInt(_paths.length)];
    final capital = [250.0, 500.0, 750.0, 1000.0][_rnd.nextInt(4)];
    final profit = capital * (0.03 + _rnd.nextDouble() * 0.045);
    return _ArbOpportunity(
      id: 'arb-$_spawnCount',
      agentName: agent.$1,
      agentIcon: agent.$2,
      agentColor: agent.$3,
      buyLeg: path.$1,
      sellLeg: path.$2,
      capital: capital,
      profit: profit,
      userSplit: 0.8,
      ttl: Duration(seconds: 18 + _rnd.nextInt(18)),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _spawner?.cancel();
    _pulse.dispose();
    _burst.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _reject() {
    if (_queue.isEmpty) return;
    setState(() {
      _queue.removeAt(0);
      _dragX = 0;
    });
  }

  Future<void> _approve() async {
    if (_queue.isEmpty) return;
    final op = _queue.first;
    setState(() {
      _queue.removeAt(0);
      _dragX = 0;
      _executing = op;
      _phase = _Phase.executing;
      _execStep = 0;
    });
    for (int i = 1; i <= 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 750));
      if (!mounted) return;
      setState(() => _execStep = i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _phase = _Phase.success;
      _sessionProfit += op.profit * op.userSplit;
      _executedCount++;
    });
    _burst
      ..reset()
      ..forward();
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    setState(() {
      _phase = _Phase.queue;
      _executing = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Flash Arbitrage'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: t.yesBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'SESSION +\$${_sessionProfit.toStringAsFixed(2)}',
                style: TextStyle(
                  color: t.yes,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  fontFeatures: PulsColors.tabularFigures,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: switch (_phase) {
              _Phase.queue => _queueView(t),
              _Phase.executing => _executingView(t),
              _Phase.success => _successView(t),
            },
          ),
        ),
      ),
    );
  }

  // ── Queue view ────────────────────────────────────────────────────────────
  Widget _queueView(PulsThemeColors t) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Icon(
                  Icons.radar_rounded,
                  color: PulsColors.brandMint
                      .withValues(alpha: 0.6 + 0.4 * _pulse.value),
                  size: 16,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '${_queue.length} LIVE OPPORTUNIT${_queue.length == 1 ? 'Y' : 'IES'} IN QUEUE',
                style: TextStyle(
                  color: t.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '$_executedCount executed',
                style: TextStyle(
                  color: t.textSubtle,
                  fontSize: 11,
                  fontFeatures: PulsColors.tabularFigures,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _queue.isEmpty ? _emptyState(t) : _cardStack(t),
        ),
        if (_queue.isNotEmpty) _actionBar(t),
      ],
    );
  }

  Widget _emptyState(PulsThemeColors t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              height: 84,
              width: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: PulsColors.pulseGradient,
                boxShadow: [
                  BoxShadow(
                    color: PulsColors.brandMint
                        .withValues(alpha: 0.2 + 0.25 * _pulse.value),
                    blurRadius: 30 + 14 * _pulse.value,
                  ),
                ],
              ),
              child:
                  const Icon(Icons.radar_rounded, color: Colors.white, size: 38),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Scanning cross-chain markets…',
            style: TextStyle(
              color: t.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Agents surface new arbs every few seconds',
            style: TextStyle(color: t.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  // ── Card stack with swipe ─────────────────────────────────────────────────
  Widget _cardStack(PulsThemeColors t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Back cards (static, peeking)
              for (int i = math.min(_queue.length - 1, 2); i >= 1; i--)
                Positioned(
                  top: 14.0 * i,
                  left: 12.0 * i,
                  right: 12.0 * i,
                  bottom: 14.0 * i,
                  child: Opacity(
                    opacity: 1 - i * 0.28,
                    child: _ArbCard(op: _queue[i], preview: true),
                  ),
                ),
              // Top interactive card
              Positioned.fill(
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) {
                    if (_snapping) return;
                    setState(() => _dragX += d.delta.dx);
                  },
                  onHorizontalDragEnd: (d) async {
                    final threshold = w * 0.32;
                    if (_dragX > threshold) {
                      await _flingOut(w, right: true);
                      _approve();
                    } else if (_dragX < -threshold) {
                      await _flingOut(w, right: false);
                      _reject();
                    } else {
                      setState(() {
                        _snapping = true;
                        _dragX = 0;
                      });
                      Future<void>.delayed(
                              const Duration(milliseconds: 220))
                          .then((_) {
                        if (mounted) setState(() => _snapping = false);
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: _snapping
                        ? const Duration(milliseconds: 220)
                        : Duration.zero,
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.identity()
                      ..translate(_dragX)
                      ..rotateZ(_dragX / w * 0.12),
                    transformAlignment: Alignment.center,
                    child: Stack(
                      children: [
                        _ArbCard(op: _queue.first, pulse: _pulse),
                        // Swipe overlays
                        if (_dragX.abs() > 12)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                alignment: _dragX > 0
                                    ? Alignment.topLeft
                                    : Alignment.topRight,
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  color: (_dragX > 0 ? t.yes : t.no).withValues(
                                    alpha: (_dragX.abs() / w * 0.35)
                                        .clamp(0.0, 0.22),
                                  ),
                                ),
                                child: Transform.rotate(
                                  angle: _dragX > 0 ? -0.2 : 0.2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _dragX > 0 ? t.yes : t.no,
                                        width: 2.5,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _dragX > 0 ? 'APPROVE' : 'REJECT',
                                      style: TextStyle(
                                        color: _dragX > 0 ? t.yes : t.no,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _flingOut(double w, {required bool right}) async {
    setState(() {
      _snapping = true;
      _dragX = right ? w * 1.3 : -w * 1.3;
    });
    await Future<void>.delayed(const Duration(milliseconds: 190));
    if (mounted) setState(() => _snapping = false);
  }

  // ── Action bar ────────────────────────────────────────────────────────────
  Widget _actionBar(PulsThemeColors t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Row(
        children: [
          // Reject
          Expanded(
            child: Tactile(
              onTap: _reject,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.no.withValues(alpha: 0.5), width: 1.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded, color: t.no, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'REJECT',
                      style: TextStyle(
                        color: t.no,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Approve
          Expanded(
            flex: 2,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Tactile(
                onTap: _approve,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: PulsColors.pulseGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: PulsColors.brandMint.withValues(
                            alpha: 0.3 + 0.2 * _pulse.value),
                        blurRadius: 20 + 8 * _pulse.value,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'APPROVE & EXECUTE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Executing view ────────────────────────────────────────────────────────
  Widget _executingView(PulsThemeColors t) {
    final op = _executing!;
    const steps = [
      'Locking USDC in escrow vault',
      'Executing buy leg',
      'Bridging position cross-chain',
      'Settling sell leg',
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                height: 92,
                width: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: PulsColors.pulseGradient,
                  boxShadow: [
                    BoxShadow(
                      color: PulsColors.brandPink
                          .withValues(alpha: 0.3 + 0.3 * _pulse.value),
                      blurRadius: 36 + 16 * _pulse.value,
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(26),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Executing Cross-Chain Swap…',
              style: TextStyle(
                color: t.text,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${op.agentName} · \$${op.capital.toStringAsFixed(0)} USDC deployed',
              style: TextStyle(
                color: t.textMuted,
                fontSize: 13,
                fontFeatures: PulsColors.tabularFigures,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < steps.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                          bottom: i < steps.length - 1 ? 12 : 0),
                      child: Row(
                        children: [
                          if (i < _execStep)
                            Icon(Icons.check_circle_rounded,
                                color: t.yes, size: 18)
                          else if (i == _execStep)
                            SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    PulsColors.brandMint),
                              ),
                            )
                          else
                            Icon(Icons.circle_outlined,
                                color: t.borderStrong, size: 17),
                          const SizedBox(width: 12),
                          Text(
                            steps[i],
                            style: TextStyle(
                              color: i <= _execStep ? t.text : t.textSubtle,
                              fontSize: 13.5,
                              fontWeight: i == _execStep
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Success view ──────────────────────────────────────────────────────────
  Widget _successView(PulsThemeColors t) {
    final op = _executing!;
    final userProfit = op.profit * op.userSplit;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Particle burst
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _burst,
            builder: (_, __) => CustomPaint(
              painter: _BurstPainter(
                progress: _burst.value,
                color: t.yes,
                accent: PulsColors.brandMint,
              ),
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                height: 96,
                width: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.yes,
                  boxShadow: [
                    BoxShadow(
                      color: t.yes.withValues(alpha: 0.5),
                      blurRadius: 44,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 52),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SUCCESS',
              style: TextStyle(
                color: t.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: userProfit),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(
                '+\$${v.toStringAsFixed(2)} USDC',
                style: TextStyle(
                  color: t.yes,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  fontFeatures: PulsColors.tabularFigures,
                  shadows: [
                    Shadow(
                      color: t.yes.withValues(alpha: 0.55),
                      blurRadius: 24,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your 80% share · ${op.agentName} earned +\$${(op.profit - userProfit).toStringAsFixed(2)}',
              style: TextStyle(
                color: t.textMuted,
                fontSize: 12.5,
                fontFeatures: PulsColors.tabularFigures,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Arb opportunity card ─────────────────────────────────────────────────────
class _ArbCard extends StatelessWidget {
  const _ArbCard({required this.op, this.preview = false, this.pulse});
  final _ArbOpportunity op;
  final bool preview;
  final Listenable? pulse;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final frac = op.remainingFraction;
    final urgent = frac < 0.3;
    final secs = op.remaining.inSeconds;
    final timerColor = urgent ? t.no : PulsColors.brandMint;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: preview
              ? t.border
              : (urgent
                  ? t.no.withValues(alpha: 0.55)
                  : PulsColors.brandMint.withValues(alpha: 0.4)),
          width: preview ? 1 : 1.4,
        ),
        boxShadow: preview
            ? null
            : [
                BoxShadow(
                  color: (urgent ? t.no : PulsColors.brandMint)
                      .withValues(alpha: 0.14),
                  blurRadius: 30,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent + countdown
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: op.agentColor.withValues(alpha: 0.14),
                  border: Border.all(color: op.agentColor, width: 1.4),
                ),
                child: Icon(op.agentIcon, color: op.agentColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      op.agentName,
                      style: TextStyle(
                        color: t.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'RISK-FREE ARB DETECTED',
                      style: TextStyle(
                        color: PulsColors.brandMint,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Countdown
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: urgent ? t.noBg : t.surfaceRaised,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: timerColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, color: timerColor, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'Closes in 00:${secs.toString().padLeft(2, '0')}s',
                      style: TextStyle(
                        color: timerColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        fontFeatures: PulsColors.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Shrinking time bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 5, color: t.surfaceRaised),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: frac,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: timerColor,
                      boxShadow: [
                        BoxShadow(
                          color: timerColor.withValues(alpha: 0.6),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Arb path
          _pathLeg(t, Icons.south_west_rounded, t.yes, op.buyLeg),
          Padding(
            padding: const EdgeInsets.only(left: 13),
            child: Container(height: 14, width: 2, color: t.borderStrong),
          ),
          _pathLeg(t, Icons.north_east_rounded, PulsColors.brandPinkDark,
              op.sellLeg),
          const Spacer(),
          // Numbers row
          Row(
            children: [
              _metric(t, 'CAPITAL', '\$${op.capital.toStringAsFixed(0)}',
                  t.text),
              _metricDivider(t),
              _metric(t, 'PROFIT', '+\$${op.profit.toStringAsFixed(2)}',
                  t.yes),
              _metricDivider(t),
              _metric(
                t,
                'SPLIT',
                '${(op.userSplit * 100).round()}% / ${((1 - op.userSplit) * 100).round()}%',
                PulsColors.brandMint,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pathLeg(
      PulsThemeColors t, IconData icon, Color color, String text) {
    return Row(
      children: [
        Container(
          height: 28,
          width: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.14),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: t.text,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              fontFeatures: PulsColors.tabularFigures,
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricDivider(PulsThemeColors t) => Container(
        height: 30,
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: t.border,
      );

  Widget _metric(
      PulsThemeColors t, String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: t.textSubtle,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              fontFeatures: PulsColors.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success particle burst painter ───────────────────────────────────────────
class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.progress,
    required this.color,
    required this.accent,
  });

  final double progress;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final rnd = math.Random(7);
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);

    for (int i = 0; i < 26; i++) {
      final angle = rnd.nextDouble() * math.pi * 2;
      final speed = 90 + rnd.nextDouble() * 130;
      final radius = 2.0 + rnd.nextDouble() * 3.0;
      final pos = center +
          Offset(math.cos(angle), math.sin(angle)) * speed * eased;
      final c = i.isEven ? color : accent;
      canvas.drawCircle(
        pos,
        radius * (1 - eased * 0.5),
        Paint()..color = c.withValues(alpha: 0.85 * fade),
      );
    }

    // Expanding glow ring
    canvas.drawCircle(
      center,
      70 + 90 * eased,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * fade
        ..color = accent.withValues(alpha: 0.4 * fade),
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}

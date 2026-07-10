import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/tactile.dart';

/// ── AI Gladiator Arena ─────────────────────────────────────────────────────
///
/// Four AI agents, $1,000 USDC each, 24 hours, one winner. A live-trading
/// tournament rendered like a fighting-game roster crossed with a Bloomberg
/// terminal: animated leaderboard track, PnL health bars, a trash-talk feed
/// ticker, and massive "Bet on Agent" stake buttons.
class GladiatorArenaScreen extends StatefulWidget {
  const GladiatorArenaScreen({super.key});

  @override
  State<GladiatorArenaScreen> createState() => _GladiatorArenaScreenState();
}

class _Gladiator {
  _Gladiator({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.equity,
    required this.odds,
  });

  final String id;
  final String name;
  final String tagline;
  final IconData icon;
  final Color color;
  double equity; // started at 1000
  double odds;
  int trades = 0;
  bool justTraded = false;
  double lastDelta = 0;

  double get pnl => equity - 1000;
  double get pnlPct => (equity / 1000 - 1) * 100;
}

class _FeedEvent {
  _FeedEvent(this.agent, this.text, this.isTrade);
  final _Gladiator agent;
  final String text;
  final bool isTrade;
}

class _GladiatorArenaScreenState extends State<GladiatorArenaScreen>
    with TickerProviderStateMixin {
  final _rnd = math.Random(42);
  Timer? _simTimer;
  Timer? _clockTimer;
  Duration _remaining = const Duration(hours: 13, minutes: 42, seconds: 8);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();

  late final List<_Gladiator> _agents = [
    _Gladiator(
      id: 'degen',
      name: 'DEGENBOT',
      tagline: 'Max leverage. Zero fear.',
      icon: Icons.local_fire_department_rounded,
      color: const Color(0xFFF87171),
      equity: 1147,
      odds: 3.1,
    ),
    _Gladiator(
      id: 'macro',
      name: 'MACROMIND',
      tagline: 'Sees the whole board.',
      icon: Icons.psychology_rounded,
      color: const Color(0xFF2DD4BF),
      equity: 1231,
      odds: 2.2,
    ),
    _Gladiator(
      id: 'sniper',
      name: 'SNIPER',
      tagline: 'One shot. One fill.',
      icon: Icons.gps_fixed_rounded,
      color: const Color(0xFFF472B6),
      equity: 1089,
      odds: 3.8,
    ),
    _Gladiator(
      id: 'insider',
      name: 'INSIDER',
      tagline: 'Heard it here first.',
      icon: Icons.visibility_rounded,
      color: const Color(0xFFF59E0B),
      equity: 962,
      odds: 5.4,
    ),
  ];

  final List<_FeedEvent> _feed = [];

  static const _trashTalk = [
    'is farming your liquidations. Stay mad.',
    'says: "I priced this in 4 hours ago."',
    'just told the orderbook to kneel.',
    'whispers: "your stop loss is my entry."',
    'declares: "volatility is a love language."',
    'says: "I don\'t chase pumps, pumps chase me."',
    'posts: "gm to everyone except my counterparties."',
    'says: "risk management is for humans."',
  ];

  static const _tradeVerbs = [
    'LONG YES @ 34¢ · \$120',
    'SHORT NO @ 61¢ · \$200',
    'FLIP YES→NO @ 48¢ · \$85',
    'SCALP YES @ 22¢ · \$150',
    'FADE NO @ 71¢ · \$95',
    'SIZE UP YES @ 55¢ · \$310',
  ];

  @override
  void initState() {
    super.initState();
    // Seed the feed
    _feed.addAll([
      _FeedEvent(_agents[1], 'MACROMIND takes the lead with a \$310 YES sweep', true),
      _FeedEvent(_agents[0], 'DEGENBOT ${_trashTalk[0]}', false),
      _FeedEvent(_agents[2], 'SNIPER ${_tradeVerbs[3]}', true),
      _FeedEvent(_agents[3], 'INSIDER ${_trashTalk[3]}', false),
    ]);

    _simTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (!mounted) return;
      _simulateTick();
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(seconds: 1);
        if (_remaining.isNegative) _remaining = Duration.zero;
      });
    });
  }

  void _simulateTick() {
    final agent = _agents[_rnd.nextInt(_agents.length)];
    final delta = (_rnd.nextDouble() * 90 - 35);
    setState(() {
      agent.equity = (agent.equity + delta).clamp(400.0, 2200.0);
      agent.trades += 1;
      agent.justTraded = true;
      agent.lastDelta = delta;
      // Odds drift with equity rank
      final sorted = [..._agents]..sort((a, b) => b.equity.compareTo(a.equity));
      for (int i = 0; i < sorted.length; i++) {
        sorted[i].odds = [1.9, 2.8, 3.9, 5.6][i] +
            _rnd.nextDouble() * 0.4 -
            0.2;
      }
      final isTrade = _rnd.nextDouble() > 0.35;
      _feed.insert(
        0,
        _FeedEvent(
          agent,
          isTrade
              ? '${agent.name} ${_tradeVerbs[_rnd.nextInt(_tradeVerbs.length)]}'
              : '${agent.name} ${_trashTalk[_rnd.nextInt(_trashTalk.length)]}',
          isTrade,
        ),
      );
      if (_feed.length > 12) _feed.removeLast();
    });
    Future<void>.delayed(const Duration(milliseconds: 700)).then((_) {
      if (mounted) setState(() => agent.justTraded = false);
    });
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _clockTimer?.cancel();
    _pulse.dispose();
    _ticker.dispose();
    super.dispose();
  }

  String get _clock {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(_remaining.inHours)}:${two(_remaining.inMinutes % 60)}:${two(_remaining.inSeconds % 60)}';
  }

  List<_Gladiator> get _ranked =>
      [..._agents]..sort((a, b) => b.equity.compareTo(a.equity));

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('Gladiator Arena'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: t.noBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: t.no.withValues(alpha: 0.3 + 0.3 * _pulse.value),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 7,
                      width: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.no,
                        boxShadow: [
                          BoxShadow(
                            color: t.no.withValues(
                                alpha: 0.4 + 0.5 * _pulse.value),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: t.no,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      _tournamentHeader(t),
                      const SizedBox(height: 16),
                      _leaderboardTrack(t),
                    ],
                  ),
                ),
              ),
            ),
            _liveTicker(t),
          ],
        ),
      ),
    );
  }

  // ── Tournament header ─────────────────────────────────────────────────────
  Widget _tournamentHeader(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (r) => PulsColors.pulseGradient.createShader(r),
            child: const Text(
              'AI GLADIATOR ARENA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '4 AGENTS · \$1,000 EACH · 24H · WINNER TAKES GLORY',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: t.textSubtle,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _headerStat(t, 'TIME LEFT', _clock, t.no),
              _headerDivider(t),
              _headerStat(t, 'PRIZE POOL', '\$4,000', PulsColors.brandMint),
              _headerDivider(t),
              _headerStat(t, 'TOTAL BETS', '\$18,240', t.text),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerDivider(PulsThemeColors t) => Container(
        height: 28,
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        color: t.border,
      );

  Widget _headerStat(
      PulsThemeColors t, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            fontFeatures: PulsColors.tabularFigures,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: t.textSubtle,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  // ── Leaderboard track ─────────────────────────────────────────────────────
  static const double _cardHeight = 148;
  static const double _cardGap = 12;

  Widget _leaderboardTrack(PulsThemeColors t) {
    final ranked = _ranked;
    return SizedBox(
      height: (_cardHeight + _cardGap) * _agents.length - _cardGap,
      child: Stack(
        children: [
          for (final agent in _agents)
            AnimatedPositioned(
              key: ValueKey(agent.id),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
              top: ranked.indexOf(agent) * (_cardHeight + _cardGap),
              left: 0,
              right: 0,
              height: _cardHeight,
              child: _gladiatorCard(t, agent, ranked.indexOf(agent)),
            ),
        ],
      ),
    );
  }

  Widget _gladiatorCard(PulsThemeColors t, _Gladiator g, int rank) {
    final winning = g.pnl >= 0;
    final pnlColor = winning ? t.yes : t.no;
    final health = (g.equity / 2000).clamp(0.05, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: g.justTraded
              ? g.color.withValues(alpha: 0.9)
              : (rank == 0 ? g.color.withValues(alpha: 0.45) : t.border),
          width: g.justTraded ? 1.6 : 1,
        ),
        boxShadow: g.justTraded
            ? [
                BoxShadow(
                  color: g.color.withValues(alpha: 0.28),
                  blurRadius: 24,
                ),
              ]
            : rank == 0
                ? [
                    BoxShadow(
                      color: g.color.withValues(alpha: 0.12),
                      blurRadius: 18,
                    ),
                  ]
                : null,
      ),
      child: Row(
        children: [
          // Rank + avatar
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: g.color.withValues(alpha: 0.12),
                  border: Border.all(
                    color: g.color.withValues(alpha: rank == 0 ? 0.9 : 0.4),
                    width: rank == 0 ? 2 : 1.2,
                  ),
                ),
                child: Icon(g.icon, color: g.color, size: 26),
              ),
              const SizedBox(height: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: rank == 0
                      ? g.color.withValues(alpha: 0.16)
                      : t.surfaceRaised,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${rank + 1}',
                  style: TextStyle(
                    color: rank == 0 ? g.color : t.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    fontFeatures: PulsColors.tabularFigures,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Name, tagline, health bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    if (rank == 0) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.emoji_events_rounded,
                          color: g.color, size: 15),
                    ],
                    if (g.justTraded) ...[
                      const SizedBox(width: 6),
                      _tradeFlash(t, g),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  g.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                // Health bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Stack(
                    children: [
                      Container(height: 9, color: t.surfaceRaised),
                      AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 550),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.centerLeft,
                        widthFactor: health,
                        child: Container(
                          height: 9,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: winning
                                  ? [t.yes.withValues(alpha: 0.7), t.yes]
                                  : [t.no.withValues(alpha: 0.7), t.no],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: pnlColor.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '\$${g.equity.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: t.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFeatures: PulsColors.tabularFigures,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${winning ? '+' : ''}${g.pnlPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: pnlColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFeatures: PulsColors.tabularFigures,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${g.trades} trades',
                      style: TextStyle(
                        color: t.textSubtle,
                        fontSize: 10.5,
                        fontFeatures: PulsColors.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Bet button
          _betButton(t, g),
        ],
      ),
    );
  }

  Widget _tradeFlash(PulsThemeColors t, _Gladiator g) {
    final up = g.lastDelta >= 0;
    return TweenAnimationBuilder<double>(
      key: ValueKey('${g.id}-${g.trades}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(
        scale: 0.6 + 0.4 * v.clamp(0.0, 1.0),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: up ? t.yesBg : t.noBg,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '${up ? '+' : ''}\$${g.lastDelta.toStringAsFixed(0)}',
          style: TextStyle(
            color: up ? t.yes : t.no,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            fontFeatures: PulsColors.tabularFigures,
          ),
        ),
      ),
    );
  }

  Widget _betButton(PulsThemeColors t, _Gladiator g) {
    return Tactile(
      onTap: () => _openStakeSheet(g),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              g.color.withValues(alpha: 0.9),
              Color.lerp(g.color, Colors.black, 0.25)!,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: g.color.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'BET',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${g.odds.toStringAsFixed(1)}x',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: PulsColors.tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stake bottom sheet ────────────────────────────────────────────────────
  void _openStakeSheet(_Gladiator g) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StakeSheet(agent: g),
    );
  }

  // ── Live feed ticker ──────────────────────────────────────────────────────
  Widget _liveTicker(PulsThemeColors t) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: PulsColors.pulseGradient,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stream_rounded, color: Colors.white, size: 14),
                SizedBox(width: 5),
                Text(
                  'LIVE FEED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _ticker,
                builder: (context, _) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final row = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final e in _feed) _tickerItem(t, e),
                        ],
                      );
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Transform.translate(
                          offset: Offset(
                            -((_ticker.value * 1400) % 1400),
                            0,
                          ),
                          child: Row(children: [row, row]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tickerItem(PulsThemeColors t, _FeedEvent e) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            e.isTrade ? Icons.swap_horiz_rounded : Icons.forum_rounded,
            color: e.agent.color,
            size: 13,
          ),
          const SizedBox(width: 6),
          Text(
            e.text,
            style: TextStyle(
              color: e.isTrade ? t.text : t.textMuted,
              fontSize: 11.5,
              fontWeight: e.isTrade ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: PulsColors.tabularFigures,
            ),
          ),
          const SizedBox(width: 14),
          Container(height: 4, width: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: t.borderStrong)),
        ],
      ),
    );
  }
}

// ── Stake sheet ──────────────────────────────────────────────────────────────
class _StakeSheet extends StatefulWidget {
  const _StakeSheet({required this.agent});
  final _Gladiator agent;

  @override
  State<_StakeSheet> createState() => _StakeSheetState();
}

class _StakeSheetState extends State<_StakeSheet> {
  double _stake = 100;
  bool _placing = false;
  bool _placed = false;

  Future<void> _place() async {
    setState(() => _placing = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() {
      _placing = false;
      _placed = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final g = widget.agent;
    final payout = _stake * g.odds;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(
          20, 18, 20, 18 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: g.color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: g.color.withValues(alpha: 0.2),
            blurRadius: 40,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: g.color.withValues(alpha: 0.14),
                  border: Border.all(color: g.color, width: 1.5),
                ),
                child: Icon(g.icon, color: g.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BET ON ${g.name}',
                      style: TextStyle(
                        color: t.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Tournament winner · ${g.odds.toStringAsFixed(1)}x payout',
                      style: TextStyle(color: t.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${_stake.round()}',
                style: TextStyle(
                  color: t.text,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1,
                  fontFeatures: PulsColors.tabularFigures,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'USDC',
                  style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: g.color,
              inactiveTrackColor: t.surfaceRaised,
              thumbColor: Colors.white,
              overlayColor: g.color.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _stake,
              min: 10,
              max: 1000,
              onChanged:
                  _placing || _placed ? null : (v) => setState(() => _stake = v),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  'Potential payout',
                  style: TextStyle(color: t.textMuted, fontSize: 12.5),
                ),
                const Spacer(),
                Text(
                  '\$${payout.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: t.yes,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFeatures: PulsColors.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Tactile(
            onTap: _placing || _placed ? null : _place,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _placed
                    ? LinearGradient(colors: [t.yes, t.yes])
                    : LinearGradient(
                        colors: [
                          g.color,
                          Color.lerp(g.color, Colors.black, 0.3)!,
                        ],
                      ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (_placed ? t.yes : g.color)
                        .withValues(alpha: _placing ? 0.55 : 0.35),
                    blurRadius: _placing ? 28 : 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: _placing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _placed
                          ? 'BET PLACED ✓'
                          : 'STAKE \$${_stake.round()} ON ${g.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

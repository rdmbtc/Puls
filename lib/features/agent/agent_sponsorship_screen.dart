import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/tactile.dart';

/// ── Agent Sponsorship & Delegation ────────────────────────────────────────
///
/// A pro-trader DeFi dashboard where users stake USDC into an AI agent's
/// smart contract. Features an animated ROI/APY performance chart, a sleek
/// investment slider, a dynamic profit-split calculator, and a glowing
/// "Sign & Delegate" flow — all wearing the signature pulse gradient.
class AgentSponsorshipScreen extends StatefulWidget {
  const AgentSponsorshipScreen({super.key});

  @override
  State<AgentSponsorshipScreen> createState() => _AgentSponsorshipScreenState();
}

class _AgentSponsorshipScreenState extends State<AgentSponsorshipScreen>
    with TickerProviderStateMixin {
  // ── Mock agent data ──
  static const _agentName = 'MacroMind v4';
  static const _contract = '0x7fA9…c3E1';
  static const _apy = 47.2;
  static const _roi30d = 12.8;
  static const _tvl = 1284530.0;
  static const _sharpe = 2.41;
  static const _winRate = 68.4;
  static const _performanceFee = 0.20; // agent keeps 20% of profits

  // ── State ──
  double _amount = 500;
  int _timeframe = 1; // 0=7D 1=30D 2=90D 3=1Y
  bool _delegating = false;
  bool _delegated = false;

  late final AnimationController _chartCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final AnimationController _glowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  static const _timeframes = ['7D', '30D', '90D', '1Y'];

  // Deterministic equity curves per timeframe (mock, upward-biased).
  List<double> _curve(int tf) {
    final rnd = math.Random(tf * 31 + 7);
    final n = [24, 30, 36, 48][tf];
    final drift = [0.9, 1.1, 1.4, 1.9][tf];
    var v = 100.0;
    return List.generate(n, (i) {
      v += drift * (rnd.nextDouble() * 2.2 - 0.8);
      return v;
    });
  }

  @override
  void dispose() {
    _chartCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _delegate() async {
    setState(() {
      _delegating = true;
      _delegated = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    setState(() {
      _delegating = false;
      _delegated = true;
    });
    Future<void>.delayed(const Duration(seconds: 4)).then((_) {
      if (mounted) setState(() => _delegated = false);
    });
  }

  String _usd(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final projectedGross = _amount * (_apy / 100);
    final agentCut = projectedGross * _performanceFee;
    final userReturn = projectedGross - agentCut;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Agent Sponsorship'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _LivePill(t: t, glow: _glowCtrl),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _agentHeader(t),
                const SizedBox(height: 14),
                _statRow(t),
                const SizedBox(height: 14),
                _chartCard(t),
                const SizedBox(height: 14),
                _amountCard(t),
                const SizedBox(height: 14),
                _profitSplitCard(t, projectedGross, agentCut, userReturn),
                const SizedBox(height: 20),
                _delegateButton(t),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Non-custodial · funds stay in your delegation vault',
                    style: TextStyle(
                      color: t.textSubtle,
                      fontSize: 11.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Agent header ──────────────────────────────────────────────────────────
  Widget _agentHeader(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          // Pulsing gradient avatar ring
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) => Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: PulsColors.pulseGradient,
                boxShadow: [
                  BoxShadow(
                    color: PulsColors.brandMint.withValues(
                      alpha: 0.18 + 0.22 * _glowCtrl.value,
                    ),
                    blurRadius: 14 + 8 * _glowCtrl.value,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: t.surfaceRaised,
                child: Icon(Icons.psychology_rounded, color: t.brand, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _agentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.verified_rounded,
                        color: PulsColors.brandMint, size: 17),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.link_rounded, color: t.textSubtle, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      _contract,
                      style: TextStyle(
                        color: t.textMuted,
                        fontSize: 12,
                        fontFeatures: PulsColors.tabularFigures,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: t.yesBg,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'AUDITED',
                        style: TextStyle(
                          color: t.yes,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                shaderCallback: (r) =>
                    PulsColors.pulseGradient.createShader(r),
                child: Text(
                  '${_apy.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    fontFeatures: PulsColors.tabularFigures,
                  ),
                ),
              ),
              Text(
                'NET APY',
                style: TextStyle(
                  color: t.textSubtle,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stat chips ────────────────────────────────────────────────────────────
  Widget _statRow(PulsThemeColors t) {
    Widget stat(String label, String value, {Color? color}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.border),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color ?? t.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFeatures: PulsColors.tabularFigures,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        );

    return Row(
      children: [
        stat('30D ROI', '+${_roi30d.toStringAsFixed(1)}%', color: t.yes),
        const SizedBox(width: 10),
        stat('TVL', _usd(_tvl)),
        const SizedBox(width: 10),
        stat('SHARPE', _sharpe.toStringAsFixed(2)),
        const SizedBox(width: 10),
        stat('WIN RATE', '${_winRate.toStringAsFixed(0)}%',
            color: PulsColors.brandMint),
      ],
    );
  }

  // ── Performance chart ─────────────────────────────────────────────────────
  Widget _chartCard(PulsThemeColors t) {
    final curve = _curve(_timeframe);
    final gain = (curve.last / curve.first - 1) * 100;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PERFORMANCE',
                      style: TextStyle(
                        color: t.textSubtle,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${gain.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: t.yes,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            fontFeatures: PulsColors.tabularFigures,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            _timeframes[_timeframe],
                            style: TextStyle(
                              color: t.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Timeframe selector
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: t.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < _timeframes.length; i++)
                      Tactile(
                        onTap: () {
                          setState(() => _timeframe = i);
                          _chartCtrl
                            ..reset()
                            ..forward();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: i == _timeframe
                                ? PulsColors.pulseGradient
                                : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _timeframes[i],
                            style: TextStyle(
                              color:
                                  i == _timeframe ? Colors.white : t.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: Listenable.merge([_chartCtrl, _glowCtrl]),
              builder: (_, __) => CustomPaint(
                painter: _RoiChartPainter(
                  values: curve,
                  progress: Curves.easeOutCubic.transform(_chartCtrl.value),
                  glow: _glowCtrl.value,
                  gridColor: t.border,
                  labelColor: t.textSubtle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Amount slider ─────────────────────────────────────────────────────────
  Widget _amountCard(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'DELEGATION AMOUNT',
                  style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Text(
                'Balance: \$4,250.00',
                style: TextStyle(
                  color: t.textMuted,
                  fontSize: 11.5,
                  fontFeatures: PulsColors.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: _amount),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => ShaderMask(
                  shaderCallback: (r) =>
                      PulsColors.pulseGradient.createShader(r),
                  child: Text(
                    '\$${v.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1,
                      fontFeatures: PulsColors.tabularFigures,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  'USDC',
                  style: TextStyle(
                    color: t.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: PulsColors.brandMint,
              inactiveTrackColor: t.surfaceRaised,
              thumbColor: Colors.white,
              overlayColor: PulsColors.brandPink.withValues(alpha: 0.12),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 11),
            ),
            child: Slider(
              value: _amount,
              min: 50,
              max: 4250,
              onChanged: _delegating
                  ? null
                  : (v) => setState(() => _amount = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final quick in [100, 500, 1000, 2500])
                Tactile(
                  onTap: () => setState(() => _amount = quick.toDouble()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: (_amount - quick).abs() < 1
                          ? t.brandSubtle
                          : t.surfaceRaised,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: (_amount - quick).abs() < 1
                            ? t.brand
                            : t.border,
                      ),
                    ),
                    child: Text(
                      '\$$quick',
                      style: TextStyle(
                        color: (_amount - quick).abs() < 1
                            ? t.brand
                            : t.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: PulsColors.tabularFigures,
                      ),
                    ),
                  ),
                ),
              Tactile(
                onTap: () => setState(() => _amount = 4250),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: PulsColors.pulseGradient,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text(
                    'MAX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Profit split calculator ───────────────────────────────────────────────
  Widget _profitSplitCard(
    PulsThemeColors t,
    double gross,
    double agentCut,
    double userReturn,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded,
                  color: PulsColors.brandMint, size: 15),
              const SizedBox(width: 6),
              Text(
                'PROJECTED PROFIT SPLIT · 1Y',
                style: TextStyle(
                  color: t.textSubtle,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Animated split bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(
                    flex: ((1 - _performanceFee) * 100).round(),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: PulsColors.pulseGradient,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: (_performanceFee * 100).round(),
                    child: Container(color: t.surfaceRaised),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _splitTile(
                  t,
                  label: 'YOUR RETURN · 80%',
                  value: userReturn,
                  color: t.yes,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _splitTile(
                  t,
                  label: 'AGENT FEE · 20%',
                  value: agentCut,
                  color: t.textMuted,
                  icon: Icons.smart_toy_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: t.brand, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: _amount + userReturn),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Text.rich(
                      TextSpan(
                        style: TextStyle(color: t.textMuted, fontSize: 12.5),
                        children: [
                          const TextSpan(text: 'Projected value in 1 year: '),
                          TextSpan(
                            text: '\$${v.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: t.text,
                              fontWeight: FontWeight.w800,
                              fontFeatures: PulsColors.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _splitTile(
    PulsThemeColors t, {
    required String label,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(
              '+\$${v.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                fontFeatures: PulsColors.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sign & Delegate button ────────────────────────────────────────────────
  Widget _delegateButton(PulsThemeColors t) {
    final label = _delegated
        ? 'Delegated ${_usd(_amount)} USDC ✓'
        : 'Sign & Delegate ${_usd(_amount)} USDC';

    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, __) {
        final glow = _delegating
            ? 0.55 + 0.35 * _glowCtrl.value
            : 0.28 + 0.10 * _glowCtrl.value;
        return Tactile(
          onTap: _delegating || _delegated ? null : _delegate,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: _delegated
                  ? LinearGradient(colors: [t.yes, t.yes])
                  : PulsColors.pulseGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (_delegated ? t.yes : PulsColors.brandPink)
                      .withValues(alpha: glow),
                  blurRadius: _delegating ? 34 : 22,
                  offset: const Offset(0, 6),
                ),
                if (_delegating)
                  BoxShadow(
                    color: PulsColors.brandMint.withValues(alpha: glow * 0.8),
                    blurRadius: 44,
                  ),
              ],
            ),
            child: _delegating
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Signing delegation on-chain…',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _delegated
                            ? Icons.check_circle_rounded
                            : Icons.bolt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// ── Live pill ────────────────────────────────────────────────────────────────
class _LivePill extends StatelessWidget {
  const _LivePill({required this.t, required this.glow});
  final PulsThemeColors t;
  final AnimationController glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: t.yesBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 7,
              width: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.yes,
                boxShadow: [
                  BoxShadow(
                    color: t.yes.withValues(alpha: 0.4 + 0.5 * glow.value),
                    blurRadius: 6 + 4 * glow.value,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'TRADING LIVE',
              style: TextStyle(
                color: t.yes,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ROI chart painter ────────────────────────────────────────────────────────
class _RoiChartPainter extends CustomPainter {
  _RoiChartPainter({
    required this.values,
    required this.progress,
    required this.glow,
    required this.gridColor,
    required this.labelColor,
  });

  final List<double> values;
  final double progress;
  final double glow;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final range = (max - min).clamp(0.001, double.infinity);

    // Grid lines
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset pointAt(int i) {
      final x = size.width * i / (values.length - 1);
      final norm = (values[i] - min) / range;
      final y = size.height * (1 - norm * 0.88 - 0.06);
      return Offset(x, y);
    }

    // Build path up to progress
    final visibleCount =
        (values.length * progress).clamp(2.0, values.length.toDouble());
    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    Offset last = pointAt(0);
    for (int i = 1; i < visibleCount.floor(); i++) {
      final p = pointAt(i);
      final mid = Offset((last.dx + p.dx) / 2, (last.dy + p.dy) / 2);
      path.quadraticBezierTo(last.dx, last.dy, mid.dx, mid.dy);
      last = p;
    }
    path.lineTo(last.dx, last.dy);

    // Area fill
    final fillPath = Path.from(path)
      ..lineTo(last.dx, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF34E5C0).withValues(alpha: 0.22),
            const Color(0xFFF65FA9).withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    // Glow stroke under the line
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..shader =
            PulsColors.pulseGradient.createShader(Offset.zero & size)
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // Main gradient line
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..shader =
            PulsColors.pulseGradient.createShader(Offset.zero & size),
    );

    // Pulsing endpoint dot
    if (progress > 0.98) {
      canvas.drawCircle(
        last,
        6 + 3 * glow,
        Paint()
          ..color = const Color(0xFFF65FA9).withValues(alpha: 0.35 * (1 - glow) + 0.1),
      );
      canvas.drawCircle(last, 4, Paint()..color = const Color(0xFFF65FA9));
      canvas.drawCircle(last, 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_RoiChartPainter old) =>
      old.progress != progress || old.glow != glow || old.values != values;
}

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config.dart';
import '../../core/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/count_up_text.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_dot.dart';
import '../../core/utils/puls_emoji.dart';
import '../../core/widgets/puls_emoji_text.dart';
import 'landing_kit.dart';

/// "Live on Arc right now" — the proof-of-life band. Pulls real protocol stats
/// (/api/stats) and the house-agent brain (/api/agents/house), and streams live
/// trades over the same WebSocket the app feed uses. Every number here is real
/// and verifiable on Arcscan. Renders nothing if the backend is unreachable —
/// the landing must never break.
class LiveOnArcSection extends StatefulWidget {
  const LiveOnArcSection({super.key});

  @override
  State<LiveOnArcSection> createState() => _LiveOnArcSectionState();
}

class _Decision {
  const _Decision({
    required this.action,
    required this.question,
    required this.side,
    required this.amount,
    required this.reasoning,
    required this.brain,
    required this.pmYes,
    required this.edge,
    required this.alphaPaid,
    required this.txHash,
    required this.alphaTx,
    required this.at,
  });
  final String action; // 'go' | 'skip'
  final String question;
  final String side; // YES | NO
  final double amount;
  final String reasoning;
  final String brain; // llm | risk
  final double pmYes; // crowd implied probability
  final double edge;
  final double alphaPaid;
  final String? txHash;
  final String? alphaTx;
  final DateTime at;
}

class _LiveOnArcSectionState extends State<LiveOnArcSection> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _agent;
  Map<String, dynamic>? _sage;
  List<_Decision> _decisions = const [];
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Future.wait([
        http.get(Uri.parse('$backendUrl/api/stats')).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('$backendUrl/api/agents/house')).timeout(const Duration(seconds: 10)),
      ]);
      if (!mounted) return;
      Map<String, dynamic>? stats;
      if (res[0].statusCode == 200) {
        stats = json.decode(res[0].body) as Map<String, dynamic>;
      }
      Map<String, dynamic>? agent, sage;
      var decisions = const <_Decision>[];
      if (res[1].statusCode == 200) {
        final house = json.decode(res[1].body) as Map<String, dynamic>;
        agent = house['agent'] as Map<String, dynamic>?;
        sage = house['sage'] as Map<String, dynamic>?;
        decisions = [
          for (final raw in (house['decisions'] as List? ?? const []))
            _parseDecision(raw as Map<String, dynamic>),
        ];
      }
      setState(() {
        if (stats != null) _stats = stats;
        if (agent != null) _agent = agent;
        if (sage != null) _sage = sage;
        if (decisions.isNotEmpty) _decisions = decisions;
      });
    } catch (_) {
      // Section degrades gracefully — never breaks the landing.
    }
  }

  _Decision _parseDecision(Map<String, dynamic> d) => _Decision(
        action: d['action'] as String? ?? 'go',
        question: d['question'] as String? ?? '',
        side: (d['side'] as String? ?? 'YES').toUpperCase(),
        amount: (d['amount'] as num?)?.toDouble() ?? 0,
        reasoning: (d['reasoning'] as String? ?? '').trim(),
        brain: d['brain'] as String? ?? 'llm',
        pmYes: (d['pmYes'] as num?)?.toDouble() ?? 0.5,
        edge: (d['edge'] as num?)?.toDouble() ?? 0,
        alphaPaid: (d['alphaPaid'] as num?)?.toDouble() ?? 0,
        txHash: d['txHash'] as String?,
        alphaTx: d['alphaOnchainTx'] as String?,
        at: DateTime.tryParse(d['at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 760;
    final hasData = _stats != null || _decisions.isNotEmpty;
    if (!hasData) return const SizedBox.shrink();

    final agentsOnline = (_stats?['agents'] as num?)?.toInt() ?? 0;
    final firstGo = _decisions.where((d) => d.action == 'go').isNotEmpty
        ? _decisions.firstWhere((d) => d.action == 'go')
        : null;

    return Container(
      width: double.infinity,
      color: t.surface.withValues(alpha: 0.35),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 48, vertical: isMobile ? 52 : 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            children: [
              const LandingEyebrow(label: 'LIVE ON ARC RIGHT NOW', live: true),
              const SizedBox(height: 20),
              LandingHeadline(
                lead: 'Not a mockup —',
                accent: 'a market that\'s breathing.',
                isMobile: isMobile,
              ),
              if (agentsOnline > 0) ...[
                const SizedBox(height: 14),
                _AgentsOnlineBadge(count: agentsOnline),
              ],
              SizedBox(height: isMobile ? 32 : 52),
              if (_stats != null) _StatBand(stats: _stats!, isMobile: isMobile),
              if (_decisions.isNotEmpty) ...[
                SizedBox(height: isMobile ? 16 : 20),
                _wideRow(
                  isMobile,
                  left: _PulseNowCard(decision: _decisions.first, agent: _agent),
                  right: _OracleVsCrowdCard(decision: firstGo ?? _decisions.first),
                ),
              ],
              if (_sage != null) ...[
                SizedBox(height: isMobile ? 16 : 20),
                _X402Lane(sage: _sage!, stats: _stats, isMobile: isMobile),
              ],
              SizedBox(height: isMobile ? 16 : 20),
              const _MarketPulse(),
              if (_decisions.isNotEmpty) ...[
                SizedBox(height: isMobile ? 24 : 32),
                _ProofStrip(decisions: _decisions, sage: _sage),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _wideRow(bool isMobile, {required Widget left, required Widget right}) {
    if (isMobile) {
      return Column(children: [left, const SizedBox(height: 16), right]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 6, child: left),
          const SizedBox(width: 20),
          Expanded(flex: 5, child: right),
        ],
      ),
    );
  }
}

// ── Agents online badge ───────────────────────────────────────────────────────
class _AgentsOnlineBadge extends StatelessWidget {
  const _AgentsOnlineBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PulseDot(size: 6, color: Color(0xFF22C55E)),
          const SizedBox(width: 4),
          Text(
            '$count autonomous agents online',
            style: TextStyle(color: t.textMuted, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Stat odometer band ──────────────────────────────────────────────────────
class _StatBand extends StatelessWidget {
  const _StatBand({required this.stats, required this.isMobile});
  final Map<String, dynamic> stats;
  final bool isMobile;

  double _n(String k) => (stats[k] as num?)?.toDouble() ?? 0;
  double _nano() {
    final np = stats['nanopayments'];
    if (np is Map) return (np['count'] as num?)?.toDouble() ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <_StatTileData>[
      _StatTileData('Trades on Arc', _n('trades'), const Color(0xFFEC4899), Icons.swap_vert_rounded),
      _StatTileData('USDC volume', _n('volumeUsdc'), const Color(0xFF2DD4BF), Icons.payments_rounded, money: true),
      _StatTileData('Markets deployed', _n('marketsDeployed'), const Color(0xFF0EA5E9), Icons.hub_rounded),
      _StatTileData('Autonomous agent trades', _n('agentTrades'), const Color(0xFF8B5CF6), Icons.smart_toy_rounded),
      _StatTileData('x402 nanopayments', _nano(), const Color(0xFFF59E0B), Icons.bolt_rounded),
      _StatTileData('Wallets onboarded', _n('users'), const Color(0xFF16A34A), Icons.account_balance_wallet_rounded),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 880 ? 3 : (c.maxWidth > 520 ? 2 : 2);
      final gap = isMobile ? 12.0 : 16.0;
      final tileW = (c.maxWidth - (cols - 1) * gap) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final d in tiles)
            SizedBox(width: tileW, child: _StatTile(data: d, isMobile: isMobile)),
        ],
      );
    });
  }
}

class _StatTileData {
  const _StatTileData(this.label, this.value, this.color, this.icon, {this.money = false});
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final bool money;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data, required this.isMobile});
  final _StatTileData data;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.surface, Color.alphaBlend(data.color.withValues(alpha: 0.05), t.surface)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, size: 18, color: data.color),
              ),
              const Spacer(),
              const PulseDot(size: 5, color: Color(0xFF22C55E)),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          CountUpText(
            data.value,
            builder: (context, v) => Text(
              data.money ? '\$${withThousands(v.round())}' : withThousands(v.round()),
              style: TextStyle(
                fontFamily: PulsColors.fontDisplay,
                color: t.text,
                fontSize: isMobile ? 26 : 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(data.label, style: TextStyle(color: t.textMuted, fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── What Pulse is doing now ───────────────────────────────────────────────────
class _PulseNowCard extends StatelessWidget {
  const _PulseNowCard({required this.decision, required this.agent});
  final _Decision decision;
  final Map<String, dynamic>? agent;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final d = decision;
    final isGo = d.action == 'go';
    final sideColor = d.side == 'YES' ? t.yes : t.no;
    final balance = (agent?['balance'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.alphaBlend(t.brand.withValues(alpha: 0.06), t.surface), t.surface],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: PulsColors.pulseGradient, borderRadius: BorderRadius.circular(12)),
                child: PulsEmoji.icon('🤖', size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pulse · house trader-agent',
                        style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const PulseDot(size: 5, color: Color(0xFF22C55E)),
                        const SizedBox(width: 3),
                        Text('ACTING AUTONOMOUSLY · ${timeAgo(d.at)}',
                            style: TextStyle(color: t.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                      ],
                    ),
                  ],
                ),
              ),
              if (balance != null)
                Text('${balance.toStringAsFixed(0)} USDC',
                    style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isGo ? sideColor : PulsColors.amber).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (isGo ? sideColor : PulsColors.amber).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isGo ? Icons.trending_up_rounded : Icons.pause_rounded,
                        size: 14, color: isGo ? sideColor : PulsColors.amber),
                    const SizedBox(width: 5),
                    Text(isGo ? 'TRADED ${d.side}' : 'HOLD',
                        style: TextStyle(color: isGo ? sideColor : PulsColors.amber, fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _chip(t, d.brain == 'risk' ? '🛡 risk engine' : '🧠 LLM + sources'),
              if (isGo && d.amount > 0) ...[
                const SizedBox(width: 8),
                _chip(t, '\$${d.amount.toStringAsFixed(d.amount == d.amount.roundToDouble() ? 0 : 2)}'),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (isGo && d.question.isNotEmpty)
            Text(d.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
          if (d.reasoning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(d.reasoning,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.5)),
          ],
          const Spacer(),
          const SizedBox(height: 12),
          Row(
            children: [
              if (d.alphaPaid > 0)
                _chip(t, '⚡ paid ${d.alphaPaid} USDC → Sage'),
              const Spacer(),
              if (d.txHash != null && d.txHash!.isNotEmpty)
                _TxLink(label: 'view trade ↗', tx: d.txHash!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(PulsThemeColors t, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.border),
        ),
        child: PulsEmojiText(label,
            style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

// ── AI Oracle vs Crowd ──────────────────────────────────────────────────────
class _OracleVsCrowdCard extends StatelessWidget {
  const _OracleVsCrowdCard({required this.decision});
  final _Decision decision;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final d = decision;
    final crowd = (d.pmYes * 100).clamp(0, 100);
    final edgePct = (d.edge * 100).clamp(0, 100);
    final sideColor = d.side == 'YES' ? t.yes : t.no;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.balance_rounded, size: 16, color: t.brand),
              const SizedBox(width: 7),
              Text('AI ORACLE vs THE CROWD',
                  style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 14),
          if (d.question.isNotEmpty)
            Text(d.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.text, fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 16),
          _row(t, '👥 Crowd (Polymarket)', '${crowd.toStringAsFixed(0)}%', crowd / 100, t.textMuted, false),
          const SizedBox(height: 12),
          _row(t, '🧠 Pulse · buy ${d.side}', '${edgePct.toStringAsFixed(0)}¢ edge', (edgePct / 100).toDouble(), sideColor, true),
          const Spacer(),
          const SizedBox(height: 14),
          Text(
            'The crowd prices YES at ${crowd.toStringAsFixed(0)}% — Pulse found an edge and is buying ${d.side}. Disagreement, on-chain.',
            style: TextStyle(color: t.textSubtle, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _row(PulsThemeColors t, String label, String value, double frac, Color color, bool gradient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PulsEmojiText(label, style: TextStyle(color: t.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(value, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Stack(
              children: [
                Container(height: 8, color: t.surfaceRaised),
                FractionallySizedBox(
                  widthFactor: frac.clamp(0.02, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: gradient ? PulsColors.pulseGradient : null,
                      color: gradient ? null : color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── x402 agent-to-agent payment lane ──────────────────────────────────────────
class _X402Lane extends StatefulWidget {
  const _X402Lane({required this.sage, required this.stats, required this.isMobile});
  final Map<String, dynamic> sage;
  final Map<String, dynamic>? stats;
  final bool isMobile;

  @override
  State<_X402Lane> createState() => _X402LaneState();
}

class _X402LaneState extends State<_X402Lane> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final t = context.puls;
    final signal = widget.sage['signal'] as Map<String, dynamic>?;
    final title = signal?['title'] as String? ?? 'Premium alpha signal';
    final unlocks = (signal?['unlocks'] as num?)?.toInt() ?? 0;
    final revenue = (signal?['revenueUsdc'] as num?)?.toDouble() ?? 0;
    final np = widget.stats?['nanopayments'];
    final npCount = np is Map ? (np['count'] as num?)?.toInt() ?? 0 : 0;
    final onchainTx = (signal?['onchain'] as Map?)?['tx'] as String?;

    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFEC4899)),
              const SizedBox(width: 7),
              const Expanded(
                child: Text('x402 · ONE AI PAYS ANOTHER FOR ALPHA',
                    style: TextStyle(color: Color(0xFFEC4899), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
              ),
              if (npCount > 0)
                Text('$npCount settled', style: TextStyle(color: t.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 64,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final v = reduce ? 0.5 : _c.value;
                final travel = Curves.easeInOut.transform(((v - 0.05) / 0.7).clamp(0.0, 1.0));
                return Stack(
                  children: [
                    Center(
                      child: Row(
                        children: [
                          _node(t, const Color(0xFF2DD4BF), '🤖', 'Pulse', 'buyer'),
                          Expanded(
                            child: Container(
                              height: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: t.border,
                            ),
                          ),
                          _node(t, const Color(0xFFEC4899), '✍️', 'Sage', 'creator'),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: Align(
                          alignment: Alignment(travel * 2 - 1, -0.55),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: PulsColors.pulseGradient,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [BoxShadow(color: const Color(0xFFF65FA9).withValues(alpha: 0.5), blurRadius: 10)],
                            ),
                            child: const Text('0.001 USDC',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('“$title”',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Sage earned \$${revenue.toStringAsFixed(2)} from $unlocks unlocks',
                          style: TextStyle(color: t.textMuted, fontSize: 11.5)),
                    ],
                  ),
                ),
                if (onchainTx != null && onchainTx.isNotEmpty) _TxLink(label: 'attested ↗', tx: onchainTx),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _node(PulsThemeColors t, Color c, String glyph, String name, String role) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c, Color.alphaBlend(Colors.white.withValues(alpha: 0.4), c)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: PulsEmoji.icon(glyph, size: 19),
          ),
          const SizedBox(height: 5),
          Text(name, style: TextStyle(color: t.text, fontSize: 11, fontWeight: FontWeight.w800)),
          Text(role, style: TextStyle(color: t.textSubtle, fontSize: 9.5)),
        ],
      );
}

// ── On-chain proof strip ──────────────────────────────────────────────────────
class _ProofStrip extends StatelessWidget {
  const _ProofStrip({required this.decisions, required this.sage});
  final List<_Decision> decisions;
  final Map<String, dynamic>? sage;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final seen = <String>{};
    final txs = <String>[];
    for (final d in decisions) {
      for (final h in [d.txHash, d.alphaTx]) {
        if (h != null && h.length > 12 && seen.add(h)) txs.add(h);
      }
      if (txs.length >= 10) break;
    }
    if (txs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF16A34A)),
            const SizedBox(width: 7),
            Text('EVERY MOVE IS ON-CHAIN — VERIFY ANY OF IT',
                style: TextStyle(color: t.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [for (final h in txs) _TxChip(tx: h)],
        ),
      ],
    );
  }
}

class _TxChip extends StatefulWidget {
  const _TxChip({required this.tx});
  final String tx;

  @override
  State<_TxChip> createState() => _TxChipState();
}

class _TxChipState extends State<_TxChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final short = '${widget.tx.substring(0, 8)}…${widget.tx.substring(widget.tx.length - 6)}';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse('https://testnet.arcscan.app/tx/${widget.tx}'),
            mode: LaunchMode.externalApplication),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: _hover ? t.brand.withValues(alpha: 0.08) : t.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _hover ? t.brand.withValues(alpha: 0.4) : t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              Text(short,
                  style: TextStyle(
                      color: t.textMuted,
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.open_in_new_rounded, size: 11, color: _hover ? t.brand : t.textSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _TxLink extends StatelessWidget {
  const _TxLink({required this.label, required this.tx});
  final String label;
  final String tx;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse('https://testnet.arcscan.app/tx/$tx'),
            mode: LaunchMode.externalApplication),
        child: Text(label,
            style: TextStyle(color: t.brand, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Market pulse (live WebSocket trades) ──────────────────────────────────────
class _MarketPulse extends StatefulWidget {
  const _MarketPulse();

  @override
  State<_MarketPulse> createState() => _MarketPulseState();
}

class _PulseTrade {
  _PulseTrade(this.question, this.side, this.amount);
  final String question;
  final String side;
  final double amount;
}

class _MarketPulseState extends State<_MarketPulse> {
  final List<_PulseTrade> _trades = [];
  WebSocketChannel? _channel;
  bool _connected = false;
  Timer? _poll;
  Timer? _reconnect;
  int _backoff = 2;

  @override
  void initState() {
    super.initState();
    _seed();
    _connect();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _reconnect?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _seed() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/trade/recent?limit=6'))
          .timeout(const Duration(seconds: 8));
      if (!mounted || res.statusCode != 200) return;
      final list = json.decode(res.body) as List<dynamic>;
      final seed = <_PulseTrade>[];
      for (final raw in list) {
        final j = raw as Map<String, dynamic>;
        if (j['state'] != null && j['state'] != 'COMPLETE') continue;
        final pt = _fromJson(j);
        if (pt != null) seed.add(pt);
        if (seed.length >= 5) break;
      }
      if (seed.isNotEmpty && mounted) setState(() => _trades..clear()..addAll(seed));
    } catch (_) {/* ignore */}
  }

  _PulseTrade? _fromJson(Map<String, dynamic> j) {
    final q = j['question'] as String? ?? '';
    if (q.isEmpty) return null;
    final side = (j['side'] as String? ?? 'YES').toUpperCase();
    final amount = (j['usdc_amount'] as num?)?.toDouble() ??
        (j['amount'] as num?)?.toDouble() ??
        (j['usdcAmount'] as num?)?.toDouble() ??
        0;
    return _PulseTrade(q, side, amount);
  }

  void _connect() {
    _reconnect?.cancel();
    try {
      final wsUri = Uri.parse(
          backendUrl.replaceAll('http://', 'ws://').replaceAll('https://', 'wss://'));
      _channel = WebSocketChannel.connect(wsUri);
      _channel!.ready.then((_) {
        if (!mounted) return;
        setState(() => _connected = true);
        _backoff = 2;
        _poll?.cancel();
        _poll = null;
      }).catchError((_) => _onFailure());
      _channel!.stream.listen(
        (event) {
          if (!mounted) return;
          if (!_connected) setState(() => _connected = true);
          try {
            final j = json.decode(event.toString()) as Map<String, dynamic>;
            final pt = _fromJson(j);
            if (pt != null) _push(pt);
          } catch (_) {/* ignore malformed */}
        },
        onError: (_) => _onFailure(),
        onDone: _onFailure,
      );
    } catch (_) {
      _onFailure();
    }
  }

  void _onFailure() {
    if (!mounted) return;
    if (_connected) setState(() => _connected = false);
    _startPolling();
    _reconnect?.cancel();
    _reconnect = Timer(Duration(seconds: _backoff), () {
      if (mounted && !_connected) _connect();
    });
    _backoff = math.min(8, _backoff * 2);
  }

  void _startPolling() {
    if (_poll != null) return;
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_connected) _seed();
    });
  }

  void _push(_PulseTrade pt) {
    setState(() {
      _trades.insert(0, pt);
      while (_trades.length > 5) {
        _trades.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_trades.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PulseDot(size: 6, color: Color(0xFF22C55E)),
              const SizedBox(width: 4),
              Text(_connected ? 'TRADES STREAMING LIVE' : 'RECENT TRADES',
                  style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const Spacer(),
              Text('via WebSocket', style: TextStyle(color: t.textSubtle, fontSize: 10.5)),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (var i = 0; i < _trades.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                    child: _PulseRow(trade: _trades[i], fresh: i == 0),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRow extends StatelessWidget {
  const _PulseRow({required this.trade, required this.fresh});
  final _PulseTrade trade;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isYes = trade.side == 'YES';
    final c = isYes ? t.yes : t.no;
    return TweenAnimationBuilder<double>(
      key: ValueKey(identityHashCode(trade)),
      tween: Tween(begin: fresh ? 0.0 : 1.0, end: 1.0),
      duration: context.motionDuration(const Duration(milliseconds: 420)),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * -8), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: fresh ? c.withValues(alpha: 0.06) : t.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fresh ? c.withValues(alpha: 0.25) : t.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(7)),
              child: Text(trade.side,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(trade.question,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 10),
            Text('\$${trade.amount.toStringAsFixed(trade.amount == trade.amount.roundToDouble() ? 0 : 2)}',
                style: TextStyle(color: t.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

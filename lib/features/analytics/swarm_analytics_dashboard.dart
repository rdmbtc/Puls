import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/puls_loader.dart';

/// Live Swarm Analytics Dashboard — the "mission control" view of the Puls
/// agent economy on Arc. Aggregates four live backend feeds into one
/// scrollable, glassmorphic dashboard:
///
///   • GET /api/agents/roster  → TVL + agent count
///   • GET /api/agents/feed    → 24h activity, hourly line chart, alpha payments
///   • GET /api/economy/feed   → on-chain USDC ticker
///   • GET /api/leaderboard    → top AI PnL vs top Human PnL
///
/// Built to prove the swarm is real: every number here is backed by live data.
class SwarmAnalyticsDashboard extends StatefulWidget {
  const SwarmAnalyticsDashboard({super.key});

  @override
  State<SwarmAnalyticsDashboard> createState() =>
      _SwarmAnalyticsDashboardState();
}

class _AlphaPayment {
  const _AlphaPayment({
    required this.payer,
    required this.recipient,
    required this.amount,
    required this.market,
    required this.at,
  });

  final String payer;
  final String recipient;
  final double amount;
  final String market;
  final DateTime at;
}

class _TickerItem {
  const _TickerItem({
    required this.action,
    required this.amount,
    required this.at,
  });

  final String action;
  final double amount;
  final DateTime at;
}

class _SwarmAnalyticsDashboardState extends State<SwarmAnalyticsDashboard> {
  bool _loading = true;
  Timer? _refresh;

  // Roster
  double _tvl = 0;
  int _agentCount = 0;

  // Feed
  int _activity24h = 0;
  List<double> _hourlyActivity = const []; // 24 buckets, oldest → newest
  List<_AlphaPayment> _alphaPayments = const [];

  // Leaderboard
  double _topAgentPnl = 0;
  double _topHumanPnl = 0;
  String _topAgentName = 'Top agent';
  String _topHumanName = 'Top human';
  bool _hasLeaderboard = false;

  // Economy ticker
  List<_TickerItem> _ticker = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
    _refresh = Timer.periodic(const Duration(seconds: 45), (_) => _loadAll());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadRoster(),
      _loadFeed(),
      _loadEconomy(),
      _loadLeaderboard(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<Map<String, dynamic>?> _getJson(String path) async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl$path'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : {'_list': decoded};
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadRoster() async {
    final body = await _getJson('/api/agents/roster');
    if (body == null || !mounted) return;
    final agents = ((body['agents'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    double tvl = 0;
    for (final a in agents) {
      tvl += (a['balance'] as num?)?.toDouble() ?? 0;
    }
    setState(() {
      _tvl = tvl;
      _agentCount = agents.length;
    });
  }

  Future<void> _loadFeed() async {
    final body = await _getJson('/api/agents/feed?limit=200');
    if (body == null || !mounted) return;
    final events = ((body['events'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));
    final buckets = List<double>.filled(24, 0);
    int count24h = 0;
    final alpha = <_AlphaPayment>[];

    for (final e in events) {
      final at =
          DateTime.tryParse(e['at'] as String? ?? '')?.toLocal() ?? now;
      if (at.isAfter(cutoff)) {
        count24h++;
        final hoursAgo = now.difference(at).inHours.clamp(0, 23);
        buckets[23 - hoursAgo] += 1;
      }
      final paid = (e['alphaPaid'] as num?)?.toDouble();
      if (paid != null && paid > 0) {
        alpha.add(_AlphaPayment(
          payer: e['agentName'] as String? ?? 'Agent',
          recipient: (e['alphaTo'] ?? e['alphaToName'] ?? 'Sage').toString(),
          amount: paid,
          market: e['question'] as String? ?? '',
          at: at,
        ));
      }
    }

    setState(() {
      _activity24h = count24h;
      _hourlyActivity = buckets;
      _alphaPayments = alpha.take(8).toList();
    });
  }

  Future<void> _loadEconomy() async {
    final body = await _getJson('/api/economy/feed?limit=30');
    if (body == null || !mounted) return;
    final items = <_TickerItem>[];
    for (final raw in ((body['feed'] ?? body['events']) as List? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      items.add(_TickerItem(
        action: raw['action'] as String? ?? 'USDC transfer',
        amount: (raw['value_usdc'] as num?)?.toDouble() ??
            (raw['amount'] as num?)?.toDouble() ??
            0,
        at: DateTime.tryParse(raw['timestamp'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      ));
    }
    setState(() => _ticker = items);
  }

  Future<void> _loadLeaderboard() async {
    try {
      final res = await http
          .get(Uri.parse(
              '$backendUrl/api/leaderboard?sort=pnl&limit=100&type=all'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 || !mounted) return;
      final decoded = jsonDecode(res.body);

      double topAgent = 0, topHuman = 0;
      String agentName = 'Top agent', humanName = 'Top human';
      bool hasAgent = false, hasHuman = false;

      double pnlOf(Map row) =>
          (row['pnlUsdc'] as num?)?.toDouble() ??
          (row['pnl'] as num?)?.toDouble() ??
          double.tryParse('${row['pnlUsdc'] ?? row['pnl'] ?? ''}') ??
          0;
      String nameOf(Map row) =>
          (row['name'] ?? row['username'] ?? row['displayName'] ?? 'Trader')
              .toString();

      if (decoded is Map<String, dynamic>) {
        // Shape: { roster: [...], human: [...] }
        for (final row
            in ((decoded['roster'] as List?) ?? const []).whereType<Map>()) {
          final p = pnlOf(row);
          if (!hasAgent || p > topAgent) {
            topAgent = p;
            agentName = nameOf(row);
            hasAgent = true;
          }
        }
        for (final row
            in ((decoded['human'] as List?) ?? const []).whereType<Map>()) {
          final p = pnlOf(row);
          if (!hasHuman || p > topHuman) {
            topHuman = p;
            humanName = nameOf(row);
            hasHuman = true;
          }
        }
      } else if (decoded is List) {
        // Shape: flat list with isAgent flag (current backend).
        for (final row in decoded.whereType<Map>()) {
          final p = pnlOf(row);
          if (row['isAgent'] == true) {
            if (!hasAgent || p > topAgent) {
              topAgent = p;
              agentName = nameOf(row);
              hasAgent = true;
            }
          } else {
            if (!hasHuman || p > topHuman) {
              topHuman = p;
              humanName = nameOf(row);
              hasHuman = true;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _topAgentPnl = topAgent;
        _topHumanPnl = topHuman;
        _topAgentName = agentName;
        _topHumanName = humanName;
        _hasLeaderboard = hasAgent || hasHuman;
      });
    } catch (_) {
      // Leaderboard is optional — dashboard still renders without it.
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_loading) return const PulsLoader();

    return RefreshIndicator(
      color: t.brand,
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (_ticker.isNotEmpty) ...[
            _OnChainTicker(items: _ticker, ago: _ago),
            const SizedBox(height: 16),
          ],
          _header(t),
          const SizedBox(height: 16),
          _headerCards(t),
          const SizedBox(height: 16),
          _GlassCard(
            title: 'Swarm activity — last 24h',
            subtitle: 'Agent decisions, trades & payments per hour',
            icon: Icons.show_chart_rounded,
            child: SizedBox(height: 200, child: _activityChart(t)),
          ),
          const SizedBox(height: 16),
          if (_hasLeaderboard)
            _GlassCard(
              title: 'AI vs Humans',
              subtitle: 'Top PnL on Arc Testnet — live',
              icon: Icons.sports_kabaddi_rounded,
              child: _aiVsHumans(t),
            ),
          if (_hasLeaderboard) const SizedBox(height: 16),
          _GlassCard(
            title: 'Agent economy flow',
            subtitle: 'Agents paying agents USDC for alpha — x402 on Arc',
            icon: Icons.currency_exchange_rounded,
            child: _alphaFlow(t),
          ),
        ],
      ),
    );
  }

  Widget _header(PulsThemeColors t) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: PulsColors.pulseGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedGradientText(
                'Swarm Analytics',
                textAlign: TextAlign.left,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              Text(
                'Live telemetry of the autonomous AI economy on Arc',
                style: TextStyle(color: t.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        _liveDot(t),
      ],
    );
  }

  Widget _liveDot(PulsThemeColors t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: t.yes.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: t.yes.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: t.yes, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text('LIVE',
                style: TextStyle(
                    color: t.yes,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8)),
          ],
        ),
      );

  // ── Header cards ───────────────────────────────────────────────────────────

  Widget _headerCards(PulsThemeColors t) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 640;
      final cards = [
        _StatCard(
          label: 'Total Swarm TVL',
          gradientValue: '\$${_tvl.toStringAsFixed(2)}',
          suffix: 'USDC',
          icon: Icons.account_balance_wallet_rounded,
          big: true,
        ),
        _StatCard(
          label: 'Agent activity · 24h',
          value: '$_activity24h',
          suffix: 'events',
          icon: Icons.bolt_rounded,
        ),
        _StatCard(
          label: 'Total agents',
          value: '$_agentCount',
          suffix: 'in the swarm',
          icon: Icons.smart_toy_rounded,
        ),
      ];
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: cards[0]),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: cards[1]),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: cards[2]),
          ],
        );
      }
      return Column(children: [
        cards[0],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: cards[1]),
          const SizedBox(width: 12),
          Expanded(child: cards[2]),
        ]),
      ]);
    });
  }

  // ── Activity line chart ────────────────────────────────────────────────────

  Widget _activityChart(PulsThemeColors t) {
    final buckets =
        _hourlyActivity.isEmpty ? List<double>.filled(24, 0) : _hourlyActivity;
    final maxY = buckets.fold<double>(0, (m, v) => v > m ? v : m);
    if (maxY == 0) {
      return Center(
        child: Text(
          'The swarm is quiet right now — activity will chart here.',
          style: TextStyle(color: t.textMuted, fontSize: 13),
        ),
      );
    }
    final spots = <FlSpot>[
      for (var i = 0; i < buckets.length; i++)
        FlSpot(i.toDouble(), buckets[i]),
    ];
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.25,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 6,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final hoursAgo = 23 - value.toInt();
                final label = hoursAgo == 0 ? 'now' : '-${hoursAgo}h';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label,
                      style: TextStyle(color: t.textSubtle, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => t.surfaceRaised,
            getTooltipItems: (touched) => touched
                .map((s) => LineTooltipItem(
                      '${s.y.toInt()} actions',
                      TextStyle(
                          color: t.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            barWidth: 3,
            isStrokeCapRound: true,
            gradient: PulsColors.pulseGradient,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  PulsColors.brandMint.withValues(alpha: 0.28),
                  PulsColors.brandMint.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI vs Humans bar chart ─────────────────────────────────────────────────

  Widget _aiVsHumans(PulsThemeColors t) {
    final maxAbs = [_topAgentPnl.abs(), _topHumanPnl.abs(), 1.0]
        .fold<double>(0, (m, v) => v > m ? v : m);
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxAbs * 1.3,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => t.surfaceRaised,
                  getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                    '\$${rod.toY.toStringAsFixed(2)} PnL',
                    TextStyle(
                        color: t.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        value == 0 ? 'AI · $_topAgentName' : _topHumanName,
                        style: TextStyle(
                            color: t.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [
                  BarChartRodData(
                    toY: _topAgentPnl.abs(),
                    width: 42,
                    borderRadius: BorderRadius.circular(8),
                    gradient: PulsColors.pulseGradient,
                  ),
                ]),
                BarChartGroupData(x: 1, barRods: [
                  BarChartRodData(
                    toY: _topHumanPnl.abs(),
                    width: 42,
                    borderRadius: BorderRadius.circular(8),
                    color: t.textSubtle,
                  ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _pnlPill(t, '🤖 $_topAgentName', _topAgentPnl,
                highlighted: true),
          ),
          const SizedBox(width: 10),
          Expanded(child: _pnlPill(t, '🧑 $_topHumanName', _topHumanPnl)),
        ]),
      ],
    );
  }

  Widget _pnlPill(PulsThemeColors t, String label, double pnl,
      {bool highlighted = false}) {
    final positive = pnl >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? t.brandSubtle : t.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: highlighted ? t.brand.withValues(alpha: 0.35) : t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: t.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '${positive ? '+' : '−'}\$${pnl.abs().toStringAsFixed(2)}',
            style: TextStyle(
                color: positive ? t.yes : t.no,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4),
          ),
        ],
      ),
    );
  }

  // ── Alpha payments flow ────────────────────────────────────────────────────

  Widget _alphaFlow(PulsThemeColors t) {
    if (_alphaPayments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No alpha payments in the recent feed — agents pay each other USDC '
          'when they buy signals. New payments land here.',
          style: TextStyle(color: t.textMuted, fontSize: 13),
        ),
      );
    }
    return Column(
      children: [
        for (final p in _alphaPayments)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.surfaceRaised.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: t.brandSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.electric_bolt_rounded,
                      color: t.brand, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: TextStyle(
                              color: t.textMuted,
                              fontSize: 12.5,
                              fontFamily: PulsColors.fontSans,
                              height: 1.4),
                          children: [
                            TextSpan(
                                text: p.payer,
                                style: TextStyle(
                                    color: t.text,
                                    fontWeight: FontWeight.w800)),
                            const TextSpan(text: ' paid '),
                            TextSpan(
                                text: p.recipient,
                                style: TextStyle(
                                    color: t.text,
                                    fontWeight: FontWeight.w800)),
                            TextSpan(
                                text:
                                    ' \$${p.amount.toStringAsFixed(3)} USDC for alpha',
                                style: TextStyle(
                                    color: t.brand,
                                    fontWeight: FontWeight.w800)),
                            if (p.market.isNotEmpty)
                              TextSpan(text: ' on "${p.market}"'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(_ago(p.at),
                          style:
                              TextStyle(color: t.textSubtle, fontSize: 10.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    this.value,
    this.gradientValue,
    this.suffix,
    this.big = false,
  });

  final String label;
  final IconData icon;
  final String? value; // plain-text number
  final String? gradientValue; // rendered with the pulse gradient
  final String? suffix;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.brand.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Icon(icon, size: 15, color: t.brand),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: t.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 10),
              if (gradientValue != null)
                AnimatedGradientText(
                  gradientValue!,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: big ? 32 : 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      fontFeatures: PulsColors.tabularFigures),
                )
              else
                Text(value ?? '—',
                    style: TextStyle(
                        color: t.text,
                        fontSize: big ? 32 : 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        fontFeatures: PulsColors.tabularFigures)),
              if (suffix != null) ...[
                const SizedBox(height: 2),
                Text(suffix!,
                    style: TextStyle(color: t.textSubtle, fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Glass section card ────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 17, color: t.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: t.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3)),
                ),
              ]),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 25),
                child: Text(subtitle,
                    style: TextStyle(color: t.textMuted, fontSize: 11.5)),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── On-chain ticker (marquee) ─────────────────────────────────────────────────

class _OnChainTicker extends StatefulWidget {
  const _OnChainTicker({required this.items, required this.ago});

  final List<_TickerItem> items;
  final String Function(DateTime) ago;

  @override
  State<_OnChainTicker> createState() => _OnChainTickerState();
}

class _OnChainTickerState extends State<_OnChainTicker> {
  final _controller = ScrollController();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Auto-scroll ~30 px/s; jump back when we near the end for an endless feel.
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) return;
      final next = _controller.offset + 1.5;
      if (next >= max) {
        _controller.jumpTo(0);
      } else {
        _controller.jumpTo(next);
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    // Repeat the list so the loop point is less jarring.
    final items = [...widget.items, ...widget.items];
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: PulsColors.pulseGradient,
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(11)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sensors_rounded, color: Colors.white, size: 14),
                SizedBox(width: 5),
                Text('ARC',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final e = items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            color: t.yes, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${widget.ago(e.at)} · ${e.action} · '
                        '${e.amount.toStringAsFixed(e.amount < 1 ? 4 : 2)} USDC on Arc Testnet',
                        style: TextStyle(
                            color: t.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            fontFeatures: PulsColors.tabularFigures),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

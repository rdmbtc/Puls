import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/agent_pfp.dart';
import 'landing_kit.dart';

/// Live "Humans vs Agents" leaderboard — the core narrative made literal.
/// Ranks real human and AI traders side by side by on-chain win rate, straight
/// from /api/leaderboard. Renders nothing until data with at least one agent
/// loads, so the landing never shows an empty board.
class AgentsLeaderboardSection extends StatefulWidget {
  const AgentsLeaderboardSection({super.key});

  @override
  State<AgentsLeaderboardSection> createState() =>
      _AgentsLeaderboardSectionState();
}

class _Row {
  const _Row({
    required this.name,
    required this.avatar,
    required this.isAgent,
    required this.erc8004,
    required this.winRate,
    required this.pnl,
    required this.trades,
  });
  final String name;
  final String avatar;
  final bool isAgent;
  final String? erc8004;
  final double winRate;
  final double pnl;
  final int trades;
}

class _AgentsLeaderboardSectionState extends State<AgentsLeaderboardSection> {
  bool _loaded = false;
  List<_Row> _rows = const [];
  double _agentWin = 0, _humanWin = 0;
  int _agentCount = 0, _humanCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final list = await WalletServiceScope.of(context)
          .getLeaderboard(sort: 'pnl', limit: 50, type: 'all');
      final rows = <_Row>[];
      double aSum = 0, hSum = 0;
      int aN = 0, hN = 0;
      for (final raw in list) {
        if (raw is! Map) continue;
        final trades = (raw['tradesCount'] as num?)?.toInt() ??
            (raw['trades'] as num?)?.toInt() ??
            0;
        final win = (raw['winRate'] as num?)?.toDouble() ??
            double.tryParse(raw['winRate']?.toString() ?? '') ??
            0;
        final isAgent = raw['isAgent'] == true;
        if (trades > 0) {
          if (isAgent) {
            aSum += win;
            aN++;
          } else {
            hSum += win;
            hN++;
          }
        }
        rows.add(_Row(
          name: (raw['displayName'] as String? ?? 'Trader').trim(),
          avatar: (raw['avatarUrl'] as String? ?? '').trim(),
          isAgent: isAgent,
          erc8004: (raw['erc8004Id']?.toString().isNotEmpty ?? false)
              ? raw['erc8004Id'].toString()
              : null,
          winRate: win,
          pnl: (raw['pnl'] as num?)?.toDouble() ?? 0,
          trades: trades,
        ));
      }
      if (!mounted) return;
      setState(() {
        _rows = rows.take(8).toList();
        _agentCount = aN;
        _humanCount = hN;
        _agentWin = aN > 0 ? aSum / aN : 0;
        _humanWin = hN > 0 ? hSum / hN : 0;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 760;
    if (!_loaded || _agentCount == 0 || _rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 52 : 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              const LandingEyebrow(label: 'HUMANS vs AGENTS', icon: Icons.emoji_events_rounded),
              const SizedBox(height: 20),
              LandingHeadline(
                lead: 'The AIs are on the',
                accent: 'leaderboard too.',
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 28 : 40),
              // Scoreboard
              Row(
                children: [
                  Expanded(
                    child: _ScorePill(
                      emoji: '🤖',
                      label: 'Agents',
                      value: '${_agentWin.toStringAsFixed(1)}%',
                      sub: '$_agentCount on-chain · avg win',
                      gradient: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ScorePill(
                      emoji: '🧑',
                      label: 'Humans',
                      value: _humanCount > 0 ? '${_humanWin.toStringAsFixed(1)}%' : '—',
                      sub: '$_humanCount traders · avg win',
                      gradient: false,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 16 : 20),
              // Leaderboard list
              Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _rows.length; i++) ...[
                      if (i > 0) Divider(height: 1, thickness: 1, color: t.border),
                      _LbRow(rank: i + 1, row: _rows[i], isMobile: isMobile),
                    ],
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 20 : 28),
              _SeeAllButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.emoji,
    required this.label,
    required this.value,
    required this.sub,
    required this.gradient,
  });
  final String emoji;
  final String label;
  final String value;
  final String sub;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.brand.withValues(alpha: 0.14), t.surface],
              )
            : null,
        color: gradient ? null : t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: gradient ? t.brand.withValues(alpha: 0.35) : t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji $label',
              style: TextStyle(
                  color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          gradient
              ? AnimatedGradientText(value,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                      fontFamily: PulsColors.fontDisplay,
                      fontSize: 32,
                      fontWeight: FontWeight.w800))
              : Text(value,
                  style: TextStyle(
                      fontFamily: PulsColors.fontDisplay,
                      color: t.text,
                      fontSize: 32,
                      fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: t.textSubtle, fontSize: 11)),
        ],
      ),
    );
  }
}

class _LbRow extends StatelessWidget {
  const _LbRow({required this.rank, required this.row, required this.isMobile});
  final int rank;
  final _Row row;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final pnlUp = row.pnl >= 0;
    final pnlColor = pnlUp ? t.yes : t.no;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 12),
      color: row.isAgent ? t.brand.withValues(alpha: 0.04) : Colors.transparent,
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('$rank',
                style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
          _Avatar(url: row.avatar, isAgent: row.isAgent, name: row.name),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: t.text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700)),
                    ),
                    if (row.isAgent) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.brand.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                            row.erc8004 != null ? 'ERC-8004 #${row.erc8004}' : '🤖 AGENT',
                            style: TextStyle(
                                color: t.brand,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('${row.trades} trades',
                    style: TextStyle(color: t.textSubtle, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${row.winRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: 2),
              Text('${pnlUp ? '+' : '-'}\$${row.pnl.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                      color: pnlColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.isAgent, required this.name});
  final String url;
  final bool isAgent;
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final ring = isAgent ? t.brand : t.border;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.surfaceRaised,
        border: Border.all(color: ring.withValues(alpha: 0.6), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: () {
        final pfp = agentPfpAsset(name);
        if (pfp != null) return Image.asset(pfp, fit: BoxFit.cover);
        if (url.isNotEmpty) {
          return Image.network(url, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                  isAgent ? Icons.smart_toy_rounded : Icons.person_rounded,
                  size: 18,
                  color: t.textSubtle));
        }
        return Icon(isAgent ? Icons.smart_toy_rounded : Icons.person_rounded,
            size: 18, color: t.textSubtle);
      }(),
    );
  }
}

class _SeeAllButton extends StatefulWidget {
  @override
  State<_SeeAllButton> createState() => _SeeAllButtonState();
}

class _SeeAllButtonState extends State<_SeeAllButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.base.resolve('/versus'),
            mode: LaunchMode.externalApplication),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _hover ? t.surfaceRaised : t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hover ? t.textMuted : t.border),
          ),
          child: Text('See the full Humans vs Agents board ↗',
              style: TextStyle(
                  color: _hover ? t.text : t.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

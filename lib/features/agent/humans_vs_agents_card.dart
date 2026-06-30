import 'package:flutter/material.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_emoji_text.dart';

/// Live "Humans vs Agents" scoreboard — Puls's core narrative made literal.
/// Aggregates live win-rates from /api/leaderboard so anyone (judges included)
/// immediately sees autonomous AI agents trading alongside — and often
/// out-performing — humans on Arc. Renders nothing until data with at least
/// one agent loads.
///
/// Shared widget: shown on Home (overview) and on the Agent tab (the flagship
/// agent home), so it lives in exactly one place in code.
class HumansVsAgentsCard extends StatefulWidget {
  const HumansVsAgentsCard({super.key});

  @override
  State<HumansVsAgentsCard> createState() => _HumansVsAgentsCardState();
}

class _HumansVsAgentsCardState extends State<HumansVsAgentsCard> {
  bool _loaded = false;
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
          .getLeaderboard(limit: 200, type: 'all');
      double aSum = 0, hSum = 0;
      int aN = 0, hN = 0;
      for (final row in list) {
        if (row is! Map) continue;
        final trades = (row['tradesCount'] as num?)?.toInt() ??
            (row['trades'] as num?)?.toInt() ??
            0;
        if (trades <= 0) continue;
        final win = double.tryParse(row['winRate']?.toString() ??
                row['win_rate']?.toString() ??
                '') ??
            0;
        if (row['isAgent'] == true) {
          aSum += win;
          aN++;
        } else {
          hSum += win;
          hN++;
        }
      }
      if (mounted) {
        setState(() {
          _agentCount = aN;
          _humanCount = hN;
          _agentWin = aN > 0 ? aSum / aN : 0;
          _humanWin = hN > 0 ? hSum / hN : 0;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    // Need at least one agent to make the comparison meaningful.
    if (!_loaded || _agentCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.brand.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.brand.withValues(alpha: 0.12), t.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: t.brand, size: 18),
              const SizedBox(width: 6),
              Text('Humans vs Agents',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Live win rate · Arc Testnet',
              style: TextStyle(color: t.textMuted, fontSize: 11)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ScorePill(
                  emoji: '🤖',
                  label: 'Agents',
                  value: '${_agentWin.toStringAsFixed(1)}%',
                  sub: '$_agentCount on-chain',
                  color: t.brand,
                  bg: t.brandSubtle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScorePill(
                  emoji: '🧑',
                  label: 'Humans',
                  value: _humanCount > 0
                      ? '${_humanWin.toStringAsFixed(1)}%'
                      : '—',
                  sub: '$_humanCount traders',
                  color: t.text,
                  bg: t.surfaceRaised,
                ),
              ),
            ],
          ),
        ],
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
    required this.color,
    required this.bg,
  });

  final String emoji;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulsEmojiText('$emoji $label',
              style: TextStyle(
                  color: t.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: t.textSubtle, fontSize: 10)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/agent_pfp.dart';

/// Compact Season-1 points leaderboard + a "season ends in Xd" timer.
/// A competitive retention loop — people trade/earn to climb. Humans + agents.
class SeasonLeaderboardCard extends StatefulWidget {
  const SeasonLeaderboardCard({super.key});

  @override
  State<SeasonLeaderboardCard> createState() => _SeasonLeaderboardCardState();
}

class _SeasonLeaderboardCardState extends State<SeasonLeaderboardCard> {
  List<dynamic> _rows = const [];
  bool _loading = true;

  // Season 1 end (event window). Adjust as needed.
  static final DateTime _seasonEnd = DateTime.utc(2026, 6, 29, 23, 59);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final wallet = WalletServiceScope.of(context);
      final rows = await wallet.getPointsLeaderboard();
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _name(String userId) {
    const agents = {
      'house_pulse': 'Pulse 🤖', 'agent_sage': 'Sage 🔮',
      'agent_swarm_vega': 'Vega ⚡', 'agent_swarm_cygnus': 'Cygnus 🛡️',
      'agent_swarm_orion': 'Orion 🔭', 'agent_swarm_atlas': 'Atlas 📈',
      'agent_swarm_nova': 'Nova 🌐', 'agent_swarm_striker': 'Striker ⚽',
    };
    if (agents.containsKey(userId)) return agents[userId]!;
    if (userId.startsWith('eth_')) {
      final a = userId.substring(4);
      return a.length > 10 ? '${a.substring(0, 6)}…${a.substring(a.length - 4)}' : a;
    }
    if (userId.startsWith('supabase_')) return 'Trader ${userId.substring(9, 13)}';
    return 'Trader';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    // Don't render an empty shell before any points exist.
    if (_loading || _rows.isEmpty) return const SizedBox.shrink();
    final daysLeft = _seasonEnd.difference(DateTime.now().toUtc()).inDays;
    final top = _rows.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.emoji_events_rounded, size: 17, color: t.brand),
            const SizedBox(width: 7),
            Text('Season 1', style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w900)),
            const Spacer(),
            if (daysLeft >= 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: t.brandSubtle, borderRadius: BorderRadius.circular(6)),
                child: Text('ends in ${daysLeft}d',
                    style: TextStyle(color: t.brand, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
          ]),
          const SizedBox(height: 12),
          ...top.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value as Map<String, dynamic>;
            final uid = r['user_id'] as String? ?? '';
            final pts = (r['season_points'] as num?)?.toInt() ?? 0;
            final isAgent = r['isAgent'] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 18, child: Text('${i + 1}',
                    style: TextStyle(color: i == 0 ? t.brand : t.textSubtle, fontSize: 12, fontWeight: FontWeight.w900))),
                if (agentPfpAsset(uid) != null) ...[
                  ClipOval(
                      child: Image.asset(agentPfpAsset(uid)!,
                          width: 18, height: 18, fit: BoxFit.cover)),
                  const SizedBox(width: 6),
                ] else if (isAgent) ...[
                  Icon(Icons.smart_toy_rounded, size: 12, color: t.brand),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(_name(uid), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: t.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
                Text('$pts XP', style: TextStyle(color: t.textMuted, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

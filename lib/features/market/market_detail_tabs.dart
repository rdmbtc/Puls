import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/config.dart' show backendUrl;
import '../../core/theme/app_theme.dart';
import '../../core/utils/agent_pfp.dart';
import '../../core/widgets/puls_loader.dart';
import '../comments/comment_thread.dart';

/// Tabbed section for Market Detail: Activity, Top Holders, Positions, Comments.
class MarketDetailTabs extends StatefulWidget {
  const MarketDetailTabs({
    super.key,
    required this.marketId,
    required this.question,
    this.contractAddress,
  });
  final String marketId;
  final String question;
  final String? contractAddress;

  @override
  State<MarketDetailTabs> createState() => _MarketDetailTabsState();
}

class _MarketDetailTabsState extends State<MarketDetailTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<Map<String, dynamic>> _activity = [];
  bool _activityLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _fetchActivity();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  /// True when a trade row belongs to this market. Trades store `market_id` as
  /// the on-chain contract address (0x…), NOT the Polymarket id used by the
  /// Market model — so match on the contract address first, then fall back to
  /// the (less reliable) question text or raw id.
  bool _belongsToMarket(Map<String, dynamic> t) {
    final tid = (t['market_id'] as String? ?? '').toLowerCase();
    final addr = widget.contractAddress?.toLowerCase();
    if (addr != null && addr.isNotEmpty && tid == addr) return true;
    if (tid == widget.marketId.toLowerCase()) return true;
    // Fallback: same question (covers rows saved before a contract was linked).
    final q = (t['question'] as String? ?? '').trim();
    if (q.isNotEmpty && q == widget.question.trim()) return true;
    return false;
  }

  Future<void> _fetchActivity() async {
    try {
      final mId = (widget.contractAddress?.isNotEmpty == true) ? widget.contractAddress! : widget.marketId;
      final res = await http.get(
        Uri.parse('$backendUrl/api/trade/recent?limit=100&marketId=$mId'),
      );
      if (res.statusCode != 200) throw Exception('Failed');
      final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      final filtered = list.where(_belongsToMarket).toList();
      if (mounted) setState(() { _activity = filtered; _activityLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.border),
          ),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(
              gradient: PulsColors.pulseGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: PulsColors.brandPink.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: t.textMuted,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Activity'),
              Tab(text: 'Holders'),
              Tab(text: 'Positions'),
              Tab(text: 'Comments'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _ActivityTab(trades: _activity, loading: _activityLoading, t: t),
              _HoldersTab(trades: _activity, loading: _activityLoading, t: t),
              _PositionsTab(trades: _activity, loading: _activityLoading, t: t),
              CommentThread(targetType: 'market', targetId: widget.marketId),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Activity Tab ────────────────────────────────────────────────────────────

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.trades, required this.loading, required this.t});
  final List<Map<String, dynamic>> trades;
  final bool loading;
  final PulsThemeColors t;

  String _ago(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso) ?? DateTime.now();
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const PulsLoader();
    if (trades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, color: t.textMuted, size: 32),
            const SizedBox(height: 8),
            Text('No trades yet on this market.', style: TextStyle(color: t.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: trades.length,
      itemBuilder: (context, i) {
        final trade = trades[i];
        final side = trade['side'] as String? ?? 'YES';
        final isYes = side == 'YES';
        final amount = (trade['usdc_amount'] as num?)?.toDouble() ?? 0;
        final userId = trade['user_id'] as String? ?? '';
        final pfp = agentPfpAsset(userId);
        final isAgent = pfp != null || userId.startsWith('house_') || userId.contains('pulse');
        final price = (trade['entry_price'] as num?)?.toDouble() ?? 0.5;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              // Side badge
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: (isYes ? t.yes : t.no).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    side,
                    style: TextStyle(
                      color: isYes ? t.yes : t.no,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // User
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (pfp != null) ...[
                          ClipOval(child: Image.asset(pfp, width: 18, height: 18, fit: BoxFit.cover)),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            isAgent ? (agentDisplayName(userId) ?? 'Pulse 🤖') : _shortAddr(userId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (pfp == null && isAgent) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.smart_toy_rounded, size: 11, color: Color(0xFF0EA5A0)), // agent teal (AgentBadge.agentColor)
                        ],
                      ],
                    ),
                    Text(
                      'at ${(price * 100).toStringAsFixed(0)}¢',
                      style: TextStyle(color: t.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Amount + time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    _ago(trade['created_at'] as String?),
                    style: TextStyle(color: t.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _shortAddr(String id) {
    if (id.startsWith('0x') && id.length > 10) {
      return '${id.substring(0, 6)}…${id.substring(id.length - 4)}';
    }
    if (id.startsWith('supabase_')) return 'User';
    return id;
  }
}

// ── Holders Tab ─────────────────────────────────────────────────────────────
// Aggregates the market's trades by trader to approximate the largest holders
// by net USDC committed. (No dedicated on-chain holders API yet — this is the
// off-chain trade ledger, which is what the rest of the app uses for social.)

class _HoldersTab extends StatelessWidget {
  const _HoldersTab({required this.trades, required this.loading, required this.t});
  final List<Map<String, dynamic>> trades;
  final bool loading;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const PulsLoader();
    }

    // userId -> { yes, no } net USDC
    final byUser = <String, Map<String, double>>{};
    for (final trade in trades) {
      final uid = trade['user_id'] as String? ?? '';
      if (uid.isEmpty) continue;
      final side = (trade['side'] as String? ?? 'YES').toUpperCase();
      final amt = (trade['usdc_amount'] as num?)?.toDouble() ?? 0;
      final e = byUser.putIfAbsent(uid, () => {'yes': 0, 'no': 0});
      if (side == 'YES') {
        e['yes'] = e['yes']! + amt;
      } else {
        e['no'] = e['no']! + amt;
      }
    }

    final holders = byUser.entries
        .map((e) => (
              uid: e.key,
              yes: e.value['yes']!,
              no: e.value['no']!,
              total: e.value['yes']! + e.value['no']!,
            ))
        .where((h) => h.total > 0)
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    if (holders.isEmpty) {
      return _emptyState(
        t,
        icon: Icons.people_outline_rounded,
        title: 'No holders yet.',
        sub: 'Be the first to take a position on this market.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: holders.length,
      itemBuilder: (context, i) {
        final h = holders[i];
        final pfp = agentPfpAsset(h.uid);
        final isAgent = pfp != null || h.uid.startsWith('house_') || h.uid.contains('pulse');
        final leansYes = h.yes >= h.no;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text('${i + 1}',
                    style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: Row(
                  children: [
                    if (pfp != null) ...[
                      ClipOval(child: Image.asset(pfp, width: 18, height: 18, fit: BoxFit.cover)),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        isAgent ? (agentDisplayName(h.uid) ?? 'Pulse 🤖') : _shortId(h.uid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (leansYes ? t.yes : t.no).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        leansYes ? 'YES' : 'NO',
                        style: TextStyle(
                          color: leansYes ? t.yes : t.no,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${h.total.toStringAsFixed(2)}',
                style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Positions Tab ───────────────────────────────────────────────────────────
// YES vs NO distribution of committed USDC across this market's trades.

class _PositionsTab extends StatelessWidget {
  const _PositionsTab({required this.trades, required this.loading, required this.t});
  final List<Map<String, dynamic>> trades;
  final bool loading;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const PulsLoader();
    }

    double yes = 0, no = 0;
    var yesCount = 0, noCount = 0;
    for (final trade in trades) {
      final side = (trade['side'] as String? ?? 'YES').toUpperCase();
      final amt = (trade['usdc_amount'] as num?)?.toDouble() ?? 0;
      if (side == 'YES') { yes += amt; yesCount++; } else { no += amt; noCount++; }
    }
    final total = yes + no;

    if (total <= 0) {
      return _emptyState(
        t,
        icon: Icons.pie_chart_outline_rounded,
        title: 'No positions yet.',
        sub: 'YES vs NO distribution appears once trading starts.',
      );
    }

    final yesPct = (yes / total * 100);
    final noPct = 100 - yesPct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Split bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                Expanded(flex: yesPct.round().clamp(1, 100), child: ColoredBox(color: t.yes)),
                Expanded(flex: noPct.round().clamp(1, 100), child: ColoredBox(color: t.no)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _posRow(t, 'YES', yes, yesPct, yesCount, t.yes),
        const SizedBox(height: 10),
        _posRow(t, 'NO', no, noPct, noCount, t.no),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total volume', style: TextStyle(color: t.textMuted, fontSize: 12)),
            Text('\$${total.toStringAsFixed(2)}',
                style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    );
  }

  Widget _posRow(PulsThemeColors t, String label, double usd, double pct, int count, Color c) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Text('$count ${count == 1 ? 'trade' : 'trades'}',
            style: TextStyle(color: t.textSubtle, fontSize: 11)),
        const Spacer(),
        Text('${pct.toStringAsFixed(0)}%  ·  \$${usd.toStringAsFixed(2)}',
            style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── shared helpers ────────────────────────────────────────────────────────────

Widget _emptyState(PulsThemeColors t,
    {required IconData icon, required String title, required String sub}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: t.textMuted, size: 32),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(color: t.textMuted, fontSize: 13)),
        const SizedBox(height: 4),
        Text(sub, textAlign: TextAlign.center,
            style: TextStyle(color: t.textSubtle, fontSize: 11)),
      ],
    ),
  );
}

String _shortId(String id) {
  if (id.startsWith('0x') && id.length > 10) {
    return '${id.substring(0, 6)}…${id.substring(id.length - 4)}';
  }
  if (id.startsWith('eth_0x') && id.length > 14) {
    return '${id.substring(4, 10)}…${id.substring(id.length - 4)}';
  }
  if (id.startsWith('supabase_')) return 'Trader';
  return id;
}

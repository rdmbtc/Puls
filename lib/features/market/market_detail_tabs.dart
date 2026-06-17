import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/config.dart' show backendUrl;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_avatar.dart';
import '../comments/comment_thread.dart';

/// Tabbed section for Market Detail: Activity, Top Holders, Positions, Comments.
class MarketDetailTabs extends StatefulWidget {
  const MarketDetailTabs({super.key, required this.marketId, required this.question});
  final String marketId;
  final String question;

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

  Future<void> _fetchActivity() async {
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/trade/recent?limit=50'),
      );
      if (res.statusCode != 200) throw Exception('Failed');
      final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      // Filter by market_id
      final filtered = list.where((t) => t['market_id'] == widget.marketId).toList();
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
              color: t.brand.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: t.brand,
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
              _HoldersTab(marketId: widget.marketId, t: t),
              _PositionsTab(marketId: widget.marketId, t: t),
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
    if (loading) return Center(child: CircularProgressIndicator(color: t.brand, strokeWidth: 2));
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
        final isAgent = userId.startsWith('house_') || userId.contains('pulse');
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
                        Flexible(
                          child: Text(
                            isAgent ? 'Pulse 🤖' : _shortAddr(userId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isAgent) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.smart_toy_rounded, size: 11, color: const Color(0xFF8B5CF6)),
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

class _HoldersTab extends StatelessWidget {
  const _HoldersTab({required this.marketId, required this.t});
  final String marketId;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    // No dedicated API yet — show placeholder
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, color: t.textMuted, size: 32),
          const SizedBox(height: 8),
          Text('Top holders coming soon.', style: TextStyle(color: t.textMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            'Shows who holds the largest positions.',
            style: TextStyle(color: t.textSubtle, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Positions Tab ───────────────────────────────────────────────────────────

class _PositionsTab extends StatelessWidget {
  const _PositionsTab({required this.marketId, required this.t});
  final String marketId;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    // No dedicated API yet — show placeholder
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline_rounded, color: t.textMuted, size: 32),
          const SizedBox(height: 8),
          Text('Position breakdown coming soon.', style: TextStyle(color: t.textMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            'Shows YES vs NO distribution across holders.',
            style: TextStyle(color: t.textSubtle, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

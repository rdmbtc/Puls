import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import 'user_profile_screen.dart';
import 'profile_screen.dart' show GlassCard;

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _sortBy = 'pnl'; // 'pnl' or 'volume'
  bool _isLoading = true;
  String? _error;
  List<dynamic> _traders = [];

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final wallet = WalletServiceScope.of(context);
      final list = await wallet.getLeaderboard(sort: _sortBy, limit: 50);
      if (mounted) {
        setState(() {
          _traders = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          'Leaderboard',
          style: TextStyle(
            color: t.text,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: t.text),
            onPressed: _fetchLeaderboard,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sort Toggles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildSortToggles(t),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: t.brand,
                      ),
                    )
                  : _error != null
                      ? _buildErrorView(t)
                      : _traders.isEmpty
                          ? _buildEmptyView(t)
                          : _buildContent(t, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortToggles(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SortButton(
              label: 'Top Profit (PnL)',
              selected: _sortBy == 'pnl',
              t: t,
              onTap: () {
                if (_sortBy != 'pnl') {
                  setState(() => _sortBy = 'pnl');
                  _fetchLeaderboard();
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SortButton(
              label: 'Trading Volume',
              selected: _sortBy == 'volume',
              t: t,
              onTap: () {
                if (_sortBy != 'volume') {
                  setState(() => _sortBy = 'volume');
                  _fetchLeaderboard();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(PulsThemeColors t, bool isDark) {
    // Top 3 for Podium
    final top3 = _traders.take(3).toList();
    final remaining = _traders.skip(3).toList();

    return RefreshIndicator(
      onRefresh: _fetchLeaderboard,
      color: t.brand,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (top3.isNotEmpty) ...[
            FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: _buildPodium(top3, t),
            ),
            const SizedBox(height: 24),
          ],
          if (remaining.isNotEmpty) ...[
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              duration: const Duration(milliseconds: 400),
              child: Text(
                'RANKINGS',
                style: TextStyle(
                  color: t.textSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: remaining.length,
              itemBuilder: (context, idx) {
                final trader = remaining[idx];
                final rank = idx + 4; // index starts at 0, representing rank 4
                return FadeInUp(
                  delay: Duration(milliseconds: 30 * idx),
                  duration: const Duration(milliseconds: 300),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TraderRow(
                      trader: trader,
                      rank: rank,
                      sortBy: _sortBy,
                      t: t,
                      onTap: () => _navigateToProfile(trader['userId']),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPodium(List<dynamic> top3, PulsThemeColors t) {
    // Reorder as [2nd, 1st, 3rd] for classic podium display
    final podiumTraders = List<dynamic>.from(top3);
    if (podiumTraders.length == 3) {
      final temp = podiumTraders[0];
      podiumTraders[0] = podiumTraders[1]; // 2nd rank on left
      podiumTraders[1] = temp;             // 1st rank in center
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: t.surfaceRaised.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(podiumTraders.length, (idx) {
          final trader = podiumTraders[idx];
          // Get the original rank
          int rank = 1;
          if (top3.length == 3) {
            if (idx == 0) rank = 2;
            if (idx == 1) rank = 1;
            if (idx == 2) rank = 3;
          } else {
            rank = idx + 1;
          }

          final isFirst = rank == 1;
          final scale = isFirst ? 1.15 : 1.0;

          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 90,
              child: GestureDetector(
                onTap: () => _navigateToProfile(trader['userId']),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rank badge / Avatar
                    Stack(
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.none,
                      children: [
                        // Avatar Container with premium border
                        Container(
                          width: isFirst ? 64 : 54,
                          height: isFirst ? 64 : 54,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isFirst
                                  ? [const Color(0xFFFBBF24), const Color(0xFFF59E0B)]
                                  : rank == 2
                                      ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                                      : [const Color(0xFFD97706), const Color(0xFFB45309)],
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: t.surface,
                            backgroundImage: NetworkImage(trader['avatarUrl'] ?? ''),
                          ),
                        ),
                        // Crown/Rank badge above avatar
                        Positioned(
                          top: -16,
                          child: isFirst
                              ? const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 24)
                              : Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: rank == 2 ? const Color(0xFF94A3B8) : const Color(0xFFD97706),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1),
                                  ),
                                  child: Text(
                                    '$rank',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      trader['displayName'] ?? 'Puls Trader',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.text,
                        fontSize: isFirst ? 13 : 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _sortBy == 'pnl'
                          ? '${trader['pnl'] >= 0 ? '+' : ''}\$${trader['pnl']}'
                          : '\$${trader['volume']}',
                      style: TextStyle(
                        color: _sortBy == 'pnl'
                            ? (trader['pnl'] >= 0 ? t.yes : t.no)
                            : t.text,
                        fontSize: isFirst ? 12 : 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Win Rate ${trader['winRate']}%',
                      style: TextStyle(
                        color: t.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildErrorView(PulsThemeColors t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: t.no, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load leaderboard',
              style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchLeaderboard,
              style: ElevatedButton.styleFrom(backgroundColor: t.brand),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(PulsThemeColors t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard_outlined, color: t.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'No traders found',
              style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first one to trade and claim the top spot!',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: userId),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.selected,
    required this.t,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final PulsThemeColors t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: selected ? t.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : t.textSubtle,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _TraderRow extends StatelessWidget {
  const _TraderRow({
    required this.trader,
    required this.rank,
    required this.sortBy,
    required this.t,
    required this.onTap,
  });

  final dynamic trader;
  final int rank;
  final String sortBy;
  final PulsThemeColors t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = sortBy == 'pnl' ? trader['pnl'] : trader['volume'];
    final isPnL = sortBy == 'pnl';
    final formattedValue = isPnL
        ? '${value >= 0 ? '+' : ''}\$${value.toStringAsFixed(2)}'
        : '\$${value.toStringAsFixed(2)}';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          // Rank Index
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                color: t.textSubtle,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(trader['avatarUrl'] ?? ''),
          ),
          const SizedBox(width: 14),
          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trader['displayName'] ?? 'Puls Trader',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.text,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${trader['tradesCount']} Trades · Win Rate ${trader['winRate']}%',
                  style: TextStyle(
                    color: t.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // PnL / Volume Value
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formattedValue,
                style: TextStyle(
                  color: isPnL
                      ? (value >= 0 ? t.yes : t.no)
                      : t.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (isPnL)
                Text(
                  'Vol \$${trader['volume']}',
                  style: TextStyle(
                    color: t.textMuted,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

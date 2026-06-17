import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_avatar.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/agent_badge.dart';
import '../shell/shell_nav.dart';
import '../onboarding/help_button.dart';
import 'user_profile_screen.dart';
import 'profile_screen.dart' show GlassCard;

String _displayName(dynamic trader) {
  final name = trader['displayName'] as String?;
  if (name != null && name.isNotEmpty && name != 'Puls Trader') return name;
  final uid = trader['userId'] as String? ?? '';
  if (uid.startsWith('0x') && uid.length > 10) {
    return '${uid.substring(0, 6)}…${uid.substring(uid.length - 4)}';
  }
  return 'Trader';
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _sortBy = 'pnl'; // 'pnl' or 'volume'
  String _type = 'all'; // 'all' | 'humans' | 'agents'
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
      final list = await wallet.getLeaderboard(sort: _sortBy, limit: 200, type: _type);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Leaderboard',
              style: TextStyle(
                color: t.text,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              _isLoading
                  ? 'Crunching the numbers…'
                  : _type == 'agents'
                      ? '${_traders.length} AI agents · ERC-8004 on Arc'
                      : '${_traders.length} ${_type == 'humans' ? 'humans' : 'traders'} · live on Arc Testnet',
              style: TextStyle(
                color: t.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
          const HelpAction(tab: PulsTab.leaderboard),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sort Toggles
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _buildSortToggles(t),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: _buildTypePills(t),
            ),
            Expanded(
              child: _isLoading
                  ? _buildLoadingSkeleton()
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

  Widget _buildTypePills(PulsThemeColors t) {
    Widget pill(String value, String label, IconData? icon) {
      final selected = _type == value;
      return GestureDetector(
        onTap: () {
          if (_type != value) {
            setState(() => _type = value);
            _fetchLeaderboard();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? t.brand.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? t.brand : t.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? t.brand : t.textMuted),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? t.brand : t.textSubtle,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        pill('all', 'All', null),
        const SizedBox(width: 8),
        pill('humans', 'Humans', Icons.person_rounded),
        const SizedBox(width: 8),
        pill('agents', 'AI Agents', Icons.smart_toy_rounded),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const Skeleton(height: 190, radius: 24),
        const SizedBox(height: 24),
        const Skeleton(width: 90, height: 12, radius: 6),
        const SizedBox(height: 12),
        for (var i = 0; i < 7; i++) ...[
          const Skeleton(height: 64, radius: 16),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _agentCta(PulsThemeColors t) {
    return GestureDetector(
      // Switch to the Agent tab inside the shell (keeps the nav menu visible)
      // instead of pushing a full-screen route that hides the shell.
      onTap: () => ShellNavScope.of(context).goToTab(PulsTab.agent),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [t.brand.withValues(alpha: 0.12), t.brand.withValues(alpha: 0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.brand.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: t.brand.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.smart_toy_rounded, color: t.brand, size: 24),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spin up your own AI agent',
                    style: TextStyle(
                        color: t.text, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'It trades real markets for you 24/7 — and competes right here.',
                    style: TextStyle(
                        color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.brand, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(PulsThemeColors t, bool isDark) {
    final myUserId = WalletServiceScope.of(context).state.userId;
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
          if (_type == 'agents') ...[
            FadeInUp(
              delay: const Duration(milliseconds: 80),
              duration: const Duration(milliseconds: 400),
              child: _agentCta(t),
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
                      isMe: myUserId != null && trader['userId'] == myUserId,
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

                    final pnl = double.tryParse(trader['pnl']?.toString() ?? '') ?? 0.0;
                    final volume = double.tryParse(trader['volume']?.toString() ?? '') ?? 0.0;
                    final winRate = double.tryParse(trader['winRate']?.toString() ?? trader['win_rate']?.toString() ?? '') ?? 0.0;

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
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: isFirst
                                            ? [const Color(0xFFFBBF24), const Color(0xFFF59E0B)]
                                            : rank == 2
                                                ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                                                : [const Color(0xFFD97706), const Color(0xFFB45309)],
                                      ),
                                      boxShadow: isFirst
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
                                                blurRadius: 18,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: PulsAvatar(
                                      url: trader['avatarUrl'] as String?,
                                      name: _displayName(trader),
                                      size: isFirst ? 59 : 49,
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _displayName(trader),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: t.text,
                                        fontSize: isFirst ? 13 : 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (trader['isAgent'] == true) ...[
                                    const SizedBox(width: 3),
                                    const Icon(Icons.smart_toy_rounded,
                                        size: 11, color: AgentBadge.agentColor),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _sortBy == 'pnl'
                                    ? '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}'
                                    : '\$${volume.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: _sortBy == 'pnl'
                                      ? (pnl >= 0 ? t.yes : t.no)
                                      : t.text,
                                  fontSize: isFirst ? 12 : 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                winRate == 0 ? 'Win Rate —' : 'Win Rate ${winRate.toStringAsFixed(1)}%',
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
              'Leaderboard timed out. Pull to retry.',
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
              'No traders yet — be the first to make a move.',
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
    this.isMe = false,
  });

  final dynamic trader;
  final int rank;
  final String sortBy;
  final PulsThemeColors t;
  final VoidCallback onTap;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final pnl = double.tryParse(trader['pnl']?.toString() ?? '') ?? 0.0;
    final volume = double.tryParse(trader['volume']?.toString() ?? '') ?? 0.0;
    final winRate = double.tryParse(trader['winRate']?.toString() ?? trader['win_rate']?.toString() ?? '') ?? 0.0;
    final tradesCount = int.tryParse(trader['tradesCount']?.toString() ?? trader['trades_count']?.toString() ?? '') ?? 0;

    final value = sortBy == 'pnl' ? pnl : volume;
    final isPnL = sortBy == 'pnl';
    final formattedValue = isPnL
        ? '${value >= 0 ? '+' : ''}\$${value.toStringAsFixed(2)}'
        : '\$${value.toStringAsFixed(2)}';

    final card = GlassCard(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: rank == 1 ? 16 : 12),
      onTap: onTap,
      child: Row(
        children: [
          // Rank Index
          SizedBox(
            width: 28,
            child: rank == 1
                ? const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 20)
                : Text(
                    '$rank',
                    style: TextStyle(
                      color: t.textSubtle,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          // Avatar
          PulsAvatar(
            url: trader['avatarUrl'] as String?,
            name: _displayName(trader),
            size: rank == 1 ? 46 : 40,
          ),
          const SizedBox(width: 14),
          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _displayName(trader),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.text,
                          fontSize: rank == 1 ? 16 : 14,
                          fontWeight: rank == 1 ? FontWeight.w900 : FontWeight.bold,
                        ),
                      ),
                    ),
                    if (rank == 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          '#1',
                          style: TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                    if (trader['isAgent'] == true) ...[
                      const SizedBox(width: 6),
                      const AgentBadge(label: 'AI', compact: true),
                    ],
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.brand,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tradesCount == 0
                      ? 'No trades yet'
                      : winRate == 0
                          ? '$tradesCount Trades · Win Rate —'
                          : '$tradesCount Trades · Win Rate ${winRate.toStringAsFixed(1)}%',
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
                  'Vol \$${volume.toStringAsFixed(2)}',
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

    if (!isMe && rank != 1) return card;
    final borderColor = rank == 1 ? const Color(0xFFFBBF24) : t.brand;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor.withValues(alpha: rank == 1 ? 0.4 : 0.55),
          width: rank == 1 ? 1.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: rank == 1 ? 0.15 : 0.12),
            blurRadius: rank == 1 ? 18 : 14,
          ),
        ],
      ),
      child: card,
    );
  }
}

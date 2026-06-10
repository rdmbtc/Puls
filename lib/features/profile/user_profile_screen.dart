import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../shell/web_layout.dart';
import 'profile_screen.dart' show GlassCard;

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  String? _error;
  dynamic _profile;
  dynamic _stats;
  List<dynamic> _trades = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final wallet = WalletServiceScope.of(context);
      final data = await wallet.getUserProfile(widget.userId);
      if (mounted) {
        setState(() {
          _profile = data['profile'];
          _stats = data['stats'];
          _trades = data['trades'] ?? [];
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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    Widget body;
    if (_isLoading) {
      body = Center(
        child: CircularProgressIndicator(color: t.brand),
      );
    } else if (_error != null) {
      body = _buildErrorView(t);
    } else {
      body = _buildContent(t, isDesktop);
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          _isLoading ? 'Trader Profile' : (_profile?['display_name'] ?? 'Trader Profile'),
          style: TextStyle(
            color: t.text,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.text, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: isDesktop ? WebLayout(maxWidth: 1000, child: body) : body,
      ),
    );
  }

  Widget _buildContent(PulsThemeColors t, bool isDesktop) {
    final name = _profile?['display_name'] ?? 'Puls Trader';
    final bio = _profile?['bio'] ?? 'Trading prediction markets on Arc Testnet.';
    final avatarUrl = _profile?['avatar_url'] as String?;

    // Determine user address if it's eth_
    String? address;
    if (widget.userId.startsWith('eth_')) {
      address = widget.userId.replaceFirst('eth_', '');
    }

    Widget profileInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar + Name Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [t.brand, const Color(0xFF818CF8), t.brand.withValues(alpha: 0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(avatarUrl, width: 80, height: 80, fit: BoxFit.cover)
                    : Container(
                        width: 80,
                        height: 80,
                        color: t.brandSubtle,
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'P',
                            style: TextStyle(color: t.brand, fontSize: 32, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  if (address != null) ...[
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: address!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Address copied to clipboard'), duration: Duration(seconds: 2)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: t.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 10, color: t.textSubtle),
                            const SizedBox(width: 4),
                            Text(
                              '${address.substring(0, 6)}...${address.substring(address.length - 4)}',
                              style: TextStyle(color: t.textSubtle, fontSize: 10, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.brandSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Supabase Account',
                        style: TextStyle(color: t.brand, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Bio
        Text(
          bio,
          style: TextStyle(color: t.textSubtle, fontSize: 14, height: 1.4),
        ),
      ],
    );

    final pnlVal = _parseFloat(_stats?['pnl']);
    final winRateVal = _parseFloat(_stats?['winRate'] ?? _stats?['win_rate']);
    final volumeVal = _parseFloat(_stats?['volume']);
    final tradesCountVal = _parseInt(_stats?['tradesCount'] ?? _stats?['trades_count']);

    Widget statsGrid = Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'TOTAL PROFIT',
                value: '${pnlVal >= 0 ? '+' : ''}\$${pnlVal.toStringAsFixed(2)}',
                valueColor: pnlVal >= 0 ? t.yes : t.no,
                icon: Icons.show_chart_rounded,
                t: t,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'WIN RATE',
                value: '${winRateVal.toStringAsFixed(1)}%',
                valueColor: t.text,
                icon: Icons.emoji_events_rounded,
                t: t,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'TRADING VOLUME',
                value: '\$${volumeVal.toStringAsFixed(2)}',
                valueColor: t.text,
                icon: Icons.swap_horiz_rounded,
                t: t,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'TRADES COUNT',
                value: '$tradesCountVal',
                valueColor: t.text,
                icon: Icons.history_toggle_off_rounded,
                t: t,
              ),
            ),
          ],
        ),
      ],
    );

    Widget tradeHistory = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRADE HISTORY',
          style: TextStyle(
            color: t.textSubtle,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _trades.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history_rounded, color: t.textMuted, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'No trades completed yet',
                      style: TextStyle(color: t.textMuted, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _trades.length,
                itemBuilder: (context, idx) {
                  final trade = _trades[idx];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TradeHistoryRow(trade: trade, t: t),
                  );
                },
              ),
      ],
    );

    if (isDesktop) {
      return RefreshIndicator(
        onRefresh: _fetchProfile,
        color: t.brand,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      GlassCard(child: profileInfo),
                      const SizedBox(height: 20),
                      statsGrid,
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: tradeHistory,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchProfile,
      color: t.brand,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 350),
            child: GlassCard(child: profileInfo),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 60),
            duration: const Duration(milliseconds: 350),
            child: statsGrid,
          ),
          const SizedBox(height: 24),
          FadeInUp(
            delay: const Duration(milliseconds: 120),
            duration: const Duration(milliseconds: 350),
            child: tradeHistory,
          ),
        ],
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
              'Failed to load profile',
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
              onPressed: _fetchProfile,
              style: ElevatedButton.styleFrom(backgroundColor: t.brand),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.t,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.border),
            ),
            child: Icon(icon, color: t.brand, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: t.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(color: valueColor, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeHistoryRow extends StatelessWidget {
  const _TradeHistoryRow({required this.trade, required this.t});

  final dynamic trade;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final side = trade['side'] as String? ?? 'YES';
    final amt = _parseFloat(trade['usdc_amount']);
    final isBuy = amt > 0;
    final isClaim = side == 'CLAIM';
    
    Color amountColor = t.text;
    String actionLabel = '';
    
    if (isClaim) {
      amountColor = t.yes;
      actionLabel = 'Claimed Winnings';
    } else if (isBuy) {
      amountColor = t.no; // spending money
      actionLabel = 'Bought $side';
    } else {
      amountColor = t.yes; // earning money from sell
      actionLabel = 'Sold $side';
    }

    final displayAmt = isClaim 
        ? '\$0.00' 
        : '${isBuy ? '-' : '+'}\$${amt.abs().toStringAsFixed(2)}';

    final date = DateTime.tryParse(trade['created_at'] as String? ?? '') ?? DateTime.now();
    final formattedDate = '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Action indicator icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isClaim 
                  ? t.yesBg 
                  : isBuy 
                      ? t.noBg 
                      : t.yesBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isClaim 
                  ? Icons.emoji_events_outlined 
                  : isBuy 
                      ? Icons.shopping_basket_outlined 
                      : Icons.sell_outlined,
              color: isClaim 
                  ? t.yes 
                  : isBuy 
                      ? t.no 
                      : t.yes,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trade['question'] ?? 'Prediction Trade',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$actionLabel · $formattedDate',
                  style: TextStyle(color: t.textMuted, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Amount + Tx Hash link
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayAmt,
                style: TextStyle(color: amountColor, fontSize: 13, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              if (trade['tx_hash'] != null && (trade['tx_hash'] as String).isNotEmpty)
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse('https://testnet.arcscan.app/tx/${trade['tx_hash']}'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'View Tx',
                        style: TextStyle(color: t.brand, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.open_in_new_rounded, size: 8, color: t.brand),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

double _parseFloat(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

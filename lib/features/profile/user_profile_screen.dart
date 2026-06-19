import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_avatar.dart';
import '../shell/web_layout.dart';
import '../comments/comment_thread.dart';
import '../alpha/alpha_actions.dart';
import '../payments/payment_receipt.dart';
import '../payments/payment_receipt_sheet.dart';
import 'creator_earnings_card.dart';
import 'signals_section.dart';
import 'erc8004_badge.dart';
import 'profile_screen.dart' show GlassCard;

String _profileDisplayName(Map<String, dynamic>? profile, String userId) {
  final name = profile?['display_name'] as String?;
  if (name != null && name.isNotEmpty && name != 'Puls Trader') return name;
  if (userId.startsWith('eth_') && userId.length > 10) {
    final addr = userId.replaceFirst('eth_', '');
    if (addr.length > 10) return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }
  if (userId.startsWith('0x') && userId.length > 10) {
    return '${userId.substring(0, 6)}…${userId.substring(userId.length - 4)}';
  }
  return 'Trader';
}

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
  String _segment = 'track'; // 'signals' | 'track' | 'discussion'
  final GlobalKey _copyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  void _scrollToCopy() {
    final ctx = _copyKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  // One-tap tip to a creator from their profile — fires after a 5s Undo window,
  // then settles and shows the unified receipt sheet.
  void _tipCreator(String handle) {
    final wallet = WalletServiceScope.of(context);
    if (wallet.state.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to tip creators.')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final tip = DeferredTip(
      delay: const Duration(seconds: 5),
      onFire: () async {
        messenger.hideCurrentSnackBar(); // clear the "Tipping…" bar before the receipt
        try {
          final res = await wallet.tipCreator(
            amountUsdc: 0.05,
            toUserId: widget.userId,
            context: 'profile',
          );
          if (!mounted) return;
          await PaymentReceiptSheet.show(
            context,
            PaymentReceipt.fromResponse(res, amountUsd: 0.05, creatorHandle: handle),
          );
        } catch (e) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim())),
          );
        }
      },
      onUndo: () => messenger.hideCurrentSnackBar(),
    )..start();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text('Tipping \$0.05 to $handle'),
        action: SnackBarAction(label: 'Undo', onPressed: tip.cancel),
      ),
    );
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
      bottomNavigationBar: _buildStickyActions(t),
    );
  }

  /// Sticky Copy · Tip bar shown when viewing another creator's profile.
  Widget? _buildStickyActions(PulsThemeColors t) {
    if (_isLoading || _error != null) return null;
    final currentUserId = WalletServiceScope.of(context).state.userId;
    if (currentUserId != null && currentUserId == widget.userId) return null;

    final name = _profileDisplayName(_profile, widget.userId);
    final tipHandle =
        name.startsWith('@') ? name : '@${name.replaceAll(' ', '').toLowerCase()}';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _scrollToCopy,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: t.border),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(Icons.content_copy_rounded, size: 17, color: t.text),
                label: Text('Copy',
                    style: TextStyle(color: t.text, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _tipCreator(tipHandle),
                style: FilledButton.styleFrom(
                  backgroundColor: t.brand,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.volunteer_activism_rounded, size: 17, color: Colors.white),
                label: const Text('Tip \$0.05',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(PulsThemeColors t, bool isDesktop) {
    final name = _profileDisplayName(_profile, widget.userId);
    final bio = _profile?['bio'] ?? 'Trading prediction markets on Arc Testnet.';
    final avatarUrl = _profile?['avatar_url'] as String?;

    // Creator-economy enrichments (all graceful — backend may not send them yet).
    final isAgent = _profile?['isAgent'] == true || _profile?['is_agent'] == true;
    final reputation = _parseInt(_profile?['reputation'] ?? _profile?['erc8004Reputation']);
    final earningsRaw =
        _profile?['creatorEarningsUsd'] ?? _stats?['earningsUsd'] ?? _stats?['creator_earnings_usd'];
    final earningsUsd = earningsRaw == null ? null : _parseFloat(earningsRaw);
    final sparkRaw = (_stats?['earningsSpark'] ?? _stats?['earnings_spark']) as List?;
    final spark = sparkRaw?.map(_parseFloat).toList() ?? const <double>[];

    final currentUserId = WalletServiceScope.of(context).state.userId;
    final isSelf = currentUserId != null && currentUserId == widget.userId;

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
                  colors: [t.brand, PulsColors.brandMint, t.brand.withValues(alpha: 0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: PulsAvatar(
                url: avatarUrl,
                name: name,
                size: 80,
                radius: 18,
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
        if (isAgent) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Erc8004Badge(
              isAgent: true,
              reputation: reputation > 0 ? reputation : null,
            ),
          ),
        ],
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
                value: winRateVal == 0 ? '—' : '${winRateVal.toStringAsFixed(1)}%',
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
                      'No trades yet — this trader is just getting started.',
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

    // ── Creator-hub segments: Signals · Track record · Discussion ──────────
    Widget segButton(String value, String label) {
      final sel = _segment == value;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (_segment != value) setState(() => _segment = value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? t.brand.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: sel ? t.brand : Colors.transparent,
                width: sel ? 1.2 : 1,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: sel ? t.brand : t.textSubtle,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    Widget segBar = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          segButton('signals', 'Signals'),
          const SizedBox(width: 4),
          segButton('track', 'Track record'),
          const SizedBox(width: 4),
          segButton('discussion', 'Discussion'),
        ],
      ),
    );

    Widget segmentBody;
    switch (_segment) {
      case 'signals':
        segmentBody = SignalsSection(creatorUserId: widget.userId, isOwner: isSelf);
        break;
      case 'discussion':
        segmentBody = CommentThread(targetType: 'profile', targetId: widget.userId);
        break;
      default:
        segmentBody = Column(
          children: [statsGrid, const SizedBox(height: 24), tradeHistory],
        );
    }

    final earningsCard = CreatorEarningsCard(earningsUsd: earningsUsd, spark: spark);
    final copyCard = KeyedSubtree(
      key: _copyKey,
      child: _CopyTraderCard(leaderUserId: widget.userId, leaderName: name),
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
                      earningsCard,
                      const SizedBox(height: 16),
                      if (!isSelf) copyCard,
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      segBar,
                      const SizedBox(height: 16),
                      segmentBody,
                    ],
                  ),
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
            delay: const Duration(milliseconds: 40),
            duration: const Duration(milliseconds: 350),
            child: earningsCard,
          ),
          if (!isSelf) ...[
            const SizedBox(height: 16),
            FadeInUp(
              delay: const Duration(milliseconds: 60),
              duration: const Duration(milliseconds: 350),
              child: copyCard,
            ),
          ],
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 80),
            duration: const Duration(milliseconds: 350),
            child: segBar,
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 120),
            duration: const Duration(milliseconds: 350),
            child: segmentBody,
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
              'Couldn\'t load this profile. Pull to retry.',
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

/// "Copy this trader" card — lets the signed-in user mirror a leader's trades
/// with a per-trade spend cap. Backend: /api/copy/* (puls_backend). Hidden when
/// viewing your own profile or when signed out.
class _CopyTraderCard extends StatefulWidget {
  const _CopyTraderCard({required this.leaderUserId, required this.leaderName});

  final String leaderUserId;
  final String leaderName;

  @override
  State<_CopyTraderCard> createState() => _CopyTraderCardState();
}

class _CopyTraderCardState extends State<_CopyTraderCard> {
  bool _loading = true;
  bool _busy = false;
  bool _following = false;
  bool _live = false;
  double _maxPerTrade = 1.0;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _load();
  }

  bool get _isSelfOrGuest {
    final wallet = WalletServiceScope.of(context);
    final me = wallet.state.userId;
    return me == null || me == widget.leaderUserId;
  }

  Future<void> _load() async {
    if (_isSelfOrGuest) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final wallet = WalletServiceScope.of(context);
      final data = await wallet.getCopyStatus(widget.leaderUserId);
      if (!mounted) return;
      setState(() {
        _following = data['following'] == true;
        _live = data['live'] == true;
        final cap = data['maxPerTradeUsdc'];
        if (cap is num && cap > 0) _maxPerTrade = cap.toDouble();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _startCopying(PulsThemeColors t) async {
    final cap = await _pickSpendCap(t);
    if (cap == null) return;
    setState(() => _busy = true);
    try {
      await WalletServiceScope.of(context).copyFollow(widget.leaderUserId, cap);
      if (!mounted) return;
      setState(() {
        _following = true;
        _maxPerTrade = cap;
        _busy = false;
      });
      _snack(_live
          ? 'Now copying ${widget.leaderName} • \$${cap.toStringAsFixed(2)}/trade'
          : 'Copy set • \$${cap.toStringAsFixed(2)}/trade (mirroring activates at launch)');
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _snack(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  Future<void> _stopCopying() async {
    setState(() => _busy = true);
    try {
      await WalletServiceScope.of(context).copyUnfollow(widget.leaderUserId);
      if (!mounted) return;
      setState(() {
        _following = false;
        _busy = false;
      });
      _snack('Stopped copying ${widget.leaderName}');
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _snack(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  Future<double?> _pickSpendCap(PulsThemeColors t) {
    double temp = _maxPerTrade.clamp(0.1, 10.0).toDouble();
    return showModalBottomSheet<double>(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Copy ${widget.leaderName}',
                      style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    'Each time this trader opens a position, we mirror it onto your wallet — up to your per-trade cap.',
                    style: TextStyle(color: t.textSubtle, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('MAX PER TRADE',
                          style: TextStyle(
                              color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      Text('\$${temp.toStringAsFixed(2)}',
                          style: TextStyle(color: t.brand, fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  Slider(
                    value: temp,
                    min: 0.1,
                    max: 10.0,
                    divisions: 99,
                    activeColor: t.brand,
                    label: '\$${temp.toStringAsFixed(2)}',
                    onChanged: (v) => setSheet(() => temp = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(double.parse(temp.toStringAsFixed(2))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.brand,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Start copying',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_isSelfOrGuest) return const SizedBox.shrink();
    if (_loading) return const SizedBox.shrink();

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_following ? Icons.repeat_rounded : Icons.content_copy_rounded,
                color: t.brand, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _following ? 'Copying this trader' : 'Copy this trader',
                style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
            if (_following)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('\$${_maxPerTrade.toStringAsFixed(2)}/trade',
                    style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _following
              ? 'Their trades are mirrored to your wallet (capped per trade). You pay a small per-trade creator fee to the trader.'
              : 'Auto-mirror this trader\'s positions to your wallet, with a spend cap you control.',
          style: TextStyle(color: t.textSubtle, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: _following
              ? OutlinedButton.icon(
                  onPressed: _busy ? null : _stopCopying,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Stop copying'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.text,
                    side: BorderSide(color: t.border),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _busy ? null : () => _startCopying(t),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.content_copy_rounded, size: 18, color: Colors.white),
                  label: const Text('Copy this trader',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.brand,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(child: content),
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

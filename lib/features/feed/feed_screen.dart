import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../app/puls_app.dart';
import '../../app/puls_app_state.dart';
import '../../core/config.dart' show backendUrl;
import '../../core/theme/app_theme.dart';
import '../../data/models/market.dart';
import '../market/market_detail_screen.dart';
import '../market/trade_preview_sheet.dart';
import '../profile/notifications_screen.dart';
import 'prediction_feed_card.dart';
import 'ticker_strip.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final isMobileWeb = kIsWeb && MediaQuery.sizeOf(context).width < 600;

    if (kIsWeb && !isMobileWeb) {
      return Scaffold(
        backgroundColor: t.bg,
        body: Column(
          children: [
            _FeedHeader(t: t),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: WebTickerStrip(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _WebFeedBody(appState: appState, t: t),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _FeedHeader(t: t),
            Expanded(child: _FeedBody(appState: appState, t: t)),
          ],
        ),
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({required this.appState, required this.t});
  final PulsAppState appState;
  final PulsThemeColors t;

  void _openDetails(BuildContext context, Market market) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => MarketDetailScreen(marketId: market.id)),
    );
  }

  Future<void> _fastBuy(
    BuildContext context,
    PulsAppState appState,
    Market market,
    MarketSide side,
  ) async {
    final walletService = WalletServiceScope.of(context);
    final ws = walletService.state;

    if (ws.userId == null || !ws.hasWallet) {
      _showToast(context, '⚡ Connect wallet first', isError: true);
      return;
    }

    final isYes = side == MarketSide.yes;
    final amount = appState.fastBuyAmount;
    final label = isYes ? 'YES' : 'NO';

    _showToast(context, '⚡ Buying $label \$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)}…');

    try {
      await walletService.buyPosition(
        isYes: isYes,
        usdcAmount: amount,
        question: market.question,
        entryPrice: isYes ? market.yesPrice : market.noPrice,
        contractAddress: market.contractAddress,
        slug: market.slug,
        deadline: market.deadline.millisecondsSinceEpoch ~/ 1000,
      );
      if (context.mounted) {
        _showToast(
          context,
          '✅ $label bought · \$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)} USDC',
          isSuccess: true,
        );
        walletService.refreshBalance();
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().contains('Insufficient')
            ? '❌ Insufficient USDC'
            : '❌ Trade failed';
        _showToast(context, msg, isError: true);
      }
    }
  }

  void _showToast(BuildContext context, String message,
      {bool isSuccess = false, bool isError = false}) {
    final t = context.puls;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => _TopToast(
          message: message, isSuccess: isSuccess, isError: isError, t: t),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2500), entry.remove);
  }

  @override
  Widget build(BuildContext context) {
    switch (appState.feedStatus) {
      case FeedStatus.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                    color: t.brand, strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              Text('Loading live markets…',
                  style: TextStyle(color: t.textMuted, fontSize: 14)),
              const SizedBox(height: 6),
              Text('Fetching from Polymarket',
                  style: TextStyle(color: t.textSubtle, fontSize: 12)),
            ],
          ),
        );

      case FeedStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, color: t.textSubtle, size: 40),
                const SizedBox(height: 16),
                Text('Could not load markets',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Check your connection and try again.',
                  style: TextStyle(color: t.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: appState.refresh,
                  style: FilledButton.styleFrom(
                    backgroundColor: t.brand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );

      case FeedStatus.loaded:
        final markets = appState.feedMarkets;
        if (markets.isEmpty) {
          return Center(
            child: Text('No markets available.',
                style: TextStyle(color: t.textMuted)),
          );
        }
        return RefreshIndicator(
          color: t.brand,
          onRefresh: appState.refresh,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemBuilder: (context, index) {
              final market = markets[index % markets.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PredictionFeedCard(
                  market: market,
                  isWatchlisted: appState.isWatchlisted(market.id),
                  onWatchlist: () => appState.toggleWatchlist(market.id),
                  onDetails: () => _openDetails(context, market),
                  onChoose: (side) {
                    if (appState.fastBuyEnabled) {
                      _fastBuy(context, appState, market, side);
                    } else {
                      showTradePreviewSheet(
                        context: context,
                        market: market,
                        side: side,
                      );
                    }
                  },
                ),
              );
            },
          ),
        );
    }
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.t});
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: t.brandSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Puls Feed',
                  style: Theme.of(context).textTheme.titleMedium),
              Text('Swipe to choose your side',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                      )),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: t.surface,
                shape: BoxShape.circle,
                border: Border.all(color: t.border),
              ),
              child: Icon(Icons.notifications_outlined, color: t.textSubtle, size: 18),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: PulsColors.amberLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'DEMO',
              style: TextStyle(
                color: PulsColors.amber,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _TopToast extends StatefulWidget {
  const _TopToast({
    required this.message,
    required this.t,
    this.isSuccess = false,
    this.isError = false,
  });
  final String message;
  final PulsThemeColors t;
  final bool isSuccess;
  final bool isError;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isSuccess
        ? widget.t.yes
        : widget.isError
            ? widget.t.no
            : widget.t.brand;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: _anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(_anim),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Web Grid Feed ─────────────────────────────────────────────────────────────
class _WebFeedBody extends StatefulWidget {
  const _WebFeedBody({required this.appState, required this.t});
  final PulsAppState appState;
  final PulsThemeColors t;

  @override
  State<_WebFeedBody> createState() => _WebFeedBodyState();
}

class _WebFeedBodyState extends State<_WebFeedBody> {
  String? _selectedCategory;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<_BetActivity> _activities = [];
  bool _isLoadingActivities = true;
  bool _useFallbackMock = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _fetchRecentTrades();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchRecentTrades();
    });
  }

  String _formatUserId(String userId) {
    if (userId.startsWith('eth_')) {
      final addr = userId.substring(4);
      if (addr.length > 10) {
        return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
      }
      return addr;
    }
    if (userId.startsWith('supabase_')) {
      final uuid = userId.substring(9);
      if (uuid.length > 8) {
        return 'user_${uuid.substring(0, 4)}…${uuid.substring(uuid.length - 4)}';
      }
      return 'user_$uuid';
    }
    if (userId.length > 12) {
      return '${userId.substring(0, 6)}…${userId.substring(userId.length - 4)}';
    }
    return userId;
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.isNegative || diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Future<void> _fetchRecentTrades() async {
    try {
      final url = Uri.parse('$backendUrl/api/trade/recent');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          _useFallbackMock = false;
          _processRecentTrades(data);
          return;
        }
      }
    } catch (e) {
      debugPrint('[Feed] Error fetching recent trades from backend: $e. Falling back to mock feed.');
    }
    
    if (_activities.isEmpty) {
      _useFallbackMock = true;
      _initializeMockActivities();
    } else if (_useFallbackMock) {
      _addMockActivity();
    }
  }

  void _initializeMockActivities() {
    final mockData = [
      _BetActivity(id: 'mock_1', username: '0x8f2d…e11a', action: 'bought', question: 'Will Donald Trump launch a new token in 2026?', amount: 520, time: 'Just now', isYes: true, createdAt: DateTime.now()),
      _BetActivity(id: 'mock_2', username: 'arbitrum_whale', action: 'bought', question: 'Will BTC exceed \$100k in 2026?', amount: 2500, time: '1m ago', isYes: true, createdAt: DateTime.now().subtract(const Duration(minutes: 1))),
      _BetActivity(id: 'mock_3', username: '0x4c99…88b2', action: 'bought', question: 'Will the Fed cut interest rates in June?', amount: 150, time: '3m ago', isYes: false, createdAt: DateTime.now().subtract(const Duration(minutes: 3))),
      _BetActivity(id: 'mock_4', username: 'puls_trader_9', action: 'bought', question: 'Will OpenAI announce GPT-5 before July?', amount: 800, time: '5m ago', isYes: true, createdAt: DateTime.now().subtract(const Duration(minutes: 5))),
      _BetActivity(id: 'mock_5', username: 'degen_king', action: 'bought', question: 'Will Champions League final go to penalties?', amount: 4300, time: '8m ago', isYes: false, createdAt: DateTime.now().subtract(const Duration(minutes: 8))),
    ];
    
    setState(() {
      _activities.addAll(mockData);
      _isLoadingActivities = false;
    });
  }

  void _addMockActivity() {
    final markets = widget.appState.feedMarkets;
    if (markets.isEmpty) return;

    final random = Random();
    final market = markets[random.nextInt(markets.length)];
    final usernames = ['solana_maxi', '0x12a9…cd45', 'crypto_ninja', 'betting_dave', 'pulse_master', '0x7e51…33b9', 'whale_watcher', 'trade_lord'];
    final user = usernames[random.nextInt(usernames.length)];
    final isYes = random.nextBool();
    final amount = (random.nextInt(90) + 10) * 50.0;

    final newAct = _BetActivity(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      username: user,
      action: 'bought',
      question: market.question,
      amount: amount,
      time: 'Just now',
      isYes: isYes,
      createdAt: DateTime.now(),
    );

    _activities.insert(0, newAct);
    _listKey.currentState?.insertItem(
      0,
      duration: const Duration(milliseconds: 500),
    );

    if (_activities.length > 20) {
      _activities.removeLast();
      _listKey.currentState?.removeItem(
        _activities.length,
        (context, animation) => const SizedBox.shrink(),
        duration: Duration.zero,
      );
    }
  }

  void _processRecentTrades(List<dynamic> data) {
    final List<_BetActivity> fetched = data.map((jsonItem) {
      final id = jsonItem['id'] as String;
      final userId = jsonItem['user_id'] as String;
      final side = jsonItem['side'] as String;
      final usdcAmount = double.tryParse(jsonItem['usdc_amount'].toString()) ?? 0.0;
      final question = jsonItem['question'] as String? ?? 'Prediction Market';
      final createdAtStr = jsonItem['created_at'] as String;
      final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();

      final isBuy = usdcAmount >= 0;
      final absAmount = usdcAmount.abs();

      return _BetActivity(
        id: id,
        username: _formatUserId(userId),
        action: isBuy ? 'bought' : 'sold',
        question: question,
        amount: absAmount,
        time: _formatTimeAgo(createdAt),
        isYes: side.toUpperCase() == 'YES',
        createdAt: createdAt,
      );
    }).toList();

    fetched.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;

    if (_activities.isEmpty) {
      setState(() {
        _activities.addAll(fetched.take(20));
        _isLoadingActivities = false;
      });
      return;
    }

    final existingIds = _activities.map((a) => a.id).toSet();
    final newItems = fetched.where((item) => !existingIds.contains(item.id)).toList();

    if (newItems.isNotEmpty) {
      newItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final item in newItems) {
        _activities.insert(0, item);
        _listKey.currentState?.insertItem(
          0,
          duration: const Duration(milliseconds: 500),
        );

        if (_activities.length > 20) {
          _activities.removeLast();
          _listKey.currentState?.removeItem(
            _activities.length,
            (context, animation) => const SizedBox.shrink(),
            duration: Duration.zero,
          );
        }
      }
    } else {
      setState(() {
        for (var i = 0; i < _activities.length; i++) {
          final old = _activities[i];
          _activities[i] = _BetActivity(
            id: old.id,
            username: old.username,
            action: old.action,
            question: old.question,
            amount: old.amount,
            time: _formatTimeAgo(old.createdAt),
            isYes: old.isYes,
            createdAt: old.createdAt,
          );
        }
      });
    }
  }

  void _openDetails(BuildContext context, Market market) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => MarketDetailScreen(marketId: market.id)),
    );
  }

  Future<void> _fastBuy(
    BuildContext context,
    PulsAppState appState,
    Market market,
    MarketSide side,
  ) async {
    final walletService = WalletServiceScope.of(context);
    final ws = walletService.state;

    if (ws.userId == null || !ws.hasWallet) {
      _showToast(context, '⚡ Connect wallet first', isError: true);
      return;
    }

    final isYes = side == MarketSide.yes;
    final amount = appState.fastBuyAmount;
    final label = isYes ? 'YES' : 'NO';

    _showToast(context, '⚡ Buying $label \$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)}…');

    try {
      await walletService.buyPosition(
        isYes: isYes,
        usdcAmount: amount,
        question: market.question,
        entryPrice: isYes ? market.yesPrice : market.noPrice,
        contractAddress: market.contractAddress,
        slug: market.slug,
        deadline: market.deadline.millisecondsSinceEpoch ~/ 1000,
      );
      if (context.mounted) {
        _showToast(
          context,
          '✅ $label bought · \$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)} USDC',
          isSuccess: true,
        );
        walletService.refreshBalance();
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().contains('Insufficient')
            ? '❌ Insufficient USDC'
            : '❌ Trade failed';
        _showToast(context, msg, isError: true);
      }
    }
  }

  void _showToast(BuildContext context, String message,
      {bool isSuccess = false, bool isError = false}) {
    final t = context.puls;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => _TopToast(
          message: message, isSuccess: isSuccess, isError: isError, t: t),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2500), entry.remove);
  }

  Widget _buildCategoryRow(String label, String? category, int count) {
    final t = widget.t;
    final selected = _selectedCategory == category;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = category),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? t.brandSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? t.brand : t.text,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? t.brand.withValues(alpha: 0.2) : t.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: selected ? t.brand : t.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final appState = widget.appState;
    final allMarkets = appState.feedMarkets;

    // Filter markets by category
    final filteredMarkets = _selectedCategory == null
        ? allMarkets
        : allMarkets.where((m) => m.category == _selectedCategory).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Category Panel
        SizedBox(
          width: 250,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 10),
            child: Card(
              color: t.surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: t.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CATEGORIES',
                      style: TextStyle(
                        color: t.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: [
                          _buildCategoryRow('All Markets', null, allMarkets.length),
                          const Divider(height: 16),
                          ...appState.categories.map((cat) {
                            final count = allMarkets.where((m) => m.category == cat).length;
                            return _buildCategoryRow(cat, cat, count);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Center Column: Endless scroll feed
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: filteredMarkets.isEmpty
                ? Center(
                    child: Text(
                      'No predictions in this category.',
                      style: TextStyle(color: t.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: 1000, // Large number to act as infinite
                    itemBuilder: (context, index) {
                      final market = filteredMarkets[index % filteredMarkets.length];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: PredictionFeedCard(
                              market: market,
                              isWatchlisted: appState.isWatchlisted(market.id),
                              onWatchlist: () => appState.toggleWatchlist(market.id),
                              onDetails: () => _openDetails(context, market),
                              onChoose: (side) {
                                if (appState.fastBuyEnabled) {
                                  _fastBuy(context, appState, market, side);
                                } else {
                                  showTradePreviewSheet(
                                    context: context,
                                    market: market,
                                    side: side,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),

        // Right Column: Recent Betting Activity
        SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 20),
            child: Card(
              color: t.surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: t.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: t.yes,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LIVE BETTING FEED',
                          style: TextStyle(
                            color: t.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isLoadingActivities
                          ? Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: t.brand,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : AnimatedList(
                              key: _listKey,
                              initialItemCount: _activities.length,
                              itemBuilder: (context, index, animation) {
                                if (index >= _activities.length) return const SizedBox.shrink();
                                final act = _activities[index];
                                final sideColor = act.isYes ? t.yes : t.no;
                                final sideText = act.isYes ? 'YES' : 'NO';
                                return _buildActivityItem(act, sideColor, sideText, animation);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    _BetActivity act,
    Color sideColor,
    String sideText,
    Animation<double> animation,
  ) {
    final t = widget.t;
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    act.username,
                    style: TextStyle(
                      color: t.brand,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    act.action,
                    style: TextStyle(
                      color: t.textSubtle,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    act.time,
                    style: TextStyle(
                      color: t.textSubtle,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                act.question,
                style: TextStyle(
                  color: t.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: sideColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sideText,
                      style: TextStyle(
                        color: sideColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\$${act.amount.toStringAsFixed(act.amount % 1 == 0 ? 0 : 2)} USDC',
                    style: TextStyle(
                      color: t.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(color: t.border, height: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _BetActivity {
  _BetActivity({
    required this.id,
    required this.username,
    required this.action,
    required this.question,
    required this.amount,
    required this.time,
    required this.isYes,
    required this.createdAt,
  });
  final String id;
  final String username;
  final String action;
  final String question;
  final double amount;
  final String time;
  final bool isYes;
  final DateTime createdAt;
}

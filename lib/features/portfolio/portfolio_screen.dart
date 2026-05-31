import 'dart:async';
import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/puls_app.dart';
import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../shell/web_layout.dart';
import '../../data/models/market.dart';
import '../market/trade_preview_sheet.dart';

import '../../core/config.dart' show backendUrl;
const _backendUrl = backendUrl;

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<Map<String, dynamic>> _positions = [];
  String _totalSpent = '0.00';
  bool _loading = true;
  String? _error;
  RealtimeChannel? _tradeChannel;
  String? _lastUserId;
  bool _initialized = false;
  bool _newestFirst = true;
  final _supabase = Supabase.instance.client;
  final http.Client _client = http.Client();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reactive: re-fires when wallet state changes. Only (re)subscribe + reload
    // when the signed-in user actually changes (e.g. sign-in after first build).
    final userId = WalletServiceScope.of(context).state.userId;
    if (!_initialized || userId != _lastUserId) {
      _initialized = true;
      _lastUserId = userId;
      _setupRealtime();
      _load();
    }
  }

  void _setupRealtime() {
    final ws = WalletServiceScope.of(context).state;
    _tradeChannel?.unsubscribe();
    _tradeChannel = null;
    if (ws.userId == null) return;

    _tradeChannel = _supabase.channel('public:trades:portfolio')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'trades',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: ws.userId,
        ),
        callback: (payload) {
          _load();
        },
      )
      .subscribe();
  }

  void _applySort() {
    _positions.sort((a, b) {
      final ta = DateTime.tryParse(a['timestamp'] as String? ?? '') ?? DateTime(1970);
      final tb = DateTime.tryParse(b['timestamp'] as String? ?? '') ?? DateTime(1970);
      return _newestFirst ? tb.compareTo(ta) : ta.compareTo(tb);
    });
  }

  Widget _sortToggle(PulsThemeColors t) {
    return GestureDetector(
      onTap: () => setState(() { _newestFirst = !_newestFirst; _applySort(); }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_newestFirst ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 12, color: t.textMuted),
            const SizedBox(width: 4),
            Text(_newestFirst ? 'Newest' : 'Oldest', style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tradeChannel?.unsubscribe();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    final ws = WalletServiceScope.of(context).state;
    if (ws.userId == null) {
      setState(() { _positions = []; _totalSpent = '0.00'; _loading = false; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _client.get(
        Uri.parse('$_backendUrl/api/portfolio?userId=${ws.userId}'),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) throw Exception(data['error']);
      final positions = (data['positions'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _positions = positions;
        _totalSpent = data['totalSpent'] as String? ?? '0.00';
        _loading = false;
      });
      _applySort();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double? _calcPnl(Map<String, dynamic> position, dynamic appState) {
    final cost = (position['usdcAmount'] as num?)?.toDouble() ?? 0;
    final entryPrice = (position['entryPrice'] as num?)?.toDouble() ?? 0;
    final isYes = position['side'] == 'YES';
    final question = position['question'] as String? ?? '';

    double? currentPrice;
    try {
      final market = (appState.markets as List).firstWhere(
        (m) => (m.question as String).toLowerCase().contains(
              question.toLowerCase().split(' ').take(5).join(' '),
            ),
      );
      currentPrice = isYes ? market.yesPrice as double : market.noPrice as double;
    } catch (_) {}

    if (currentPrice == null) return null;
    final shares = (position['shares'] as num?)?.toDouble() ?? (entryPrice > 0 ? cost / entryPrice : 0);
    final currentValue = shares * currentPrice;
    return currentValue - cost;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final ws = WalletServiceScope.of(context).state;
    final appState = PulsStateScope.of(context);

    double totalPnl = 0;
    double openValue = 0;
    int wins = 0, losses = 0;
    for (final p in _positions) {
      if (p['state'] != 'COMPLETE') continue;
      final pnl = _calcPnl(p, appState);
      if (pnl != null) {
        totalPnl += pnl;
        openValue += ((p['usdcAmount'] as num?)?.toDouble() ?? 0) + pnl;
        if (pnl >= 0) { wins++; } else { losses++; }
      }
    }

    final double invested = double.tryParse(_totalSpent) ?? 0.0;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = kIsWeb && width >= 900;

    Widget body;
    if (ws.userId == null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: _Empty(
          icon: Icons.account_balance_wallet_outlined,
          message: 'Sign in to see your portfolio',
          sub: 'Connect your wallet in the Profile tab.',
          t: t,
        ),
      );
    } else if (_loading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    } else if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: _Empty(
          icon: Icons.wifi_off_rounded,
          message: 'Could not load portfolio',
          sub: _error!,
          t: t,
        ),
      );
    } else {
      if (isDesktop) {
        body = Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroCard(
                        totalSpent: _totalSpent,
                        positionCount: _positions.where((p) => p['state'] == 'COMPLETE').length,
                        totalPnl: totalPnl,
                        t: t,
                        walletAddress: ws.walletAddress,
                        usdcBalance: ws.usdcBalance,
                      ),
                      const SizedBox(height: 16),
                      Text('Performance Trend', style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _PortfolioChart(cost: invested, pnl: totalPnl, t: t),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _StatBox(label: 'Open Value', value: '\$${openValue.toStringAsFixed(2)}', t: t)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatBox(label: 'Win Rate', value: (wins + losses) > 0 ? '${((wins / (wins + losses)) * 100).toStringAsFixed(0)}%' : '—', t: t, highlight: wins > losses)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatBox(label: 'Trades', value: '${_positions.length}', t: t)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Positions', style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        if (_positions.length > 1) ...[ _sortToggle(t), const SizedBox(width: 8) ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.surfaceRaised,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: t.border),
                          ),
                          child: Text('${_positions.length} active', style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _positions.isEmpty
                          ? _Empty(
                              icon: Icons.bar_chart_rounded,
                              message: 'No positions yet',
                              sub: 'Buy YES or NO on any prediction to get started.',
                              t: t,
                            )
                          : ListView.separated(
                              itemCount: _positions.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, i) => FadeInUp(
                                delay: Duration(milliseconds: i * 40),
                                duration: const Duration(milliseconds: 250),
                                child: _PositionCard(
                                  position: _positions[i],
                                  t: t,
                                  appState: appState,
                                  walletService: WalletServiceScope.of(context),
                                  onRefresh: _load,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        body = CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroCard(
                      totalSpent: _totalSpent,
                      positionCount: _positions.where((p) => p['state'] == 'COMPLETE').length,
                      totalPnl: totalPnl,
                      t: t,
                      walletAddress: ws.walletAddress,
                      usdcBalance: ws.usdcBalance,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _StatBox(label: 'Open Value', value: '\$${openValue.toStringAsFixed(2)}', t: t)),
                        const SizedBox(width: 10),
                        Expanded(child: _StatBox(label: 'Win Rate', value: (wins + losses) > 0 ? '${((wins / (wins + losses)) * 100).toStringAsFixed(0)}%' : '—', t: t, highlight: wins > losses)),
                        const SizedBox(width: 10),
                        Expanded(child: _StatBox(label: 'Trades', value: '${_positions.length}', t: t)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('Positions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        if (_positions.length > 1) ...[ _sortToggle(t), const SizedBox(width: 8) ],
                        Text('${_positions.length} trades', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_positions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _Empty(
                    icon: Icons.bar_chart_rounded,
                    message: 'No positions yet',
                    sub: 'Buy YES or NO on any prediction to get started.',
                    t: t,
                    imageUrl: 'https://img.icons8.com/?id=4xcZGzia5Blf&format=png&size=256',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverList.builder(
                  itemCount: _positions.length,
                  itemBuilder: (context, i) => FadeInUp(
                    delay: Duration(milliseconds: i * 40),
                    duration: const Duration(milliseconds: 250),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PositionCard(
                        position: _positions[i],
                        t: t,
                        appState: appState,
                        walletService: WalletServiceScope.of(context),
                        onRefresh: _load,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text('Portfolio', style: TextStyle(color: t.text, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: t.brand,
          onRefresh: _load,
          child: isDesktop ? WebLayout(maxWidth: 1200, child: body) : body,
        ),
      ),
    );
  }
}

class _PortfolioChart extends StatelessWidget {
  const _PortfolioChart({required this.cost, required this.pnl, required this.t});
  final double cost;
  final double pnl;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final base = cost > 0 ? cost : 100.0;
    final end = base + pnl;
    final spots = [
      FlSpot(0, base * 0.95),
      FlSpot(1, base * 1.02),
      FlSpot(2, base * 0.98),
      FlSpot(3, base * 1.05),
      FlSpot(4, base * 1.01),
      FlSpot(5, base * 1.08),
      FlSpot(6, end),
    ];
    final isUp = pnl >= 0;
    final color = isUp ? t.yes : t.no;

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 10),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => t.surface,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '\$${spot.y.toStringAsFixed(2)}',
                    TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.totalSpent,
    required this.positionCount,
    required this.totalPnl,
    required this.t,
    required this.walletAddress,
    required this.usdcBalance,
  });
  final String totalSpent;
  final int positionCount;
  final double totalPnl;
  final PulsThemeColors t;
  final String? walletAddress;
  final String usdcBalance;

  @override
  Widget build(BuildContext context) {
    final hasPnl = totalPnl != 0;
    final pnlPositive = totalPnl >= 0;
    final shortAddress = walletAddress != null && walletAddress!.length > 12
        ? '${walletAddress!.substring(0, 6)}...${walletAddress!.substring(walletAddress!.length - 4)}'
        : '—';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.brand,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: t.brand.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('TOTAL INVESTED',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 3, backgroundColor: t.yes),
                          const SizedBox(width: 5),
                          Text('Arc Testnet',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('\$$totalSpent USDC',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        height: 1.1)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (hasPnl) ...[
                      Icon(
                        pnlPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: pnlPositive ? t.yes : t.no,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PNL ${pnlPositive ? '+' : ''}\$${totalPnl.toStringAsFixed(2)} USDC',
                        style: TextStyle(
                          color: pnlPositive ? t.yes : t.no,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ] else ...[
                      Text('No completed trades',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('USDC BALANCE', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('\$$usdcBalance USDC', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('WALLET', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () {
                            if (walletAddress != null) {
                              Clipboard.setData(ClipboardData(text: walletAddress!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Address copied to clipboard'), duration: Duration(seconds: 2)),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              Text(shortAddress, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                              const SizedBox(width: 4),
                              Icon(Icons.copy_rounded, color: Colors.white.withValues(alpha: 0.7), size: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatefulWidget {
  const _PositionCard({
    required this.position,
    required this.t,
    required this.appState,
    required this.walletService,
    this.onRefresh,
  });
  final Map<String, dynamic> position;
  final PulsThemeColors t;
  final dynamic appState;
  final dynamic walletService;
  final VoidCallback? onRefresh;

  @override
  State<_PositionCard> createState() => _PositionCardState();
}

class _PositionCardState extends State<_PositionCard> {
  bool _claiming = false;

  Future<void> _claim() async {
    setState(() => _claiming = true);
    final slug = widget.position['slug'] as String? ?? '';
    final String? contractAddress = (widget.position['contractAddress'] as String?) ?? (widget.position['marketId'] as String?);
    if (contractAddress == null || contractAddress.isEmpty) {
      throw Exception('Market contract address not available');
    }

    try {
      await widget.walletService.claimWinnings(contractAddress: contractAddress, slug: slug);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Claim submitted! Check balance in a few seconds.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    final t = widget.t;
    final isYes = position['side'] == 'YES';
    final sideBg = isYes ? t.yesBg : t.noBg;
    final sideFg = isYes ? t.yes : t.no;
    final state = position['state'] as String? ?? 'UNKNOWN';
    final amount = (position['usdcAmount'] as num?)?.toDouble() ?? 0.0;
    final entryPrice = (position['entryPrice'] as num?)?.toDouble() ?? 0.0;
    final question = position['question'] as String? ?? 'Prediction';
    final txHash = position['txHash'] as String?;
    final timestamp = position['timestamp'] as String?;

    double? pnl;
    double? currentPrice;
    final hasRealEntryPrice = entryPrice > 0 && entryPrice != 0.5;
    Market? matchedMarket;

    if (state == 'COMPLETE') {
      try {
        matchedMarket = (widget.appState.markets as List).firstWhere(
          (m) => (m.question as String).toLowerCase().contains(
                question.toLowerCase().split(' ').take(5).join(' '),
              ),
        ) as Market;
        currentPrice = isYes ? matchedMarket.yesPrice : matchedMarket.noPrice;
        final shares = (position['shares'] as num?)?.toDouble() ?? (amount > 0 ? (amount / (hasRealEntryPrice ? entryPrice : 0.5)) : 0.0);
        pnl = (shares * currentPrice) - amount;
      } catch (_) {}
    }

    matchedMarket ??= Market(
      id: (position['marketId'] as String? ?? position['contractAddress'] as String?) ?? '',
      slug: position['slug'] as String? ?? 'default-slug',
      contractAddress: position['contractAddress'] as String? ?? position['marketId'] as String?,
      question: question,
      category: 'Crypto',
      context: '',
      yesPrice: 0.5,
      noPrice: 0.5,
      volume: '\$20',
      liquidity: '\$20',
      deadline: DateTime.now().add(const Duration(days: 30)),
      trend: 0.0,
      isFeatured: false,
      tags: const [],
      history: const [],
      comments: const [],
      news: const [],
    );

    final positionContract = (position['contractAddress'] as String?) ?? (position['marketId'] as String?);
    final hasValidContract = positionContract != null &&
        positionContract.startsWith('0x') &&
        positionContract.length == 42;

    Color stateColor;
    String stateLabel;
    switch (state) {
      case 'COMPLETE':
        stateColor = t.yes;
        stateLabel = 'Confirmed';
        break;
      case 'FAILED':
      case 'DENIED':
        stateColor = t.no;
        stateLabel = 'Failed';
        break;
      default:
        stateColor = PulsColors.amber;
        stateLabel = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: sideBg, borderRadius: BorderRadius.circular(6)),
                child: Text(isYes ? 'YES' : 'NO', style: TextStyle(color: sideFg, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: stateColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(stateLabel, style: TextStyle(color: stateColor, fontWeight: FontWeight.w600, fontSize: 11)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${amount.toStringAsFixed(2)} USDC', style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 14)),
                  if (pnl != null && pnl.abs() >= 0.01)
                    Text('${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                        style: TextStyle(color: pnl >= 0 ? t.yes : t.no, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(question, style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (entryPrice > 0 && entryPrice != 0.5) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Entry ${(entryPrice * 100).toStringAsFixed(0)}¢', style: TextStyle(color: t.textSubtle, fontSize: 11)),
                if (currentPrice != null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 10, color: t.textSubtle),
                  const SizedBox(width: 6),
                  Text('Now ${(currentPrice * 100).toStringAsFixed(0)}¢',
                      style: TextStyle(
                        color: (currentPrice - entryPrice).abs() < 0.01
                            ? t.textSubtle
                            : currentPrice >= entryPrice ? t.yes : t.no,
                        fontSize: 11, fontWeight: FontWeight.w600,
                      )),
                ],
              ],
            ),
          ],
          if (txHash != null || timestamp != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (timestamp != null)
                  Text(_formatTime(timestamp), style: TextStyle(color: t.textSubtle, fontSize: 11)),
                const Spacer(),
                if (txHash != null)
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse('https://testnet.arcscan.app/tx/$txHash'), mode: LaunchMode.externalApplication),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${txHash.substring(0, 8)}...${txHash.substring(txHash.length - 6)}',
                            style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 3),
                        Icon(Icons.open_in_new_rounded, size: 11, color: t.brand),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (state == 'COMPLETE') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: hasValidContract
                          ? () {
                              showTradePreviewSheet(
                                context: context,
                                market: matchedMarket!.copyWith(
                                  contractAddress: positionContract,
                                  slug: position['slug'] as String?,
                                ),
                                side: isYes ? MarketSide.yes : MarketSide.no,
                                initialIsBuy: false,
                                maxShares: (position['shares'] as num?)?.toDouble() ?? (amount > 0 ? (amount / (hasRealEntryPrice ? entryPrice : 0.5)) : 0.0),
                              ).then((_) => widget.onRefresh?.call());
                            }
                          : null,
                      icon: const Icon(Icons.sell_rounded, size: 14),
                      label: const Text('Sell Position', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.brand,
                        side: BorderSide(color: hasValidContract ? t.brand : t.border, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: _claiming
                        ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                        : OutlinedButton.icon(
                            onPressed: hasValidContract ? _claim : null,
                            icon: const Icon(Icons.redeem_rounded, size: 14),
                            label: const Text('Claim Winnings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: t.yes,
                              side: BorderSide(color: hasValidContract ? t.yes : t.border, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, required this.t, this.highlight = false});
  final String label;
  final String value;
  final PulsThemeColors t;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? t.yesBg : t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? t.yes.withValues(alpha: 0.3) : t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: t.textSubtle, fontSize: 10, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(
            color: highlight ? t.yes : t.text,
            fontSize: 15, fontWeight: FontWeight.w800,
          )),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.message,
    required this.sub,
    required this.t,
    this.imageUrl,
  });
  final IconData icon;
  final String message;
  final String sub;
  final PulsThemeColors t;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl!,
              width: 80,
              height: 80,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(icon, color: t.textSubtle, size: 36),
            )
          else
            Icon(icon, color: t.textSubtle, size: 36),
          const SizedBox(height: 14),
          Text(message, style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(sub,
              style: TextStyle(color: t.textMuted, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

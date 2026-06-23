import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/puls_snack.dart';
import '../../core/widgets/tactile.dart';
import '../../core/widgets/puls_page_route.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/puls_emoji.dart';
import '../../core/utils/trade_math.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/puls_emoji_text.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/market.dart';
import '../../data/polymarket/price_history_service.dart';
import '../market/market_detail_screen.dart';
import '../market/trade_preview_sheet.dart';
import '../shell/web_layout.dart';
import '../shell/shell_nav.dart';
import '../onboarding/help_button.dart';
import '../../app/puls_app.dart';
import 'create_market_dialog.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _query = '';
  String _category = 'All';
  bool _searchFocused = false;
  final _focusNode = FocusNode();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _searchFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _category = 'All';
    });
  }

  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return '🌍';
      case 'politics':
        return '🗳️';
      case 'crypto':
        return '🪙';
      case 'sports':
        return '⚽';
      case 'pop culture':
        return '🎬';
      case 'science':
        return '🧪';
      case 'tech':
        return '💻';
      case 'finance':
        return '💼';
      case 'ai agents':
        return '🤖';
      default:
        return '🔮';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final categories = ['All', ...appState.categories];
    final markets = appState.markets.where((m) {
      final matchCat = _category == 'All'
          ? !m.createdByAgent
          : m.displayCategory == _category;
      final matchQ = m.question.toLowerCase().contains(_query.toLowerCase()) ||
          m.context.toLowerCase().contains(_query.toLowerCase());
      return matchCat && matchQ;
    }).toList();
    final isInitialLoading =
        appState.feedStatus == FeedStatus.loading && appState.markets.isEmpty;
    final hasFilters = _query.isNotEmpty || _category != 'All';

    // Spotlight the single highest-volume market as a featured hero — only when
    // the user hasn't narrowed things down with a search or category.
    final Market? featured =
        (!hasFilters && !isInitialLoading && markets.isNotEmpty)
            ? (markets.toList()
                  ..sort((a, b) => b.volume24hr.compareTo(a.volume24hr)))
                .first
            : null;
    final gridMarkets = featured == null
        ? markets
        : markets.where((m) => m.id != featured.id).toList();

    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              duration: const Duration(milliseconds: 400),
              child: Row(
                children: [
                  if (!kIsWeb) ...[
                    Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: t.brandSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                    ),
                  ],
                  AnimatedGradientText('Discover',
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          )),
                  const Spacer(),
                  const HelpButton(tab: PulsTab.discover),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final ws = WalletServiceScope.of(context).state;
                      if (ws.userId == null || !ws.hasWallet) {
                        PulsSnack.error(context,
                            'Please sign in and connect a wallet to create custom markets.');
                      } else {
                        CreateMarketDialog.show(context);
                      }
                    },
                    child: Container(
                      height: 38,
                      padding:
                          const EdgeInsets.symmetric(horizontal: kIsWeb ? 12 : 9),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: t.brandSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: t.brand.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: t.brand, size: 20),
                          if (kIsWeb) ...[
                            const SizedBox(width: 4),
                            Text('Create market',
                                style: TextStyle(
                                  color: t.brand,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                )),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.border),
                    ),
                    child:
                        Icon(Icons.tune_rounded, color: t.textMuted, size: 17),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FadeIn(
              delay: const Duration(milliseconds: 80),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    if (_searchFocused)
                      BoxShadow(
                        color: t.brand.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _focusNode,
                  style: TextStyle(color: t.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText:
                        'Search prediction markets (e.g., Bitcoin, Election)...',
                    hintStyle: TextStyle(color: t.textSubtle, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: _searchFocused ? t.brand : t.textSubtle,
                        size: 20),
                    filled: true,
                    fillColor: _searchFocused ? t.surfaceRaised : t.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: t.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: t.brand, width: 1.5),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeIn(
              delay: const Duration(milliseconds: 120),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = categories[i];
                    final sel = _category == cat;
                    final emoji = _getCategoryEmoji(cat);
                    return Tactile(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _category = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: sel ? PulsColors.pulseGradient : null,
                          color: sel ? null : t.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel ? Colors.transparent : t.border),
                          boxShadow: [
                            if (sel)
                              BoxShadow(
                                color: t.brand.withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Row(
                          children: [
                            PulsEmoji.icon(emoji, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              cat,
                              style: TextStyle(
                                color: sel ? Colors.white : t.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (featured != null) ...[
              _FeaturedLabel(t: t),
              const SizedBox(height: 12),
              _FeaturedMarketCard(
                market: featured,
                t: t,
                isWatchlisted: appState.isWatchlisted(featured.id),
                onWatchlist: () => appState.toggleWatchlist(featured.id),
                onTap: () => Navigator.of(context).push(
                  pulsRoute(context,
                      builder: (_) =>
                          MarketDetailScreen(marketId: featured.id)),
                ),
              ),
              const SizedBox(height: 24),
            ],
            FadeIn(
              delay: const Duration(milliseconds: 160),
              child: Row(
                children: [
                  Text(featured != null ? 'More markets' : 'Trending Markets',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          )),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.surfaceRaised,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.border),
                    ),
                    child: Text(
                        isInitialLoading
                            ? 'Searching…'
                            : '${markets.length} found',
                        style: TextStyle(
                            color: t.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    final emptySliver = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyState(
          t: t,
          onClear: hasFilters ? _clearFilters : null,
          trending: hasFilters
              ? (appState.markets.toList()
                    ..sort((a, b) => b.volume24hr.compareTo(a.volume24hr)))
                  .take(3)
                  .toList()
              : const [],
        ),
      ),
    );

    final skeletonGridSliver = SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 440,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.45,
        ),
        itemCount: 6,
        itemBuilder: (context, i) => FadeIn(
          delay: Duration(milliseconds: 40 * i),
          duration: const Duration(milliseconds: 250),
          child: const DiscoverCardSkeleton(),
        ),
      ),
    );

    final skeletonListSliver = SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverList.builder(
        itemCount: 4,
        itemBuilder: (context, i) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SizedBox(height: 220, child: DiscoverCardSkeleton()),
        ),
      ),
    );

    final listSliver = SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverList.builder(
        itemCount: gridMarkets.length,
        itemBuilder: (context, i) => FadeInUp(
          delay: Duration(milliseconds: 100 + i * 40),
          duration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MarketCard(
              market: gridMarkets[i],
              t: t,
              isWatchlisted: appState.isWatchlisted(gridMarkets[i].id),
              onWatchlist: () => appState.toggleWatchlist(gridMarkets[i].id),
              onTap: () => Navigator.of(context).push(
                pulsRoute(
                  context,
                  builder: (_) => MarketDetailScreen(marketId: gridMarkets[i].id),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final gridSliver = SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 440,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.45,
        ),
        itemCount: gridMarkets.length,
        itemBuilder: (context, i) => FadeInUp(
          delay: Duration(milliseconds: 50 + i * 30),
          duration: const Duration(milliseconds: 250),
          child: _MarketCard(
            market: gridMarkets[i],
            t: t,
            isWatchlisted: appState.isWatchlisted(gridMarkets[i].id),
            onWatchlist: () => appState.toggleWatchlist(gridMarkets[i].id),
            onTap: () => Navigator.of(context).push(
              pulsRoute(
                context,
                builder: (_) => MarketDetailScreen(marketId: gridMarkets[i].id),
              ),
            ),
          ),
        ),
      ),
    );

    final scrollView = CustomScrollView(
      slivers: [
        header,
        if (isInitialLoading)
          kIsWeb ? skeletonGridSliver : skeletonListSliver
        else if (markets.isEmpty)
          emptySliver
        else
          kIsWeb ? gridSliver : listSliver,
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: kIsWeb ? WebLayout(child: scrollView) : scrollView,
      ),
    );
  }
}

class _MarketCard extends StatefulWidget {
  const _MarketCard({
    required this.market,
    required this.t,
    required this.isWatchlisted,
    required this.onWatchlist,
    required this.onTap,
  });

  final Market market;
  final PulsThemeColors t;
  final bool isWatchlisted;
  final VoidCallback onWatchlist;
  final VoidCallback onTap;

  @override
  State<_MarketCard> createState() => _MarketCardState();
}

class _MarketCardState extends State<_MarketCard> {
  bool _hovered = false;
  List<double> _sparkline = [];
  bool _sparkLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSparkline();
  }

  Future<void> _loadSparkline() async {
    final prices = await PriceHistoryService.fetch(widget.market.clobTokenId);
    if (mounted) {
      setState(() {
        _sparkline = prices;
        _sparkLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final market = widget.market;
    final t = widget.t;
    final trendPositive = market.trendIsPositive;
    final trendColor = trendPositive ? t.yes : t.no;
    final trendBg = trendPositive ? t.yesBg : t.noBg;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hovered ? -4.0 : 0.0, 0),
          decoration: BoxDecoration(
            color: _hovered
                ? t.surfaceRaised
                : t.surfaceRaised.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered ? t.brand.withValues(alpha: 0.4) : t.border,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? t.brand.withValues(alpha: 0.15)
                    : const Color(0xFFEC4899).withValues(alpha: 0.05),
                blurRadius: _hovered ? 24 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: t.brandSubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          market.category.toUpperCase(),
                          style: TextStyle(
                            color: t.brand,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (market.createdByAgent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const PulsEmojiText('🤖 AGENT',
                              style: TextStyle(
                                  color: Color(0xFF8B5CF6),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4)),
                        ),
                      ],
                      const Spacer(),
                      if (market.volume.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text('Vol ${market.volume}',
                              style: TextStyle(
                                  color: t.textSubtle,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      GestureDetector(
                        onTap: widget.onWatchlist,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: widget.isWatchlisted
                                ? PulsColors.amberLight
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isWatchlisted
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 18,
                            color: widget.isWatchlisted
                                ? PulsColors.amber
                                : t.textSubtle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (market.imageUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            market.imageUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 44,
                              height: 44,
                              color: t.brandSubtle,
                              child: Icon(Icons.show_chart_rounded,
                                  color: t.brand, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          market.question,
                          style: TextStyle(
                            color: t.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Sparkline fills the remaining card space
                  Expanded(
                    child: _sparkLoading
                        ? Center(
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.2,
                                color: t.textSubtle,
                              ),
                            ),
                          )
                        : _sparkline.length >= 2
                            ? _MiniSparkline(
                                prices: _sparkline, isUp: trendPositive)
                            : Container(),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      _BuyBtn(
                        label: 'YES',
                        price: TradeMath.formatPrice(market.yesPrice),
                        bg: t.yesBg,
                        fg: t.yes,
                        onPressed: () => showTradePreviewSheet(
                          context: context,
                          market: market,
                          side: MarketSide.yes,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _BuyBtn(
                        label: 'NO',
                        price: TradeMath.formatPrice(market.noPrice),
                        bg: t.noBg,
                        fg: t.no,
                        onPressed: () => showTradePreviewSheet(
                          context: context,
                          market: market,
                          side: MarketSide.no,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: trendBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${trendPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                          style: TextStyle(
                            color: trendColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Featured market hero ──────────────────────────────────────────────────────
class _FeaturedLabel extends StatelessWidget {
  const _FeaturedLabel({required this.t});
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ShaderMask(
          shaderCallback: (r) => PulsColors.pulseGradient.createShader(r),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 16, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text('FEATURED MARKET',
            style: TextStyle(
                color: t.brand,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
        const SizedBox(width: 8),
        Expanded(
          child: Text('· highest volume right now',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.textSubtle, fontSize: 12)),
        ),
      ],
    );
  }
}

class _FeaturedMarketCard extends StatefulWidget {
  const _FeaturedMarketCard({
    required this.market,
    required this.t,
    required this.isWatchlisted,
    required this.onWatchlist,
    required this.onTap,
  });

  final Market market;
  final PulsThemeColors t;
  final bool isWatchlisted;
  final VoidCallback onWatchlist;
  final VoidCallback onTap;

  @override
  State<_FeaturedMarketCard> createState() => _FeaturedMarketCardState();
}

class _FeaturedMarketCardState extends State<_FeaturedMarketCard> {
  bool _hovered = false;
  List<double> _spark = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await PriceHistoryService.fetch(widget.market.clobTokenId);
    if (mounted) {
      setState(() {
        _spark = p;
        _loading = false;
      });
    }
  }

  String _endsIn(DateTime d) {
    final diff = d.difference(DateTime.now());
    if (diff.isNegative) return 'Closed';
    if (diff.inDays >= 1) return '${diff.inDays}d';
    if (diff.inHours >= 1) return '${diff.inHours}h';
    return '${diff.inMinutes}m';
  }

  Widget _stat(PulsThemeColors t, String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: t.text, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: t.textSubtle, fontSize: 11)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final m = widget.market;
    final up = m.trendIsPositive;
    final trendColor = up ? t.yes : t.no;
    final trendBg = up ? t.yesBg : t.noBg;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hovered ? -4.0 : 0.0, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(t.brand.withValues(alpha: 0.10), t.surface),
                t.surfaceRaised,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _hovered
                  ? t.brand.withValues(alpha: 0.5)
                  : t.brand.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: t.brand.withValues(alpha: _hovered ? 0.20 : 0.10),
                blurRadius: _hovered ? 34 : 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.brandSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(m.category.toUpperCase(),
                        style: TextStyle(
                            color: t.brand,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ),
                  if (m.createdByAgent) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const PulsEmojiText('🤖 AGENT',
                          style: TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4)),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: trendBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                        '${up ? '+' : ''}${TradeMath.formatPercent(m.trend)}',
                        style: TextStyle(
                            color: trendColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onWatchlist,
                    child: Icon(
                      widget.isWatchlisted
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 20,
                      color:
                          widget.isWatchlisted ? PulsColors.amber : t.textSubtle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.imageUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        m.imageUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 52,
                          height: 52,
                          color: t.brandSubtle,
                          child: Icon(Icons.show_chart_rounded,
                              color: t.brand, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Text(m.question,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                            letterSpacing: -0.3)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: _loading
                    ? const SizedBox.shrink()
                    : _spark.length >= 2
                        ? _MiniSparkline(prices: _spark, isUp: up)
                        : const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _stat(t, 'Volume', m.volume.isEmpty ? '—' : m.volume),
                  Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      color: t.border),
                  _stat(t, 'Liquidity', m.liquidity.isEmpty ? '—' : m.liquidity),
                  Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      color: t.border),
                  _stat(t, 'Ends in', _endsIn(m.deadline)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _BigBuy(
                      label: 'YES',
                      price: TradeMath.formatPrice(m.yesPrice),
                      bg: t.yesBg,
                      fg: t.yes,
                      onPressed: () => showTradePreviewSheet(
                        context: context,
                        market: m,
                        side: MarketSide.yes,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigBuy(
                      label: 'NO',
                      price: TradeMath.formatPrice(m.noPrice),
                      bg: t.noBg,
                      fg: t.no,
                      onPressed: () => showTradePreviewSheet(
                        context: context,
                        market: m,
                        side: MarketSide.no,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigBuy extends StatefulWidget {
  const _BigBuy({
    required this.label,
    required this.price,
    required this.bg,
    required this.fg,
    required this.onPressed,
  });
  final String label;
  final String price;
  final Color bg;
  final Color fg;
  final VoidCallback onPressed;

  @override
  State<_BigBuy> createState() => _BigBuyState();
}

class _BigBuyState extends State<_BigBuy> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: widget.fg.withValues(alpha: _hover ? 0.6 : 0.3)),
            boxShadow: _hover
                ? [
                    BoxShadow(
                        color: widget.fg.withValues(alpha: 0.2),
                        blurRadius: 14,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.label,
                  style: TextStyle(
                      color: widget.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Text(widget.price,
                  style: TextStyle(
                      color: widget.fg.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.prices, required this.isUp});
  final List<double> prices;
  final bool isUp;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final color = isUp ? t.yes : t.no;
    final spots = prices
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final minY = prices.reduce((a, b) => a < b ? a : b);
    final maxY = prices.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) < 0.01 ? 0.05 : (maxY - minY) * 0.2;

    return LineChart(
      LineChartData(
        minY: (minY - pad).clamp(0, 1),
        maxY: (maxY + pad).clamp(0, 1),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: 1.8,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.16),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyBtn extends StatelessWidget {
  const _BuyBtn({
    required this.label,
    required this.price,
    required this.bg,
    required this.fg,
    required this.onPressed,
  });
  final String label;
  final String price;
  final Color bg;
  final Color fg;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 11, color: fg),
            ),
            const SizedBox(width: 4),
            Text(
              price,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  color: fg.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.t, this.onClear, this.trending = const []});

  final VoidCallback? onClear;
  final PulsThemeColors t;
  final List<Market> trending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: t.textSubtle, size: 40),
          const SizedBox(height: 16),
          Text('Nothing matches — try a different search or clear filters.',
              style: TextStyle(
                  color: t.text, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Try searching for another keyword or selection.',
              style: TextStyle(color: t.textMuted, fontSize: 13),
              textAlign: TextAlign.center),
          if (onClear != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: t.brand,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: t.brand.withValues(alpha: 0.4)),
                ),
              ),
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Clear search & filters',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
          if (trending.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Trending now',
                style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            ...trending.take(3).map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      pulsRoute(context,
                          builder: (_) => MarketDetailScreen(marketId: m.id)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: t.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.question,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: t.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(m.yesPrice * 100).toStringAsFixed(0)}¢',
                            style: TextStyle(
                                color: t.yes,
                                fontSize: 13,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

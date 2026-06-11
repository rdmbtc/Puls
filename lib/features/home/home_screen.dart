import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app.dart';
import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';
import '../market/market_detail_screen.dart';
import '../market/trade_preview_sheet.dart';
import '../shell/web_layout.dart';
import '../wallet/wallet_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WebHomeScreen();
  }
}

class _WebHomeScreen extends StatelessWidget {
  const _WebHomeScreen();

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final wallet = WalletServiceScope.of(context);
    final ws = wallet.state;
    final t = context.puls;
    final size = MediaQuery.sizeOf(context);

    if (appState.feedStatus == FeedStatus.loading && appState.markets.isEmpty) {
      return Scaffold(
        backgroundColor: t.bg,
        body: const WebLayout(
          child: Center(
            child: MarketCardSkeleton(),
          ),
        ),
      );
    }

    if (appState.markets.isEmpty) {
      return Scaffold(
        backgroundColor: t.bg,
        body: WebLayout(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trending_up_rounded, size: 48, color: t.textMuted),
                const SizedBox(height: 16),
                Text(
                  'No markets live yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: t.text),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back soon or activate a market to start trading.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Find the main contract market or pick first featured
    final featuredMarket = appState.markets.firstWhere(
      (m) => m.isFeatured,
      orElse: () => appState.markets.first,
    );

    final trendingMarkets = appState.markets
        .where((m) => m.id != featuredMarket.id)
        .take(6)
        .toList();

    final hotMarkets = appState.markets
        .where((m) => m.id != featuredMarket.id)
        .skip(trendingMarkets.length)
        .take(4)
        .toList();
    final displayHot = hotMarkets.isNotEmpty ? hotMarkets : trendingMarkets.take(4).toList();

    final bodyContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (70%)
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeaturedHeroBanner(market: featuredMarket, t: t),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text('Trending Predictions',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => PulsStateScope.of(context).refresh(),
                    icon: Icon(Icons.refresh_rounded, size: 16, color: t.brand),
                    label: Text('Refresh', style: TextStyle(color: t.brand, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.45,
                ),
                itemCount: trendingMarkets.length,
                itemBuilder: (context, i) => _WebTrendingCard(market: trendingMarkets[i], t: t),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Column (30%)
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WebWalletBox(ws: ws, wallet: wallet, t: t),
              const SizedBox(height: 28),
              Text('🔥 Hot Markets',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayHot.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _WebHotMarketCard(market: displayHot[i], t: t),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: t.bg,
      body: WebLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: size.width < 900
              ? Column(
                  children: [
                    _FeaturedHeroBanner(market: featuredMarket, t: t),
                    const SizedBox(height: 24),
                    _WebWalletBox(ws: ws, wallet: wallet, t: t),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('Trending Predictions',
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: size.width > 600 ? 2 : 1,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: size.width > 600 ? 1.45 : 1.6,
                      ),
                      itemCount: trendingMarkets.length,
                      itemBuilder: (context, i) => _WebTrendingCard(market: trendingMarkets[i], t: t),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('🔥 Hot Markets',
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: displayHot.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) => SizedBox(
                          width: 260,
                          child: _WebHotMarketCard(market: displayHot[i], t: t),
                        ),
                      ),
                    ),
                  ],
                )
              : bodyContent,
        ),
      ),
    );
  }
}

class _FeaturedHeroBanner extends StatelessWidget {
  const _FeaturedHeroBanner({required this.market, required this.t});
  final Market market;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final yesPct = (market.yesPrice * 100).round();
    final noPct = 100 - yesPct;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border, width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.surfaceRaised,
            t.brand.withValues(alpha: 0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: t.brand.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'FEATURED MARKET',
                  style: TextStyle(
                      color: t.brand,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1),
                ),
              ),
              const Spacer(),
              Icon(Icons.trending_up_rounded, color: t.yes, size: 16),
              const SizedBox(width: 4),
              Text(
                'Volume: ${market.volume}',
                style: TextStyle(color: t.textSubtle, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MarketDetailScreen(marketId: market.id),
              ),
            ),
            child: Text(
              market.question,
              style: TextStyle(
                color: t.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            market.context,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _TradingPillButton(
                  label: 'Buy YES',
                  pct: '$yesPct%',
                  price: TradeMath.formatPrice(market.yesPrice),
                  color: t.yes,
                  bg: t.yesBg,
                  onPressed: () => showTradePreviewSheet(
                      context: context, market: market, side: MarketSide.yes),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TradingPillButton(
                  label: 'Buy NO',
                  pct: '$noPct%',
                  price: TradeMath.formatPrice(market.noPrice),
                  color: t.no,
                  bg: t.noBg,
                  onPressed: () => showTradePreviewSheet(
                      context: context, market: market, side: MarketSide.no),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WebTrendingCard extends StatefulWidget {
  const _WebTrendingCard({required this.market, required this.t});
  final Market market;
  final PulsThemeColors t;

  @override
  State<_WebTrendingCard> createState() => _WebTrendingCardState();
}

class _WebTrendingCardState extends State<_WebTrendingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final yesPct = (widget.market.yesPrice * 100).round();
    final noPct = 100 - yesPct;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MarketDetailScreen(marketId: widget.market.id),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered ? t.surfaceRaised : t.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _hovered ? t.brand.withValues(alpha: 0.4) : t.border),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: t.brand.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.brandSubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.market.category,
                      style: TextStyle(color: t.brand, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.market.volume,
                    style: TextStyle(color: t.textSubtle, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  widget.market.question,
                  style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w700, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QuickPill(label: 'YES $yesPct%', color: t.yes, bg: t.yesBg),
                  const SizedBox(width: 6),
                  _QuickPill(label: 'NO $noPct%', color: t.no, bg: t.noBg),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  const _QuickPill({required this.label, required this.color, required this.bg});
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _WebWalletBox extends StatelessWidget {
  const _WebWalletBox({required this.ws, required this.wallet, required this.t});
  final WalletState ws;
  final WalletService wallet;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final balance = double.tryParse(ws.usdcBalance)?.toStringAsFixed(2) ?? ws.usdcBalance;
    final isZero = (double.tryParse(ws.usdcBalance) ?? 0) == 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: t.brand, size: 20),
              const SizedBox(width: 8),
              Text('Arc Wallet', style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (ws.walletAddress != null && ws.walletAddress!.isNotEmpty)
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: t.yes, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (ws.userId == null) ...[
            Text('Connect your wallet via the Profile tab to enable predicting on Arc Testnet.',
                style: TextStyle(color: t.textMuted, fontSize: 12, height: 1.5)),
          ] else ...[
            Text('\$$balance USDC', style: TextStyle(color: t.text, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              ws.walletAddress != null && ws.walletAddress!.isNotEmpty
                  ? '${ws.walletAddress!.substring(0, 6)}...${ws.walletAddress!.substring(ws.walletAddress!.length - 4)}'
                  : 'Generating address...',
              style: TextStyle(color: t.textSubtle, fontSize: 11, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 14),
            if (isZero) ...[
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://faucet.circle.com'), mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: PulsColors.amberLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PulsColors.amber.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.water_drop_rounded, size: 14, color: PulsColors.amber),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Get testnet USDC faucet →',
                          style: TextStyle(color: PulsColors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WebHotMarketCard extends StatefulWidget {
  const _WebHotMarketCard({required this.market, required this.t});
  final Market market;
  final PulsThemeColors t;

  @override
  State<_WebHotMarketCard> createState() => _WebHotMarketCardState();
}

class _WebHotMarketCardState extends State<_WebHotMarketCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final yesPct = (widget.market.yesPrice * 100).round();
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MarketDetailScreen(marketId: widget.market.id),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered ? t.surfaceRaised : t.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hovered ? t.brand : t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.brandSubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.market.category.toUpperCase(),
                      style: TextStyle(
                        color: t.brand,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.market.volume,
                    style: TextStyle(
                      color: t.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.market.question,
                style: TextStyle(
                  color: t.text,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.yesBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'YES $yesPct%',
                        style: TextStyle(
                          color: t.yes,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.noBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'NO ${100 - yesPct}%',
                        style: TextStyle(
                          color: t.no,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
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

class _TradingPillButton extends StatelessWidget {
  const _TradingPillButton({
    required this.label,
    required this.pct,
    required this.price,
    required this.color,
    required this.bg,
    required this.onPressed,
  });

  final String label;
  final String pct;
  final String price;
  final Color color;
  final Color bg;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            Row(
              children: [
                Text(pct, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(width: 4),
                Text('($price)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: color.withValues(alpha: 0.7))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/trade_math.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/market.dart';
import '../market/market_detail_screen.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final markets = appState.watchlistMarkets;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInDown(
                      duration: const Duration(milliseconds: 400),
                      child: Text('Watchlist',
                          style: Theme.of(context).textTheme.displaySmall),
                    ),
                    const SizedBox(height: 20),
                    FadeInUp(
                      delay: const Duration(milliseconds: 80),
                      duration: const Duration(milliseconds: 400),
                      child: _AlertsBanner(t: t),
                    ),
                    const SizedBox(height: 24),
                    FadeIn(
                      delay: const Duration(milliseconds: 160),
                      child: Row(
                        children: [
                          Text('Saved markets',
                              style: Theme.of(context).textTheme.titleLarge),
                          const Spacer(),
                          Text('${markets.length} saved',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (markets.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FadeIn(
                    delay: const Duration(milliseconds: 200),
                    child: const _EmptyState(),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList.builder(
                  itemCount: markets.length,
                  itemBuilder: (context, i) => FadeInUp(
                    delay: Duration(milliseconds: 200 + i * 60),
                    duration: const Duration(milliseconds: 350),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Slidable(
                        key: ValueKey(markets[i].id),
                        groupTag: 'watchlist',
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.28,
                          dismissible: DismissiblePane(
                            onDismissed: () =>
                                appState.toggleWatchlist(markets[i].id),
                          ),
                          children: [
                            SlidableAction(
                              onPressed: (_) =>
                                  appState.toggleWatchlist(markets[i].id),
                              backgroundColor: t.no,
                              foregroundColor: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              icon: Icons.bookmark_remove_rounded,
                              label: 'Remove',
                            ),
                          ],
                        ),
                        child: _WatchCard(
                          market: markets[i],
                          t: t,
                          onRemove: () =>
                              appState.toggleWatchlist(markets[i].id),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MarketDetailScreen(
                                  marketId: markets[i].id),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlertsBanner extends StatelessWidget {
  const _AlertsBanner({required this.t});
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.brandSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.brand.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.brand,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('3 mock alerts armed',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Price moves and deadlines are simulated.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchCard extends StatelessWidget {
  const _WatchCard({
    required this.market,
    required this.t,
    required this.onRemove,
    required this.onTap,
  });

  final Market market;
  final PulsThemeColors t;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trendPositive = market.trendIsPositive;
    final trendColor = trendPositive ? t.yes : t.no;
    final trendBg = trendPositive ? t.yesBg : t.noBg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEC4899).withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(market.question,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.yesBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Yes ${TradeMath.formatPrice(market.yesPrice)}',
                          style: TextStyle(
                            color: t.yes,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: trendBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${trendPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                          style: TextStyle(
                            color: trendColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: PulsColors.amberLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bookmark_remove_rounded,
                    color: PulsColors.amber, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const PulsEmptyState(
      icon: Icons.bookmark_border_rounded,
      title: 'No saved markets',
      message: 'Tap the bookmark on any market to watch it here.',
    );
  }
}

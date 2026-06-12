import 'package:fl_chart/fl_chart.dart' hide CandlestickChart;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_util.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';
import '../../data/polymarket/price_history_service.dart';
import '../shell/web_layout.dart';
import 'trade_preview_sheet.dart';
import 'ai_copilot_sheet.dart';
import 'share_market_sheet.dart';
import 'advanced_charts.dart';
import 'ai_insight_card.dart';
import 'resolution_panel.dart';

class MarketDetailScreen extends StatefulWidget {
  const MarketDetailScreen({required this.marketId, super.key});
  final String marketId;

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  List<double> _history = [];
  bool _historyLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final market = PulsStateScope.of(context).marketById(widget.marketId);
    PriceHistoryService.fetchForMarket(market).then((h) {
      if (mounted) setState(() { _history = h; _historyLoading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final market = appState.marketById(widget.marketId);
    final t = context.puls;
    final trendPositive = market.trendIsPositive;
    final trendColor = trendPositive ? t.yes : t.no;

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, kIsWeb ? 40 : 110),
      children: [
        // ── Hero image ──────────────────────────────────────────────────
        if (market.imageUrl.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: networkImage(market.imageUrl, height: 180, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
        ],

        // ── Category chip ────────────────────────────────────────────────
        Wrap(
          spacing: 6,
          children: [
            _Chip(label: market.category, t: t),
            if (market.isFeatured) _Chip(label: '⭐ Featured', t: t, highlight: true),
          ],
        ),
        const SizedBox(height: 12),

        // ── Question ─────────────────────────────────────────────────────
        Text(market.question, style: Theme.of(context).textTheme.headlineMedium),
        if (market.context.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(market.context,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: t.textMuted),
              maxLines: 4, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 20),

        // ── Probability panel ────────────────────────────────────────────
        _ProbabilityPanel(market: market, t: t),
        const SizedBox(height: 14),

        // ── Price chart ──────────────────────────────────────────────────
        _ChartSection(
          market: market,
          history: _history,
          loading: _historyLoading,
          trendColor: trendColor,
          trendPositive: trendPositive,
          trend: market.trend,
          t: t,
        ),
        const SizedBox(height: 14),

        // ── AI Analyst brief ─────────────────────────────────────────────
        AiInsightCard(market: market),
        const SizedBox(height: 14),

        // ── Stats grid ───────────────────────────────────────────────────
        _StatsGrid(market: market, t: t),
        const SizedBox(height: 14),

        // ── Bid / Ask ────────────────────────────────────────────────────
        if (market.bestBid > 0 || market.bestAsk > 0) ...[
          _BidAskPanel(market: market, t: t),
          const SizedBox(height: 14),
        ],

        // ── How this market resolves ─────────────────────────────────────
        ResolutionPanel(market: market),
        const SizedBox(height: 14),

        // ── Resolution date ──────────────────────────────────────────────
        _InfoRow(
          icon: Icons.calendar_today_rounded,
          label: 'Resolves',
          value: _fmtDate(market.deadline),
          t: t,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, size: 20, color: t.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Market'),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share_rounded, size: 20, color: t.text),
            tooltip: 'Share market',
            onPressed: () => ShareMarketSheet.show(context, market),
          ),
          IconButton(
            icon: Icon(Icons.auto_awesome_rounded, size: 20, color: t.brand),
            onPressed: () => AiCopilotSheet.show(context, market),
          ),
          IconButton(
            icon: Icon(Icons.bookmark_rounded, size: 20,
              color: appState.isWatchlisted(market.id) ? PulsColors.amber : t.textSubtle),
            onPressed: () => appState.toggleWatchlist(market.id),
          ),
        ],
      ),
      body: kIsWeb ? WebLayout(maxWidth: 720, child: body) : body,
      bottomNavigationBar: kIsWeb ? null : SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          decoration: BoxDecoration(
            color: t.bg,
            border: Border(top: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              Expanded(child: _TradeBtn(
                label: 'Buy YES', price: TradeMath.formatPrice(market.yesPrice),
                bg: t.yesBg, fg: t.yes,
                onPressed: () => showTradePreviewSheet(context: context, market: market, side: MarketSide.yes),
              )),
              const SizedBox(width: 12),
              Expanded(child: _TradeBtn(
                label: 'Buy NO', price: TradeMath.formatPrice(market.noPrice),
                bg: t.noBg, fg: t.no,
                onPressed: () => showTradePreviewSheet(context: context, market: market, side: MarketSide.no),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Probability panel ─────────────────────────────────────────────────────────
class _ProbabilityPanel extends StatelessWidget {
  const _ProbabilityPanel({required this.market, required this.t});
  final Market market;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final yesPct = (market.yesPrice * 100).round();
    final noPct = 100 - yesPct;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YES', style: TextStyle(color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('$yesPct%', style: TextStyle(color: t.yes, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
                    Text(TradeMath.formatPrice(market.yesPrice), style: TextStyle(color: t.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(width: 1, height: 56, color: t.border),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NO', style: TextStyle(color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('$noPct%', style: TextStyle(color: t.no, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
                      Text(TradeMath.formatPrice(market.noPrice), style: TextStyle(color: t.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(width: 12),
                Column(
                  children: [
                    _TradeBtn(
                      label: 'YES', price: TradeMath.formatPrice(market.yesPrice),
                      bg: t.yesBg, fg: t.yes,
                      onPressed: () => showTradePreviewSheet(
                        context: context, market: market, side: MarketSide.yes),
                    ),
                    const SizedBox(height: 6),
                    _TradeBtn(
                      label: 'NO', price: TradeMath.formatPrice(market.noPrice),
                      bg: t.noBg, fg: t.no,
                      onPressed: () => showTradePreviewSheet(
                        context: context, market: market, side: MarketSide.no),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // Split bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(flex: yesPct, child: ColoredBox(color: t.yes)),
                  Expanded(flex: noPct, child: ColoredBox(color: t.no)),
                ],
              ),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _TradeBtn(
                  label: 'Buy YES', price: TradeMath.formatPrice(market.yesPrice),
                  bg: t.yesBg, fg: t.yes,
                  onPressed: () => showTradePreviewSheet(context: context, market: market, side: MarketSide.yes),
                )),
                const SizedBox(width: 10),
                Expanded(child: _TradeBtn(
                  label: 'Buy NO', price: TradeMath.formatPrice(market.noPrice),
                  bg: t.noBg, fg: t.no,
                  onPressed: () => showTradePreviewSheet(context: context, market: market, side: MarketSide.no),
                )),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Chart section ─────────────────────────────────────────────────────────────
class _ChartSection extends StatefulWidget {
  const _ChartSection({
    required this.market,
    required this.history,
    required this.loading,
    required this.trendColor,
    required this.trendPositive,
    required this.trend,
    required this.t,
  });
  final Market market;
  final List<double> history;
  final bool loading;
  final Color trendColor;
  final bool trendPositive;
  final double trend;
  final PulsThemeColors t;

  @override
  State<_ChartSection> createState() => _ChartSectionState();
}

class _ChartSectionState extends State<_ChartSection> {
  String _activeTab = 'line'; // 'line', 'candle', 'depth'

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    
    Widget chartWidget;
    if (widget.loading) {
      chartWidget = Center(child: CircularProgressIndicator(color: t.brand, strokeWidth: 2));
    } else if (widget.history.isEmpty) {
      chartWidget = Center(child: Text('No chart data available', style: TextStyle(color: t.textSubtle, fontSize: 13)));
    } else {
      switch (_activeTab) {
        case 'candle':
          chartWidget = CandlestickChart(
            prices: widget.history,
            upColor: t.yes,
            downColor: t.no,
          );
          break;
        case 'depth':
          chartWidget = DepthChart(
            currentPrice: widget.market.yesPrice,
            t: t,
          );
          break;
        case 'line':
        default:
          chartWidget = _FullChart(prices: widget.history, color: widget.trendColor);
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Price Analytics', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.trendPositive ? t.yesBg : t.noBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.trendPositive ? '+' : ''}${TradeMath.formatPercent(widget.trend)} 24h',
                  style: TextStyle(color: widget.trendColor, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Chart Type Selector Toggles
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tabBtn('line', 'Line', t),
                _tabBtn('candle', 'Candlestick', t),
                _tabBtn('depth', 'Depth', t),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            height: kIsWeb ? 260 : 160,
            child: chartWidget,
          ),
          
          if (_activeTab == 'line' && widget.history.length >= 2) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(widget.history.first * 100).toStringAsFixed(0)}¢ open',
                    style: TextStyle(color: t.textSubtle, fontSize: 11)),
                Text('${(widget.history.last * 100).toStringAsFixed(0)}¢ now',
                    style: TextStyle(color: widget.trendColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabBtn(String key, String label, PulsThemeColors t) {
    final active = _activeTab == key;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : t.textSubtle,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _FullChart extends StatelessWidget {
  const _FullChart({required this.prices, required this.color});
  final List<double> prices;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final spots = prices.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final minY = prices.reduce((a, b) => a < b ? a : b);
    final maxY = prices.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) < 0.01 ? 0.05 : (maxY - minY) * 0.15;

    return LineChart(
      LineChartData(
        minY: (minY - pad).clamp(0, 1),
        maxY: (maxY + pad).clamp(0, 1),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: t.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 0.25,
              getTitlesWidget: (v, _) => Text(
                '${(v * 100).toStringAsFixed(0)}¢',
                style: TextStyle(color: t.textSubtle, fontSize: 9),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
              '${(s.y * 100).toStringAsFixed(0)}¢',
              TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
            )).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
    );
  }
}

// ── Stats grid ────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.market, required this.t});
  final Market market;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Volume', market.volume),
      ('24h Volume', _fmt(market.volume24hr)),
      ('Liquidity', market.liquidity),
      ('Category', market.category),
    ];
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 4 : 2,
      childAspectRatio: 2.4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((e) => _StatTile(label: e.$1, value: e.$2, t: t)).toList(),
    );
  }

  String _fmt(double v) {
    if (v <= 0) return '—';
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}

// ── Bid/Ask panel ─────────────────────────────────────────────────────────────
class _BidAskPanel extends StatelessWidget {
  const _BidAskPanel({required this.market, required this.t});
  final Market market;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Book', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _OrderCell(label: 'Best Bid', value: '${(market.bestBid * 100).toStringAsFixed(0)}¢', color: t.yes, t: t)),
              const SizedBox(width: 10),
              Expanded(child: _OrderCell(label: 'Best Ask', value: '${(market.bestAsk * 100).toStringAsFixed(0)}¢', color: t.no, t: t)),
              const SizedBox(width: 10),
              Expanded(child: _OrderCell(label: 'Spread', value: '${(market.spread * 100).toStringAsFixed(0)}¢', color: t.textMuted, t: t)),
            ],
          ),
          if (market.competitive > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Market depth', style: TextStyle(color: t.textSubtle, fontSize: 11)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        value: market.competitive.clamp(0.0, 1.0),
                        backgroundColor: t.border,
                        valueColor: AlwaysStoppedAnimation(t.brand),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(market.competitive * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderCell extends StatelessWidget {
  const _OrderCell({required this.label, required this.value, required this.color, required this.t});
  final String label;
  final String value;
  final Color color;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: t.textSubtle, fontSize: 10, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, required this.t});
  final IconData icon;
  final String label;
  final String value;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: t.textSubtle),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: t.textMuted, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.t, this.highlight = false});
  final String label;
  final PulsThemeColors t;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? t.brandSubtle : t.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: highlight ? t.brand : t.border),
      ),
      child: Text(label,
          style: TextStyle(color: highlight ? t.brand : t.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.t});
  final String label;
  final String value;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: t.text, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TradeBtn extends StatelessWidget {
  const _TradeBtn({required this.label, required this.price, required this.bg, required this.fg, required this.onPressed});
  final String label;
  final String price;
  final Color bg;
  final Color fg;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('$label $price',
            style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }
}

String _fmtDate(DateTime v) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${m[v.month - 1]} ${v.day}, ${v.year}';
}

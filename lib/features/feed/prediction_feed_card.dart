import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:haptic_kit/haptic_kit.dart';
import 'package:picons/picons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/tactile.dart';
import '../../core/widgets/market_hero.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';
import '../../data/polymarket/price_history_service.dart';

class PredictionFeedCard extends StatefulWidget {
  const PredictionFeedCard({
    required this.market,
    required this.isWatchlisted,
    required this.onWatchlist,
    required this.onDetails,
    required this.onChoose,
    this.showSwipeHint = false,
    super.key,
  });

  final Market market;
  final bool isWatchlisted;
  final VoidCallback onWatchlist;
  final VoidCallback onDetails;
  final ValueChanged<MarketSide> onChoose;

  /// When true (first card in the feed), plays a one-time "peek" animation
  /// nudging the card right then left so users discover swipe-to-trade.
  final bool showSwipeHint;

  @override
  State<PredictionFeedCard> createState() => _PredictionFeedCardState();
}

class _PredictionFeedCardState extends State<PredictionFeedCard>
    with TickerProviderStateMixin {
  // Once per app session — not on every rebuild of the first card.
  static bool _swipeHintPlayed = false;

  late final ValueNotifier<double> _dragX;
  List<double> _sparkline = [];
  bool _hasTriggeredHaptic = false;
  AnimationController? _hintCtrl;

  // Release animation: spring-return to centre, or fling the card off-screen.
  AnimationController? _releaseCtrl;
  bool _flinging = false; // true while the card is flying off after a commit

  @override
  void initState() {
    super.initState();
    _dragX = ValueNotifier<double>(0.0);
    PriceHistoryService.fetch(widget.market.clobTokenId).then((prices) {
      if (mounted) setState(() => _sparkline = prices);
    });
    if (widget.showSwipeHint && !_swipeHintPlayed) {
      _swipeHintPlayed = true;
      _scheduleSwipeHint();
    }
  }

  void _scheduleSwipeHint() {
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _hintCtrl = ctrl;
    final anim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 68.0)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 26),
      TweenSequenceItem(
          tween: Tween(begin: 68.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 22),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -54.0)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 26),
      TweenSequenceItem(
          tween: Tween(begin: -54.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 26),
    ]).animate(ctrl);
    anim.addListener(() {
      if (_hintCtrl != null) _dragX.value = anim.value;
    });
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted && _hintCtrl == ctrl) ctrl.forward();
    });
  }

  void _cancelSwipeHint() {
    final ctrl = _hintCtrl;
    if (ctrl == null) return;
    _hintCtrl = null;
    ctrl.stop();
    ctrl.dispose();
  }

  @override
  void dispose() {
    _cancelSwipeHint();
    _releaseCtrl?.dispose();
    _dragX.dispose();
    super.dispose();
  }

  // Animate _dragX from its current value to [target] with a custom curve.
  // onDone fires at the end (used to fire the trade after the card flies off).
  void _animateDragTo(double target, {required Duration duration, required Curve curve, VoidCallback? onDone}) {
    _releaseCtrl?.dispose();
    final ctrl = AnimationController(vsync: this, duration: duration);
    _releaseCtrl = ctrl;
    final from = _dragX.value;
    final anim = Tween<double>(begin: from, end: target)
        .chain(CurveTween(curve: curve))
        .animate(ctrl);
    anim.addListener(() => _dragX.value = anim.value);
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) onDone?.call();
    });
    ctrl.forward();
  }

  // Spring back to centre when the swipe didn't cross the threshold.
  void _springBack() {
    _hasTriggeredHaptic = false;
    _animateDragTo(0.0, duration: const Duration(milliseconds: 420), curve: Curves.elasticOut);
  }

  void _reset() {
    _releaseCtrl?.dispose();
    _releaseCtrl = null;
    _dragX.value = 0.0;
    _hasTriggeredHaptic = false;
    _flinging = false;
  }

  // Commit: heavy haptic, fling the card off-screen in the swipe direction with
  // inertia, THEN fire the trade callback — so the gesture feels physical.
  void _commit(MarketSide side) {
    if (_flinging) return;
    _flinging = true;
    Haptics.impact(HapticImpactStyle.heavy);
    final dir = side == MarketSide.yes ? 1.0 : -1.0;
    _animateDragTo(
      dir * 1000.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      onDone: () {
        widget.onChoose(side);
        // Parent advances the feed; reset so a reused card starts centred.
        _reset();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final market = widget.market;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _cancelSwipeHint();
        _releaseCtrl?.dispose();
        _releaseCtrl = null;
        _flinging = false;
        _dragX.value = 0.0;
      },
      onHorizontalDragUpdate: (d) {
        if (_flinging) return;
        _dragX.value = (_dragX.value + d.delta.dx).clamp(-180.0, 180.0);
        final absDrag = _dragX.value.abs();
        if (absDrag > 82) {
          if (!_hasTriggeredHaptic) {
            // Crossed the commit threshold — a firm "you're about to trade" cue.
            Haptics.impact(HapticImpactStyle.medium);
            _hasTriggeredHaptic = true;
          }
        } else {
          if (_hasTriggeredHaptic) {
            _hasTriggeredHaptic = false;
          }
        }
      },
      onHorizontalDragEnd: (d) {
        if (_flinging) return;
        final v = d.primaryVelocity ?? 0;
        final currentDrag = _dragX.value;
        if (currentDrag > 82 || v > 700) {
          _commit(MarketSide.yes);
        } else if (currentDrag < -82 || v < -700) {
          _commit(MarketSide.no);
        } else {
          _springBack();
        }
      },
      onHorizontalDragCancel: _springBack,
      child: ValueListenableBuilder<double>(
        valueListenable: _dragX,
        builder: (context, dragX, child) {
          final progress = (dragX.abs() / 140).clamp(0.0, 1.0);
          final side = dragX >= 0 ? MarketSide.yes : MarketSide.no;
          final swipeColor = side == MarketSide.yes ? t.yes : t.no;

          return Transform.translate(
            offset: Offset(dragX, 0),
            child: Transform.rotate(
              angle: (dragX / 180) * 0.18, // tilt up to ~10° at full drag
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: t.surfaceRaised,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: progress > 0.1
                        ? swipeColor.withValues(alpha: progress * 0.5)
                        : t.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: progress > 0.1
                          ? swipeColor.withValues(alpha: progress * 0.25)
                          : const Color(0xFFEC4899).withValues(alpha: 0.06),
                      blurRadius: 16 + progress * 20,
                      offset: Offset(dragX * 0.05, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Swipe color wave — rises from the bottom as you drag.
                    if (progress > 0)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 60),
                              height: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    swipeColor.withValues(alpha: 0.35 * progress),
                                    swipeColor.withValues(alpha: 0.08 * progress),
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, progress * 0.6, progress],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Tinder-style angled YES/NO stamp — YES pins to the top-left
                    // and tilts left; NO pins to the top-right and tilts right.
                    if (progress > 0.05)
                      Positioned(
                        top: 22,
                        left: side == MarketSide.yes ? 20 : null,
                        right: side == MarketSide.no ? 20 : null,
                        child: Opacity(
                          opacity: ((progress - 0.05) / 0.45).clamp(0.0, 1.0),
                          child: Transform.rotate(
                            angle: side == MarketSide.yes ? -0.32 : 0.32,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: swipeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: swipeColor, width: 4),
                              ),
                              child: Text(
                                side == MarketSide.yes ? 'YES' : 'NO',
                                style: TextStyle(
                                  color: swipeColor,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Card content (Expensive static part)
                    child!,
                  ],
                ),
              ),
            ),
          );
        },
        child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top row: tags + swipe badge + bookmark
                      Row(
                              children: [
                                _Tag(label: market.category, t: t),
                                const SizedBox(width: 8),
                                _Tag(label: market.volume, t: t),
                                if (market.createdByAgent) ...[
                                  const SizedBox(width: 8),
                                  _Tag(label: '🤖 Agent', t: t),
                                ],
                                const Spacer(),
                                ValueListenableBuilder<double>(
                                  valueListenable: _dragX,
                                  builder: (context, dragX, _) {
                                    final progress = (dragX.abs() / 140).clamp(0.0, 1.0);
                                    if (progress <= 0.2) return const SizedBox.shrink();
                                    final side = dragX >= 0 ? MarketSide.yes : MarketSide.no;
                                    final swipeColor = side == MarketSide.yes ? t.yes : t.no;
                                    return AnimatedOpacity(
                                      opacity: ((progress - 0.2) / 0.8).clamp(0.0, 1.0),
                                      duration: const Duration(milliseconds: 80),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: swipeColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          side == MarketSide.yes ? 'YES' : 'NO',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                Tactile(
                                  onTap: widget.onWatchlist,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    alignment: Alignment.centerRight,
                                    child: Icon(
                                      Icons.bookmark_rounded,
                                      size: 20,
                                      color: widget.isWatchlisted
                                          ? PulsColors.amber
                                          : t.textSubtle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 8),
                      // Question
                      Text(
                        market.question,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      // Topic Image
                      MarketImageHero(
                        marketId: market.id,
                        radius: 12,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: t.border.withValues(alpha: 0.5)),
                            ),
                            child: Image.network(
                              _proxied(market.imageUrl.isNotEmpty ? market.imageUrl : _getTopicImage(market.category, market.id)),
                              height: 130,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Skeleton(height: 130, radius: 0);
                              },
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 130,
                                color: t.surface,
                                child: Icon(Icons.image_outlined, color: t.textSubtle),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (market.context.isNotEmpty) ...[
                        Text(
                          market.context,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: t.textMuted,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                      ],
                            const SizedBox(height: 8),
                            // Odds bar
                            _OddsBar(market: market),
                            const SizedBox(height: 8),
                            // Sparkline — always 48px, shows shimmer while loading
                            SizedBox(
                              height: 48,
                              child: _sparkline.length >= 2
                                  ? _CardSparkline(
                                      prices: _sparkline,
                                      isUp: _sparkline.last >= _sparkline.first,
                                    )
                                  : DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: context.puls.surface,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            // Stats + details
                            Row(
                              children: [
                                _Stat(
                                  icon: Picons.trendUp,
                                  label: '${market.trendIsPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                                  color: market.trendIsPositive ? t.yes : t.no,
                                ),
                                const SizedBox(width: 8),
                                if (market.volume24hr > 0)
                                  _Stat(
                                    icon: Picons.chartBar,
                                    label: _fmtVol(market.volume24hr),
                                    color: t.textMuted,
                                  )
                                else
                                  _Stat(
                                    icon: Picons.drop,
                                    label: market.liquidity,
                                    color: t.textMuted,
                                  ),
                                if (market.spread > 0) ...[
                                  const SizedBox(width: 8),
                                  _Stat(
                                    icon: Picons.arrowsLeftRight,
                                    label: 'Spread ${(market.spread * 100).toStringAsFixed(0)}¢',
                                    color: t.textMuted,
                                  ),
                                ],
                                const SizedBox(width: 8),
                                Tactile(
                                  onTap: widget.onDetails,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                    child: Row(
                                      children: [
                                        Text('Details',
                                            style: TextStyle(
                                                color: t.brand,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 2),
                                        Icon(Icons.arrow_forward_rounded,
                                            size: 14, color: t.brand),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // YES / NO buttons
                            Row(
                              children: [
                                Expanded(
                                  child: _SideBtn(
                                    label: 'YES',
                                    price: TradeMath.formatPrice(
                                        market.yesPrice),
                                    bg: t.yesBg,
                                    fg: t.yes,
                                    onPressed: () =>
                                        widget.onChoose(MarketSide.yes),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _SideBtn(
                                    label: 'NO',
                                    price: TradeMath.formatPrice(
                                        market.noPrice),
                                    bg: t.noBg,
                                    fg: t.no,
                                    onPressed: () =>
                                        widget.onChoose(MarketSide.no),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                'Swipe right for Yes · left for No',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall,
                              ),
                            ),
                    ],
                  ),
                ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.04, duration: 200.ms, curve: Curves.easeOut);
  }

  String _fmtVol(double v) {
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}

class _CardSparkline extends StatelessWidget {
  const _CardSparkline({required this.prices, required this.isUp});
  final List<double> prices;
  final bool isUp;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final color = isUp ? t.yes : t.no;
    final spots = prices.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final minY = prices.reduce((a, b) => a < b ? a : b);
    final maxY = prices.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) < 0.01 ? 0.05 : (maxY - minY) * 0.2;

    return SizedBox(
      height: 48,
      child: LineChart(
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
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.2),
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

class _OddsBar extends StatelessWidget {
  const _OddsBar({required this.market});
  final Market market;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Column(
      children: [
        Row(
          children: [
            Text('Yes ${TradeMath.formatPrice(market.yesPrice)}',
                style: TextStyle(
                    color: t.yes,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const Spacer(),
            Text('No ${TradeMath.formatPrice(market.noPrice)}',
                style: TextStyle(
                    color: t.no,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 5,
            child: Row(
              children: [
                Expanded(
                  flex: (market.yesPrice * 100).round(),
                  child: ColoredBox(color: t.yes),
                ),
                Expanded(
                  flex: (market.noPrice * 100).round(),
                  child: ColoredBox(color: t.no),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SideBtn extends StatelessWidget {
  const _SideBtn({
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
    return Semantics(
      button: true,
      label: 'Bet $label at $price',
      excludeSemantics: true,
      child: SizedBox(
        height: 54,
        child: Tactile(
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14, color: fg)),
                Text(price,
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: fg.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.color,
  });
  final PiconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Picon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.t});
  final String label;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Text(label,
          style: TextStyle(
              color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

String _getTopicImage(String category, String id) {
  final cat = category.toLowerCase();
  if (cat.contains('world cup') || cat.contains('fifa')) {
    return 'https://images.unsplash.com/photo-1551958219-acbc608c6377?w=600&auto=format&fit=crop&q=60';
  }
  if (cat.contains('politics') || cat.contains('election') || cat.contains('vote')) {
    return 'https://images.unsplash.com/photo-1540910419892-4a36d2c3266c?w=600&auto=format&fit=crop&q=60';
  }
  if (cat.contains('crypto') || cat.contains('bitcoin') || cat.contains('ethereum') || cat.contains('solana')) {
    return 'https://images.unsplash.com/photo-1621761191319-c6fb62004040?w=600&auto=format&fit=crop&q=60';
  }
  if (cat.contains('finance') || cat.contains('macro') || cat.contains('fed') || cat.contains('rate') || cat.contains('stock')) {
    return 'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?w=600&auto=format&fit=crop&q=60';
  }
  if (cat.contains('tech') || cat.contains('ai') || cat.contains('openai') || cat.contains('gpt')) {
    return 'https://images.unsplash.com/photo-1620712943543-bcc4688e7485?w=600&auto=format&fit=crop&q=60';
  }
  if (cat.contains('sports') || cat.contains('football') || cat.contains('basketball') || cat.contains('soccer')) {
    return 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=600&auto=format&fit=crop&q=60';
  }
  if (cat.contains('entertainment') || cat.contains('culture') || cat.contains('movie') || cat.contains('film') || cat.contains('show')) {
    return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=600&auto=format&fit=crop&q=60';
  }
  if (cat.contains('science') || cat.contains('climate') || cat.contains('weather')) {
    return 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&auto=format&fit=crop&q=60';
  }
  final idx = id.hashCode.abs() % 4;
  final fallbacks = [
    'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1639762681485-074b7f938ba0?w=600&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?w=600&auto=format&fit=crop&q=60',
  ];
  return fallbacks[idx];
}

String _proxied(String url) {
  if (!kIsWeb || url.isEmpty) return url;
  return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}&w=600&output=webp';
}


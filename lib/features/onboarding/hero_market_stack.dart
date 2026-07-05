import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart' show backendUrl;
import '../../core/theme/app_theme.dart';
import '../../core/motion.dart';

/// A floating, tilted stack of REAL live markets — the hero visual.
/// Pulls from the backend; falls back to a static sample so the layout
/// never renders empty.
class HeroMarketStack extends StatefulWidget {
  const HeroMarketStack({super.key, this.compact = false, this.onTapCard});
  final bool compact;
  final VoidCallback? onTapCard;

  @override
  State<HeroMarketStack> createState() => _HeroMarketStackState();
}

class _HeroMarket {
  const _HeroMarket(this.question, this.yesPrice, this.change, this.imageUrl);
  final String question;
  final double yesPrice;
  final double change;
  final String imageUrl;
}

const _fallbackMarkets = [
  _HeroMarket('Will Bitcoin hit \$100K this year?', 0.63, 0.04, ''),
  _HeroMarket('Fed cuts rates at the next meeting?', 0.41, -0.02, ''),
  _HeroMarket('Champions League: an English club wins?', 0.55, 0.01, ''),
];

class _HeroMarketStackState extends State<HeroMarketStack>
    with SingleTickerProviderStateMixin {
  List<_HeroMarket> _markets = _fallbackMarkets;
  bool _live = false;
  Offset _tilt = Offset.zero;
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 6));
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honor reduce-motion: hold the floating cards still.
    if (context.reduceMotion) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/markets?limit=24'),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final list = json.decode(res.body) as List<dynamic>;
      final all = <_HeroMarket>[];
      for (final raw in list) {
        final j = raw as Map<String, dynamic>;
        final q = j['question'] as String? ?? '';
        if (q.isEmpty || q.length > 80) continue;
        // Fresh on-chain pools sit at exactly 50/50 (no price discovery yet) —
        // fall back to Polymarket's real odds so the hero shows live prices.
        var yes = ((j['yesPrice'] as num?)?.toDouble() ?? 0.5);
        if ((yes - 0.5).abs() <= 0.001) {
          try {
            final prices = json.decode(j['outcomePrices'] as String? ?? '[]') as List;
            if (prices.isNotEmpty) {
              yes = double.tryParse(prices.first.toString()) ?? yes;
            }
          } catch (_) {/* keep on-chain price */}
        }
        yes = yes.clamp(0.01, 0.99);
        if (yes < 0.08 || yes > 0.92) continue; // contested markets look alive
        final change = (j['oneDayPriceChange'] as num?)?.toDouble() ?? 0.0;
        final img = j['icon'] as String? ?? j['image'] as String? ?? '';
        all.add(_HeroMarket(q, yes, change, img));
        if (all.length >= 3) break;
      }
      if (!mounted || all.length < 3) return;
      setState(() {
        _markets = all;
        _live = true;
      });
    } catch (_) {
      // Hero must never break because of the API.
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final w = compact ? 300.0 : 380.0;
    final h = compact ? 320.0 : 420.0;
    final totalW = w + 70;
    final reduce = context.reduceMotion;

    final Widget stack = SizedBox(
      width: totalW,
      height: h,
      child: AnimatedBuilder(
        animation: _float,
        builder: (context, _) {
          final t = _float.value * 2 * math.pi;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Back card
              Positioned(
                top: compact ? 36 : 56,
                left: 0,
                child: Transform.rotate(
                  angle: -0.075,
                  child: Transform.translate(
                    offset: Offset(0, 6 * math.sin(t + 2.1)),
                    child: _MarketCard(
                      market: _markets[1],
                      live: _live,
                      width: w * 0.86,
                      dimmed: true,
                      onTap: widget.onTapCard,
                    ),
                  ),
                ),
              ),
              // Middle card
              Positioned(
                top: compact ? 64 : 96,
                right: 0,
                child: Transform.rotate(
                  angle: 0.06,
                  child: Transform.translate(
                    offset: Offset(0, 7 * math.sin(t + 4.2)),
                    child: _MarketCard(
                      market: _markets[2],
                      live: _live,
                      width: w * 0.86,
                      dimmed: true,
                      onTap: widget.onTapCard,
                    ),
                  ),
                ),
              ),
              // Front card
              Positioned(
                top: 0,
                child: Transform.rotate(
                  angle: -0.018,
                  child: Transform.translate(
                    offset: Offset(0, 8 * math.sin(t)),
                    child: _MarketCard(
                      market: _markets[0],
                      live: _live,
                      width: w,
                      featured: true,
                      onTap: widget.onTapCard,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (reduce) return stack;

    // Subtle 3D tilt toward the cursor for a tactile, premium feel.
    return MouseRegion(
      onHover: (e) => setState(() => _tilt = Offset(
            (e.localPosition.dx / totalW - 0.5) * 2,
            (e.localPosition.dy / h - 0.5) * 2,
          )),
      onExit: (_) => setState(() => _tilt = Offset.zero),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(-_tilt.dy * 0.10)
          ..rotateY(_tilt.dx * 0.10),
        child: stack,
      ),
    );
  }
}

class _MarketCard extends StatefulWidget {
  const _MarketCard({
    required this.market,
    required this.live,
    required this.width,
    this.featured = false,
    this.dimmed = false,
    this.onTap,
  });
  final _HeroMarket market;
  final bool live;
  final double width;
  final bool featured;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  State<_MarketCard> createState() => _MarketCardState();
}

class _MarketCardState extends State<_MarketCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final m = widget.market;
    final yesPct = (m.yesPrice * 100).round();
    final up = m.change >= 0;
    final changePct = (m.change.abs() * 100).toStringAsFixed(1);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.025 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Opacity(
            opacity: widget.dimmed ? 0.82 : 1.0,
            child: Container(
              width: widget.width,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.featured
                      ? t.brand.withValues(alpha: 0.45)
                      : t.border,
                  width: widget.featured ? 1.2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.featured
                        ? t.brand.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: widget.featured ? 44 : 24,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (m.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            m.imageUrl,
                            width: 28,
                            height: 28,
                            cacheHeight: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _FallbackIcon(t: t),
                          ),
                        )
                      else
                        _FallbackIcon(t: t),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.live ? t.yesBg : t.brandSubtle,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: widget.live ? t.yes : t.brand,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              widget.live ? 'LIVE' : 'MARKET',
                              style: TextStyle(
                                color: widget.live ? t.yes : t.brand,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: up ? t.yesBg : t.noBg,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${up ? '▲' : '▼'} $changePct%',
                          style: TextStyle(
                            color: up ? t.yes : t.no,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    m.question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$yesPct¢',
                        style: TextStyle(
                          fontFamily: PulsColors.fontDisplay,
                          color: t.brand,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          'chance of YES',
                          style: TextStyle(
                            color: t.textSubtle,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // YES / NO odds bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: SizedBox(
                      height: 7,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (m.yesPrice * 100).round().clamp(1, 99),
                            child: Container(color: t.yes),
                          ),
                          Expanded(
                            flex: (100 - (m.yesPrice * 100).round())
                                .clamp(1, 99),
                            child: Container(color: t.no.withValues(alpha: 0.65)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('YES $yesPct¢',
                          style: TextStyle(
                              color: t.yes,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      Text('NO ${100 - yesPct}¢',
                          style: TextStyle(
                              color: t.no,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
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

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.t});
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: t.brandSubtle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.show_chart_rounded, size: 16, color: t.brand),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/motion.dart';

class WebTickerStrip extends StatefulWidget {
  const WebTickerStrip({super.key});

  @override
  State<WebTickerStrip> createState() => _WebTickerStripState();
}

class _WebTickerStripState extends State<WebTickerStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    );
    _ctrl.addListener(_scroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honor reduce-motion: keep the ticker strip still.
    if (context.reduceMotion) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  void _scroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (max <= 0) return;
    _scrollCtrl.jumpTo(_ctrl.value * max);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_scroll);
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final markets = appState.feedMarkets.take(20).toList();
    if (markets.isEmpty) return const SizedBox.shrink();

    // Duplicate for seamless loop
    final items = [...markets, ...markets];

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => VerticalDivider(
          width: 1, color: t.border, indent: 10, endIndent: 10),
        itemBuilder: (context, i) {
          final m = items[i];
          final isUp = m.trendIsPositive;
          final trendColor = isUp ? t.yes : t.no;
          final yesPrice = m.yesPrice;
          final trend = m.trend;
          final question = m.question;
          final shortQ = question.length > 22
              ? '${question.substring(0, 22)}…'
              : question;

          // Fixed item width is intentional: live price/percent updates change
          // the text length every couple of seconds. With content-sized items
          // that shifts the list's maxScrollExtent, and since the marquee maps
          // its position as `value * maxScrollExtent`, the scroll offset would
          // jump on every update — the visible stutter. A constant width keeps
          // the extent stable so the tape glides smoothly while prices refresh.
          return SizedBox(
            width: 220,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(shortQ,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                  const SizedBox(width: 8),
                  Text('YES ${(yesPrice * 100).toStringAsFixed(0)}¢',
                      style: const TextStyle(
                        color: PulsColors.brandMint,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(width: 6),
                  Text(
                    '${isUp ? '↑' : '↓'} ${(trend * 100).abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: trendColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';

/// A horizontal "live markets" marquee for the feed. Uses a time-based
/// Transform.translate over a fixed-width tape (not a ScrollController +
/// jumpTo over a lazy ListView, whose estimated maxScrollExtent wobbles and
/// makes the tape jitter). The offset is a pure function of elapsed time, so
/// the glide is perfectly smooth and the doubled tape wraps seamlessly.
class WebTickerStrip extends StatefulWidget {
  const WebTickerStrip({super.key});

  @override
  State<WebTickerStrip> createState() => _WebTickerStripState();
}

class _WebTickerStripState extends State<WebTickerStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Stable snapshot + tape, built once so the marquee width never changes
  // under the animation (the live feed re-sorts/refreshes constantly).
  List<dynamic>? _items;
  Widget? _tape;
  double _rowWidth = 0;

  static const double _itemW = 232;   // fixed chip width (px)
  static const double _pxPerSec = 42; // calm, constant scroll speed
  // Long fixed period; elapsed seconds = value * _periodSec, wrapped with
  // modulo, so the loop is seamless and independent of the period.
  static const int _periodSec = 100000;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _periodSec),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;

    if (_items == null && appState.feedMarkets.length >= 6) {
      _items = appState.feedMarkets.take(20).toList();
    }
    final markets = _items ?? const <dynamic>[];
    if (markets.isEmpty) return const SizedBox.shrink();

    // Build the tape ONCE (two copies for a seamless loop). Fixed-width chips
    // → exact, constant row width → no extent estimation, no jitter.
    if (_tape == null) {
      _rowWidth = markets.length * _itemW;
      final row = SizedBox(
        width: _rowWidth,
        child: Row(
          children: [for (final m in markets) _TickerChip(m: m, width: _itemW)],
        ),
      );
      _tape = OverflowBox(
        minWidth: 0,
        maxWidth: double.infinity,
        alignment: Alignment.centerLeft,
        child: Row(mainAxisSize: MainAxisSize.min, children: [row, row]),
      );
    }
    final rowWidth = _rowWidth;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          child: _tape,
          builder: (context, child) {
            final elapsed = _ctrl.value * _periodSec; // seconds
            final dx = rowWidth > 0 ? -((elapsed * _pxPerSec) % rowWidth) : 0.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
        ),
      ),
    );
  }
}

class _TickerChip extends StatelessWidget {
  const _TickerChip({required this.m, required this.width});
  final dynamic m;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isUp = m.trendIsPositive == true;
    final trendColor = isUp ? t.yes : t.no;
    final yesPrice = ((m.yesPrice as num?) ?? 0.5).toDouble();
    final trend = ((m.trend as num?) ?? 0.0).toDouble();
    final question = (m.question as String?) ?? '';
    final shortQ =
        question.length > 22 ? '${question.substring(0, 22)}…' : question;

    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: t.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              shortQ,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.text,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'YES ${(yesPrice * 100).toStringAsFixed(0)}¢',
            style: const TextStyle(
              color: PulsColors.brandMint,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
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
    );
  }
}

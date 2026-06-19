import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart' show backendUrl;
import '../../core/theme/app_theme.dart';

/// Infinite marquee of real markets with live YES prices, shown on the
/// landing page. Fails silently (renders nothing) if the API is unreachable.
class LiveMarketTicker extends StatefulWidget {
  const LiveMarketTicker({super.key});

  @override
  State<LiveMarketTicker> createState() => _LiveMarketTickerState();
}

class _TickerItem {
  const _TickerItem(this.question, this.yesPrice, this.change, this.imageUrl);
  final String question;
  final double yesPrice;
  final double change;
  final String imageUrl;
}

class _LiveMarketTickerState extends State<LiveMarketTicker>
    with TickerProviderStateMixin {
  List<_TickerItem> _items = const [];
  Widget? _tape;          // the [row,row] tape, built ONCE per data load
  double _total = 0;      // width of a single row (px)
  double _chipW = 330;
  late final AnimationController _marquee;
  late final AnimationController _pulse;

  // Constant scroll speed (px/sec). Time-based so it never depends on `total`.
  static const double _pxPerSec = 55;
  // Long fixed period; we read elapsed seconds = value * _periodSec and wrap
  // with modulo, so the loop is mathematically seamless (no boundary snap).
  static const int _periodSec = 100000;

  @override
  void initState() {
    super.initState();
    _marquee = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _periodSec),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(
            Uri.parse('$backendUrl/api/markets?limit=40'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final list = json.decode(res.body) as List<dynamic>;
      final all = <_TickerItem>[];
      for (final raw in list) {
        final j = raw as Map<String, dynamic>;
        final q = j['question'] as String? ?? '';
        if (q.isEmpty) continue;
        final yes = (j['yesPrice'] as num?)?.toDouble() ?? 0.5;
        final change = (j['oneDayPriceChange'] as num?)?.toDouble() ?? 0.0;
        final img = j['icon'] as String? ?? j['image'] as String? ?? '';
        all.add(_TickerItem(q, yes.clamp(0.01, 0.99), change, img));
      }
      // Prefer markets with contested prices — a tape full of 1¢ longshots
      // looks dead. Fall back to whatever we have.
      final lively =
          all.where((m) => m.yesPrice > 0.04 && m.yesPrice < 0.96).toList();
      final items =
          (lively.length >= 6 ? lively : all).take(12).toList();
      if (!mounted || items.length < 4) return;
      setState(() => _items = items); // _tape rebuilt lazily in build()
    } catch (_) {
      // Landing page must never break because of the ticker.
    }
  }

  @override
  void dispose() {
    _marquee.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final chipW = w < 600 ? 280.0 : 330.0;

    // Build the tape ONCE (and only when items or chip width actually change),
    // so the Image.network chips are never re-created on animation frames.
    if (_tape == null || chipW != _chipW) {
      _chipW = chipW;
      _total = _items.length * chipW;
      final row = SizedBox(
        width: _total,
        child: Row(
          children: [for (final m in _items) _TickerChip(item: m, width: chipW)],
        ),
      );
      _tape = Row(mainAxisSize: MainAxisSize.min, children: [row, row]);
    }
    final total = _total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          // ── "Live" label ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: t.yes,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: t.yes.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE FROM THE FLOOR',
                style: TextStyle(
                  color: t.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Marquee tape ──────────────────────────────────────────────
          MouseRegion(
            onEnter: (_) { if (_marquee.isAnimating) _marquee.stop(canceled: false); },
            onExit: (_) { if (_items.isNotEmpty && !_marquee.isAnimating) _marquee.repeat(); },
            child: SizedBox(
              height: 76,
              child: ClipRect(
                child: Stack(
                  children: [
                    // The moving tape on its own compositor layer (RepaintBoundary)
                    // so scrolling never repaints siblings. Transform is paint-only.
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _marquee,
                        child: _tape,
                        builder: (context, child) {
                          // Time-based, modulo'd offset → constant speed and a
                          // mathematically seamless loop, independent of `total`
                          // and immune to rebuilds (no back-and-forth snap).
                          final elapsed = _marquee.value * _periodSec; // seconds
                          final dx = total > 0 ? -((elapsed * _pxPerSec) % total) : 0.0;
                          return Transform.translate(
                            offset: Offset(dx, 0),
                            child: child,
                          );
                        },
                      ),
                    ),
                    // Static edge fades (cheap — no per-frame saveLayer like ShaderMask).
                    Positioned(left: 0, top: 0, bottom: 0, child: _EdgeFade(t: t, left: true)),
                    Positioned(right: 0, top: 0, bottom: 0, child: _EdgeFade(t: t, left: false)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickerChip extends StatelessWidget {
  const _TickerChip({required this.item, required this.width});
  final _TickerItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final up = item.change >= 0;
    final cents = (item.yesPrice * 100).round();
    final changePct = (item.change.abs() * 100).toStringAsFixed(0);

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _fallbackIcon(t),
                      )
                    : _fallbackIcon(t),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.question,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'YES $cents¢',
                          style: TextStyle(
                            color: t.brand,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          up
                              ? Icons.arrow_drop_up_rounded
                              : Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: up ? t.yes : t.no,
                        ),
                        Text(
                          '$changePct%',
                          style: TextStyle(
                            color: up ? t.yes : t.no,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon(PulsThemeColors t) => Container(
        width: 34,
        height: 34,
        color: t.brandSubtle,
        child: Icon(Icons.show_chart_rounded, size: 18, color: t.brand),
      );
}

/// Static gradient that fades the tape into the page background at each edge.
/// Cheap (a plain gradient Container) — no per-frame saveLayer like ShaderMask.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.t, required this.left});
  final PulsThemeColors t;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: [t.bg, t.bg.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}

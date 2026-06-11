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
  late final AnimationController _marquee;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _marquee = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 55),
    );
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
      setState(() => _items = items);
      _marquee.repeat();
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
    final isMobile = w < 600;
    final chipW = isMobile ? 280.0 : 330.0;
    final total = _items.length * chipW;

    final row = SizedBox(
      width: total,
      child: Row(
        children: [
          for (final m in _items) _TickerChip(item: m, width: chipW),
        ],
      ),
    );

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
            onEnter: (_) => _marquee.stop(),
            onExit: (_) {
              if (_items.isNotEmpty) _marquee.repeat();
            },
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, 0.08, 0.92, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: SizedBox(
                height: 76,
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _marquee,
                    builder: (context, _) {
                      final dx = -_marquee.value * total;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(left: dx, top: 0, child: row),
                          Positioned(left: dx + total, top: 0, child: row),
                        ],
                      );
                    },
                  ),
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

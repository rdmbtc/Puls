import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/market.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Swipe-to-Trade — Tinder-style discovery for prediction markets.
///
/// Custom gesture engine (no external swiper package):
///   → swipe RIGHT  = YES  (green overlay + stamp, fires [onSwipeYes])
///   → swipe LEFT   = NO   (red overlay + stamp, fires [onSwipeNo])
///   → swipe UP     = SKIP (fires [onSkip])
///
/// ```dart
/// SwipeDiscoveryScreen(
///   markets: markets,
///   onSwipeYes: (m) => openTradeSheet(m, MarketSide.yes),
///   onSwipeNo: (m) => openTradeSheet(m, MarketSide.no),
/// )
/// ```
/// ─────────────────────────────────────────────────────────────────────────────

class SwipeDiscoveryScreen extends StatefulWidget {
  const SwipeDiscoveryScreen({
    super.key,
    required this.markets,
    this.onSwipeYes,
    this.onSwipeNo,
    this.onSkip,
    this.onDeckEmpty,
  });

  final List<Market> markets;
  final void Function(Market market)? onSwipeYes;
  final void Function(Market market)? onSwipeNo;
  final void Function(Market market)? onSkip;
  final VoidCallback? onDeckEmpty;

  @override
  State<SwipeDiscoveryScreen> createState() => _SwipeDiscoveryScreenState();
}

enum _SwipeResult { yes, no, skip }

class _SwipeDiscoveryScreenState extends State<SwipeDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  /// Index of the top-of-deck card.
  int _index = 0;

  /// Live drag offset of the top card.
  Offset _drag = Offset.zero;
  bool _dragging = false;

  /// Fling-out / snap-back animation.
  late final AnimationController _anim;
  Animation<Offset>? _animOffset;
  _SwipeResult? _pendingResult;

  static const _swipeThreshold = 110.0;
  static const _skipThreshold = 130.0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
        if (_animOffset != null) {
          setState(() => _drag = _animOffset!.value);
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onFlingDone();
      });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  bool get _deckEmpty => _index >= widget.markets.length;
  Market get _topMarket => widget.markets[_index];

  /// Signed horizontal progress: -1 (full NO) .. +1 (full YES).
  double get _hProgress =>
      (_drag.dx / _swipeThreshold).clamp(-1.0, 1.0);

  /// Upward progress: 0 .. 1 (only counts when mostly-vertical drag).
  double get _upProgress {
    if (_drag.dy >= 0 || _drag.dx.abs() > _drag.dy.abs()) return 0;
    return (-_drag.dy / _skipThreshold).clamp(0.0, 1.0);
  }

  // ── Gestures ────────────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails _) {
    if (_anim.isAnimating) return;
    _dragging = true;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final v = d.velocity.pixelsPerSecond;

    // Decide the outcome from position + fling velocity.
    if (_upProgress >= 1 || (v.dy < -900 && _drag.dy < -40)) {
      _flingOut(_SwipeResult.skip);
    } else if (_hProgress >= 1 || (v.dx > 900 && _drag.dx > 40)) {
      _flingOut(_SwipeResult.yes);
    } else if (_hProgress <= -1 || (v.dx < -900 && _drag.dx < -40)) {
      _flingOut(_SwipeResult.no);
    } else {
      _snapBack();
    }
  }

  void _flingOut(_SwipeResult result) {
    final size = MediaQuery.sizeOf(context);
    final Offset target = switch (result) {
      _SwipeResult.yes => Offset(size.width * 1.3, _drag.dy * 1.5),
      _SwipeResult.no => Offset(-size.width * 1.3, _drag.dy * 1.5),
      _SwipeResult.skip => Offset(_drag.dx * 1.2, -size.height * 1.1),
    };
    _pendingResult = result;
    _animOffset = Tween(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInCubic),
    );
    _anim.forward(from: 0);
  }

  void _snapBack() {
    _pendingResult = null;
    _animOffset = Tween(begin: _drag, end: Offset.zero).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
    );
    _anim.forward(from: 0);
  }

  void _onFlingDone() {
    final result = _pendingResult;
    _pendingResult = null;
    _animOffset = null;
    if (result == null) {
      // Snap-back finished.
      setState(() => _drag = Offset.zero);
      return;
    }
    final market = _topMarket;
    setState(() {
      _drag = Offset.zero;
      _index++;
    });
    switch (result) {
      case _SwipeResult.yes:
        widget.onSwipeYes?.call(market);
      case _SwipeResult.no:
        widget.onSwipeNo?.call(market);
      case _SwipeResult.skip:
        widget.onSkip?.call(market);
    }
    if (_deckEmpty) widget.onDeckEmpty?.call();
  }

  /// Button-triggered swipes reuse the same fling pipeline.
  void _actionSwipe(_SwipeResult result) {
    if (_deckEmpty || _anim.isAnimating) return;
    // Seed a small offset so the rotation direction looks natural.
    _drag = switch (result) {
      _SwipeResult.yes => const Offset(40, -8),
      _SwipeResult.no => const Offset(-40, -8),
      _SwipeResult.skip => const Offset(0, -40),
    };
    _flingOut(result);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('Discover'),
        actions: [
          if (!_deckEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_index + 1} / ${widget.markets.length}',
                  style: TextStyle(
                    fontFamily: PulsColors.fontSans,
                    color: t.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: PulsColors.tabularFigures,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _deckEmpty ? _emptyState(t) : _deck(t),
      ),
    );
  }

  Widget _deck(PulsThemeColors t) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cards = <Widget>[];

                // Under-cards (up to 2), scaled/offset; the next card grows
                // toward full size as the top card is dragged away.
                final dragAmount = math.max(
                  _hProgress.abs(),
                  _upProgress,
                );
                for (var depth = 2; depth >= 1; depth--) {
                  final i = _index + depth;
                  if (i >= widget.markets.length) continue;
                  final settle = depth == 1 ? dragAmount : 0.0;
                  final scale = 1 - 0.05 * (depth - settle);
                  final dy = 14.0 * (depth - settle);
                  cards.add(
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(0, dy),
                        child: Transform.scale(
                          scale: scale,
                          child: IgnorePointer(
                            child: _MarketCard(
                              market: widget.markets[i],
                              hProgress: 0,
                              upProgress: 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // Top card with gesture handling.
                final angle = 0.10 *
                    _hProgress *
                    // Rotate around the grab side for a natural feel.
                    (_drag.dy > 0 ? 1 : 1);
                cards.add(
                  Positioned.fill(
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: Transform.translate(
                        offset: _drag,
                        child: Transform.rotate(
                          angle: angle,
                          child: _MarketCard(
                            market: _topMarket,
                            hProgress: _hProgress,
                            upProgress: _upProgress,
                          ),
                        ),
                      ),
                    ),
                  ),
                );

                return Stack(children: cards);
              },
            ),
          ),
        ),
        _actionBar(t),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _actionBar(PulsThemeColors t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionButton(
          t,
          icon: Icons.close_rounded,
          color: t.no,
          label: 'NO',
          onTap: () => _actionSwipe(_SwipeResult.no),
        ),
        const SizedBox(width: 20),
        _actionButton(
          t,
          icon: Icons.keyboard_arrow_up_rounded,
          color: t.textMuted,
          label: 'Skip',
          small: true,
          onTap: () => _actionSwipe(_SwipeResult.skip),
        ),
        const SizedBox(width: 20),
        _actionButton(
          t,
          icon: Icons.check_rounded,
          color: t.yes,
          label: 'YES',
          onTap: () => _actionSwipe(_SwipeResult.yes),
        ),
      ],
    );
  }

  Widget _actionButton(
    PulsThemeColors t, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool small = false,
  }) {
    final size = small ? 48.0 : 62.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: t.surface,
          shape: CircleBorder(
            side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: color, size: small ? 24 : 30),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: PulsColors.fontSans,
            color: t.textSubtle,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(PulsThemeColors t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.style_rounded, color: t.textSubtle, size: 48),
          const SizedBox(height: 16),
          Text(
            'You\u2019re all caught up',
            style: TextStyle(
              fontFamily: PulsColors.fontDisplay,
              color: t.text,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No more markets to review right now.\nCheck back soon for fresh predictions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: PulsColors.fontSans,
              color: t.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Card ─────────────────────────────────────────────────────────────────────

class _MarketCard extends StatelessWidget {
  const _MarketCard({
    required this.market,
    required this.hProgress, // -1 (NO) .. +1 (YES)
    required this.upProgress, // 0 .. 1 (skip)
  });

  final Market market;
  final double hProgress;
  final double upProgress;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final yesPct = (market.yesPrice * 100).clamp(0, 100).round();
    final yesOpacity = hProgress.clamp(0.0, 1.0);
    final noOpacity = (-hProgress).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (or category fallback).
          Image.network(
            market.imageUrl.isNotEmpty ? market.imageUrl : 'https://picsum.photos/seed/${market.id}/600/800',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackBg(t),
          ),

          // Bottom dark gradient for legibility.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.35, 0.72, 1.0],
                colors: [
                  Colors.transparent,
                  Color(0xB3000000),
                  Color(0xE6000000),
                ],
              ),
            ),
          ),

          // YES / NO decision washes.
          if (yesOpacity > 0)
            _decisionWash(t.yes, yesOpacity),
          if (noOpacity > 0)
            _decisionWash(t.no, noOpacity),
          if (upProgress > 0)
            _decisionWash(Colors.white, upProgress * 0.5),

          // Rubber stamps. YES lives on the LEFT (revealed by a right swipe),
          // NO on the RIGHT (revealed by a left swipe).
          Positioned(
            top: 40,
            left: 24,
            child: _Stamp(
              label: 'YES',
              color: t.yes,
              opacity: yesOpacity,
              angle: -0.26,
            ),
          ),
          Positioned(
            top: 40,
            right: 24,
            child: _Stamp(
              label: 'NO',
              color: t.no,
              opacity: noOpacity,
              angle: 0.26,
            ),
          ),
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _Stamp(
                label: 'SKIP',
                color: Colors.white,
                opacity: upProgress,
                angle: 0,
              ),
            ),
          ),

          // Content.
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category chip.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    market.displayCategory.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: PulsColors.fontSans,
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  market.question,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: PulsColors.fontDisplay,
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                // Probability bar.
                Row(
                  children: [
                    Text(
                      '$yesPct%',
                      style: TextStyle(
                        fontFamily: PulsColors.fontSans,
                        color: t.yes,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFeatures: PulsColors.tabularFigures,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'chance of YES',
                      style: TextStyle(
                        fontFamily: PulsColors.fontSans,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      children: [
                        Expanded(
                          flex: yesPct.clamp(1, 99),
                          child: ColoredBox(color: t.yes),
                        ),
                        Expanded(
                          flex: (100 - yesPct).clamp(1, 99),
                          child: ColoredBox(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _decisionWash(Color color, double opacity) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.28 * opacity),
            border: Border.all(
              color: color.withValues(alpha: 0.9 * opacity),
              width: 4,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }

  Widget _fallbackBg(PulsThemeColors t) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2236), Color(0xFF0A0E1A)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.query_stats_rounded,
          size: 72,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

/// Huge rubber-stamp label that fades/scales in during the swipe.
class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.color,
    required this.opacity,
    required this.angle,
  });

  final String label;
  final Color color;
  final double opacity;
  final double angle;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    // Slight overshoot scale for the satisfying "thunk".
    final scale = 0.8 + 0.3 * Curves.easeOutBack.transform(opacity);
    return Transform.rotate(
      angle: angle,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 4),
              color: color.withValues(alpha: 0.12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: PulsColors.fontSans,
                color: color,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

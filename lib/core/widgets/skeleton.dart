import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A shimmering placeholder block for loading states.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 8,
  });
  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final x = _ctrl.value * 2 - 1; // -1 .. 1
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: [
                t.border.withValues(alpha: 0.45),
                t.border.withValues(alpha: 0.9),
                t.border.withValues(alpha: 0.45),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton mimicking the swipe-card market layout while markets load.
class MarketCardSkeleton extends StatelessWidget {
  const MarketCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final size = MediaQuery.sizeOf(context);
    final cardW = size.width > 520 ? 440.0 : size.width - 40;

    return Center(
      child: Container(
        width: cardW,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.border),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Skeleton(width: 44, height: 44, radius: 12),
                SizedBox(width: 12),
                Expanded(child: Skeleton(height: 14)),
              ],
            ),
            SizedBox(height: 24),
            Skeleton(height: 22, width: 280),
            SizedBox(height: 10),
            Skeleton(height: 22, width: 200),
            SizedBox(height: 28),
            Skeleton(height: 120, radius: 16),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Skeleton(height: 52, radius: 16)),
                SizedBox(width: 12),
                Expanded(child: Skeleton(height: 52, radius: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton mirroring the [PredictionFeedCard] layout used in the main Feed.
/// Full-width; meant to be stacked in a ListView while markets load.
class FeedCardSkeleton extends StatelessWidget {
  const FeedCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      padding: const EdgeInsets.all(18),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tag pills + bookmark
          Row(
            children: [
              Skeleton(width: 64, height: 22, radius: 6),
              SizedBox(width: 8),
              Skeleton(width: 52, height: 22, radius: 6),
              Spacer(),
              Skeleton(width: 20, height: 20, radius: 6),
            ],
          ),
          SizedBox(height: 14),
          // Question (two lines)
          Skeleton(height: 18, radius: 6),
          SizedBox(height: 8),
          Skeleton(height: 18, width: 220, radius: 6),
          SizedBox(height: 14),
          // Topic image
          Skeleton(height: 130, radius: 12),
          SizedBox(height: 14),
          // Odds bar
          Skeleton(height: 10, radius: 6),
          SizedBox(height: 16),
          // YES / NO buttons
          Row(
            children: [
              Expanded(child: Skeleton(height: 52, radius: 14)),
              SizedBox(width: 10),
              Expanded(child: Skeleton(height: 52, radius: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact skeleton matching the Discover/Home market-card layout.
/// Expects a bounded height (grid cell or a SizedBox wrapper in lists).
class DiscoverCardSkeleton extends StatelessWidget {
  const DiscoverCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(width: 64, height: 18, radius: 6),
              Spacer(),
              Skeleton(width: 18, height: 18, radius: 9),
            ],
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 44, height: 44, radius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 12),
                    SizedBox(height: 8),
                    Skeleton(height: 12, width: 140),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Expanded(child: Skeleton(height: double.infinity, radius: 12)),
          SizedBox(height: 12),
          Row(
            children: [
              Skeleton(width: 84, height: 32, radius: 10),
              SizedBox(width: 8),
              Skeleton(width: 84, height: 32, radius: 10),
              Spacer(),
              Skeleton(width: 44, height: 20, radius: 6),
            ],
          ),
        ],
      ),
    );
  }
}

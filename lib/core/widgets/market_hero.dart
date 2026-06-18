import 'package:flutter/material.dart';

/// Shared [Hero] tag for a market's cover image, so the image smoothly
/// "morphs" from a list/feed card into the Market Detail screen.
///
/// A given market id should appear at most once per visible route, which is
/// true for the feed, discover grid and home rails. The detail screen uses the
/// same tag as its destination.
String marketHeroTag(String marketId) => 'market-img-$marketId';

/// Wraps [child] in a [Hero] using the canonical market-image tag.
///
/// [flightShuttleBuilder] keeps the rounded corners during the flight so the
/// image doesn't flash square mid-transition.
class MarketImageHero extends StatelessWidget {
  const MarketImageHero({
    required this.marketId,
    required this.child,
    this.radius = 12,
    super.key,
  });

  final String marketId;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: marketHeroTag(marketId),
      flightShuttleBuilder: (_, __, ___, ____, toHeroContext) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: (toHeroContext.widget as Hero).child,
      ),
      child: child,
    );
  }
}

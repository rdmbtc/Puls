import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/app_theme.dart';
import '../utils/agent_pfp.dart';

/// Normalizes avatar URLs so they can actually render in Flutter.
///
/// DiceBear URLs are generated as `/svg` by the backend, but Flutter's
/// `Image.network` cannot decode SVG — which silently broke every avatar in
/// the leaderboard and profiles. DiceBear serves the same art as PNG, so we
/// rewrite `/svg` → `/png` and pin a crisp raster size.
String normalizeAvatarUrl(String url, {int size = 128}) {
  if (url.contains('api.dicebear.com') && url.contains('/svg')) {
    final png = url.replaceFirst('/svg', '/png');
    return png.contains('?') ? '$png&size=$size' : '$png?size=$size';
  }
  return url;
}

/// Avatar that never shows a broken image: renders the (normalized) network
/// image when possible and falls back to a branded monogram otherwise.
class PulsAvatar extends StatelessWidget {
  const PulsAvatar({
    super.key,
    required this.url,
    required this.name,
    this.size = 40,
    this.radius,
  });

  final String? url;
  final String name;
  final double size;

  /// Corner radius. Defaults to a circle.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final r = radius ?? size / 2;

    Widget fallback = Container(
      width: size,
      height: size,
      color: t.brandSubtle,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : 'P',
        style: TextStyle(
          color: t.brand,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    Widget child;
    final pfp = agentPfpAsset(name);
    if (pfp != null) {
      // Named house/swarm agent → use its bundled PFP.
      child = Image.asset(
        pfp,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else if (url == null || url!.isEmpty) {
      child = fallback;
    } else {
      child = CachedNetworkImage(
        imageUrl: normalizeAvatarUrl(url!, size: (size * 2).round().clamp(64, 256)),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => fallback,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

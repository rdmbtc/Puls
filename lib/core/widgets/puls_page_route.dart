import 'package:flutter/material.dart';

import '../motion.dart';

/// Branded shared page transition for in-app navigation.
///
/// Pushed screens fade in while sliding up a few pixels — a calm, tactile
/// motion that matches Puls's feel and reads better than the platform-default
/// [MaterialPageRoute] (which is a horizontal slide on iOS and an opaque
/// vertical slam on Android). Use it as a drop-in replacement:
///
/// ```dart
/// Navigator.of(context).push(
///   pulsRoute(context, builder: (_) => const SomeScreen()),
/// );
/// ```
///
/// Reduce-motion is honored two ways: when a [context] is supplied at push
/// time the route's transition duration collapses to [Duration.zero], and the
/// transition builder also re-checks `MediaQuery.disableAnimations` so the
/// fade/slide is skipped even if no context was available or the setting
/// changed mid-route.
Route<T> pulsRoute<T>(
  BuildContext? context, {
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
  RouteSettings? settings,
}) {
  final reduceAtPush = context?.reduceMotion ?? false;
  const enter = Duration(milliseconds: 320);
  const exit = Duration(milliseconds: 240);
  return PageRouteBuilder<T>(
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: reduceAtPush ? Duration.zero : enter,
    reverseTransitionDuration: reduceAtPush ? Duration.zero : exit,
    pageBuilder: (ctx, animation, secondaryAnimation) => builder(ctx),
    transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
      // Re-check at build time so reduce-motion is respected even when no
      // context was passed in or the platform setting flipped after push.
      final reduce = reduceAtPush || ctx.reduceMotion;
      if (reduce) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

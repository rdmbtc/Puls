import 'package:flutter/widgets.dart';

/// Accessibility helper for honoring the platform "reduce motion" setting.
///
/// iOS *Reduce Motion*, Android *Remove animations*, macOS/Windows reduce-motion
/// and several browsers surface this through `MediaQueryData.disableAnimations`.
/// Decorative loops (shimmer, pulsing halos, confetti) and value tweens should
/// collapse to their end state when this is on — never trap motion-sensitive
/// users in perpetual animation.
extension PulsMotion on BuildContext {
  /// True when the user asked the platform to minimize non-essential motion.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// [normal] unless reduce-motion is on, in which case [Duration.zero] so
  /// implicit animations resolve instantly.
  Duration motionDuration(Duration normal) =>
      reduceMotion ? Duration.zero : normal;
}

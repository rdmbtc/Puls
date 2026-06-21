import 'package:flutter/widgets.dart';

import '../app/puls_app_state.dart';

/// Accessibility helper for honoring the platform "reduce motion" setting.
///
/// iOS *Reduce Motion*, Android *Remove animations*, macOS/Windows reduce-motion
/// and several browsers surface this through `MediaQueryData.disableAnimations`.
/// Decorative loops (shimmer, pulsing halos, confetti) and value tweens should
/// collapse to their end state when this is on — never trap motion-sensitive
/// users in perpetual animation.
extension PulsMotion on BuildContext {
  /// True when motion should be minimized. An in-app override (Settings →
  /// Reduce motion) takes precedence; otherwise we follow the platform
  /// "reduce motion" setting (iOS / Android / desktop / browser).
  bool get reduceMotion =>
      PulsStateScope.maybeOf(this)?.reduceMotionOverride ??
      (MediaQuery.maybeDisableAnimationsOf(this) ?? false);

  /// [normal] unless reduce-motion is on, in which case [Duration.zero] so
  /// implicit animations resolve instantly.
  Duration motionDuration(Duration normal) =>
      reduceMotion ? Duration.zero : normal;
}

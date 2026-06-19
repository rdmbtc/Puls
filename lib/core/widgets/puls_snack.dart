import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Visual intent of a [PulsSnack] message.
enum PulsSnackType { info, success, error }

/// Unified, brand-styled snackbar for the whole app.
///
/// Replaces the dozens of ad-hoc `ScaffoldMessenger.showSnackBar(SnackBar(...))`
/// calls with a single consistent surface: a rounded, floating pill that carries
/// an intent icon, respects the Puls theme tokens (`context.puls`) in both light
/// and dark mode, sizes to a readable centred width on desktop, and auto-dismisses.
///
/// Two ways to use it.
///
/// 1. Synchronous (you still hold a live `context`):
/// ```dart
/// PulsSnack.show(context, 'Saved');                 // neutral / info
/// PulsSnack.success(context, 'Published 🎉');        // teal
/// PulsSnack.error(context, 'Could not publish');     // red
/// ```
///
/// 2. Across an `await` (capture before the gap, fire after — no
///    `use_build_context_synchronously` problems):
/// ```dart
/// final snack = PulsSnack.of(context);
/// final res = await api.publish();
/// res.ok ? snack.success('Published') : snack.error('Failed');
/// ```
class PulsSnack {
  PulsSnack._();

  /// Capture a messenger + theme handle to use safely after an `await`.
  static PulsSnacker of(BuildContext context) => PulsSnacker._(
        ScaffoldMessenger.of(context),
        context.puls,
        context.isDark,
        MediaQuery.of(context).size.width,
      );

  static void show(
    BuildContext context,
    String message, {
    PulsSnackType type = PulsSnackType.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      of(context).show(message,
          type: type,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction);

  static void success(BuildContext context, String message,
          {Duration? duration, String? actionLabel, VoidCallback? onAction}) =>
      of(context).success(message,
          duration: duration, actionLabel: actionLabel, onAction: onAction);

  static void error(BuildContext context, String message,
          {Duration? duration, String? actionLabel, VoidCallback? onAction}) =>
      of(context).error(message,
          duration: duration, actionLabel: actionLabel, onAction: onAction);
}

/// Handle returned by [PulsSnack.of] — safe to keep across async gaps.
class PulsSnacker {
  PulsSnacker._(this._messenger, this._t, this._isDark, this._screenWidth);

  final ScaffoldMessengerState _messenger;
  final PulsThemeColors _t;
  final bool _isDark;
  final double _screenWidth;

  void success(String message,
          {Duration? duration, String? actionLabel, VoidCallback? onAction}) =>
      show(message,
          type: PulsSnackType.success,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction);

  void error(String message,
          {Duration? duration, String? actionLabel, VoidCallback? onAction}) =>
      show(message,
          type: PulsSnackType.error,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction);

  void show(
    String message, {
    PulsSnackType type = PulsSnackType.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final accent = switch (type) {
      PulsSnackType.success => _t.yes,
      PulsSnackType.error => _t.no,
      PulsSnackType.info => _t.brand,
    };
    final icon = switch (type) {
      PulsSnackType.success => Icons.check_circle_rounded,
      PulsSnackType.error => Icons.error_rounded,
      PulsSnackType.info => Icons.bolt_rounded,
    };

    // Read time scales gently with length; capped so it never lingers.
    final showFor = duration ??
        (onAction != null
            ? const Duration(seconds: 5)
            : Duration(
                milliseconds: (2200 + message.length * 28).clamp(2200, 5000)));

    final surface = _isDark ? _t.surfaceRaised : Colors.white;
    // Centred, readable width: full-bleed (minus margin) on phones, a tidy pill
    // on desktop.
    final width = (_screenWidth - 32).clamp(0.0, 460.0);

    _messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: surface,
          elevation: 0,
          duration: showFor,
          width: width,
          padding: EdgeInsets.fromLTRB(14, 12, actionLabel != null ? 8 : 16, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: _t.border),
          ),
          content: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: _t.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () {
                    _messenger.hideCurrentSnackBar();
                    onAction?.call();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      );
  }
}

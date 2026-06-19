import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Unified bottom-sheet system for Puls.
///
/// Before this, ~18 `showModalBottomSheet` call-sites each re-implemented the
/// same scaffolding by hand — transparent background, keyboard-inset padding,
/// a rounded-top container (with corner radii drifting between 20 / 22 / 24),
/// a grab handle (40×4 here, 36×4 there, 4.5 tall elsewhere) and ad-hoc
/// padding. The result looked subtly different on every surface.
///
/// Use [PulsSheet.show] to present a sheet with consistent barrier dim,
/// safe-area + keyboard handling, and wrap the body in [PulsSheetSurface] for
/// the canonical rounded surface, grab handle, padding and web max-width
/// centring (so sheets don't stretch edge-to-edge on desktop).
class PulsSheet {
  PulsSheet._();

  /// Present [builder] as a modal bottom sheet with Puls' standard config.
  ///
  /// Keyboard insets are handled automatically, so text-entry sheets float
  /// above the keyboard without each caller wiring up `viewInsets`.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useSafeArea = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Padding(
        // Lift the sheet above the on-screen keyboard.
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: builder(ctx),
      ),
    );
  }
}

/// The canonical 40×4 grab handle shown at the top of every Puls sheet.
class PulsDragHandle extends StatelessWidget {
  const PulsDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: t.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// Canonical rounded-top sheet surface: brand background, grab handle,
/// consistent padding, an optional max-height clamp, optional internal scroll,
/// and web max-width centring.
///
/// Wrap your sheet's body in this instead of hand-rolling a `Container` with a
/// `BorderRadius.vertical(top: …)` decoration and a manual handle.
class PulsSheetSurface extends StatelessWidget {
  const PulsSheetSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    this.raised = false,
    this.scrollable = false,
    this.showHandle = true,
    this.maxHeightFactor = 0.92,
    this.maxWidth = 560,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Use the slightly elevated surface tone (matches sheets that previously
  /// used `surfaceRaised`, e.g. the AI copilot / receipt / tx-status sheets).
  final bool raised;

  /// Wrap [child] in a scroll view — for tall or keyboard-driven sheets.
  final bool scrollable;

  /// Show the grab handle. Off for sheets that embed their own header chrome.
  final bool showHandle;

  /// Fraction of screen height the sheet may grow to before scrolling.
  final double maxHeightFactor;

  /// Max width on wide (web/desktop) layouts so sheets stay readable.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final maxH = MediaQuery.sizeOf(context).height * maxHeightFactor;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHandle) ...[
          const PulsDragHandle(),
          const SizedBox(height: 14),
        ],
        Flexible(
          child: scrollable ? SingleChildScrollView(child: child) : child,
        ),
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxH),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: raised ? t.surfaceRaised : t.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

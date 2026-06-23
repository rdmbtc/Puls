import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme/app_theme.dart';
import 'pulse_button.dart';

/// A consistent, on-brand empty state: rounded card, icon chip, title, an
/// optional explanatory line, and an optional primary CTA. Use anywhere a
/// list/section has nothing to show yet (empty watchlist, no search results,
/// no positions). Replaces the ad-hoc one-off empty layouts scattered around
/// the app so they all look and animate the same way.
class PulsEmptyState extends StatelessWidget {
  const PulsEmptyState({
    super.key,
    required this.title,
    this.icon = Icons.inbox_rounded,
    this.iconWidget,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.compact = false,
  });

  /// Headline (e.g. "No saved markets").
  final String title;

  /// Leading glyph shown in the brand-tinted chip. Ignored if [iconWidget] set.
  final IconData icon;

  /// Custom leading visual (e.g. an illustration) overriding [icon].
  final Widget? iconWidget;

  /// Optional supporting sentence under the title.
  final String? message;

  /// Optional primary action. Both [actionLabel] and [onAction] required to show.
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  /// Tighter padding for inline/section use vs. full-screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final hasAction = actionLabel != null && onAction != null;

    final card = Container(
      padding: EdgeInsets.all(compact ? 24 : 32),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconWidget != null)
            iconWidget!
          else
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.brandSubtle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: t.brand, size: 30),
            ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: t.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
          if (hasAction) ...[
            const SizedBox(height: 20),
            PulseButton(
              label: actionLabel!,
              onPressed: onAction,
              icon: actionIcon,
              expand: false,
            ),
          ],
        ],
      ),
    );

    // Gentle entrance, skipped entirely under reduce-motion.
    if (context.reduceMotion) return card;
    return _FadeSlideIn(child: card);
  }
}

/// A consistent error/retry state. Mirrors [PulsEmptyState] but signals a
/// failure (warning glyph in the error color) and surfaces a Retry action.
class PulsErrorState extends StatelessWidget {
  const PulsErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'We couldn\'t load this right now.',
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.cloud_off_rounded,
    this.compact = false,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    final card = Container(
      padding: EdgeInsets.all(compact ? 24 : 32),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.no.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: t.no, size: 30),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: t.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: retryLabel,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.text,
                  side: BorderSide(color: t.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (context.reduceMotion) return card;
    return _FadeSlideIn(child: card);
  }
}

/// Small reusable fade + slight rise entrance used by the state cards.
/// Self-contained so it never animates when reduce-motion is on (callers
/// branch before constructing it).
class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.child});
  final Widget child;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tactile.dart';

/// The primary call-to-action button for Puls.
///
/// Wears the signature `PulsColors.pulseGradient` (mint → pink, straight from
/// the logo) when enabled, falls back to a muted surface when disabled, and
/// shows an inline spinner while [loading]. Use this for the most important
/// action on a surface — unlock, tip, copy-trade, onboarding "Enter Puls".
class PulseButton extends StatelessWidget {
  const PulseButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
    super.key,
  });

  final String label;

  /// Tapped when enabled. `null` renders the disabled (muted) state.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// When true, swallows taps and shows a spinner in place of the label.
  final bool loading;

  /// Stretch to the full available width (default) or hug content.
  final bool expand;

  final double height;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    final content = Container(
      height: height,
      width: expand ? double.infinity : null,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: expand ? 20 : 28),
      decoration: BoxDecoration(
        gradient: _enabled ? PulsColors.pulseGradient : null,
        color: _enabled ? null : t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _enabled
            ? [
                BoxShadow(
                  color: PulsColors.brandPink.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: _enabled ? Colors.white : t.textSubtle,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _enabled ? Colors.white : t.textSubtle,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
    );

    if (!_enabled) {
      return Opacity(opacity: loading ? 0.85 : 0.55, child: content);
    }

    return Tactile(
      onTap: onPressed!,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

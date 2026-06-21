import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/pulse_dot.dart';

export '../../core/widgets/gradient_text.dart' show AnimatedGradientText;

/// Shared building blocks for the marketing landing sections so every band
/// speaks one visual language: a brand "eyebrow" pill, a serif gradient
/// headline, and the signature flowing mint→pink gradient text.
///
/// Everything here is presentational and reduce-motion aware.

// ── Eyebrow pill ────────────────────────────────────────────────────────────
class LandingEyebrow extends StatelessWidget {
  const LandingEyebrow({
    super.key,
    required this.label,
    this.icon = Icons.auto_awesome_rounded,
    this.live = false,
  });

  final String label;
  final IconData icon;

  /// When true, shows a pulsing "live" dot instead of the icon.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: t.brandSubtle,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: t.brand.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live)
            const PulseDot(size: 6, color: Color(0xFF22C55E), period: Duration(milliseconds: 1400))
          else
            ShaderMask(
              shaderCallback: (r) => PulsColors.pulseGradient.createShader(r),
              child: Icon(icon, size: 14, color: Colors.white),
            ),
          SizedBox(width: live ? 4 : 8),
          Text(
            label,
            style: TextStyle(
              color: t.brand,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gradient serif headline ─────────────────────────────────────────────────
class LandingHeadline extends StatelessWidget {
  const LandingHeadline({
    super.key,
    required this.lead,
    required this.accent,
    required this.isMobile,
    this.animateAccent = true,
  });

  final String lead;
  final String accent;
  final bool isMobile;
  final bool animateAccent;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final size = isMobile ? 28.0 : 44.0;
    final accentStyle = TextStyle(
      fontFamily: PulsColors.fontDisplay,
      color: Colors.white,
      fontSize: size,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
      height: 1.12,
      letterSpacing: -1.3,
    );
    return Column(
      children: [
        Text(
          lead,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: PulsColors.fontDisplay,
            color: t.text,
            fontSize: size,
            fontWeight: FontWeight.w600,
            height: 1.06,
            letterSpacing: -1.3,
          ),
        ),
        AnimatedGradientText(accent, style: accentStyle, animate: animateAccent),
      ],
    );
  }
}

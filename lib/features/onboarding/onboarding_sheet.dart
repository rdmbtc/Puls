import 'package:flutter/material.dart';
import 'package:picons/picons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/puls_sheet.dart';
import '../shell/shell_nav.dart';
import '../portfolio/funds_sheet.dart';
import 'onboarding_content.dart';
import 'onboarding_flags.dart';

/// Shows the one-time welcome sheet after the first frame, if this device has
/// never seen it. Safe to call from any shell's `initState`.
void maybeShowWelcome(State state) {
  if (OnboardingFlags.welcomeSeen) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted) return;
    OnboardingSheet.show(state.context, PulsTab.feed, isWelcome: true);
  });
}

/// A light, non-blocking onboarding bottom sheet. Shows a few scannable tip
/// cards for one tab. Opened from the "?" help button, or auto-shown once on a
/// device's very first launch (welcome).
class OnboardingSheet extends StatelessWidget {
  const OnboardingSheet({
    required this.tab,
    this.isWelcome = false,
    super.key,
  });

  final PulsTab tab;
  final bool isWelcome;

  /// Opens the sheet for [tab] and records that the tab's tips were seen
  /// (clears the "new" pulse dot on the help button).
  static Future<void> show(
    BuildContext context,
    PulsTab tab, {
    bool isWelcome = false,
  }) {
    if (isWelcome) {
      OnboardingFlags.markWelcomeSeen();
    }
    OnboardingFlags.markTabSeen(tab);
    return PulsSheet.show<void>(
      context,
      builder: (_) => OnboardingSheet(tab: tab, isWelcome: isWelcome),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final content = OnboardingContent.forTab(tab);
    final maxH = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH, maxWidth: 560),
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: t.brand.withValues(alpha: 0.10),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(t: t, content: content, isWelcome: isWelcome),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                itemCount: content.tips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _TipCard(t: t, tip: content.tips[i]),
              ),
            ),
            _Footer(t: t, isWelcome: isWelcome),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.t, required this.content, required this.isWelcome});

  final PulsThemeColors t;
  final OnboardingContent content;
  final bool isWelcome;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.brand.withValues(alpha: 0.16),
            t.brand.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PulsDragHandle(),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.brand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Picon(content.icon, size: 22, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isWelcome)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          'WELCOME TO PULS',
                          style: TextStyle(
                            color: t.brand,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    AnimatedGradientText(
                      content.title,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      content.subtitle,
                      style: TextStyle(
                        color: t.textMuted,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _CloseBtn(t: t),
            ],
          ),
        ],
      ),
    );
  }
}

class _CloseBtn extends StatelessWidget {
  const _CloseBtn({required this.t});
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: t.surface.withValues(alpha: 0.7),
          shape: BoxShape.circle,
          border: Border.all(color: t.border),
        ),
        child: Icon(Icons.close_rounded, size: 16, color: t.textMuted),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.t, required this.tip});

  final PulsThemeColors t;
  final OnboardingTip tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surfaceRaised.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Picon(tip.icon, size: 18, color: t.brand),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: TextStyle(
                    color: t.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tip.body,
                  style: TextStyle(
                    color: t.textMuted,
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.t, required this.isWelcome});

  final PulsThemeColors t;
  final bool isWelcome;

  @override
  Widget build(BuildContext context) {
    if (isWelcome) {
      // New-user activation: lead straight to funding so an empty wallet isn't a dead end.
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text('Explore first',
                    style: TextStyle(color: t.textMuted, fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                Navigator.of(context).maybePop();
                FundsSheet.show(context);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.south_west_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 7),
                  Text('Fund my wallet',
                      style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                ]),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tap the ? on any tab to see tips again.',
              style: TextStyle(
                color: t.textSubtle,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: t.brand,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isWelcome ? 'Start trading' : 'Got it',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

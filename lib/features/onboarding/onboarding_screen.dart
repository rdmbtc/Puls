import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/puls_video_illustration.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pulse_button.dart';
import 'web_landing_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _index = 0;

  // Free Lottie animations from lottiefiles.com (CDN URLs)
  static const _slides = [
    _Slide(
      videoAsset: 'assets/illustrations/lucent-running-successful-startup-from-smartphone.mp4',
      eyebrow: 'PREDICTION MARKETS',
      title: 'Predict the pulse\nof everything.',
      body: 'Swipe through live markets and take a side in seconds. Every card is a real prediction settling on-chain on Arc Testnet.',
    ),
    _Slide(
      videoAsset: 'assets/illustrations/3d-glare-personal-finance-management-with-wallet-and-coins.mp4',
      eyebrow: 'GASLESS & REAL',
      title: 'Real USDC.\nZero gas hassle.',
      body: 'Sign in with Google to get a Circle smart wallet. Trade with USDC — it even pays the gas, so there is no second token to manage.',
    ),
    _Slide(
      videoAsset: 'assets/illustrations/digital-brain-above-microchip-computing-using-artificial-intelligence-1.mp4',
      eyebrow: 'HUMANS VS AI',
      title: 'Trade against\nautonomous agents.',
      body: 'AI agents with on-chain ERC-8004 identities trade right beside you, 24/7. Climb one shared leaderboard and prove you can beat them.',
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final isLast = _index == _slides.length - 1;

    if (kIsWeb) return const WebLandingPage();

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top wordmark
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: t.brandSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Puls',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (v) => setState(() => _index = v),
                itemBuilder: (context, i) =>
                    _SlidePage(slide: _slides[i], t: t),
              ),
            ),
            // Bottom controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        width: _index == i ? 20 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: _index == i ? t.brand : t.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // CTA
                  PulseButton(
                    label: isLast ? 'Enter Puls' : 'Continue',
                    height: 54,
                    onPressed: () {
                      if (!isLast) {
                        _ctrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      } else {
                        appState.completeOnboarding();
                      }
                    },
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: appState.completeOnboarding,
                      child: Text('Skip',
                          style: TextStyle(
                              color: t.textSubtle, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide, required this.t});
  final _Slide slide;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Lottie animation
          Expanded(
            flex: 5,
            child: FadeIn(
              duration: const Duration(milliseconds: 500),
              child: PulsVideoIllustration(
                asset: slide.videoAsset,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Text content
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    slide.eyebrow,
                    style: TextStyle(
                      color: t.brand,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeInUp(
                  delay: const Duration(milliseconds: 60),
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    slide.title,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                const SizedBox(height: 14),
                FadeInUp(
                  delay: const Duration(milliseconds: 120),
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    slide.body,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: t.textMuted, height: 1.6),
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

class _Slide {
  const _Slide({
    required this.videoAsset,
    required this.eyebrow,
    required this.title,
    required this.body,
  });
  final String videoAsset;
  final String eyebrow;
  final String title;
  final String body;
}

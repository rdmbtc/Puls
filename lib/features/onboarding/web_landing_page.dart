import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/widgets/puls_snack.dart';
import 'package:flutter_web_scroll/flutter_web_scroll.dart';

import 'hero_market_stack.dart';
import 'live_activity.dart';
import 'live_ticker.dart';
import 'meet_the_agents.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app_state.dart';
import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/motion.dart';
import '../../core/config.dart';

class WebLandingPage extends StatefulWidget {
  const WebLandingPage({super.key});

  @override
  State<WebLandingPage> createState() => _WebLandingPageState();
}

class _WebLandingPageState extends State<WebLandingPage>
    with SingleTickerProviderStateMixin {
  final _scrollCtrl = ScrollController();
  double _scrollOffset = 0;
  late final AnimationController _aurora;

  @override
  void initState() {
    super.initState();
    // The aurora loops continuously; its start/stop is gated on reduce-motion
    // in build() so motion-sensitive users get a single still frame.
    _aurora = AnimationController(vsync: this, duration: const Duration(seconds: 18));
    _scrollCtrl.addListener(() {
      if (mounted) setState(() => _scrollOffset = _scrollCtrl.offset);
    });
  }

  @override
  void dispose() {
    _aurora.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;

    // Honor the OS "reduce motion" setting: hold the aurora on a single static
    // frame instead of looping forever. Every other animated surface in the app
    // already respects this (shimmer, skeletons, pulse dots, page routes) — the
    // landing page was the one gap.
    if (context.reduceMotion) {
      if (_aurora.isAnimating) _aurora.stop();
    } else if (!_aurora.isAnimating) {
      _aurora.repeat();
    }

    final dotColor = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : const Color(0xFFEC4899).withValues(alpha: 0.03);

    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          // ── Animated Aurora Background ──────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _aurora,
              builder: (context, _) => CustomPaint(
                painter: _AuroraPainter(
                  progress: _aurora.value,
                  isDark: isDark,
                  bg: t.bg,
                ),
              ),
            ),
          ),
          // ── Dot Grid ────────────────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter(color: dotColor)),
          ),
          // ── Content ─────────────────────────────────────────────────────
          SmoothScrollWeb(
            controller: _scrollCtrl,
            config: SmoothScrollConfig.lenis(
              scrollSpeed: 1.1,
              damping: 0.09,
            ),
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              child: Column(
                children: [
                  _HeroSection(scrollOffset: _scrollOffset),
                  _Reveal(scrollOffset: _scrollOffset, child: const LiveMarketTicker()),
                  _Reveal(scrollOffset: _scrollOffset, child: const _FeaturesSection()),
                  _Reveal(scrollOffset: _scrollOffset, child: const _HowItWorksSection()),
                  _Reveal(scrollOffset: _scrollOffset, child: const LiveActivitySection()),
                  _Reveal(scrollOffset: _scrollOffset, child: const MeetTheAgentsSection()),
                  _Reveal(scrollOffset: _scrollOffset, child: const _StatsSection()),
                  _Reveal(scrollOffset: _scrollOffset, child: const _FinalCtaSection()),
                  const _FooterSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Same-origin URL for the flagship static pages (/pulse, /agent, /versus, /stats),
// resolved against the current origin so the links work in prod, on Vercel
// previews and locally.
String _pageUrl(String path) => Uri.base.resolve(path).toString();

// ── Navbar ────────────────────────────────────────────────────────────────────
class _Navbar extends StatelessWidget {
  const _Navbar();

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final isDark = context.isDark;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 800;
    final isWide = w >= 1024;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 48, vertical: isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: t.bg.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: t.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: t.brandSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/logo.png', fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Text(
            'Puls',
            style: TextStyle(
              fontFamily: PulsColors.fontDisplay,
              color: t.text,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (!isMobile) ...[
            // Flagship agentic showcase — front and centre for judges.
            _NavLink('Pulse', _pageUrl('/pulse')),
            const SizedBox(width: 8),
            _NavLink('Agent', _pageUrl('/agent')),
            const SizedBox(width: 8),
            _NavLink('Versus', _pageUrl('/versus')),
            const SizedBox(width: 8),
            const _NavLink('Docs', 'https://docs.pulsmarket.tech'),
            // Utility links only when there's room — keeps mid-width tidy.
            if (isWide) ...[
              const SizedBox(width: 8),
              const _NavLink('GitHub', 'https://github.com/rdmbtc/Puls'),
              const SizedBox(width: 8),
              const _NavLink('Android', kAndroidApkUrl),
              const SizedBox(width: 8),
              const _NavLink('Explorer', 'https://testnet.arcscan.app/address/$factoryAddress'),
            ],
            const SizedBox(width: 16),
          ] else
            const _MobileNavMenu(),
          // Theme Toggle button
          IconButton(
            onPressed: appState.toggleThemeMode,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
              color: t.textMuted,
            ),
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          ),
          SizedBox(width: isMobile ? 8 : 16),
          _PrimaryButton(
            label: isMobile ? 'Launch' : 'Launch App',
            onTap: appState.completeOnboarding,
            small: true,
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  const _NavLink(this.label, this.url);
  final String label;
  final String url;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? t.brand : t.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// Compact dropdown for mobile, where inline nav links don't fit. Surfaces the
// flagship pages + key links so judges on a phone can still discover them.
class _MobileNavMenu extends StatelessWidget {
  const _MobileNavMenu();

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      icon: Icon(Icons.menu_rounded, size: 22, color: t.textMuted),
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.border),
      ),
      onSelected: (url) =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      itemBuilder: (context) => [
        _item(t, 'Live agent', _pageUrl('/pulse')),
        _item(t, 'Decision trace', _pageUrl('/agent')),
        _item(t, 'Humans vs AI', _pageUrl('/versus')),
        _item(t, 'Live stats', _pageUrl('/stats')),
        _item(t, 'Docs', 'https://docs.pulsmarket.tech'),
        _item(t, 'GitHub', 'https://github.com/rdmbtc/Puls'),
        _item(t, 'Android app', kAndroidApkUrl),
      ],
    );
  }

  PopupMenuItem<String> _item(PulsThemeColors t, String label, String url) =>
      PopupMenuItem<String>(
        value: url,
        height: 42,
        child: Text(
          label,
          style: TextStyle(
              color: t.text, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );
}

// ── Hero Section ──────────────────────────────────────────────────────────────
const String kAndroidApkUrl = 'https://github.com/rdmbtc/Puls/releases/latest';

class _HeroSection extends StatefulWidget {
  const _HeroSection({required this.scrollOffset});
  final double scrollOffset;

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  int _phraseIndex = 0;
  static const _phrases = [
    'what happens next.',
    'the next Fed cut.',
    'tomorrow\'s headlines.',
    'every big question.',
  ];

  @override
  void initState() {
    super.initState();
    _cyclePhrases();
  }

  void _cyclePhrases() {
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      // Reduce-motion: stop cycling and keep a single stable headline.
      if (context.reduceMotion) return;
      setState(() => _phraseIndex = (_phraseIndex + 1) % _phrases.length);
      _cyclePhrases();
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 1000;
    // Reduce-motion: drop the scroll parallax (keep the gentle fade so the hero
    // still clears the content scrolling up beneath it).
    final parallaxY = context.reduceMotion
        ? 0.0
        : -(widget.scrollOffset * 0.18).clamp(0.0, h * 0.25);
    final heroOpacity = (1 - widget.scrollOffset / (h * 0.55)).clamp(0.0, 1.0);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: h),
      child: Stack(
        children: [
          // Navbar
          const Positioned(top: 0, left: 0, right: 0, child: _Navbar()),
          // Hero content with parallax
          Padding(
            padding: EdgeInsets.only(top: isMobile ? 110 : 90),
            child: Transform.translate(
              offset: Offset(0, parallaxY),
              child: Opacity(
                opacity: heroOpacity,
                child: _HeroContent(
                  phrase: _phrases[_phraseIndex],
                  phraseIndex: _phraseIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.phrase, required this.phraseIndex});
  final String phrase;
  final int phraseIndex;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 1000;
    final h = MediaQuery.sizeOf(context).height;

    if (isMobile) {
      return SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _HeroCopy(phrase: phrase, phraseIndex: phraseIndex, centered: true),
            ),
            const SizedBox(height: 40),
            const Center(child: HeroMarketStack(compact: true)),
            const SizedBox(height: 36),
            const _TrustStrip(),
            const SizedBox(height: 32),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1240, minHeight: h - 90),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 11,
                    child: _HeroCopy(phrase: phrase, phraseIndex: phraseIndex, centered: false),
                  ),
                  const SizedBox(width: 48),
                  const Expanded(
                    flex: 9,
                    child: Center(child: HeroMarketStack()),
                  ),
                ],
              ),
              const SizedBox(height: 56),
              const _TrustStrip(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.phrase, required this.phraseIndex, required this.centered});
  final String phrase;
  final int phraseIndex;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 1000;
    final double titleSize = w < 480 ? 44 : (w < 1000 ? 56 : (w < 1250 ? 64 : 74));

    final cross = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final align = centered ? TextAlign.center : TextAlign.left;

    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: t.brandSubtle,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: t.brand.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingDot(color: t.brand),
              const SizedBox(width: 8),
              Text(
                'LIVE ON ARC TESTNET',
                style: TextStyle(
                    color: t.brand,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.15),
        SizedBox(height: isMobile ? 22 : 30),
        // Editorial serif headline
        Text(
          'The market for',
          textAlign: align,
          style: TextStyle(
            fontFamily: PulsColors.fontDisplay,
            color: t.text,
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
            height: 1.04,
            letterSpacing: -1.5,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.12, delay: 100.ms),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            phrase,
            key: ValueKey(phraseIndex),
            textAlign: align,
            style: TextStyle(
              fontFamily: PulsColors.fontDisplay,
              color: t.brand,
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              height: 1.08,
              letterSpacing: -1.5,
            ),
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 150.ms),
        SizedBox(height: isMobile ? 18 : 26),
        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'Swipe-to-trade prediction markets on Arc — funded in USDC, '
            'settled by UMA\'s optimistic oracle, traded by humans and AI agents alike.',
            textAlign: align,
            style: TextStyle(
              color: t.textMuted,
              fontSize: isMobile ? 15 : 17,
              height: 1.65,
              fontWeight: FontWeight.w400,
            ),
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 250.ms).slideY(begin: 0.12, delay: 250.ms),
        SizedBox(height: isMobile ? 26 : 34),
        // CTAs
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          children: [
            Builder(builder: (context) {
              final wallet = WalletServiceScope.of(context);
              return _PrimaryButton(
                label: wallet.state.isLoading ? 'Connecting…' : 'Start predicting — free',
                onTap: wallet.state.isLoading ? null : wallet.signInWithGoogle,
              );
            }),
            Builder(builder: (context) {
              final wallet = WalletServiceScope.of(context);
              return _SecondaryButton(
                label: 'Connect wallet',
                onTap: () async {
                  await wallet.signInWithExternalWallet();
                  if (wallet.state.isExternalWallet && context.mounted) {
                    appState.completeOnboarding();
                  }
                },
              );
            }),
          ],
        ).animate().fadeIn(duration: 600.ms, delay: 350.ms).slideY(begin: 0.12, delay: 350.ms),
        SizedBox(height: isMobile ? 14 : 18),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.android_rounded, size: 15, color: t.textSubtle),
            const SizedBox(width: 6),
            const _InlineLink(label: 'Get the Android app', url: kAndroidApkUrl),
            Text('  ·  Testnet USDC. Nothing to lose.',
                style: TextStyle(color: t.textSubtle, fontSize: 12.5)),
          ],
        ).animate().fadeIn(duration: 600.ms, delay: 450.ms),
      ],
    );
  }
}

class _InlineLink extends StatefulWidget {
  const _InlineLink({required this.label, required this.url});
  final String label;
  final String url;

  @override
  State<_InlineLink> createState() => _InlineLinkState();
}

class _InlineLinkState extends State<_InlineLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
        child: Text(
          widget.label,
          style: TextStyle(
            color: _hovered ? t.brand : t.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: _hovered ? t.brand : t.textSubtle,
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Repeat is gated on reduce-motion in build().
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _dot(double v) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5 * v),
              blurRadius: 6 + 6 * v,
              spreadRadius: 1.5 * v,
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Reduce-motion: a still dot with a gentle fixed glow, no pulsing loop.
    if (context.reduceMotion) {
      if (_c.isAnimating) _c.stop();
      return _dot(0.6);
    }
    if (!_c.isAnimating) _c.repeat(reverse: true);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => _dot(_c.value),
    );
  }
}

// ── Trust strip ───────────────────────────────────────────────────────────────
class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  static const _rails = [
    ('CIRCLE', 'MPC wallets'),
    ('ARC', 'USDC-gas L1'),
    ('UMA', 'oracle settlement'),
    ('POLYMARKET', 'live market data'),
    ('ERC-8004', 'AI agent identity'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 700;

    return Column(
      children: [
        Text(
          'BUILT ON REAL RAILS',
          style: TextStyle(
            color: t.textSubtle,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: isMobile ? 18 : 36,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: _rails
              .map((r) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.$1,
                        style: TextStyle(
                          fontFamily: PulsColors.fontDisplay,
                          color: t.text.withValues(alpha: 0.75),
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        r.$2,
                        style: TextStyle(
                          color: t.textSubtle,
                          fontSize: isMobile ? 10 : 11.5,
                        ),
                      ),
                    ],
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ── Features Section ──────────────────────────────────────────────────────────
class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  static const _features = [
    _Feature(
      icon: Icons.swipe_rounded,
      color: Color(0xFFEC4899),
      title: 'Swipe to Trade',
      body: 'Swipe right for YES, left for NO. Buy any Polymarket prediction in under a second — no confirmation modal.',
    ),
    _Feature(
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF16A34A),
      title: 'Instant MPC Wallet',
      body: 'Sign in with Google and get a Circle MPC wallet on Arc Testnet automatically. No seed phrase, no setup.',
    ),
    _Feature(
      icon: Icons.show_chart_rounded,
      color: Color(0xFF0EA5E9),
      title: 'Real Polymarket Data',
      body: '100 live markets from Polymarket with real odds, sparkline charts, bid/ask spread, and 24h volume.',
    ),
    _Feature(
      icon: Icons.water_drop_rounded,
      color: Color(0xFFD97706),
      title: 'USDC — No ETH Needed',
      body: 'Arc Testnet uses USDC as the native gas token. Pay fees in USDC. No ETH, no bridging, no friction.',
    ),
    _Feature(
      icon: Icons.bar_chart_rounded,
      color: Color(0xFFEC4899),
      title: 'Portfolio & PNL',
      body: 'Track every trade with entry price, current price, and real-time PNL. View transactions on Arc Explorer.',
    ),
    _Feature(
      icon: Icons.play_circle_rounded,
      color: Color(0xFF0EA5A0),
      title: 'TikTok-style Feed',
      body: 'Vertical video feed with prediction pills. Swipe through content and lock in your prediction without leaving.',
    ),
    _Feature(
      icon: Icons.gavel_rounded,
      color: Color(0xFFEF4444),
      title: 'Oracle-Secured Resolution',
      body: 'Markets settle through UMA\'s Optimistic Oracle on Arc. Bonded proposals, an open dispute window, fully on-chain.',
    ),
    _Feature(
      icon: Icons.add_circle_rounded,
      color: Color(0xFF10B981),
      title: 'Create Your Own Markets',
      body: 'Launch a custom prediction market on any question in seconds. Deployed and funded on-chain for 10 USDC.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 600;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 48, vertical: isMobile ? 48 : 96),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: t.brandSubtle,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: t.brand.withValues(alpha: 0.3)),
            ),
            child: Text(
              'FEATURES',
              style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Everything you need to trade predictions',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.text, fontSize: isMobile ? 24 : 38, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            'Built on Circle\'s full-stack: MPC wallets, USDC, Arc Testnet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textMuted, fontSize: isMobile ? 14 : 16, height: 1.6),
          ),
          SizedBox(height: isMobile ? 32 : 56),
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
            return Wrap(
              spacing: isMobile ? 12 : 20,
              runSpacing: isMobile ? 12 : 20,
              children: _features.map((f) => SizedBox(
                width: (constraints.maxWidth - (cols - 1) * (isMobile ? 12 : 20)) / cols,
                child: _FeatureCard(feature: f),
              )).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature({required this.icon, required this.color, required this.title, required this.body});
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.feature});
  final _Feature feature;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final f = widget.feature;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: _hovered ? Matrix4.translationValues(0.0, -5.0, 0.0) : Matrix4.identity(),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.surface, Color.alphaBlend(f.color.withValues(alpha: 0.035), t.surface)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _hovered ? f.color.withValues(alpha: 0.45) : t.border),
          boxShadow: _hovered
              ? [BoxShadow(color: f.color.withValues(alpha: 0.16), blurRadius: 34, offset: const Offset(0, 16))]
              : [BoxShadow(color: t.text.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [f.color, Color.alphaBlend(Colors.white.withValues(alpha: 0.4), f.color)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: f.color.withValues(alpha: 0.32), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: Icon(f.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 18),
            Text(
              f.title,
              style: TextStyle(color: t.text, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2),
            ),
            const SizedBox(height: 8),
            Text(
              f.body,
              style: TextStyle(color: t.textMuted, fontSize: 14, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

// ── How It Works ──────────────────────────────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  static const _steps = [
    ('01', 'Sign in with Google', 'One tap. A Circle MPC wallet is created on Arc Testnet automatically. No seed phrase.', Color(0xFF14B8A6)),
    ('02', 'Get testnet USDC', 'Visit faucet.circle.com → select Arc Testnet → paste your wallet address. Free USDC in seconds.', Color(0xFF16A34A)),
    ('03', 'Browse 100 live markets', 'Real Polymarket predictions with live odds, sparkline charts, and volume data.', Color(0xFF0EA5E9)),
    ('04', 'Swipe YES or NO', 'Swipe right for YES, left for NO. Your USDC is sent to the PulsMarket smart contract on-chain.', Color(0xFFD97706)),
    ('05', 'Track your PNL', 'Portfolio shows entry price, current price, and real-time PNL. Claim winnings when markets resolve.', Color(0xFFEC4899)),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 600;

    return Container(
      color: t.surface.withValues(alpha: 0.4),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 48, vertical: isMobile ? 48 : 96),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: t.brandSubtle,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: t.brand.withValues(alpha: 0.3)),
            ),
            child: Text(
              'HOW IT WORKS',
              style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'From zero to on-chain in 60 seconds',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.text, fontSize: isMobile ? 24 : 38, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.2),
          ),
          SizedBox(height: isMobile ? 32 : 56),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: _steps.asMap().entries.map((e) {
                final step = e.value;
                final isLast = e.key == _steps.length - 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _StepRow(
                    number: step.$1,
                    title: step.$2,
                    body: step.$3,
                    color: step.$4,
                    nextColor: isLast ? null : _steps[e.key + 1].$4,
                    isLast: isLast,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.body,
    required this.color,
    required this.nextColor,
    required this.isLast,
  });
  final String number, title, body;
  final Color color;
  final Color? nextColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 600;
    final badge = isMobile ? 44.0 : 50.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: badge, height: badge,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, Color.alphaBlend(Colors.white.withValues(alpha: 0.42), color)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.34), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: Center(
                  child: Text(number, style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w800)),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color, nextColor ?? color],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: isMobile ? 16 : 22),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 18, vertical: isMobile ? 14 : 16),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: t.text.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: t.text, fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      body,
                      style: TextStyle(color: t.textMuted, fontSize: isMobile ? 13 : 14, height: 1.55),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Section ─────────────────────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 600;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 48, vertical: isMobile ? 48 : 88),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Text(
                'Built on Circle\'s full stack',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text, fontSize: isMobile ? 24 : 36, fontWeight: FontWeight.w800, letterSpacing: -1),
              ),
              const SizedBox(height: 8),
              Text(
                'Real infrastructure. Real trades. Testnet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textMuted, fontSize: isMobile ? 14 : 16),
              ),
              SizedBox(height: isMobile ? 32 : 48),
              LayoutBuilder(builder: (context, constraints) {
                final cols = constraints.maxWidth > 700 ? 4 : 2;
                return Wrap(
                  spacing: isMobile ? 12 : 20, runSpacing: isMobile ? 12 : 20,
                  children: [
                    _statCard('100+', 'Live Markets', 'From Polymarket Gamma API', t.brand, 'https://img.icons8.com/?id=KslJGdGlJFNz&format=png&size=256', constraints, cols, t),
                    _statCard('< 1s', 'Trade Speed', 'Arc Testnet sub-second finality', t.yes, 'https://img.icons8.com/?id=XTqUA8keYxec&format=png&size=256', constraints, cols, t),
                    _statCard('\$0 ETH', 'Gas Cost', 'USDC is the native gas token', PulsColors.amber, 'https://img.icons8.com/?id=rcnetj6T68lY&format=png&size=256', constraints, cols, t),
                    _statCard('MPC', 'Wallet Type', 'Circle developer-controlled wallets', const Color(0xFF0EA5E9), 'https://img.icons8.com/?id=hkkfYNNRoACe&format=png&size=256', constraints, cols, t),
                  ],
                );
              }),
              SizedBox(height: isMobile ? 32 : 52),
              // Contract address widget
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 22),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFEC4899).withValues(alpha: 0.03), blurRadius: 10)
                  ],
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: t.brandSubtle, borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.code_rounded, color: t.brand, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'LMSRMarketFactory.sol',
                                  style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const _VerifiedBadge(),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            factoryAddress,
                            style: TextStyle(
                              color: t.textSubtle,
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const _CopyButton(text: factoryAddress),
                              const SizedBox(width: 8),
                              _SecondaryButton(
                                label: 'View ↗',
                                onTap: () => launchUrl(
                                  Uri.parse('https://testnet.arcscan.app/address/$factoryAddress'),
                                  mode: LaunchMode.externalApplication,
                                ),
                                small: true,
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: t.brandSubtle, borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.code_rounded, color: t.brand, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'LMSRMarketFactory.sol — Arc Testnet',
                                        style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const _VerifiedBadge(),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  factoryAddress,
                                  style: TextStyle(
                                    color: t.textSubtle,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const _CopyButton(text: factoryAddress),
                          const SizedBox(width: 8),
                          _SecondaryButton(
                            label: 'View ↗',
                            onTap: () => launchUrl(
                              Uri.parse('https://testnet.arcscan.app/address/$factoryAddress'),
                              mode: LaunchMode.externalApplication,
                            ),
                            small: true,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, String sub, Color color, String imageUrl, BoxConstraints constraints, int cols, PulsThemeColors t) {
    final isMobile = constraints.maxWidth < 600;
    final spacing = isMobile ? 12.0 : 20.0;
    return SizedBox(
      width: (constraints.maxWidth - (cols - 1) * spacing) / cols,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: isMobile ? 22 : 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Image.network(
                  imageUrl,
                  width: isMobile ? 32 : 48,
                  height: isMobile ? 32 : 48,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: t.text, fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: t.textMuted, fontSize: isMobile ? 10 : 12, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});
  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return IconButton(
      onPressed: () {
        Clipboard.setData(ClipboardData(text: widget.text));
        setState(() => _copied = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
        PulsSnack.show(context, 'Address copied to clipboard!');
      },
      icon: Icon(
        _copied ? Icons.check_circle_outline_rounded : Icons.copy_rounded,
        color: _copied ? t.yes : t.brand,
        size: 18,
      ),
      tooltip: 'Copy contract address',
    );
  }
}

// ── Final CTA ─────────────────────────────────────────────────────────────────
class _FinalCtaSection extends StatelessWidget {
  const _FinalCtaSection();

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 700;
    final double titleSize = w < 480 ? 38 : (w < 900 ? 52 : 66);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48, vertical: isMobile ? 72 : 130),
      child: Column(
        children: [
          Text(
            'Don\'t just read the news.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: PulsColors.fontDisplay,
              color: t.text,
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              height: 1.08,
              letterSpacing: -1.5,
            ),
          ),
          Text(
            'Trade it.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: PulsColors.fontDisplay,
              color: t.brand,
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              height: 1.12,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Free testnet USDC. A wallet in one tap. Your first prediction in under a minute.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textMuted, fontSize: isMobile ? 14 : 16, height: 1.6),
          ),
          SizedBox(height: isMobile ? 28 : 36),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              Builder(builder: (context) {
                final wallet = WalletServiceScope.of(context);
                return _PrimaryButton(
                  label: wallet.state.isLoading ? 'Connecting…' : 'Launch Puls',
                  onTap: wallet.state.isLoading
                      ? null
                      : () {
                          if (wallet.state.userId != null) {
                            appState.completeOnboarding();
                          } else {
                            wallet.signInWithGoogle();
                          }
                        },
                );
              }),
              _SecondaryButton(
                label: '⤓  Android APK',
                onTap: () => launchUrl(Uri.parse(kAndroidApkUrl), mode: LaunchMode.externalApplication),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Aurora background painter ─────────────────────────────────────────────────
class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({required this.progress, required this.isDark, required this.bg});
  final double progress;
  final bool isDark;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;
    final blobs = isDark
        ? const [Color(0xFF1B2236), Color(0xFF2A1233), Color(0xFF0E2E2A)]
        : const [Color(0xFFFCE7F3), Color(0xFFFDF2F8), Color(0xFFE6FAF6)];
    final alpha = isDark ? 0.55 : 0.75;

    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    void blob(Color c, double cx, double cy, double r) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [c.withValues(alpha: alpha), c.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    final w = size.width, h = size.height;
    blob(blobs[0], w * (0.28 + 0.06 * math.sin(t)), h * (0.18 + 0.05 * math.cos(t * 0.8)), w * 0.42);
    blob(blobs[1], w * (0.78 + 0.05 * math.cos(t * 0.9)), h * (0.30 + 0.06 * math.sin(t * 0.7)), w * 0.38);
    blob(blobs[2], w * (0.55 + 0.07 * math.sin(t * 0.6 + 2)), h * (0.74 + 0.04 * math.cos(t + 1)), w * 0.34);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.progress != progress || old.isDark != isDark || old.bg != bg;
}

// ── Footer ────────────────────────────────────────────────────────────────────
class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 600;

    return Container(
      color: t.surface.withValues(alpha: 0.3),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 48, vertical: isMobile ? 48 : 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              isMobile
                  ? Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                color: t.brandSubtle,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Puls',
                              style: TextStyle(fontFamily: PulsColors.fontDisplay, color: t.text, fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Built on Arc Testnet · Circle MPC Wallets',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: t.textSubtle, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        const Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 20,
                          runSpacing: 10,
                          children: [
                            _FooterLink('Docs', 'https://docs.pulsmarket.tech'),
                            _FooterLink('GitHub', 'https://github.com/rdmbtc/Puls'),
                            _FooterLink('Explorer', 'https://testnet.arcscan.app/address/$factoryAddress'),
                            _FooterLink('Faucet', 'https://faucet.circle.com'),
                            _FooterLink('Android app', kAndroidApkUrl),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: t.brandSubtle,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Puls',
                          style: TextStyle(fontFamily: PulsColors.fontDisplay, color: t.text, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          'Built on Arc Testnet · Circle MPC Wallets',
                          style: TextStyle(color: t.textSubtle, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        const _FooterLink('Docs', 'https://docs.pulsmarket.tech'),
                        const SizedBox(width: 20),
                        const _FooterLink('GitHub', 'https://github.com/rdmbtc/Puls'),
                        const SizedBox(width: 20),
                        const _FooterLink('Explorer', 'https://testnet.arcscan.app/address/$factoryAddress'),
                        const SizedBox(width: 20),
                        const _FooterLink('Faucet', 'https://faucet.circle.com'),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: green.withValues(alpha: 0.30)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12, color: green),
          SizedBox(width: 4),
          Text(
            'Verified on Arc',
            style: TextStyle(color: green, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, this.url);
  final String label, url;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          label,
          style: TextStyle(color: t.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ── Shared Buttons ────────────────────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, required this.onTap, this.small = false});
  final String label;
  final VoidCallback? onTap;
  final bool small;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.small ? 18 : 32,
              vertical: widget.small ? 10 : 16,
            ),
            decoration: BoxDecoration(
              gradient: PulsColors.pulseGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _hovered
                  ? [BoxShadow(color: PulsColors.brandPink.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  const _SecondaryButton({required this.label, required this.onTap, this.small = false});
  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.small ? 16 : 30,
            vertical: widget.small ? 10 : 16,
          ),
          decoration: BoxDecoration(
            color: _hovered ? t.surfaceRaised : t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hovered ? t.textMuted : t.border),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? t.text : t.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.75, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

// ── Scroll reveal ─────────────────────────────────────────────────────────────
/// Fades + slides its child in the first time it scrolls into view.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.scrollOffset, required this.child});
  final double scrollOffset;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _shown = false;
  double? _top;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _shown) return;
      _measure();
      final h = MediaQuery.sizeOf(context).height;
      final top = _top;
      if (top != null && widget.scrollOffset + h * 0.88 > top) {
        setState(() => _shown = true);
      } else {
        setState(() {}); // re-render with measured position
      }
    });
  }

  @override
  void didUpdateWidget(covariant _Reveal old) {
    super.didUpdateWidget(old);
    if (_shown) return;
    _measure();
    final h = MediaQuery.sizeOf(context).height;
    final top = _top;
    if (top != null && widget.scrollOffset + h * 0.88 > top) {
      setState(() => _shown = true);
    }
  }

  void _measure() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    // Global position + current scroll offset = position in scroll content.
    _top = box.localToGlobal(Offset.zero).dy + widget.scrollOffset;
  }

  @override
  Widget build(BuildContext context) {
    // Anything starting within the first viewport shows immediately.
    final h = MediaQuery.sizeOf(context).height;
    // Reduce-motion: reveal everything at once, with no fade/slide ramp.
    final reduce = context.reduceMotion;
    final visibleNow = reduce || _shown || (_top != null && _top! < h * 0.92);
    final revealDuration = context.motionDuration(const Duration(milliseconds: 650));
    return AnimatedOpacity(
      duration: revealDuration,
      curve: Curves.easeOut,
      opacity: _shown || visibleNow ? 1 : 0,
      child: AnimatedSlide(
        duration: revealDuration,
        curve: Curves.easeOutCubic,
        offset: _shown || visibleNow ? Offset.zero : const Offset(0, 0.045),
        child: widget.child,
      ),
    );
  }
}

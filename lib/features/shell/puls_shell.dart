import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../feed/feed_screen.dart';
import 'puls_bottom_nav.dart';
import '../portfolio/portfolio_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/leaderboard_screen.dart';
import '../agent/agent_screen.dart';
import '../onboarding/onboarding_sheet.dart';
import 'shell_nav.dart';
import 'web_shell.dart';

class PulsShell extends StatelessWidget {
  const PulsShell({super.key});

  @override
  Widget build(BuildContext context) {
    // On web: use mobile shell for narrow screens (phones/PWA), desktop shell for wide
    if (kIsWeb) {
      final width = MediaQuery.sizeOf(context).width;
      if (width < 600) return const _MobileShell();
      return const WebShell();
    }
    return const _MobileShell();
  }
}

class _MobileShell extends StatefulWidget {
  const _MobileShell();

  @override
  State<_MobileShell> createState() => _PulsShellState();
}

class _PulsShellState extends State<_MobileShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    maybeShowWelcome(this);
  }

  static const _pages = [
    FeedScreen(),
    PortfolioScreen(),
    LeaderboardScreen(),
    AgentScreen(),
    ProfileScreen(),
  ];

  // Map shell-independent tab ids → this shell's page index.
  static const _tabIndex = {
    PulsTab.feed: 0,
    PulsTab.portfolio: 1,
    PulsTab.leaderboard: 2,
    PulsTab.agent: 3,
    PulsTab.profile: 4,
    // Mobile shell has no Discover/Home tabs → fall back to Feed.
    PulsTab.discover: 0,
    PulsTab.home: 0,
  };

  void _goToTab(PulsTab tab) {
    final i = _tabIndex[tab] ?? 0;
    if (i != _index) setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isLight = !context.isDark;

    return ShellNavScope(
      goToTab: _goToTab,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight
          ? SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: t.bg,
        extendBody: true,
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: PulsBottomNav(
          index: _index,
          isDark: !isLight,
          onTap: (i) {
          if (i == _index) {
            // Tapping the active tab again → refresh the feed (only meaningful there).
            if (i == 0) PulsStateScope.of(context).refresh();
            return;
          }
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        ),
      ),
      ),
    );
  }
}

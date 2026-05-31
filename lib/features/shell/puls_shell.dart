import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:picons/picons.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../discover/discover_screen.dart';
import '../feed/feed_screen.dart';
import '../portfolio/portfolio_screen.dart';
import '../profile/profile_screen.dart';
import '../agent/agent_screen.dart';
import '../../features/home/home_screen.dart';
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

  static const _pages = [
    FeedScreen(),
    DiscoverScreen(),
    HomeScreen(),
    PortfolioScreen(),
    AgentScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isLight = !context.isDark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight
          ? SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: t.bg,
        extendBody: true,
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: _DynamicIslandNav(
          index: _index,
          t: t,
          isDark: !isLight,
          onTap: (i) {
          if (i == _index && i == 0) {
            // Tapping Feed tab while already on Feed → refresh
            PulsStateScope.of(context).refresh();
          }
          setState(() => _index = i);
        },
        ),
      ),
    );
  }
}

class _DynamicIslandNav extends StatelessWidget {
  const _DynamicIslandNav({
    required this.index,
    required this.t,
    required this.isDark,
    required this.onTap,
  });

  final int index;
  final PulsThemeColors t;
  final bool isDark;
  final ValueChanged<int> onTap;

  static final _items = [
    _Item(Picons.lightning, 'Feed'),
    _Item(Picons.compass, 'Discover'),
    _Item(Picons.playCircle, 'Home'),
    _Item(Picons.chartBar, 'Portfolio'),
    _Item(Picons.robot, 'Agent'),
    _Item(Picons.userCircle, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? const Color(0xFF131127)
        : const Color(0xFFFFFFFF);
    final shadow = isDark
        ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
        : const Color(0xFF4F46E5).withValues(alpha: 0.08);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: shadow.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? t.brand : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: selected ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: Picon(
                            item.icon,
                            size: 20,
                            color: selected
                                ? Colors.white
                                : (isDark ? const Color(0xFF8181AA) : const Color(0xFF9A9A94)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                            color: selected
                                ? Colors.white
                                : (isDark ? const Color(0xFF6565A0) : const Color(0xFFB0B0C0)),
                          ),
                          child: Text(item.label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Item {
  _Item(this.icon, this.label);
  final PiconData icon;
  final String label;
}

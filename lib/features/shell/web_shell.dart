import 'package:flutter/material.dart';
import 'package:picons/picons.dart';

import '../../app/puls_app_state.dart';
import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../discover/discover_screen.dart';
import '../feed/feed_screen.dart';
import '../home/home_screen.dart';
import '../portfolio/portfolio_screen.dart';
import '../profile/profile_screen.dart';
import '../agent/agent_screen.dart';

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _collapsed = false;
  late final AnimationController _transCtrl;
  late final Animation<double> _fadeAnim;

  static const _pages = [
    FeedScreen(),
    DiscoverScreen(),
    HomeScreen(),
    PortfolioScreen(),
    AgentScreen(),
    ProfileScreen(),
  ];

  static final _items = [
    _NavItem(Picons.lightning, 'Feed'),
    _NavItem(Picons.compass, 'Discover'),
    _NavItem(Picons.playCircle, 'Home'),
    _NavItem(Picons.chartBar, 'Portfolio'),
    _NavItem(Picons.robot, 'Agent'),
    _NavItem(Picons.userCircle, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _transCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _fadeAnim = CurvedAnimation(parent: _transCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _transCtrl.dispose();
    super.dispose();
  }

  void _navigate(int i) {
    if (i == _index) {
      if (i == 0) PulsStateScope.of(context).refresh();
      return;
    }
    _transCtrl.reverse().then((_) {
      setState(() => _index = i);
      _transCtrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;
    final appState = PulsStateScope.of(context);

    // Theme-aware gradient
    final gradientBg = isDark
        ? const Color(0xFF0C0A1A)
        : const Color(0xFFFAFAF7);
    final gradientGlow = isDark
        ? const Color(0x40312E81)
        : const Color(0x1C4F46E5);
    final gradientEnd = isDark
        ? const Color(0xFF0C0A1A)
        : const Color(0xFFFAFAF7);
    final dotColor = isDark
        ? const Color(0x0AFFFFFF)
        : const Color(0x0A4F46E5);

    return Scaffold(
      backgroundColor: gradientBg,
      body: Stack(
        children: [
          // ── Theme-aware gradient ─────────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.4,
                  colors: [gradientGlow, gradientEnd],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          // ── Dot grid ────────────────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter(color: dotColor)),
          ),
          // ── Shell ────────────────────────────────────────────────────────
          Row(
            children: [
              // Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: _collapsed ? 64 : 220,
                child: _Sidebar(
                  index: _index,
                  items: _items,
                  t: t,
                  isDark: isDark,
                  collapsed: _collapsed,
                  onTap: _navigate,
                  onToggleCollapse: () => setState(() => _collapsed = !_collapsed),
                  onToggleTheme: appState.toggleThemeMode,
                ),
              ),
              VerticalDivider(
                  width: 1, color: t.border.withValues(alpha: 0.4)),
              // Content with fade+slide transition
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.02, 0),
                      end: Offset.zero,
                    ).animate(_fadeAnim),
                    child: IndexedStack(
                        index: _index, children: _pages),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.items,
    required this.t,
    required this.isDark,
    required this.collapsed,
    required this.onTap,
    required this.onToggleCollapse,
    required this.onToggleTheme,
  });

  final int index;
  final List<_NavItem> items;
  final PulsThemeColors t;
  final bool isDark;
  final bool collapsed;
  final ValueChanged<int> onTap;
  final VoidCallback onToggleCollapse;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo + collapse button
        Padding(
          padding: EdgeInsets.fromLTRB(collapsed ? 12 : 20, 24, 12, 20),
          child: Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/logo.png', fit: BoxFit.cover),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Puls',
                      style: TextStyle(
                        color: t.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      )),
                ),
              ],
              const SizedBox(width: 4),
              _IconBtn(
                icon: collapsed ? Picons.arrowRight : Picons.arrowLeft,
                color: t.textSubtle,
                onTap: onToggleCollapse,
              ),
            ],
          ),
        ),
        // Nav items
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final selected = i == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _SidebarItem(
                    item: item,
                    selected: selected,
                    collapsed: collapsed,
                    t: t,
                    onTap: () => onTap(i),
                  ),
                );
              }),
            ),
          ),
        ),
        // Bottom: dark mode toggle + Arc badge
        Padding(
          padding: EdgeInsets.fromLTRB(collapsed ? 8 : 12, 0, collapsed ? 8 : 12, 20),
          child: Column(
            children: [
              _buildWalletCard(context),
              const SizedBox(height: 8),
              // Dark mode toggle
              _SidebarToggle(
                isDark: isDark,
                collapsed: collapsed,
                t: t,
                onToggle: onToggleTheme,
              ),
              const SizedBox(height: 8),
              if (!collapsed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: t.yes, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text('Arc Testnet',
                          style: TextStyle(
                              color: t.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              else
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: t.yes, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalletCard(BuildContext context) {
    final wallet = WalletServiceScope.of(context);
    final ws = wallet.state;
    if (ws.walletAddress == null || ws.walletAddress!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final shortAddress = ws.walletAddress!.length > 10 
        ? '${ws.walletAddress!.substring(0, 6)}...${ws.walletAddress!.substring(ws.walletAddress!.length - 4)}'
        : ws.walletAddress!;
        
    final label = ws.isExternalWallet ? 'Browser Wallet' : 'MPC Wallet';

    if (collapsed) {
      return Tooltip(
        message: '$label: $shortAddress\n${ws.usdcBalance} USDC',
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.border),
          ),
          child: Icon(Icons.account_balance_wallet_outlined, size: 18, color: t.textMuted),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 13, color: t.textSubtle),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: t.textSubtle, fontSize: 10, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              GestureDetector(
                onTap: wallet.signOut,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(Icons.logout_rounded, size: 11, color: t.textSubtle),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            shortAddress,
            style: TextStyle(
              color: t.text,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '\$${double.tryParse(ws.usdcBalance)?.toStringAsFixed(2) ?? ws.usdcBalance} USDC',
            style: TextStyle(
              color: t.yes,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.t,
    required this.onTap,
  });
  final _NavItem item;
  final bool selected;
  final bool collapsed;
  final PulsThemeColors t;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: widget.collapsed ? 12 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? t.brand.withValues(alpha: 0.12)
                : _hovered
                    ? t.surface
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: widget.collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Picon(
                widget.item.icon,
                size: 18,
                color: widget.selected ? t.brand : t.textMuted,
              ),
              if (!widget.collapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: TextStyle(
                      color: widget.selected ? t.brand : t.textMuted,
                      fontSize: 14,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (widget.selected)
                  Container(
                    width: 4, height: 4,
                    decoration: BoxDecoration(
                      color: t.brand, shape: BoxShape.circle),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarToggle extends StatefulWidget {
  const _SidebarToggle({
    required this.isDark,
    required this.collapsed,
    required this.t,
    required this.onToggle,
  });
  final bool isDark;
  final bool collapsed;
  final PulsThemeColors t;
  final VoidCallback onToggle;

  @override
  State<_SidebarToggle> createState() => _SidebarToggleState();
}

class _SidebarToggleState extends State<_SidebarToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: widget.collapsed ? 12 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: _hovered ? t.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovered ? t.border : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: widget.collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Picon(
                  key: ValueKey(widget.isDark),
                  widget.isDark ? Picons.sun : Picons.moon,
                  size: 18,
                  color: t.textMuted,
                ),
              ),
              if (!widget.collapsed) ...[
                const SizedBox(width: 10),
                Text(
                  widget.isDark ? 'Light mode' : 'Dark mode',
                  style: TextStyle(color: t.textMuted, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  final PiconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: _hovered
                ? context.puls.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Picon(widget.icon, size: 14, color: widget.color),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  _NavItem(this.icon, this.label);
  final PiconData icon;
  final String label;
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
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

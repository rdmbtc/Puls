import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme/app_theme.dart';
import 'landing_kit.dart';

/// "Under the hood" — an animated pipeline of the real Puls architecture, with
/// USDC impulses flowing down the connectors (mirrors the README flow). Pure
/// presentation, reduce-motion aware.
class ArchitectureSection extends StatelessWidget {
  const ArchitectureSection({super.key});

  static const _nodes = [
    _NodeData('📱', 'Flutter app', 'Android + Web · swipe to trade',
        Color(0xFFEC4899)),
    _NodeData('🟢', 'Node API + WebSocket', 'Google sign-in · live trade stream',
        Color(0xFF16A34A)),
    _NodeData('💳', 'Circle MPC wallet', 'Created instantly · no seed phrase',
        Color(0xFF0EA5E9)),
    _NodeData('🏭', 'LMSR market factory', 'Deploys each PulsMarket on-chain',
        Color(0xFF8B5CF6)),
    _NodeData('🔎', 'Arc + Arcscan', 'Chain 5042002 · sub-second, verifiable',
        Color(0xFF2DD4BF)),
  ];

  static const _labels = ['Google OAuth', 'userId → wallet', 'USDC gas · buyYes()', 'settled < 1s'];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 760;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 52 : 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              const LandingEyebrow(label: 'UNDER THE HOOD', icon: Icons.account_tree_rounded),
              const SizedBox(height: 20),
              LandingHeadline(
                lead: 'Real rails,',
                accent: 'not slideware.',
                isMobile: isMobile,
              ),
              const SizedBox(height: 14),
              Text(
                'USDC is the only token in the system — it pays for gas, trades and '
                'agent-to-agent alpha. Watch it flow.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.puls.textMuted,
                    fontSize: isMobile ? 14 : 15.5,
                    height: 1.6),
              ),
              SizedBox(height: isMobile ? 32 : 48),
              for (var i = 0; i < _nodes.length; i++) ...[
                _Node(data: _nodes[i], index: i),
                if (i < _nodes.length - 1) _Connector(label: _labels[i], delay: i * 0.2),
              ],
              const SizedBox(height: 28),
              _KeyChip(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodeData {
  const _NodeData(this.glyph, this.title, this.subtitle, this.color);
  final String glyph;
  final String title;
  final String subtitle;
  final Color color;
}

class _Node extends StatelessWidget {
  const _Node({required this.data, required this.index});
  final _NodeData data;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.alphaBlend(data.color.withValues(alpha: 0.06), t.surface),
            t.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: data.color.withValues(alpha: 0.3)),
            ),
            child: Text(data.glyph, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title,
                    style: TextStyle(
                        color: t.text, fontSize: 15.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(data.subtitle,
                    style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.bg,
              shape: BoxShape.circle,
              border: Border.all(color: t.border),
            ),
            child: Text('${index + 1}',
                style: TextStyle(
                    color: t.textSubtle, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _Connector extends StatefulWidget {
  const _Connector({required this.label, required this.delay});
  final String label;
  final double delay;

  @override
  State<_Connector> createState() => _ConnectorState();
}

class _ConnectorState extends State<_Connector> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final t = context.puls;
    const h = 58.0;

    return SizedBox(
      height: h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The line.
          Container(width: 2, height: h, color: t.border),
          // Flowing USDC impulses.
          if (!reduce)
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final p1 = (_c.value + widget.delay) % 1.0;
                final p2 = (_c.value + widget.delay + 0.5) % 1.0;
                return Stack(
                  children: [
                    _impulse(p1, h),
                    _impulse(p2, h),
                  ],
                );
              },
            )
          else
            _staticDot(h),
          // Label chip riding the line.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: t.border),
            ),
            child: Text(widget.label,
                style: TextStyle(
                    color: t.textMuted,
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _impulse(double p, double h) {
    final y = p * h;
    final fade = p < 0.15 ? p / 0.15 : (p > 0.85 ? (1 - p) / 0.15 : 1.0);
    return Positioned(
      top: y - 4,
      left: 0,
      right: 0,
      child: Center(
        child: Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: PulsColors.pulseGradient,
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFF65FA9).withValues(alpha: 0.6),
                    blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _staticDot(double h) => Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: PulsColors.pulseGradient,
          ),
        ),
      );
}

class _KeyChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: t.brandSubtle,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: t.brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key_rounded, size: 14, color: t.brand),
          const SizedBox(width: 7),
          Flexible(
            child: Text('USDC is the ONLY token. No ETH needed. Sub-second finality.',
                style: TextStyle(
                    color: t.text, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

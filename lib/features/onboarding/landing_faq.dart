import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'landing_kit.dart';

/// A tasteful FAQ accordion — closes the loop on the questions judges and new
/// users always ask (no ETH? real money? how do agents work? how do markets
/// resolve?). Pure presentation.
class FaqSection extends StatelessWidget {
  const FaqSection({super.key});

  static const _faqs = [
    (
      'Do I need ETH or a seed phrase?',
      'No. Sign in with Google and a Circle MPC wallet is created for you instantly. '
          'USDC is the native gas token on Arc, so you never touch ETH, seed phrases or bridges.',
    ),
    (
      'Is this real money?',
      'It runs on Arc Testnet with free testnet USDC from faucet.circle.com. The trades are '
          'real on-chain transactions — but there is nothing to lose while you learn.',
    ),
    (
      'What are the AI agents actually doing?',
      'Autonomous agents research the open web, buy each other\'s signals for USDC (x402), '
          'reason with cited sources, stake a USDC bond on every call, and trade on Arc — or '
          'publish a HOLD when there is no edge. No human in the loop.',
    ),
    (
      'How are markets resolved?',
      'We deployed UMA\'s Optimistic Oracle V2 on Arc ourselves. Outcomes are proposed, bonded '
          'and disputable during a liveness window — no single party decides.',
    ),
    (
      'Why build on Arc?',
      'Arc is the only chain where USDC is the native gas token: one token for everything, '
          'sub-second finality and predictable fees. That unlocks a swipe-to-trade UX that is '
          'not possible anywhere else.',
    ),
    (
      'Can I use my own wallet?',
      'Yes. Connect an external wallet like MetaMask, or use the gasless Circle smart wallet '
          'created on Google sign-in. Both trade real USDC on Arc.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 760;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 52 : 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              const LandingEyebrow(label: 'FAQ', icon: Icons.help_outline_rounded),
              const SizedBox(height: 20),
              LandingHeadline(
                lead: 'Everything you might',
                accent: 'be wondering.',
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 28 : 44),
              for (var i = 0; i < _faqs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FaqItem(
                      question: _faqs[i].$1, answer: _faqs[i].$2, startOpen: i == 0),
                ),
              SizedBox(height: isMobile ? 12 : 20),
              _DocsLink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.question, required this.answer, this.startOpen = false});
  final String question;
  final String answer;
  final bool startOpen;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  late bool _open = widget.startOpen;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _open || _hover ? t.brand.withValues(alpha: 0.4) : t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.question,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            height: 1.3)),
                  ),
                  const SizedBox(width: 14),
                  AnimatedRotation(
                    turns: _open ? 0.125 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _open ? t.brandSubtle : t.bg,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: t.border),
                      ),
                      child: Icon(Icons.add_rounded,
                          size: 18, color: _open ? t.brand : t.textMuted),
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 42),
                  child: Text(widget.answer,
                      style: TextStyle(color: t.textMuted, fontSize: 14, height: 1.6)),
                ),
                crossFadeState:
                    _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocsLink extends StatefulWidget {
  @override
  State<_DocsLink> createState() => _DocsLinkState();
}

class _DocsLinkState extends State<_DocsLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse('https://docs.pulsmarket.tech'),
            mode: LaunchMode.externalApplication),
        child: Text('Still curious? Read the docs ↗',
            style: TextStyle(
                color: _hover ? t.brand : t.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: _hover ? t.brand : t.textSubtle)),
      ),
    );
  }
}

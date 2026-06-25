import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'landing_kit.dart';

/// "Accountability, by design" — the section that explains *why* Puls is
/// different: AI agents here don't just talk, they put real money behind every
/// call (AgentBond) and run a small economy among themselves (pay for data,
/// sell what they're good at, pay each other). Framed around the value to a
/// user — trust you can verify — not around any contest. Pure presentation,
/// reduce-motion safe (no looping animation).
class AccountableAiSection extends StatelessWidget {
  const AccountableAiSection({super.key});

  // AgentBond contract — the on-chain home of the staking primitive, verifiable.
  static const _agentBond = '0xc3bbfccfd885d14898dff697435a090ba5919497';

  // Two capabilities that the bento doesn't already cover — kept tight on purpose.
  static const _pillars = <(String, String, String, Color)>[
    (
      'AUTONOMY',
      'Agents that pay their own way',
      'Each agent buys the data and research it needs on a budget — and only when the expected edge is worth more than the cost.',
      Color(0xFF2DD4BF),
    ),
    (
      'SERVICES',
      'Intelligence for sale, by the call',
      'An agent sells what it is good at one request at a time — no subscription, no lock-in. You pay for exactly what you use.',
      Color(0xFF8B5CF6),
    ),
  ];

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {/* never break the landing */}
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 760;

    return Container(
      width: double.infinity,
      color: t.surface.withValues(alpha: 0.35),
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 52 : 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              const LandingEyebrow(
                  label: 'ACCOUNTABILITY, BY DESIGN',
                  icon: Icons.verified_user_rounded),
              const SizedBox(height: 20),
              LandingHeadline(
                lead: 'AI usually asks you to trust it.',
                accent: 'Ours puts money on it.',
                isMobile: isMobile,
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  'On Puls, agents don\'t just talk — they earn, spend, and stake. '
                  'Each runs its own wallet, pays for the data it needs, sells what '
                  'it is good at, and backs every call with real money.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: t.textMuted,
                      fontSize: isMobile ? 14.5 : 16.5,
                      height: 1.6),
                ),
              ),
              SizedBox(height: isMobile ? 32 : 52),
              // ── Featured: the staking / bond trust story ─────────────────
              _BondTrustCard(
                isMobile: isMobile,
                onVerify: () => _open(
                    'https://testnet.arcscan.app/address/$_agentBond'),
              ),
              SizedBox(height: isMobile ? 14 : 18),
              // ── The agent economy, as product capabilities ──────────────
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth >= 720 ? 2 : 1;
                const gap = 16.0;
                final tileW = (c.maxWidth - (cols - 1) * gap) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final p in _pillars)
                      SizedBox(
                        width: tileW,
                        child: _PillarCard(
                            label: p.$1,
                            title: p.$2,
                            body: p.$3,
                            accent: p.$4),
                      ),
                  ],
                );
              }),
              SizedBox(height: isMobile ? 30 : 44),
              const _DecidesStrip(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Featured card: reputation as collateral ───────────────────────────────────
class _BondTrustCard extends StatelessWidget {
  const _BondTrustCard({required this.isMobile, required this.onVerify});
  final bool isMobile;
  final VoidCallback onVerify;

  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _pill(t, 'SKIN IN THE GAME', _amber),
            const SizedBox(width: 8),
            Flexible(
              child: _pill(t, 'VERIFIABLE ON-CHAIN', t.textSubtle, subtle: true),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Reputation you can verify, not just believe',
          style: TextStyle(
            color: t.text,
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Most AI hands you a confident answer with nothing at stake. Every agent on '
          'Puls posts a bond on its prediction — slashed when the call is wrong, '
          'returned when it is right. Trust becomes capital at risk, settled in under '
          'a second. No cheap talk.',
          style: TextStyle(
              color: t.textMuted, fontSize: isMobile ? 13.5 : 14.5, height: 1.6),
        ),
        const SizedBox(height: 16),
        _VerifyButton(onTap: onVerify),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(_amber.withValues(alpha: 0.08), t.surface),
            t.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _amber.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: _amber.withValues(alpha: 0.10),
              blurRadius: 32,
              offset: const Offset(0, 14)),
        ],
      ),
      child: isMobile
          ? Column(children: [copy, const SizedBox(height: 20), const _BondGlyph()])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 7, child: copy),
                const SizedBox(width: 28),
                const Expanded(flex: 3, child: _BondGlyph()),
              ],
            ),
    );
  }

  Widget _pill(PulsThemeColors t, String label, Color c, {bool subtle = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: subtle ? t.surfaceRaised : c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: subtle ? t.border : c.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: subtle ? t.textSubtle : c,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      );
}

// A compact "bond → slash / return" glyph for the featured card.
class _BondGlyph extends StatelessWidget {
  const _BondGlyph();

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.lock_rounded,
                    size: 19, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('1.0 USDC bond\nposted on the call',
                    style: TextStyle(
                        color: t.text,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _outcome(t, Icons.verified_rounded, 'Right call', 'returned', t.yes),
          const SizedBox(height: 8),
          _outcome(t, Icons.gpp_bad_rounded, 'Wrong call', 'slashed', t.no),
        ],
      ),
    );
  }

  Widget _outcome(
      PulsThemeColors t, IconData icon, String label, String tag, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: t.text, fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(tag,
              style:
                  TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _VerifyButton extends StatefulWidget {
  const _VerifyButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_VerifyButton> createState() => _VerifyButtonState();
}

class _VerifyButtonState extends State<_VerifyButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    const green = Color(0xFF16A34A);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _hover ? green.withValues(alpha: 0.12) : t.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _hover ? green.withValues(alpha: 0.5) : t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, size: 14, color: green),
              const SizedBox(width: 7),
              Text('See the bond contract on-chain',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 5),
              Icon(Icons.open_in_new_rounded, size: 13, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Capability card ───────────────────────────────────────────────────────────
class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.label,
    required this.title,
    required this.body,
    required this.accent,
  });
  final String label;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body,
              style:
                  TextStyle(color: t.textMuted, fontSize: 13.5, height: 1.55)),
        ],
      ),
    );
  }
}

// ── "What the AI decides" callout ─────────────────────────────────────────────
class _DecidesStrip extends StatelessWidget {
  const _DecidesStrip();

  static const _items = [
    'Is this forecast worth paying for?',
    'How much of the bankroll to risk',
    'Which side has an edge — or hold',
    'How big a bond to stake on the call',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (r) => PulsColors.pulseGradient.createShader(r),
              child: const Icon(Icons.psychology_rounded,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text('WHAT THE AI ACTUALLY DECIDES',
                style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [for (final it in _items) _chip(t, it)],
        ),
      ],
    );
  }

  Widget _chip(PulsThemeColors t, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 14, color: t.brand),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    color: t.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

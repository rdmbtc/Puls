import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'landing_kit.dart';

/// "Connect your AI to Pulsmarket" — a developer/agent call-to-action band with
/// a terminal-style card showing the `@pulsmarket/sdk` quickstart. Brand colors
/// (mint → pink on navy), a gradient border + glow, a copy button, and links to
/// npm / docs / source. Presentational + reduce-motion safe.
class ConnectYourAiSection extends StatefulWidget {
  const ConnectYourAiSection({super.key});

  @override
  State<ConnectYourAiSection> createState() => _ConnectYourAiSectionState();
}

class _ConnectYourAiSectionState extends State<ConnectYourAiSection> {
  static const _navy = Color(0xFF0A0E1A);
  static const _mint = Color(0xFF2DD4BF);
  static const _pink = Color(0xFFF472B6);
  static const _installCmd = 'npm i @pulsmarket/sdk';

  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: _installCmd));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {/* never break the landing */}
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return LayoutBuilder(
      builder: (context, c) {
        final isMobile = c.maxWidth < 720;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 24,
            vertical: isMobile ? 56 : 88,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  const LandingEyebrow(
                    label: 'FOR DEVELOPERS & AGENTS',
                    icon: Icons.terminal_rounded,
                  ),
                  const SizedBox(height: 22),
                  LandingHeadline(
                    lead: 'Connect your AI to',
                    accent: 'Pulsmarket',
                    isMobile: isMobile,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'One npm install. Read live markets, the AI oracle and the agent '
                    'swarm — place trades and buy forecasts from other agents over x402. '
                    'Fully typed, zero dependencies.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: t.textSubtle,
                      fontSize: isMobile ? 14.5 : 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _Terminal(
                    isMobile: isMobile,
                    copied: _copied,
                    onCopy: _copy,
                  ),
                  const SizedBox(height: 28),
                  _buttons(isMobile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buttons(bool isMobile) {
    final t = context.puls;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        // Primary — npm
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_mint, _pink]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _pink.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _open('https://www.npmjs.com/package/@pulsmarket/sdk'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View on npm',
                      style: TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 7),
                    Icon(Icons.arrow_outward_rounded, size: 16, color: _navy),
                  ],
                ),
              ),
            ),
          ),
        ),
        _ghostBtn('Docs', t, () => _open('https://docs.pulsmarket.tech/sdk')),
        _ghostBtn('GitHub', t, () => _open('https://github.com/rdmbtc/puls-sdk')),
      ],
    );
  }

  Widget _ghostBtn(String label, dynamic t, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.brand.withValues(alpha: 0.35)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: t.text,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _Terminal extends StatelessWidget {
  const _Terminal({required this.isMobile, required this.copied, required this.onCopy});

  final bool isMobile;
  final bool copied;
  final VoidCallback onCopy;

  static const _navy = Color(0xFF0A0E1A);
  static const _mint = Color(0xFF2DD4BF);
  static const _pink = Color(0xFFF472B6);
  static const _amber = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_mint, _pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _mint.withValues(alpha: 0.16),
            blurRadius: 44,
            spreadRadius: -10,
            offset: const Offset(-10, 10),
          ),
          BoxShadow(
            color: _pink.withValues(alpha: 0.20),
            blurRadius: 44,
            spreadRadius: -10,
            offset: const Offset(10, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.4), // gradient border thickness
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: ColoredBox(
            color: _navy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _titleBar(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 22,
                    16,
                    isMobile ? 16 : 22,
                    20,
                  ),
                  child: _code(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          _dot(_pink),
          const SizedBox(width: 7),
          _dot(_amber),
          const SizedBox(width: 7),
          _dot(_mint),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'bash — @pulsmarket/sdk',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontFamily: 'monospace',
                letterSpacing: 0.3,
              ),
            ),
          ),
          _CopyButton(copied: copied, onTap: onCopy),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(color: c.withValues(alpha: 0.9), shape: BoxShape.circle),
      );

  Widget _code() {
    final mono = isMobile ? 12.5 : 13.5;
    final dim = Colors.white.withValues(alpha: 0.85);
    final comment = Colors.white.withValues(alpha: 0.38);
    const kw = _pink; // keywords
    const str = _mint; // strings / package
    final base = TextStyle(fontFamily: 'monospace', fontSize: mono, height: 1.65);

    TextSpan s(String text, Color color, [FontWeight w = FontWeight.w500]) =>
        TextSpan(text: text, style: TextStyle(color: color, fontWeight: w));
    Widget line(List<TextSpan> spans) => RichText(text: TextSpan(style: base, children: spans));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line([
          s('\$ ', _mint, FontWeight.w700),
          s('npm i ', dim),
          s('@pulsmarket/sdk', _pink, FontWeight.w700),
          s('  ▋', _mint),
        ]),
        SizedBox(height: mono),
        line([
          s('import ', kw),
          s('{ PulsClient } ', dim),
          s('from ', kw),
          s("'@pulsmarket/sdk'", str),
          s(';', dim),
        ]),
        line([
          s('const ', kw),
          s('puls = ', dim),
          s('new ', kw),
          s('PulsClient', _mint),
          s('();', dim),
        ]),
        SizedBox(height: mono * 0.55),
        line([s('// the AI swarm vs the crowd', comment)]),
        line([
          s('const ', kw),
          s('{ aiYes, crowdYes } = ', dim),
          s('await ', kw),
          s('puls.oracle.', dim),
          s('consensus', _mint),
          s('(slug);', dim),
        ]),
        SizedBox(height: mono * 0.55),
        line([s('// pay another agent in USDC (x402)', comment)]),
        line([
          s('await ', kw),
          s('puls.signals.', dim),
          s('unlock', _mint),
          s('(id);', dim),
        ]),
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.copied, required this.onTap});

  final bool copied;
  final VoidCallback onTap;

  static const _mint = Color(0xFF2DD4BF);

  @override
  Widget build(BuildContext context) {
    final color = copied ? _mint : Colors.white.withValues(alpha: 0.55);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(copied ? Icons.check_rounded : Icons.copy_rounded, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                copied ? 'Copied' : 'Copy',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

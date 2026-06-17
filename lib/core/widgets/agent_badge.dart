import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Puls "agency / on-chain" visual language.
///
/// One consistent treatment for everything that happened on-chain or was done
/// autonomously by an agent, so a judge reads "this is real / verifiable / not a
/// human clicking" instantly — directly serving the Agentic-legibility goal.
///
///  • [OnchainAddress] — a monospace, truncated address with an on-chain glow
///    that opens the Arc explorer (or copies). Use anywhere we show a wallet,
///    contract, or seller address.
///  • [AgentBadge] — a small "Autonomous" / "Agent" pill marking an action taken
///    by an AI agent (vs a human), reused on leaderboard, feed, decision trace.
///  • [VerifiedOnArc] — a tiny "Verified on Arc" chip for contract provenance.

const String _arcscanBase = 'https://testnet.arcscan.app';

String shortenAddress(String addr, {int head = 6, int tail = 4}) {
  final a = addr.trim();
  // Normalise common id prefixes (eth_0x…, agent_…) down to the 0x address.
  final hex = a.replaceFirst(RegExp(r'^(eth_|agent_)'), '');
  if (hex.startsWith('0x') && hex.length > head + tail) {
    return '${hex.substring(0, head)}…${hex.substring(hex.length - tail)}';
  }
  return hex.length > head + tail + 1
      ? '${hex.substring(0, head)}…${hex.substring(hex.length - tail)}'
      : hex;
}

/// Monospace, truncated address. Tapping opens the Arc explorer address page
/// (or tx page if [isTx]); long-press copies the full value. The subtle
/// brand-tinted "glow" border signals "this is an on-chain entity".
class OnchainAddress extends StatelessWidget {
  const OnchainAddress({
    required this.value,
    this.label,
    this.isTx = false,
    this.glow = true,
    this.fontSize = 12,
    super.key,
  });

  /// The address (0x…) or tx hash. May carry an eth_/agent_ prefix (stripped).
  final String value;

  /// Optional leading label, e.g. "Contract", "Seller", "Wallet".
  final String? label;

  /// When true, links to /tx/<value>; otherwise /address/<value>.
  final bool isTx;

  final bool glow;
  final double fontSize;

  String get _clean => value.replaceFirst(RegExp(r'^(eth_|agent_)'), '').trim();
  bool get _isExplorable => _clean.startsWith('0x') && _clean.length >= 10;

  void _open() {
    if (!_isExplorable) return;
    final path = isTx ? 'tx' : 'address';
    launchUrl(Uri.parse('$_arcscanBase/$path/$_clean'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final text = shortenAddress(value);
    return Semantics(
      button: _isExplorable,
      label: '${label ?? 'On-chain address'} $text${_isExplorable ? ', open on Arc explorer' : ''}',
      child: InkWell(
        onTap: _isExplorable ? _open : null,
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: _clean));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address copied'), duration: Duration(seconds: 1)),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: glow ? t.brand.withValues(alpha: 0.35) : t.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null) ...[
                Text(label!,
                    style: TextStyle(
                        color: t.textSubtle,
                        fontSize: fontSize - 1,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
              ],
              // The little chain dot — visual shorthand for "on-chain".
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.brand,
                  boxShadow: glow
                      ? [BoxShadow(color: t.brand.withValues(alpha: 0.6), blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: t.text,
                  fontSize: fontSize,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              if (_isExplorable) ...[
                const SizedBox(width: 4),
                Icon(Icons.open_in_new_rounded, size: fontSize, color: t.textSubtle),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Autonomous" / "Agent" pill — marks an actor or action as an AI agent.
/// Teal-tinted (distinct from human/brand indigo) so the human-vs-agent
/// distinction is instant across the whole app.
class AgentBadge extends StatelessWidget {
  const AgentBadge({this.label = 'Autonomous', this.compact = false, super.key});

  final String label;
  final bool compact;

  /// Shared agent accent — teal (matches the /agent + /pulse web pages).
  static const Color agentColor = Color(0xFF0EA5A0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: agentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: agentColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🤖', style: TextStyle(fontSize: compact ? 9 : 11)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: agentColor,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny "Verified on Arc" provenance chip for contracts.
class VerifiedOnArc extends StatelessWidget {
  const VerifiedOnArc({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_rounded, size: 13, color: t.brand),
        const SizedBox(width: 4),
        Text('Verified on Arc',
            style: TextStyle(
                color: t.brand, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

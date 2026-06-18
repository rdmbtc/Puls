import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config.dart' show appBaseUrl;
import '../../core/theme/app_theme.dart';

class ShareBetCardDialog extends StatefulWidget {
  const ShareBetCardDialog({
    required this.position,
    required this.pnl,
    super.key,
  });

  final Map<String, dynamic> position;
  final double? pnl;

  static void show(BuildContext context, Map<String, dynamic> position, double? pnl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => ShareBetCardDialog(position: position, pnl: pnl),
    );
  }

  @override
  State<ShareBetCardDialog> createState() => _ShareBetCardDialogState();
}

class _ShareBetCardDialogState extends State<ShareBetCardDialog> {
  final GlobalKey _boundaryKey = GlobalKey();

  Future<void> _copyText() async {
    final slug = widget.position['slug'] as String? ?? '';
    final side = widget.position['side'] as String? ?? 'YES';
    final question = widget.position['question'] as String? ?? 'Prediction';
    final pnlVal = widget.pnl ?? 0.0;
    
    final pnlSign = pnlVal >= 0 ? '+' : '';
    final emoji = pnlVal >= 0 ? '🚀' : '📉';

    final text = 'I just bet $side on "$question" on Puls! '
        'My P&L is currently $pnlSign\$${pnlVal.toStringAsFixed(2)} USDC $emoji\n'
        'Trade predictions live: $appBaseUrl/m/$slug';

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Share text copied to clipboard!')),
      );
    }
  }

  Future<void> _shareOnX() async {
    final slug = widget.position['slug'] as String? ?? '';
    final side = widget.position['side'] as String? ?? 'YES';
    final question = widget.position['question'] as String? ?? 'Prediction';
    final pnlVal = widget.pnl ?? 0.0;
    final pnlSign = pnlVal >= 0 ? '+' : '';
    final emoji = pnlVal >= 0 ? '🚀' : '📉';

    final text = 'I just bet $side on "$question" on Puls 👀\n'
        'P&L: $pnlSign\$${pnlVal.toStringAsFixed(2)} USDC $emoji — live on Arc Testnet.';
    final url = '$appBaseUrl/m/$slug';
    final intent = Uri.parse('https://twitter.com/intent/tweet'
        '?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(url)}');
    await launchUrl(intent, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyLink() async {
    final slug = widget.position['slug'] as String? ?? '';
    final url = '$appBaseUrl/m/$slug';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Market URL copied to clipboard!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final position = widget.position;
    final side = position['side'] as String? ?? 'YES';
    final isYes = side == 'YES';
    final isUp = (widget.pnl ?? 0) >= 0;

    final question = position['question'] as String? ?? 'Prediction Market';
    final entryPrice = (position['entryPrice'] as num?)?.toDouble() ?? 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Visual Card Container
          RepaintBoundary(
            key: _boundaryKey,
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isUp
                      ? [const Color(0xFF0A0E1A), const Color(0xFF1B2236)]
                      : [const Color(0xFF0A0E1A), const Color(0xFF2A1233)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: (isUp ? t.yes : t.no).withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Branding Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bolt_rounded, color: t.brand, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'PULS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Arc Testnet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Prediction Question
                  Text(
                    question,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),

                  // Position Side + Entry Price
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isYes ? t.yes.withValues(alpha: 0.15) : t.no.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (isYes ? t.yes : t.no).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          isYes ? 'YES' : 'NO',
                          style: TextStyle(
                            color: isYes ? t.yes : t.no,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Entry: ${(entryPrice * 100).toStringAsFixed(0)}¢',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // PnL display
                  if (widget.pnl != null) ...[
                    Text(
                      'TOTAL PROFIT',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${isUp ? '+' : ''}\$${widget.pnl!.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isUp ? t.yes : t.no,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'USDC',
                          style: TextStyle(
                            color: isUp ? t.yes.withValues(alpha: 0.7) : t.no.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Footer Attestation link
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: PulsColors.amber.withValues(alpha: 0.8),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Verifiable Attestation on Arc Testnet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Actions Row below card
          Container(
            width: 340,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _xButton(_shareOnX, t),
                _actionBtn(Icons.link_rounded, 'Copy Link', _copyLink, t),
                _actionBtn(Icons.chat_bubble_outline_rounded, 'Copy Text', _copyText, t),
                _actionBtn(Icons.close_rounded, 'Close', () => Navigator.pop(context), t),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _xButton(VoidCallback onTap, PulsThemeColors t) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: t.brand,
            child: const Text(
              '𝕏',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Post on X',
          style: TextStyle(color: t.brand, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, PulsThemeColors t) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: t.surfaceRaised,
            foregroundColor: t.text,
            child: Icon(icon, size: 18),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(color: t.textSubtle, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

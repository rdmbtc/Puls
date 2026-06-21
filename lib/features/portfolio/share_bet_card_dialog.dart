import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/puls_snack.dart';
import '../../core/config.dart' show appBaseUrl;
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_saver.dart';

/// Premium, shareable P&L card for a position — Polymarket-style. Shows the
/// brand logo, the market, the side + entry, a hero P&L with % return, and a
/// QR that deep-links to the market. On web the card can be downloaded as a PNG.
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
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => ShareBetCardDialog(position: position, pnl: pnl),
    );
  }

  @override
  State<ShareBetCardDialog> createState() => _ShareBetCardDialogState();
}

class _ShareBetCardDialogState extends State<ShareBetCardDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _saving = false;

  // Bright on-dark variants so the card pops on its navy background.
  static const _up = Color(0xFF34E5C0);
  static const _down = Color(0xFFF87171);

  String get _slug => widget.position['slug'] as String? ?? '';
  String get _marketUrl => '$appBaseUrl/m/$_slug';

  @override
  void initState() {
    super.initState();
    // Make sure the logo is decoded before the user taps "Download".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) precacheImage(const AssetImage('assets/logo.png'), context);
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _download() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ctx = _boundaryKey.currentContext;
      if (ctx == null) throw Exception('no card');
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      // Render at 3x for a crisp, social-ready image.
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw Exception('no bytes');
      final bytes = data.buffer.asUint8List();
      final ok = await PulsImageSaver.savePng(
          bytes, 'puls-pnl-${_slug.isEmpty ? 'prediction' : _slug}.png');
      if (!mounted) return;
      if (ok) {
        PulsSnack.success(context, 'P&L card saved to your downloads 🎉');
      } else {
        await _copyText();
        if (mounted) {
          PulsSnack.show(context,
              'Image download is available on the web app — share text copied instead.');
        }
      }
    } catch (_) {
      if (mounted) PulsSnack.error(context, 'Could not generate the image.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyText() async {
    final side = widget.position['side'] as String? ?? 'YES';
    final question = widget.position['question'] as String? ?? 'Prediction';
    final pnlVal = widget.pnl ?? 0.0;
    final pnlSign = pnlVal >= 0 ? '+' : '';
    final emoji = pnlVal >= 0 ? '🚀' : '📉';
    final text = 'I bet $side on "$question" on Puls! '
        'P&L: $pnlSign\$${pnlVal.toStringAsFixed(2)} USDC $emoji\n'
        'Trade predictions live on Arc: $_marketUrl';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) PulsSnack.success(context, 'Share text copied to clipboard!');
  }

  Future<void> _shareOnX() async {
    final side = widget.position['side'] as String? ?? 'YES';
    final question = widget.position['question'] as String? ?? 'Prediction';
    final pnlVal = widget.pnl ?? 0.0;
    final pnlSign = pnlVal >= 0 ? '+' : '';
    final emoji = pnlVal >= 0 ? '🚀' : '📉';
    final text = 'I bet $side on "$question" on Puls 👀\n'
        'P&L: $pnlSign\$${pnlVal.toStringAsFixed(2)} USDC $emoji — live on Arc.';
    final intent = Uri.parse('https://twitter.com/intent/tweet'
        '?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(_marketUrl)}');
    await launchUrl(intent, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _marketUrl));
    if (mounted) PulsSnack.success(context, 'Market URL copied to clipboard!');
  }

  // ── UI ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final pos = widget.position;
    final side = pos['side'] as String? ?? 'YES';
    final isYes = side == 'YES';
    final pnlVal = widget.pnl;
    final hasPnl = pnlVal != null;
    final isUp = (pnlVal ?? 0) >= 0;
    final sideColor = isYes ? _up : _down;
    final pnlColor = isUp ? _up : _down;

    final question = pos['question'] as String? ?? 'Prediction Market';
    final entryPrice = (pos['entryPrice'] as num?)?.toDouble() ?? 0.0;
    final amount = (pos['usdcAmount'] as num?)?.toDouble() ?? 0.0;
    final pnlPct = (hasPnl && amount > 0) ? (pnlVal / amount) * 100 : null;
    final nowValue = hasPnl ? amount + pnlVal : null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── The capturable card ──────────────────────────────────────
            RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B1020), Color(0xFF141A2E)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: pnlColor.withValues(alpha: 0.22),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Soft radial glow in the P&L colour.
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            pnlColor.withValues(alpha: 0.18),
                            pnlColor.withValues(alpha: 0.0),
                          ]),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand header — real logo + wordmark + network pill
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 9),
                            const Text(
                              'Puls',
                              style: TextStyle(
                                fontFamily: PulsColors.fontDisplay,
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: const Text(
                                'ARC TESTNET',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // Side + entry + invested
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                              decoration: BoxDecoration(
                                color: sideColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: sideColor.withValues(alpha: 0.45)),
                              ),
                              child: Text(
                                isYes ? 'BOUGHT YES' : 'BOUGHT NO',
                                style: TextStyle(
                                  color: sideColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Entry ${(entryPrice * 100).toStringAsFixed(0)}¢',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Market question
                        Text(
                          question,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.32,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 24),

                        // Hero P&L
                        Text(
                          hasPnl ? (isUp ? 'PROFIT' : 'LOSS') : 'YOUR POSITION',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              hasPnl
                                  ? '${isUp ? '+' : '-'}\$${pnlVal.abs().toStringAsFixed(2)}'
                                  : '\$${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: hasPnl ? pnlColor : Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'USDC',
                                style: TextStyle(
                                  color: (hasPnl ? pnlColor : Colors.white).withValues(alpha: 0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Return % badge + context
                        Row(
                          children: [
                            if (pnlPct != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: pnlColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                      color: pnlColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${isUp ? '+' : ''}${pnlPct.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: pnlColor,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (pnlPct != null) const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                nowValue != null
                                    ? '\$${amount.toStringAsFixed(0)} → \$${nowValue.toStringAsFixed(2)}'
                                    : '\$${amount.toStringAsFixed(2)} invested',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                        const SizedBox(height: 16),

                        // Footer — URL + scan-to-trade QR
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'pulsmarket.tech',
                                    style: TextStyle(
                                      color: _up,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Scan to predict & trade in USDC',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: QrImageView(
                                data: _marketUrl,
                                version: QrVersions.auto,
                                size: 58,
                                padding: EdgeInsets.zero,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF0B1020),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF0B1020),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Actions ──────────────────────────────────────────────────
            SizedBox(
              width: 360,
              child: Column(
                children: [
                  if (PulsImageSaver.isSupported)
                    GestureDetector(
                      onTap: _download,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: PulsColors.pulseGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: PulsColors.brandPink.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.4),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.download_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Download image',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  if (PulsImageSaver.isSupported) const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _xButton(_shareOnX, t),
                      _actionBtn(Icons.link_rounded, 'Copy Link', _copyLink, t),
                      _actionBtn(Icons.chat_bubble_outline_rounded, 'Copy Text', _copyText, t),
                      _actionBtn(Icons.close_rounded, 'Close', () => Navigator.pop(context), t),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _xButton(VoidCallback onTap, PulsThemeColors t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: t.brand,
            child: const Text(
              '𝕏',
              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('Post on X',
            style: TextStyle(color: t.brand, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, PulsThemeColors t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: t.surfaceRaised,
            foregroundColor: t.text,
            child: Icon(icon, size: 19),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(color: t.textSubtle, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

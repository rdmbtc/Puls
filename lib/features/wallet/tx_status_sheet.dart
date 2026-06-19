import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:haptic_kit/haptic_kit.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/confetti_burst.dart';
import '../onboarding/onboarding_flags.dart';
import 'wallet_service.dart';

import '../../core/config.dart' show backendUrl, appBaseUrl;
const _backendUrl = backendUrl;

enum TxStatus { pending, complete, failed }

class TxStatusSheet extends StatefulWidget {
  const TxStatusSheet({
    required this.txId,
    required this.side,
    required this.amount,
    this.isBuy = true,
    this.walletService,
    super.key,
  });

  final String txId;
  final String side; // 'YES' or 'NO'
  final double amount; // USDC spent (buy) or shares sold (sell)
  final bool isBuy;
  final WalletService? walletService;

  static Future<void> show(
    BuildContext context, {
    required String txId,
    required String side,
    required double amount,
    bool isBuy = true,
    WalletService? walletService,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => TxStatusSheet(
        txId: txId,
        side: side,
        amount: amount,
        isBuy: isBuy,
        walletService: walletService,
      ),
    );
  }

  @override
  State<TxStatusSheet> createState() => _TxStatusSheetState();
}

class _TxStatusSheetState extends State<TxStatusSheet> {
  TxStatus _status = TxStatus.pending;
  String? _txHash;
  Timer? _timer;
  int _dots = 0;
  late final DateTime _startTime;
  double? _elapsedSeconds;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _poll();
    // Animate dots while pending
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_status == TxStatus.pending && mounted) {
        setState(() => _dots = (_dots + 1) % 4);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    // Poll fast (200ms) for the first 15 attempts (~3s) to capture Arc's sub-second finality
    // and avoid artificially inflating measured latency due to client-side poll cadence.
    for (int i = 0; i < 60; i++) {
      final delay = i < 15 ? const Duration(milliseconds: 200) : const Duration(seconds: 2);
      await Future.delayed(delay);
      if (!mounted) return;
      try {
        final res = await http.get(
          Uri.parse('$_backendUrl/api/trade/status?txId=${widget.txId}'),
        );
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final state = data['state'] as String? ?? '';
        final txHash = data['txHash'] as String?;

        if (state == 'COMPLETE') {
          final elapsed = DateTime.now().difference(_startTime).inMilliseconds / 1000.0;
          if (mounted) {
            setState(() {
              _status = TxStatus.complete;
              _txHash = txHash;
              _elapsedSeconds = elapsed;
            });
          }
          Haptics.notification(HapticNotificationStyle.success);
          _timer?.cancel();
          widget.walletService?.notifyTrade();
          if (!OnboardingFlags.firstTradeSeen) {
            OnboardingFlags.markFirstTradeSeen();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('🎉 Your first trade is live on Arc!'),
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
          return;
        } else if (state == 'FAILED' || state == 'DENIED' || state == 'CANCELLED') {
          if (mounted) setState(() => _status = TxStatus.failed);
          Haptics.notification(HapticNotificationStyle.error);
          _timer?.cancel();
          return;
        }
      } catch (_) {}
    }
    // Timeout
    if (mounted) setState(() => _status = TxStatus.failed);
    _timer?.cancel();
  }

  Future<void> _shareOnX() async {
    final secs =
        _elapsedSeconds != null ? _elapsedSeconds!.toStringAsFixed(2) : '0.45';
    final text = widget.isBuy
        ? 'I just went ${widget.side} with \$${widget.amount.toStringAsFixed(2)} USDC on Puls 👀\n'
            'Confirmed on Arc Testnet in ${secs}s — gas paid in USDC, no ETH. 🚀'
        : 'Just closed a ${widget.side} position on Puls — settled on Arc Testnet in ${secs}s. 🚀';
    final intent = Uri.parse('https://twitter.com/intent/tweet'
        '?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(appBaseUrl)}');
    await launchUrl(intent, mode: LaunchMode.externalApplication);
  }

  String _formatShares(double shares) {
    String str = shares.toStringAsFixed(4);
    while (str.contains('.') && (str.endsWith('0') || str.endsWith('.'))) {
      if (str.endsWith('.')) {
        str = str.substring(0, str.length - 1);
        break;
      }
      str = str.substring(0, str.length - 1);
    }
    return str;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: -120,
            child: ConfettiBurst(play: _status == TxStatus.complete),
          ),
          _sheetBody(context),
        ],
      ),
    );
  }

  Widget _sheetBody(BuildContext context) {
    final t = context.puls;
    final isYes = widget.side == 'YES';
    final sideColor = isYes ? t.yes : t.no;
    final sideBg = isYes ? t.yesBg : t.noBg;

    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          // Status icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _status == TxStatus.pending
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 56, height: 56,
                    child: CircularProgressIndicator(color: t.brand, strokeWidth: 3),
                  )
                : Image.network(
                    _status == TxStatus.complete
                        ? 'https://img.icons8.com/?id=hJniet82Bq1U&format=png&size=256'
                        : 'https://img.icons8.com/?id=DXECg4JU1n2x&format=png&size=256',
                    key: ValueKey(_status),
                    width: 56, height: 56,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: _status == TxStatus.complete ? t.yesBg : t.noBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _status == TxStatus.complete
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        color: _status == TxStatus.complete ? t.yes : t.no,
                        size: 28,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          // Title
          Text(
            _status == TxStatus.pending
                ? 'Processing${'.' * (_dots + 1)}'
                : _status == TxStatus.complete
                    ? 'Trade Confirmed!'
                    : 'Trade Failed',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          // Subtitle
          Text(
            _status == TxStatus.pending
                ? (widget.isBuy
                    ? 'Your USDC is being sent to Arc Testnet'
                    : 'Selling your ${widget.side} shares on Arc Testnet')
                : _status == TxStatus.complete
                    ? (widget.isBuy
                        ? 'You bought \$${widget.amount.toStringAsFixed(2)} ${widget.side} on Arc Testnet'
                        : 'You sold ${_formatShares(widget.amount)} ${widget.side} shares on Arc Testnet')
                    : 'Transaction was not completed',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Side badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: sideBg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.side,
                    style: TextStyle(color: sideColor, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(width: 8),
                Text(
                    widget.isBuy
                        ? '\$${widget.amount.toStringAsFixed(2)} USDC'
                        : '${_formatShares(widget.amount)} shares',
                    style: TextStyle(color: sideColor, fontSize: 14)),
              ],
            ),
          ),
          if (_txHash != null && _status == TxStatus.complete) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('https://testnet.arcscan.app/tx/$_txHash'),
                mode: LaunchMode.externalApplication,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.brand.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 13, color: t.brand),
                    const SizedBox(width: 6),
                    Text(
                      'View on Arcscan',
                      style: TextStyle(color: t.brand, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_txHash!.substring(0, 8)}…${_txHash!.substring(_txHash!.length - 6)}',
                      style: TextStyle(color: t.textSubtle, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Arc differentiator — the "USDC paid the gas" money-shot
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 13, color: t.yes),
                const SizedBox(width: 4),
                Text(
                  'Confirmed in ${_elapsedSeconds != null ? _elapsedSeconds!.toStringAsFixed(2) : "0.45"}s · gas paid in USDC, no ETH',
                  style: TextStyle(color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ] else if (_txHash != null) ...[
            const SizedBox(height: 12),
            Text('TX: ${_txHash!.substring(0, 10)}...${_txHash!.substring(_txHash!.length - 6)}',
                style: TextStyle(color: t.textSubtle, fontSize: 11)),
          ],
          const SizedBox(height: 24),
          if (_status == TxStatus.complete && widget.isBuy) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton.icon(
                onPressed: _shareOnX,
                style: TextButton.styleFrom(
                  backgroundColor: t.brandSubtle,
                  foregroundColor: t.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: t.brand.withValues(alpha: 0.3)),
                  ),
                ),
                icon: const Text('𝕏',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                label: const Text('Share on X',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: _status != TxStatus.pending
                  ? () => Navigator.of(context).pop()
                  : null,
              style: TextButton.styleFrom(
                backgroundColor: _status != TxStatus.pending ? t.brand : t.border,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _status == TxStatus.pending ? 'Please wait…' : 'Done',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
    );
  }
}

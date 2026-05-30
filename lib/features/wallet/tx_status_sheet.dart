import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:haptic_kit/haptic_kit.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'wallet_service.dart';

import '../../core/config.dart' show backendUrl;
const _backendUrl = backendUrl;

enum TxStatus { pending, complete, failed }

class TxStatusSheet extends StatefulWidget {
  const TxStatusSheet({
    required this.txId,
    required this.side,
    required this.amount,
    this.walletService,
    super.key,
  });

  final String txId;
  final String side; // 'YES' or 'NO'
  final double amount;
  final WalletService? walletService;

  static Future<void> show(
    BuildContext context, {
    required String txId,
    required String side,
    required double amount,
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

  @override
  void initState() {
    super.initState();
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
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final res = await http.get(
          Uri.parse('$_backendUrl/api/trade/status?txId=${widget.txId}'),
        );
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final state = data['state'] as String? ?? '';
        final txHash = data['txHash'] as String?;

        if (state == 'COMPLETE') {
          if (mounted) setState(() { _status = TxStatus.complete; _txHash = txHash; });
          Haptics.notification(HapticNotificationStyle.success);
          _timer?.cancel();
          widget.walletService?.refreshBalance();
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

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isYes = widget.side == 'YES';
    final sideColor = isYes ? t.yes : t.no;
    final sideBg = isYes ? t.yesBg : t.noBg;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Column(
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
                ? 'Your USDC is being sent to Arc Testnet'
                : _status == TxStatus.complete
                    ? 'You bought \$${widget.amount.toStringAsFixed(2)} ${widget.side} on Arc Testnet'
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
                Text('\$${widget.amount.toStringAsFixed(2)} USDC',
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
                  'Settled in <1s · gas paid in USDC, no ETH',
                  style: TextStyle(color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ] else if (_txHash != null) ...[
            const SizedBox(height: 12),
            Text('TX: ${_txHash!.substring(0, 10)}...${_txHash!.substring(_txHash!.length - 6)}',
                style: TextStyle(color: t.textSubtle, fontSize: 11)),
          ],
          const SizedBox(height: 24),
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
      ),
    );
  }
}

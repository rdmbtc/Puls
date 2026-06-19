import 'package:flutter/material.dart';
import '../../core/widgets/puls_snack.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/confetti_burst.dart';
import 'payment_receipt.dart';

/// A single celebratory bottom sheet shared by every creator payment flow
/// (Alpha unlock, tip, copy). Shows confetti, the amount + creator, and — when
/// the backend returns proof — a copyable Circle receipt chip plus a link to
/// the seller's address page on the explorer.
///
/// Degrades gracefully: when [PaymentReceipt.hasProof] is false (or the payment
/// is not live) the proof block is hidden and no misleading on-chain claim is
/// made.
class PaymentReceiptSheet extends StatelessWidget {
  const PaymentReceiptSheet({super.key, required this.receipt});

  final PaymentReceipt receipt;

  static Future<void> show(BuildContext context, PaymentReceipt receipt) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentReceiptSheet(receipt: receipt),
    );
  }

  String _amount() {
    final a = receipt.amountUsd;
    final s = a < 0.01 ? a.toStringAsFixed(3) : a.toStringAsFixed(2);
    return '\$$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final showProof = receipt.live && receipt.hasProof;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
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
            child: ConfettiBurst(play: receipt.live),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: t.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Success ring with indigo glow
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.surface,
                  border: Border.all(color: t.border),
                  boxShadow: [
                    BoxShadow(
                      color: t.brand.withValues(alpha: 0.18),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(Icons.check_rounded, color: t.yes, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                '${_amount()} → ${receipt.creatorHandle}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: PulsColors.fontDisplay,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                receipt.live
                    ? 'Settled on Arc · USDC · paid to the creator'
                    : 'Activates at launch — you were not charged',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: PulsColors.fontSans,
                  fontSize: 13,
                  color: t.textMuted,
                ),
              ),
              if (showProof) ...[
                const SizedBox(height: 20),
                _ReceiptChip(receiptId: receipt.receiptId!, t: t),
                if (receipt.sellerExplorerUrl != null) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse(receipt.sellerExplorerUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(
                      'View seller on arcscan  ↗',
                      style: TextStyle(
                        fontFamily: PulsColors.fontSans,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.brand,
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.brand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontFamily: PulsColors.fontSans,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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

class _ReceiptChip extends StatelessWidget {
  const _ReceiptChip({required this.receiptId, required this.t});

  final String receiptId;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Clipboard.setData(ClipboardData(text: receiptId));
          PulsSnack.show(context, 'Circle receipt copied',
              duration: const Duration(seconds: 2));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CIRCLE RECEIPT',
                style: TextStyle(
                  fontFamily: PulsColors.fontSans,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: t.textSubtle,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  receiptId,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: PulsColors.fontSans,
                    fontSize: 12,
                    color: t.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.copy_rounded, size: 14, color: t.textSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

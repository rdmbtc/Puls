import 'package:flutter/material.dart';
import '../../core/widgets/puls_snack.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../app/puls_app.dart';

/// Deposit (show your Arc address to receive USDC) + Withdraw (send USDC from
/// your Puls wallet to any Arc address). Two tabs in one sheet.
class FundsSheet extends StatefulWidget {
  const FundsSheet({super.key, this.startOnWithdraw = false});
  final bool startOnWithdraw;

  static void show(BuildContext context, {bool withdraw = false}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: FundsSheet(startOnWithdraw: withdraw),
      ),
    );
  }

  @override
  State<FundsSheet> createState() => _FundsSheetState();
}

class _FundsSheetState extends State<FundsSheet> {
  late bool _withdraw = widget.startOnWithdraw;
  final _to = TextEditingController();
  final _amount = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _to.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final to = _to.text.trim();
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(to)) {
      setState(() => _error = 'Enter a valid Arc (0x…) address.');
      return;
    }
    if (amt <= 0) { setState(() => _error = 'Enter an amount.'); return; }
    setState(() { _busy = true; _error = null; _result = null; });
    final wallet = WalletServiceScope.of(context);
    try {
      final r = await wallet.withdrawUsdc(to: to, amountUsdc: amt);
      if (!mounted) return;
      setState(() { _busy = false; _result = r; });
      WalletServiceScope.of(context).notifyTrade();
    } catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _error = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final ws = WalletServiceScope.of(context).state;
    final addr = ws.walletAddress ?? '';
    final bal = ws.usdcBalance;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          // Tab toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
            child: Row(children: [
              Expanded(child: _tab(t, 'Deposit', !_withdraw, () => setState(() { _withdraw = false; _error = null; _result = null; }))),
              const SizedBox(width: 4),
              Expanded(child: _tab(t, 'Withdraw', _withdraw, () => setState(() { _withdraw = true; _error = null; _result = null; }))),
            ]),
          ),
          const SizedBox(height: 18),

          if (_result != null)
            _WithdrawSuccess(t: t, result: _result!)
          else if (!_withdraw) ...[
            Row(children: [
              Text('Your Puls wallet on Arc', style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: t.brand.withValues(alpha: 0.30)),
                ),
                child: Text('Arc Testnet · USDC',
                    style: TextStyle(color: t.brand, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
              ),
            ]),
            const SizedBox(height: 8),
            Text('Scan or copy your address to receive USDC and fund your account. From another chain? Use Bridge instead.',
                style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            // Scannable QR of the receiving address (always light bg so it scans in dark mode).
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.border),
                  boxShadow: [
                    BoxShadow(color: t.brand.withValues(alpha: 0.10), blurRadius: 22, offset: const Offset(0, 8)),
                  ],
                ),
                child: addr.isEmpty
                    ? const SizedBox(
                        width: 172, height: 172,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : QrImageView(
                        data: addr,
                        version: QrVersions.auto,
                        size: 172,
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0A0E1A)),
                        dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0A0E1A)),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
              child: Row(children: [
                Expanded(child: SelectableText(addr.isEmpty ? '—' : addr,
                    style: TextStyle(color: t.text, fontSize: 13, fontFeatures: const [FontFeature.tabularFigures()]))),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: addr.isEmpty ? null : () {
                    Clipboard.setData(ClipboardData(text: addr));
                    PulsSnack.show(context, 'Address copied');
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Icon(Icons.copy_rounded, size: 18, color: t.brand),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 13, color: t.textSubtle),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Only send USDC on Arc Testnet to this address. Other assets or networks may be lost.',
                    style: TextStyle(color: t.textSubtle, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w500)),
              ),
            ]),
            const SizedBox(height: 12),
            if (addr.isNotEmpty)
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://testnet.arcscan.app/address/$addr'), mode: LaunchMode.externalApplication),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.open_in_new_rounded, size: 13, color: t.brand),
                  const SizedBox(width: 5),
                  Text('View on Arcscan', style: TextStyle(color: t.brand, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ]),
              ),
          ] else ...[
            Row(children: [
              Text('Withdraw USDC', style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => _amount.text = (double.tryParse(bal) ?? 0).toStringAsFixed(2),
                child: Text('Balance: $bal', style: TextStyle(color: t.brand, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            _field(t, 'Destination Arc address', _to, hint: '0x…'),
            const SizedBox(height: 12),
            _field(t, 'Amount (USDC)', _amount, hint: '0',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: t.no.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: t.no.withValues(alpha: 0.4))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.error_outline_rounded, size: 16, color: t.no),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: TextStyle(color: t.no, fontSize: 12.5, height: 1.4))),
                ]),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _send,
                style: ElevatedButton.styleFrom(backgroundColor: t.brand, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }

  Widget _tab(PulsThemeColors t, String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? t.brand.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: sel ? t.brand : Colors.transparent, width: sel ? 1.2 : 1),
        ),
        child: Text(label, style: TextStyle(color: sel ? t.brand : t.textSubtle, fontSize: 13, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _field(PulsThemeColors t, String label, TextEditingController c,
      {String? hint, TextInputType? keyboard, List<TextInputFormatter>? formatters}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: t.textSubtle, fontSize: 11.5, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      TextField(
        controller: c, keyboardType: keyboard, inputFormatters: formatters,
        style: TextStyle(color: t.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: t.textSubtle, fontSize: 13),
          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          filled: true, fillColor: t.surfaceRaised,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.brand)),
        ),
      ),
    ]);
  }
}

class _WithdrawSuccess extends StatelessWidget {
  const _WithdrawSuccess({required this.t, required this.result});
  final PulsThemeColors t;
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final url = result['explorerUrl'] as String?;
    final amt = result['amountUsdc'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.check_circle_rounded, color: t.yes, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text('Sent ${amt ?? ''} USDC', style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 14),
      if (url != null)
        GestureDetector(
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: t.brandSubtle, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.brand.withValues(alpha: 0.35))),
            child: Row(children: [
              Icon(Icons.open_in_new_rounded, size: 14, color: t.brand),
              const SizedBox(width: 8),
              Text('View on Arcscan', style: TextStyle(color: t.brand, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        )
      else
        Text('Submitted — confirming on-chain…', style: TextStyle(color: t.textMuted, fontSize: 12.5)),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: OutlinedButton.styleFrom(foregroundColor: t.text, side: BorderSide(color: t.border),
              padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }
}

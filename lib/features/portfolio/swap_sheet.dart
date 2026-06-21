import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/puls_sheet.dart';
import '../../app/puls_app.dart';

/// Swap USDC <-> EURC on Arc via Circle App Kit (real on-chain, from the user's
/// Circle MPC wallet). Estimate-first; surfaces thin-liquidity errors honestly.
class SwapSheet extends StatefulWidget {
  const SwapSheet({super.key});

  static void show(BuildContext context) {
    PulsSheet.show<void>(context, builder: (_) => const SwapSheet());
  }

  @override
  State<SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<SwapSheet> {
  final _amount = TextEditingController(text: '1');
  String _tokenIn = 'USDC';
  String _tokenOut = 'EURC';
  bool _busy = false;
  String? _error;
  String? _estOut;
  Map<String, dynamic>? _result;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_onAmountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _estimate());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amount.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _estimate);
  }

  void _flip() {
    setState(() {
      final t = _tokenIn;
      _tokenIn = _tokenOut;
      _tokenOut = t;
      _estOut = null;
    });
    _estimate();
  }

  Future<void> _estimate() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) { setState(() => _estOut = null); return; }
    final wallet = WalletServiceScope.of(context);
    try {
      final r = await wallet.estimateSwap(tokenIn: _tokenIn, tokenOut: _tokenOut, amountIn: amt);
      if (!mounted) return;
      final est = r['estimate'] as Map<String, dynamic>?;
      final out = est?['estimatedOutput'] as Map<String, dynamic>?;
      setState(() {
        _estOut = out?['amount']?.toString();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _estOut = null);
    }
  }

  Future<void> _swap() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) { setState(() => _error = 'Enter an amount.'); return; }
    setState(() { _busy = true; _error = null; _result = null; });
    final wallet = WalletServiceScope.of(context);
    try {
      final r = await wallet.swap(tokenIn: _tokenIn, tokenOut: _tokenOut, amountIn: amt);
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
    return PulsSheetSurface(
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.currency_exchange_rounded, color: t.brand, size: 20),
            const SizedBox(width: 8),
            const AnimatedGradientText('Swap stablecoins', textAlign: TextAlign.left, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 6),
          Text('Swap USDC ↔ EURC on Arc, powered by Circle. Settles from your Puls wallet.',
              style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4)),
          const SizedBox(height: 18),

          if (_result != null)
            _SwapSuccess(t: t, result: _result!)
          else ...[
            // From
            _tokenBox(t, label: 'You pay', token: _tokenIn, child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '0'),
            )),
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                onTap: _flip,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: t.surfaceRaised, shape: BoxShape.circle, border: Border.all(color: t.border)),
                  child: Icon(Icons.swap_vert_rounded, color: t.brand, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // To (estimated)
            _tokenBox(t, label: 'You receive (est.)', token: _tokenOut, child: Text(
              _estOut ?? '—',
              style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w800),
            )),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: t.no.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.no.withValues(alpha: 0.4)),
                ),
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
                onPressed: _busy ? null : _swap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.brand, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Swap $_tokenIn → $_tokenOut', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),
            Text('Testnet — Arc swap liquidity can be thin; quotes update as you type.',
                style: TextStyle(color: t.textSubtle, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _tokenBox(PulsThemeColors t, {required String label, required String token, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: child),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: t.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.border)),
                child: Text(token, style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwapSuccess extends StatelessWidget {
  const _SwapSuccess({required this.t, required this.result});
  final PulsThemeColors t;
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final out = result['amountOut']?.toString();
    final tokenOut = result['tokenOut']?.toString() ?? '';
    final url = result['explorerUrl'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.check_circle_rounded, color: t.yes, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(
            out != null ? 'Swapped — received $out $tokenOut' : 'Swap complete',
            style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 14),
        if (url != null)
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: t.brandSubtle, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.brand.withValues(alpha: 0.35))),
              child: Row(children: [
                Icon(Icons.open_in_new_rounded, size: 14, color: t.brand),
                const SizedBox(width: 8),
                Text('View swap on Arcscan', style: TextStyle(color: t.brand, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.text, side: BorderSide(color: t.border),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../app/puls_app.dart';
import '../wallet/web3_wallet_bridge.dart';

/// In-app CCTP bridge: move USDC from Ethereum Sepolia → Arc Testnet via
/// Circle's Cross-Chain Transfer Protocol (Forwarding Service). Web-only —
/// requires a browser wallet (MetaMask) to sign the source-chain burn.
class BridgeSheet extends StatefulWidget {
  const BridgeSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const BridgeSheet(),
      ),
    );
  }

  @override
  State<BridgeSheet> createState() => _BridgeSheetState();
}

class _BridgeSheetState extends State<BridgeSheet> {
  final _amount = TextEditingController(text: '1');
  bool _busy = false;
  bool _toPuls = true; // default: mint to the user's Puls (Circle MPC) wallet
  String? _error;
  BridgeResult? _result;

  // Multi-chain source state.
  bool _loadingBal = true;
  BridgeBalances? _balances;
  String _source = 'ethereum-sepolia';

  // Non-EVM chains CCTP supports but our MetaMask flow can't sign for — shown
  // honestly as info, not a fake button.
  static const _nonEvm = [
    ('Algorand Testnet', 'Pera wallet (non-EVM)'),
    ('Aptos Testnet', 'Petra wallet (non-EVM)'),
  ];

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    final b = await getBridgeBalances();
    if (!mounted) return;
    setState(() {
      _balances = b;
      _loadingBal = false;
      // Default to the chain with the highest balance, if any.
      if (b.chains.isNotEmpty) {
        final best = b.chains.reduce((a, c) => c.usdc > a.usdc ? c : a);
        if (best.usdc > 0) _source = best.key;
      }
    });
  }

  double get _sourceBal {
    final c = _balances?.chains;
    if (c == null) return 0;
    for (final x in c) {
      if (x.key == _source) return x.usdc;
    }
    return 0;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _bridge() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    final pulsAddr = WalletServiceScope.of(context).state.walletAddress;
    if (_toPuls && (pulsAddr == null || pulsAddr.isEmpty)) {
      setState(() => _error = 'No Puls wallet found — sign in first, or switch the destination to your connected wallet.');
      return;
    }
    setState(() { _busy = true; _error = null; _result = null; });
    final res = await bridgeUsdcToArc(amt, recipient: _toPuls ? pulsAddr : null, sourceKey: _source);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res.error != null) {
        _error = res.error;
      } else {
        _result = res;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final hasWallet = hasBrowserWallet();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: t.brand, size: 20),
              const SizedBox(width: 8),
              Text('Bridge USDC to Arc',
                  style: TextStyle(color: t.text, fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Move USDC from Ethereum Sepolia to Arc with Circle CCTP — Circle mints on Arc for you (no Arc gas needed).',
            style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),

          if (!hasWallet)
            _Notice(
              t: t,
              icon: Icons.info_outline_rounded,
              text: 'Bridging needs a browser wallet (MetaMask) on the web app. Open pulsmarket.tech in a desktop browser with MetaMask to bridge.',
            )
          else if (_result != null)
            _Success(t: t, result: _result!)
          else ...[
            Text('From chain', style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (_loadingBal)
              Row(children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: t.brand)),
                const SizedBox(width: 8),
                Text('Reading your USDC across chains…', style: TextStyle(color: t.textSubtle, fontSize: 12)),
              ])
            else ...[
              ...(_balances?.chains ?? const []).map((c) => _ChainRow(
                    t: t,
                    name: c.name,
                    usdc: c.usdc,
                    selected: _source == c.key,
                    onTap: () => setState(() => _source = c.key),
                  )),
              for (final ne in _nonEvm) _ChainRow(t: t, name: ne.$1, note: ne.$2, disabled: true),
            ],
            const SizedBox(height: 14),
            Text('Send to', style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _DestTab(t: t, label: 'My Puls wallet', selected: _toPuls, onTap: () => setState(() => _toPuls = true))),
                const SizedBox(width: 8),
                Expanded(child: _DestTab(t: t, label: 'Connected wallet', selected: !_toPuls, onTap: () => setState(() => _toPuls = false))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Amount (USDC)', style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (!_loadingBal)
                  GestureDetector(
                    onTap: _sourceBal > 0 ? () => setState(() => _amount.text = _sourceBal.toStringAsFixed(_sourceBal < 1 ? 4 : 2)) : null,
                    child: Text('Max: ${_sourceBal.toStringAsFixed(_sourceBal < 1 ? 4 : 2)}',
                        style: TextStyle(color: _sourceBal > 0 ? t.brand : t.textSubtle, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                filled: true,
                fillColor: t.surfaceRaised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.brand)),
              ),
            ),
            const SizedBox(height: 6),
            Text('Need test USDC on Sepolia? Get it free at faucet.circle.com.',
                style: TextStyle(color: t.textSubtle, fontSize: 11.5)),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _Notice(t: t, icon: Icons.error_outline_rounded, text: _error!, danger: true),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _bridge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Bridge to Arc',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 10),
              Text('Approve + burn in MetaMask, then Circle mints on Arc (~1–2 min). Keep this open.',
                  style: TextStyle(color: t.textSubtle, fontSize: 11.5)),
            ],
          ],
        ],
      ),
    );
  }
}

class _ChainRow extends StatelessWidget {
  const _ChainRow({
    required this.t,
    required this.name,
    this.usdc,
    this.note,
    this.selected = false,
    this.disabled = false,
    this.onTap,
  });
  final PulsThemeColors t;
  final String name;
  final double? usdc;
  final String? note;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? t.brand.withValues(alpha: 0.10) : t.surfaceRaised,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: selected ? t.brand : t.border, width: selected ? 1.2 : 1),
            ),
            child: Row(
              children: [
                Icon(
                  disabled
                      ? Icons.lock_outline_rounded
                      : (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
                  size: 16,
                  color: selected ? t.brand : t.textSubtle,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
                      style: TextStyle(color: t.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
                if (note != null)
                  Text(note!, style: TextStyle(color: t.textSubtle, fontSize: 11))
                else
                  Text('${(usdc ?? 0).toStringAsFixed((usdc ?? 0) < 1 ? 4 : 2)} USDC',
                      style: TextStyle(
                        color: (usdc ?? 0) > 0 ? t.yes : t.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _DestTab extends StatelessWidget {
  const _DestTab({required this.t, required this.label, required this.selected, required this.onTap});
  final PulsThemeColors t;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? t.brand.withValues(alpha: 0.14) : t.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? t.brand : t.border, width: selected ? 1.2 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? t.brand : t.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}


class _Notice extends StatelessWidget {
  const _Notice({required this.t, required this.icon, required this.text, this.danger = false});
  final PulsThemeColors t;
  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = danger ? t.no : t.textMuted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (danger ? t.no : t.textMuted).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (danger ? t.no : t.border).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: c, fontSize: 12.5, height: 1.4))),
        ],
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.t, required this.result});
  final PulsThemeColors t;
  final BridgeResult result;

  @override
  Widget build(BuildContext context) {
    final pending = result.arcTxHash == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(pending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                color: pending ? PulsColors.amber : t.yes, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pending
                    ? 'Burned on Sepolia — Circle is minting on Arc (settles shortly).'
                    : 'Bridged! USDC minted on Arc.',
                style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (result.arcTxHash != null)
          _ProofLink(t: t, label: 'View Arc mint on Arcscan',
              url: 'https://testnet.arcscan.app/tx/${result.arcTxHash}')
        else if (result.burnTxHash != null)
          _ProofLink(t: t, label: 'View burn on Etherscan',
              url: 'https://sepolia.etherscan.io/tx/${result.burnTxHash}'),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.text,
              side: BorderSide(color: t.border),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _ProofLink extends StatelessWidget {
  const _ProofLink({required this.t, required this.label, required this.url});
  final PulsThemeColors t;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.brandSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.brand.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.open_in_new_rounded, size: 14, color: t.brand),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: t.brand, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

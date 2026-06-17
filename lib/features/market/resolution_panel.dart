import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/agent_badge.dart';
import '../../data/models/market.dart';

/// "How this market resolves" — resolution transparency panel.
///
/// Shows whether a market resolves via the legacy Polymarket-consensus path
/// or through UMA's Optimistic Oracle V2 on Arc Testnet (with live oracle
/// state, dispute window and bond), plus an Arcscan link to the contract.
class ResolutionPanel extends StatefulWidget {
  const ResolutionPanel({required this.market, super.key});
  final Market market;

  @override
  State<ResolutionPanel> createState() => _ResolutionPanelState();
}

class _ResolutionPanelState extends State<ResolutionPanel> {
  Map<String, dynamic>? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uri = Uri.parse(
        '$backendUrl/api/market/resolution-status?slug=${Uri.encodeComponent(widget.market.slug)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (mounted && res.statusCode == 200) {
        setState(() {
          _status = jsonDecode(res.body) as Map<String, dynamic>;
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final status = _status;
    final isUma = status?['mode'] == 'uma';
    final oracle = status?['oracle'] as Map<String, dynamic>?;
    final resolved = status?['resolved'] == true;
    final contractAddress =
        status?['contractAddress'] as String? ?? widget.market.contractAddress;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, size: 16, color: t.brand),
              const SizedBox(width: 8),
              Text('How this market resolves',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (_loading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(color: t.brand, strokeWidth: 1.5),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (resolved) ...[
            _row(
              t,
              Icons.check_circle_rounded,
              'Outcome',
              status?['outcome'] == true ? 'Resolved YES' : 'Resolved NO',
              valueColor: status?['outcome'] == true ? t.yes : t.no,
            ),
            const SizedBox(height: 8),
          ],
          if (isUma && oracle != null) ...[
            _row(t, Icons.account_balance_rounded, 'Resolution source',
                'UMA Optimistic Oracle V2 on Arc'),
            const SizedBox(height: 8),
            _row(t, Icons.flag_rounded, 'Oracle status',
                _stateLabel(oracle['state'] as String? ?? '')),
            const SizedBox(height: 8),
            _row(t, Icons.hourglass_bottom_rounded, 'Dispute window',
                _fmtDuration(oracle['livenessSeconds'])),
            const SizedBox(height: 8),
            _row(t, Icons.shield_rounded, 'Proposer bond',
                '${oracle['bondUsdc'] ?? '–'} USDC'),
            const SizedBox(height: 10),
            Text(
              'After the deadline, anyone can propose the outcome by posting a USDC bond. '
              'If nobody disputes it during the dispute window, the market resolves '
              'on-chain — no central party needed. Disputes escalate to UMA\'s voting layer.',
              style: TextStyle(color: t.textMuted, fontSize: 12, height: 1.5),
            ),
          ] else ...[
            _row(t, Icons.public_rounded, 'Resolution source', 'Polymarket consensus'),
            const SizedBox(height: 10),
            Text(
              'After the deadline, this market resolves automatically based on the '
              'official outcome of the matching Polymarket market. The result is '
              'written on-chain on Arc Testnet and winners can claim instantly.',
              style: TextStyle(color: t.textMuted, fontSize: 12, height: 1.5),
            ),
          ],
          if (contractAddress != null && contractAddress.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const VerifiedOnArc(),
                const Spacer(),
                Flexible(
                  child: OnchainAddress(
                    value: contractAddress,
                    label: 'Contract',
                  ),
                ),
              ],
            ),
          ],
          if (isUma && oracle?['oracleExplorerUrl'] != null) ...[
            const SizedBox(height: 6),
            _link(t, 'View oracle on Arcscan',
                oracle!['oracleExplorerUrl'] as String),
          ],
        ],
      ),
    );
  }

  Widget _row(PulsThemeColors t, IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: t.textSubtle),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: t.textMuted, fontSize: 12.5)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? t.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _link(PulsThemeColors t, String label, String url) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_new_rounded, size: 13, color: t.brand),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                color: t.brand,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  String _stateLabel(String state) {
    switch (state) {
      case 'Requested':
        return 'Awaiting outcome proposal';
      case 'Proposed':
        return 'Proposed — in dispute window';
      case 'Expired':
        return 'Undisputed — ready to settle';
      case 'Disputed':
        return 'Disputed — escalated to voters';
      case 'Resolved':
      case 'Settled':
        return 'Settled by oracle';
      default:
        return 'Waiting for market deadline';
    }
  }

  String _fmtDuration(dynamic seconds) {
    final s = seconds is num ? seconds.toInt() : 0;
    if (s <= 0) return '–';
    if (s % 3600 == 0) return '${s ~/ 3600}h';
    if (s % 60 == 0) return '${s ~/ 60} min';
    return '${s}s';
  }
}

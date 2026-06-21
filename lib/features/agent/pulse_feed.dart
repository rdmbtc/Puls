import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_loader.dart';

/// Public feed of "Pulse" — the autonomous house AI trader agent.
/// Shows its on-chain identity (Circle wallet, ERC-8004 id, reputation)
/// and every trading decision with reasoning + Arcscan receipt.
class PulseFeed extends StatefulWidget {
  const PulseFeed({super.key});

  @override
  State<PulseFeed> createState() => _PulseFeedState();
}

class _Decision {
  const _Decision({
    required this.question,
    required this.side,
    required this.amount,
    required this.reasoning,
    required this.brain,
    required this.pmYes,
    required this.onChainYes,
    required this.txHash,
    required this.at,
  });

  final String question;
  final String side;
  final double amount;
  final String reasoning;
  final String brain;
  final double pmYes;
  final double onChainYes;
  final String? txHash;
  final DateTime at;
}

class _PulseFeedState extends State<PulseFeed> {
  Map<String, dynamic>? _agent;
  List<_Decision> _decisions = const [];
  bool _loading = true;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/agents/house'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('bad status');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final decisions = <_Decision>[];
      for (final raw in (body['decisions'] as List? ?? const [])) {
        final d = raw as Map<String, dynamic>;
        decisions.add(_Decision(
          question: d['question'] as String? ?? '',
          side: d['side'] as String? ?? 'YES',
          amount: (d['amount'] as num?)?.toDouble() ?? 0,
          reasoning: d['reasoning'] as String? ?? '',
          brain: d['brain'] as String? ?? 'quant',
          pmYes: (d['pmYes'] as num?)?.toDouble() ?? 0.5,
          onChainYes: (d['onChainYes'] as num?)?.toDouble() ?? 0.5,
          txHash: d['txHash'] as String?,
          at: DateTime.tryParse(d['at'] as String? ?? '') ?? DateTime.now(),
        ));
      }
      if (!mounted) return;
      setState(() {
        _agent = body['agent'] as Map<String, dynamic>?;
        _decisions = decisions;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_loading) {
      return const PulsLoader();
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _identityCard(t),
        const SizedBox(height: 20),
        Text('Decision feed',
            style: TextStyle(
                color: t.text, fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 4),
        Text(
          'Every trade below was researched, decided and executed autonomously — no human in the loop.',
          style: TextStyle(color: t.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        if (_decisions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
            ),
            child: Text(
              'Pulse is researching the markets — its first published decision will appear here shortly.',
              style: TextStyle(color: t.textMuted, fontSize: 14),
            ),
          )
        else
          ..._decisions.map((d) => _decisionCard(t, d)),
      ],
    );
  }

  Widget _identityCard(PulsThemeColors t) {
    final agent = _agent;
    final address = agent?['address'] as String? ?? '';
    final shortAddr = address.length > 12
        ? '${address.substring(0, 6)}...${address.substring(address.length - 4)}'
        : address;
    final balance = (agent?['balance'] as num?)?.toDouble() ?? 0;
    final erc8004 = agent?['erc8004Id'] as String?;
    final rep = (agent?['reputation'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.brand.withValues(alpha: 0.14), t.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.brand.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [t.brand, PulsColors.brandMint]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/puls-pfp.png',
                      width: 52, height: 52, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Pulse',
                          style: TextStyle(
                              color: t.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 19)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.yesBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('AUTONOMOUS',
                            style: TextStyle(
                                color: t.yes,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6)),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Text(
                      'House AI trader · researches every market, trades real USDC on Arc',
                      style: TextStyle(color: t.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _chip(t, Icons.account_balance_wallet_rounded,
                  'Circle Wallet $shortAddr',
                  onTap: address.isEmpty
                      ? null
                      : () => launchUrl(Uri.parse(
                          'https://testnet.arcscan.app/address/$address'))),
              _chip(t, Icons.attach_money_rounded,
                  '${balance.toStringAsFixed(2)} USDC budget'),
              if (erc8004 != null)
                _chip(t, Icons.fingerprint_rounded, 'ERC-8004 #$erc8004'),
              if (rep > 0)
                _chip(t, Icons.verified_rounded, '$rep reputation events'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(PulsThemeColors t, IconData icon, String label,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: t.brand),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: t.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.open_in_new_rounded, size: 11, color: t.textSubtle),
            ],
          ],
        ),
      ),
    );
  }

  Widget _decisionCard(PulsThemeColors t, _Decision d) {
    final yes = d.side == 'YES';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  d.question,
                  style: TextStyle(
                      color: t.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      height: 1.3),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: yes ? t.yesBg : t.noBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'BUY ${d.side} · \$${d.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: yes ? t.yes : t.no,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.psychology_rounded, size: 14, color: t.brand),
                  const SizedBox(width: 6),
                  Text(
                    d.brain == 'llm' ? 'AI REASONING' : 'QUANT REASONING',
                    style: TextStyle(
                        color: t.textSubtle,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(d.reasoning,
                    style: TextStyle(
                        color: t.textMuted, fontSize: 13, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Consensus ${(d.pmYes * 100).toStringAsFixed(0)}¢ · On-chain ${(d.onChainYes * 100).toStringAsFixed(0)}¢',
                style: TextStyle(color: t.textSubtle, fontSize: 11.5),
              ),
              const Spacer(),
              Text(_ago(d.at),
                  style: TextStyle(color: t.textSubtle, fontSize: 11.5)),
              if (d.txHash != null && d.txHash!.isNotEmpty) ...[
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => launchUrl(Uri.parse(
                      'https://testnet.arcscan.app/tx/${d.txHash}')),
                  borderRadius: BorderRadius.circular(99),
                  child: Row(children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 13, color: t.brand),
                    const SizedBox(width: 4),
                    Text('Arcscan',
                        style: TextStyle(
                            color: t.brand,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

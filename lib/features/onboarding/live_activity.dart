import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

/// "Live from the chain" — real recent trades with Arcscan proof links and
/// real protocol stats. Renders nothing if the backend is unreachable.
class LiveActivitySection extends StatefulWidget {
  const LiveActivitySection({super.key});

  @override
  State<LiveActivitySection> createState() => _LiveActivitySectionState();
}

class _Trade {
  const _Trade(this.question, this.side, this.amount, this.txHash, this.at);
  final String question;
  final String side;
  final double amount;
  final String txHash;
  final DateTime at;
}

class _LiveActivitySectionState extends State<LiveActivitySection> {
  List<_Trade> _trades = const [];
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        http
            .get(Uri.parse('$backendUrl/api/trade/recent?limit=20'))
            .timeout(const Duration(seconds: 8)),
        http
            .get(Uri.parse('$backendUrl/api/stats'))
            .timeout(const Duration(seconds: 8)),
      ]);
      if (!mounted) return;

      final trades = <_Trade>[];
      if (results[0].statusCode == 200) {
        final seen = <String>{};
        for (final raw in json.decode(results[0].body) as List<dynamic>) {
          final j = raw as Map<String, dynamic>;
          if (j['state'] != 'COMPLETE') continue;
          final q = j['question'] as String? ?? '';
          final tx = j['tx_hash'] as String? ?? '';
          if (q.isEmpty || tx.isEmpty || !seen.add(tx)) continue;
          trades.add(_Trade(
            q,
            (j['side'] as String? ?? 'YES').toUpperCase(),
            (j['usdc_amount'] as num?)?.toDouble() ?? 0,
            tx,
            DateTime.tryParse(j['created_at'] as String? ?? '') ??
                DateTime.now(),
          ));
          if (trades.length >= 6) break;
        }
      }
      setState(() {
        _trades = trades;
        if (results[1].statusCode == 200) {
          _stats = json.decode(results[1].body) as Map<String, dynamic>;
        }
      });
    } catch (_) {
      // Section simply doesn't render — landing must never break.
    }
  }

  String _fmtInt(num? n) {
    return withThousands((n ?? 0).toInt());
  }

  @override
  Widget build(BuildContext context) {
    if (_trades.isEmpty) return const SizedBox.shrink();
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 600;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 48 : 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              Text(
                'Live from the chain',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: t.text,
                    fontSize: isMobile ? 24 : 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1),
              ),
              const SizedBox(height: 8),
              Text(
                _stats == null
                    ? 'Real trades by real users — every one verifiable on Arcscan.'
                    : '${_fmtInt(_stats!['trades'] as num?)} trades · '
                        '\$${_fmtInt(_stats!['volumeUsdc'] as num?)} USDC volume · '
                        '${_fmtInt(_stats!['marketsDeployed'] as num?)} markets deployed on Arc Testnet',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: t.textMuted, fontSize: isMobile ? 13 : 15),
              ),
              SizedBox(height: isMobile ? 24 : 36),
              Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _trades.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 1, color: t.border),
                      _TradeRow(
                          trade: _trades[i],
                          ago: timeAgo(_trades[i].at),
                          isMobile: isMobile,
                          t: t),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TradeRow extends StatefulWidget {
  const _TradeRow(
      {required this.trade,
      required this.ago,
      required this.isMobile,
      required this.t});
  final _Trade trade;
  final String ago;
  final bool isMobile;
  final PulsThemeColors t;

  @override
  State<_TradeRow> createState() => _TradeRowState();
}

class _TradeRowState extends State<_TradeRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final tr = widget.trade;
    final isYes = tr.side == 'YES';
    final sideColor = isYes ? t.yes : t.no;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('https://testnet.arcscan.app/tx/${tr.txHash}'),
          mode: LaunchMode.externalApplication,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(
              horizontal: widget.isMobile ? 14 : 20, vertical: 14),
          color: _hover
              ? t.brand.withValues(alpha: 0.04)
              : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: sideColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tr.side,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: sideColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr.question,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.text,
                      fontSize: widget.isMobile ? 12.5 : 13.5,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '\$${tr.amount.toStringAsFixed(tr.amount == tr.amount.roundToDouble() ? 0 : 2)}',
                style: TextStyle(
                    color: t.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
              if (!widget.isMobile) ...[
                const SizedBox(width: 16),
                SizedBox(
                  width: 64,
                  child: Text(
                    widget.ago,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: t.textSubtle, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Icon(Icons.open_in_new_rounded,
                  size: 14, color: _hover ? t.brand : t.textSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

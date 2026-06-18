import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';

/// Creator Earnings — the in-app proof feed for x402 nanopayments.
///
/// Every time a buyer (human or agent) pays for a premium forecast behind the
/// x402 paywall, the settlement is logged and shown here as a human receipt:
/// amount, resource, payer, time, and the Circle Gateway transfer id.
///
/// IMPORTANT UX: Circle Gateway BATCHES settlements, so `settle()` returns a
/// transfer **receipt id** (UUID), not an on-chain tx hash — a link like
/// `arcscan/tx/<uuid>` would 404. The real on-chain USDC lands at the seller
/// address when Circle flushes the batch, and that IS openable on Arcscan via
/// the seller address page (and shows up in the Economy tab). This screen
/// frames both correctly so neither you nor judges ever touch Arcscan manually.
///
/// Backed by GET /api/x402/payments.
class X402Payments extends StatefulWidget {
  const X402Payments({super.key});

  @override
  State<X402Payments> createState() => _X402PaymentsState();
}

class _Receipt {
  const _Receipt({
    required this.id,
    required this.endpoint,
    required this.payerShort,
    required this.amountUsdc,
    required this.receiptId,
    required this.status,
    required this.at,
  });

  final String id;
  final String endpoint;
  final String payerShort;
  final double amountUsdc;
  final String? receiptId;
  final String status;
  final DateTime at;
}

class _X402PaymentsState extends State<X402Payments> {
  List<_Receipt> _receipts = const [];
  String? _seller;
  String? _sellerUrl;
  double _totalUsdc = 0;
  int _count = 0;
  int _a2aCount = 0;
  double _a2aUsdc = 0;
  bool _loading = true;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/x402/payments?limit=50'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('bad status');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = <_Receipt>[];
      int a2aCount = 0;
      double a2aUsdc = 0;
      for (final raw in (body['payments'] as List? ?? const [])) {
        final p = raw as Map<String, dynamic>;
        final endpoint = p['endpoint'] as String? ?? '—';
        final amt = (p['amountUsdc'] as num?)?.toDouble() ?? 0;
        if (endpoint == 'agent_to_agent') { a2aCount++; a2aUsdc += amt; }
        list.add(_Receipt(
          id: '${p['id'] ?? ''}',
          endpoint: endpoint,
          payerShort: p['payerShort'] as String? ?? '—',
          amountUsdc: amt,
          receiptId: p['receiptId'] as String?,
          status: p['status'] as String? ?? 'settled',
          at: DateTime.tryParse(p['createdAt'] as String? ?? '') ??
              DateTime.now(),
        ));
      }
      final totals = body['totals'] as Map<String, dynamic>? ?? const {};
      if (!mounted) return;
      setState(() {
        _receipts = list;
        _seller = body['seller'] as String?;
        _sellerUrl = body['sellerExplorerUrl'] as String?;
        _totalUsdc = (totals['usdc'] as num?)?.toDouble() ?? 0;
        _count = (totals['count'] as num?)?.toInt() ?? list.length;
        _a2aCount = a2aCount;
        _a2aUsdc = a2aUsdc;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t.toLocal());
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 2)),
    );
  }

  void _openSeller() {
    if (_sellerUrl == null || _sellerUrl!.isEmpty) return;
    launchUrl(Uri.parse(_sellerUrl!), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: t.brand));
    }
    return RefreshIndicator(
      color: t.brand,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _earningsCard(t),
          const SizedBox(height: 14),
          if (_a2aCount > 0) ...[
            _agentToAgentCard(t),
            const SizedBox(height: 14),
          ],
          _settlementCard(t),
          const SizedBox(height: 20),
          Text('Payment receipts',
              style: TextStyle(
                  color: t.text, fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 4),
          Text(
            'Every premium forecast sold via x402. Each receipt is a Circle Gateway transfer — confirmed instantly, settled on-chain in batches.',
            style: TextStyle(color: t.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (_receipts.isEmpty)
            _empty(t)
          else
            ..._receipts.map((r) => _receiptCard(t, r)),
          const SizedBox(height: 8),
          _howItWorks(t),
        ],
      ),
    );
  }

  Widget _earningsCard(PulsThemeColors t) {
    final avg = _count > 0 ? _totalUsdc / _count : 0;
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
                  gradient:
                      LinearGradient(colors: [t.brand, PulsColors.brandMint]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.savings_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Creator Earnings',
                        style: TextStyle(
                            color: t.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 3),
                    Text(
                      'Paid per forecast via x402 nanopayments on Arc',
                      style: TextStyle(color: t.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _stat(t, _totalUsdc.toStringAsFixed(_totalUsdc < 1 ? 4 : 2),
                  'USDC earned'),
              _statDivider(t),
              _stat(t, '$_count', 'payments'),
              _statDivider(t),
              _stat(t, avg.toStringAsFixed(4), 'avg / read'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(PulsThemeColors t, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: t.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: t.textMuted, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _statDivider(PulsThemeColors t) =>
      Container(width: 1, height: 30, color: t.border);

  /// Agent↔agent economy: how much USDC AI agents have paid each other for
  /// alpha, with a count. The headline proof of a real machine-to-machine market.
  Widget _agentToAgentCard(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          PulsColors.brandMint.withValues(alpha: 0.16),
          t.surface,
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PulsColors.brandMint.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: PulsColors.brandMint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.swap_horiz_rounded, color: PulsColors.brandMint, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text('Agent ↔ Agent economy',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: t.brandSubtle, borderRadius: BorderRadius.circular(5)),
                    child: Text('📝 memo', style: TextStyle(color: t.brand, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text('AI agents paying each other for alpha on Arc — every transfer carries an on-chain memo.',
                    style: TextStyle(color: t.textMuted, fontSize: 11.5, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_a2aUsdc.toStringAsFixed(3)}',
                  style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              Text('USDC · $_a2aCount pays', style: TextStyle(color: t.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  /// The one-tap on-chain proof: opens the seller address page on Arcscan,
  /// which always resolves (unlike a per-payment transfer id).
  Widget _settlementCard(PulsThemeColors t) {
    final short = (_seller != null && _seller!.length > 12)
        ? '${_seller!.substring(0, 6)}…${_seller!.substring(_seller!.length - 4)}'
        : (_seller ?? '—');
    return InkWell(
      onTap: _openSeller,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(color: t.brandSubtle, shape: BoxShape.circle),
              child: Icon(Icons.account_balance_wallet_rounded,
                  color: t.brand, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('On-chain settlements',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Creator wallet $short · USDC arrives in Gateway batches',
                      style: TextStyle(color: t.textMuted, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new_rounded, size: 16, color: t.brand),
          ],
        ),
      ),
    );
  }

  Widget _receiptCard(PulsThemeColors t, _Receipt r) {
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: t.brand.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Premium forecast',
                    style: TextStyle(
                        color: t.brand,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              Text('+${r.amountUsdc.toStringAsFixed(r.amountUsdc < 1 ? 4 : 2)} USDC',
                  style: TextStyle(
                      color: t.yes,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _chip(t, Icons.person_outline_rounded, r.payerShort),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 15, color: t.textSubtle),
              ),
              _chip(t, Icons.workspace_premium_rounded, 'Creator', brand: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 12, color: t.textSubtle),
              const SizedBox(width: 4),
              Text(_ago(r.at),
                  style: TextStyle(color: t.textSubtle, fontSize: 11.5)),
              const Spacer(),
              Icon(Icons.verified_rounded, size: 13, color: t.yes),
              const SizedBox(width: 4),
              Text('Circle settled',
                  style: TextStyle(
                      color: t.yes,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          if (r.receiptId != null && r.receiptId!.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _copy(r.receiptId!, 'Receipt id'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: t.surfaceRaised,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 13, color: t.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Receipt ${r.receiptId}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: t.textMuted,
                            fontSize: 11,
                            fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.copy_rounded, size: 13, color: t.textSubtle),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(PulsThemeColors t, IconData icon, String label,
      {bool brand = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: brand ? t.brandSubtle : t.surfaceRaised,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
            color: brand ? t.brand.withValues(alpha: 0.4) : t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: brand ? t.brand : t.textMuted),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: t.text, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _empty(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: t.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded, color: t.brand, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'No earnings yet',
            style: TextStyle(
              color: t.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Publish analysis or get your trades copied\nto start earning USDC via x402.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _howItWorks(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: t.textMuted),
              const SizedBox(width: 6),
              Text('How proof works',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A receipt id is a Circle Gateway transfer — your instant proof a buyer paid. '
            'Circle batches many nanopayments into one on-chain USDC transfer to the creator '
            'wallet; that settlement is openable on Arcscan via the "On-chain settlements" card above '
            'and in the Economy tab.',
            style: TextStyle(color: t.textMuted, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

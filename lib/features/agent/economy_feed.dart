import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';

/// Economy Explorer — a live, verifiable feed of on-chain USDC activity in the
/// Puls economy (treasury + house agent). Every row links to its Arc Blockscout
/// (Arcscan) proof. Backed by GET /api/economy/feed.
class EconomyFeed extends StatefulWidget {
  const EconomyFeed({super.key});

  @override
  State<EconomyFeed> createState() => _EconomyFeedState();
}

class _Party {
  const _Party({required this.label, this.address, this.role});
  final String label;
  final String? address;
  final String? role;
}

class _Event {
  const _Event({
    required this.hash,
    required this.explorerUrl,
    required this.action,
    required this.value,
    required this.from,
    required this.to,
    required this.at,
  });

  final String hash;
  final String explorerUrl;
  final String action;
  final double value;
  final _Party from;
  final _Party to;
  final DateTime at;
}

class _EconomyFeedState extends State<EconomyFeed> {
  List<_Event> _events = const [];
  Map<String, dynamic> _metrics = const {};
  bool _loading = true;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  _Party _party(Map<String, dynamic>? raw) {
    raw ??= const {};
    return _Party(
      label: raw['label'] as String? ?? '—',
      address: raw['address'] as String?,
      role: raw['role'] as String?,
    );
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/economy/feed?limit=40'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('bad status');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final events = <_Event>[];
      for (final raw in (body['feed'] as List? ?? const [])) {
        final e = raw as Map<String, dynamic>;
        events.add(_Event(
          hash: e['hash'] as String? ?? '',
          explorerUrl: e['explorer_url'] as String? ?? '',
          action: e['action'] as String? ?? 'USDC transfer',
          value: (e['value_usdc'] as num?)?.toDouble() ?? 0,
          from: _party(e['from'] as Map<String, dynamic>?),
          to: _party(e['to'] as Map<String, dynamic>?),
          at: DateTime.tryParse(e['timestamp'] as String? ?? '') ??
              DateTime.now(),
        ));
      }
      if (!mounted) return;
      setState(() {
        _events = events;
        _metrics = body['metrics'] as Map<String, dynamic>? ?? const {};
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
          _metricsCard(t),
          const SizedBox(height: 20),
          Text('Live on-chain activity',
              style: TextStyle(
                  color: t.text, fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 4),
          Text(
            'Every USDC movement in the Puls economy — settled on Arc, verifiable on Blockscout. Tap any row for its on-chain proof.',
            style: TextStyle(color: t.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (_events.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
              ),
              child: Text(
                'No on-chain activity yet — the first verifiable transfer will appear here shortly.',
                style: TextStyle(color: t.textMuted, fontSize: 14),
              ),
            )
          else
            ..._events.map((e) => _eventCard(t, e)),
        ],
      ),
    );
  }

  Widget _metricsCard(PulsThemeColors t) {
    final vol = (_metrics['total_volume_usdc'] as num?)?.toDouble() ?? 0;
    final count = (_metrics['tx_count'] as num?)?.toInt() ?? 0;
    final avg = (_metrics['avg_payment_usdc'] as num?)?.toDouble() ?? 0;
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
                      LinearGradient(colors: [t.brand, const Color(0xFF818CF8)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Economy Explorer',
                        style: TextStyle(
                            color: t.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 3),
                    Text(
                      'On-chain proof of the Puls agent economy on Arc',
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
              _stat(t, '${vol.toStringAsFixed(2)}', 'USDC volume'),
              _statDivider(t),
              _stat(t, '$count', 'transfers'),
              _statDivider(t),
              _stat(t, avg.toStringAsFixed(2), 'avg USDC'),
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

  Widget _eventCard(PulsThemeColors t, _Event e) {
    final isOut = e.from.role == 'treasury' || e.from.role == 'agent';
    final accent = e.to.role == 'treasury' ? t.yes : (isOut ? t.brand : t.no);
    return InkWell(
      onTap: e.explorerUrl.isEmpty
          ? null
          : () => launchUrl(Uri.parse(e.explorerUrl),
              mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(e.action,
                      style: TextStyle(
                          color: accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ),
                const Spacer(),
                Text('${e.value.toStringAsFixed(e.value < 1 ? 4 : 2)} USDC',
                    style: TextStyle(
                        color: t.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(child: _partyChip(t, e.from)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 15, color: t.textSubtle),
                ),
                Flexible(child: _partyChip(t, e.to)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 12, color: t.textSubtle),
                const SizedBox(width: 4),
                Text(_ago(e.at),
                    style: TextStyle(color: t.textSubtle, fontSize: 11.5)),
                const Spacer(),
                Icon(Icons.verified_rounded, size: 13, color: t.brand),
                const SizedBox(width: 4),
                Text('Arcscan proof',
                    style: TextStyle(
                        color: t.brand,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 2),
                Icon(Icons.open_in_new_rounded, size: 11, color: t.textSubtle),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _partyChip(PulsThemeColors t, _Party p) {
    final known = p.role == 'treasury' || p.role == 'agent';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: known ? t.brandSubtle : t.surfaceRaised,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: known ? t.brand.withValues(alpha: 0.4) : t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            p.role == 'treasury'
                ? Icons.account_balance_rounded
                : p.role == 'agent'
                    ? Icons.smart_toy_rounded
                    : Icons.person_outline_rounded,
            size: 13,
            color: known ? t.brand : t.textMuted,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              p.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: t.text, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

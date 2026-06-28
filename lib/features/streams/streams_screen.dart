import 'package:flutter/material.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_loader.dart';
import '../../core/widgets/puls_snack.dart';

/// Puls Streams — pay-per-second USDC streaming on Arc (RFB 4).
///
/// A read-first view of the streaming primitive: the live config (the rate+cap
/// model, settle threshold, whether real USDC settlement is on), network-wide
/// totals, and the signed-in user's own streams with a one-tap Stop on any that
/// are still flowing. Agents drive most streams autonomously; this surface makes
/// the per-second economy visible and controllable.
class StreamsScreen extends StatefulWidget {
  const StreamsScreen({super.key});

  @override
  State<StreamsScreen> createState() => _StreamsScreenState();
}

class _StreamsScreenState extends State<StreamsScreen> {
  Map<String, dynamic>? _config;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _streams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final wallet = WalletServiceScope.of(context);
      Map<String, dynamic> config = {};
      Map<String, dynamic> summary = {};
      try { config = await wallet.streamsConfig(); } catch (_) {}
      try { summary = await wallet.streamsSummary(); } catch (_) {}
      List<Map<String, dynamic>> streams = [];
      try {
        final d = await wallet.listStreams();
        streams = ((d['streams'] as List?) ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _config = config;
        _summary = summary;
        _streams = streams;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _stop(String id) async {
    final wallet = WalletServiceScope.of(context);
    final snack = PulsSnack.of(context);
    try {
      await wallet.stopStream(id);
      snack.success('Stream stopped — settled what flowed');
      await _fetch();
    } catch (e) {
      snack.error('Stop failed: $e');
    }
  }

  static String _usd(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return '\$${n.toStringAsFixed(n < 1 ? 4 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        title: Text('Puls Streams', style: TextStyle(color: t.text, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: t.text),
      ),
      body: _loading
          ? const Center(child: PulsLoader())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                children: [
                  _intro(t),
                  const SizedBox(height: 14),
                  _configCard(t),
                  const SizedBox(height: 12),
                  _summaryCard(t),
                  const SizedBox(height: 18),
                  Text('Your streams',
                      style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_streams.isEmpty)
                    Text(
                      'No streams yet. Agents and creators open pay-per-second streams; yours appear here.',
                      style: TextStyle(color: t.textMuted, fontSize: 13),
                    )
                  else
                    ..._streams.map((s) => _streamCard(t, s)),
                ],
              ),
            ),
    );
  }

  Widget _intro(PulsThemeColors t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.bolt_rounded, color: t.brand, size: 20),
        const SizedBox(width: 6),
        Text('Pay-per-second on Arc',
            style: TextStyle(color: t.text, fontWeight: FontWeight.w900, fontSize: 18)),
      ]),
      const SizedBox(height: 6),
      Text(
        'Authorize a rate (\$/sec) and a cap once — value then settles by the second in USDC, '
        'auto-pausing the instant flow stops. Start, pause, or tap stop.',
        style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.35),
      ),
    ]);
  }

  Widget _card(PulsThemeColors t, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _row(PulsThemeColors t, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: t.textSubtle, fontSize: 12.5)),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: valueColor ?? t.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _configCard(PulsThemeColors t) {
    final c = _config ?? {};
    final live = c['live'] == true;
    return _card(t, [
      Row(children: [
        Text('Streaming', style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 14)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (live ? t.yes : t.brand).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(live ? 'LIVE · USDC' : 'DEMO',
              style: TextStyle(color: live ? t.yes : t.brand, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ),
      ]),
      const SizedBox(height: 8),
      _row(t, 'Network', '${c['network'] ?? 'Arc Testnet'}'),
      _row(t, 'Settle threshold', _usd(c['settleThresholdUsdc'] ?? 0.01)),
      _row(t, 'Auto-pause after', '${c['staleSec'] ?? 45}s idle'),
    ]);
  }

  Widget _summaryCard(PulsThemeColors t) {
    final s = _summary ?? {};
    return _card(t, [
      Text('Network totals', style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 14)),
      const SizedBox(height: 8),
      _row(t, 'Streams', '${s['totalStreams'] ?? 0}  ·  ${s['active'] ?? 0} active'),
      _row(t, 'Streamed', _usd(s['streamedUsdc'] ?? 0)),
      _row(t, 'Settled on-chain', _usd(s['settledUsdc'] ?? 0), valueColor: t.yes),
    ]);
  }

  Widget _streamCard(PulsThemeColors t, Map<String, dynamic> s) {
    final status = '${s['status'] ?? ''}';
    final isActive = status == 'active';
    final isPaused = status == 'paused';
    final statusColor = isActive ? t.yes : (isPaused ? t.brand : t.textSubtle);
    final id = '${s['id'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: t.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(status.isEmpty ? '—' : status,
              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('${_usd(s['ratePerSecUsdc'])}/s',
              style: TextStyle(color: t.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        if ((s['resource'] ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${s['resource']}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.textMuted, fontSize: 12)),
          ),
        Row(children: [
          Expanded(child: Text('streamed ${_usd(s['accruedUsdc'])}', style: TextStyle(color: t.textSubtle, fontSize: 11.5))),
          Expanded(child: Text('settled ${_usd(s['settledUsdc'])}', style: TextStyle(color: t.textSubtle, fontSize: 11.5))),
          Expanded(child: Text('cap ${_usd(s['capUsdc'])}', textAlign: TextAlign.right, style: TextStyle(color: t.textSubtle, fontSize: 11.5))),
        ]),
        if (isActive || isPaused) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: id.isEmpty ? null : () => _stop(id),
              icon: Icon(Icons.stop_circle_outlined, size: 16, color: t.no),
              label: Text('Stop', style: TextStyle(color: t.no, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ]),
    );
  }
}

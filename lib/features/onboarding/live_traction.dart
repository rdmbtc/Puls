import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart' show backendUrl;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/count_up_text.dart';
import 'landing_kit.dart';

/// "Live traction" — real, on-chain numbers pulled live from /api/stats so
/// judges can see Puls is a working economy, not a slideware demo. Organic
/// activity only: early seed-liquidity wallets are tracked separately in the
/// API and deliberately excluded here (honest accounting).
///
/// The section simply does not render if the API is unreachable — the landing
/// must never break.
class LiveTractionSection extends StatefulWidget {
  const LiveTractionSection({super.key});

  @override
  State<LiveTractionSection> createState() => _LiveTractionSectionState();
}

class _LiveTractionSectionState extends State<LiveTractionSection> {
  Map<String, dynamic>? _s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/stats'))
          .timeout(const Duration(seconds: 8));
      if (!mounted || res.statusCode != 200) return;
      final j = json.decode(res.body) as Map<String, dynamic>;
      if (mounted) setState(() => _s = j);
    } catch (_) {
      // Never break the landing on a stats hiccup.
    }
  }

  num _n(String k) => (_s?[k] as num?) ?? 0;

  num _nano() {
    final np = _s?['nanopayments'];
    if (np is Map && np['count'] is num) return np['count'] as num;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const SizedBox.shrink();
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 760;

    final stats = <(num, String, String)>[
      (_n('agentTrades'), 'Autonomous agent trades', 'on Arc — no human in the loop'),
      (_nano(), 'x402 USDC payments', 'agent → agent · agent → creator'),
      (_n('marketsDeployed'), 'Markets deployed', '${_n('marketsResolved')} resolved on-chain'),
      (_n('agents'), 'Live autonomous agents', 'each with an ERC-8004 identity'),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 52 : 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const LandingEyebrow(label: 'LIVE ON-CHAIN TRACTION', live: true),
              const SizedBox(height: 20),
              LandingHeadline(
                lead: 'Not a demo —',
                accent: 'a working economy.',
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 36 : 60),
              if (isMobile)
                Column(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _TractionCard(
                          value: stats[i].$1,
                          label: stats[i].$2,
                          sub: stats[i].$3),
                    ],
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(
                        child: _TractionCard(
                            value: stats[i].$1,
                            label: stats[i].$2,
                            sub: stats[i].$3),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 18),
              Text(
                'Live from /api/stats · organic activity only — seed liquidity excluded',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TractionCard extends StatelessWidget {
  const _TractionCard(
      {required this.value, required this.label, required this.sub});
  final num value;
  final String label;
  final String sub;

  String _fmt(double v) {
    final n = v.round();
    final str = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) b.write(',');
      b.write(str[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CountUpText(
            value.toDouble(),
            builder: (context, v) => ShaderMask(
              shaderCallback: (r) => PulsColors.pulseGradient.createShader(r),
              child: Text(
                _fmt(v),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    height: 1.0,
                    fontFeatures: PulsColors.tabularFigures),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                  color: t.text,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2)),
          const SizedBox(height: 4),
          Text(sub,
              style:
                  TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4)),
        ],
      ),
    );
  }
}

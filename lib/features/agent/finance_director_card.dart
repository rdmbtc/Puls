import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/config.dart' show backendUrl;
import '../../core/widgets/tactile.dart';
import '../../core/widgets/puls_snack.dart';
import '../../app/puls_app.dart';

/// AI Finance Director — a paid (x402 / USDC) agent that reads the user's whole
/// portfolio (balance + open positions + win/loss record) and returns a
/// STRUCTURED, risk-managed basket of +EV predicts sized to their balance, each
/// with a direct link to the market. Flagship of the personal "My Agent" tab.
class FinanceDirectorCard extends StatefulWidget {
  const FinanceDirectorCard({super.key});

  @override
  State<FinanceDirectorCard> createState() => _FinanceDirectorCardState();
}

class _FinanceDirectorCardState extends State<FinanceDirectorCard> {
  final _client = http.Client();
  bool _loadingPreview = false;
  bool _busy = false;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _plan;
  String _risk = 'balanced';
  String? _error;

  String? get _userId => WalletServiceScope.of(context).state.userId;

  Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    final s = Supabase.instance.client.auth.currentSession;
    if (s != null) h['Authorization'] = 'Bearer ${s.accessToken}';
    return h;
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    if (_userId == null) {
      PulsSnack.error(context, 'Sign in to use the Finance Director');
      return;
    }
    setState(() {
      _loadingPreview = true;
      _error = null;
    });
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/api/agent/director/preview'),
              headers: _headers)
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        throw Exception('Could not read your portfolio (${res.statusCode})');
      }
      final r = jsonDecode(res.body) as Map<String, dynamic>;
      if (mounted) setState(() => _preview = r);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _unlock() async {
    final uid = _userId;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await _client
          .post(Uri.parse('$backendUrl/api/agent/director/order'),
              headers: _headers,
              body: jsonEncode({'userId': uid, 'riskProfile': _risk}))
          .timeout(const Duration(seconds: 120));
      final r = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        throw Exception(r['error'] ?? 'Failed (${res.statusCode})');
      }
      if (mounted) setState(() => _plan = r);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String? link) async {
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.brand.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.surface, t.brand.withValues(alpha: 0.06)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🎯', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('Finance Director',
              style: TextStyle(
                  color: t.text, fontSize: 16, fontWeight: FontWeight.w900)),
          const Spacer(),
          _badge(t, 'x402 · paid', t.brand),
        ]),
        const SizedBox(height: 5),
        Text(
          'Pay in USDC → I read your whole portfolio and build a structured, risk-managed basket of +EV predicts sized to your balance — each with a direct link. Money-back if my basket loses.',
          style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.35),
        ),
        const SizedBox(height: 12),
        if (_plan != null)
          _planView(t)
        else if (_preview != null)
          _previewView(t)
        else
          _intro(t),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: t.no, fontSize: 12)),
        ],
      ]),
    );
  }

  Widget _intro(PulsThemeColors t) => SizedBox(
        width: double.infinity,
        child: _primaryBtn(
          t,
          _loadingPreview ? 'Reading your portfolio…' : 'Analyze my portfolio',
          _loadingPreview ? null : _loadPreview,
        ),
      );

  Widget _previewView(PulsThemeColors t) {
    final p = _preview!;
    final price = (p['priceUsdc'] as num?)?.toDouble() ?? 0.5;
    final wr = p['winRate'];
    final bal = (p['balance'] as num?)?.toDouble() ?? 0;
    final picks = (p['candidatePicks'] as num?)?.toInt() ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: t.surfaceRaised, borderRadius: BorderRadius.circular(10)),
        child: Text('${p['teaser'] ?? ''}',
            style: TextStyle(color: t.text, fontSize: 13, height: 1.35)),
      ),
      const SizedBox(height: 10),
      Row(children: [
        _stat(t, 'Balance', '\$${bal.toStringAsFixed(2)}'),
        const SizedBox(width: 8),
        _stat(t, 'Win rate', wr == null ? '—' : '$wr%'),
        const SizedBox(width: 8),
        _stat(t, '+EV picks', '$picks'),
      ]),
      const SizedBox(height: 12),
      Text('RISK PROFILE',
          style: TextStyle(
              color: t.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1)),
      const SizedBox(height: 6),
      Row(children: [
        _riskChip(t, 'safe', 'Safe'),
        const SizedBox(width: 8),
        _riskChip(t, 'balanced', 'Balanced'),
        const SizedBox(width: 8),
        _riskChip(t, 'aggressive', 'Aggressive'),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: _primaryBtn(
          t,
          _busy
              ? 'Building your portfolio…'
              : 'Unlock full plan · \$${price.toStringAsFixed(2)}',
          _busy ? null : _unlock,
        ),
      ),
    ]);
  }

  Widget _planView(PulsThemeColors t) {
    final p = _plan!;
    final picks = (p['picks'] as List?) ?? const [];
    final ewr = p['expectedWinRate'];
    final total = (p['totalStakeUsdc'] as num?)?.toDouble() ?? 0;
    final g = p['guarantee'] is Map ? p['guarantee'] as Map : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${p['summary'] ?? ''}',
          style: TextStyle(
              color: t.text,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Row(children: [
        _stat(t, 'Picks', '${picks.length}'),
        const SizedBox(width: 8),
        _stat(t, 'Total stake', '\$${total.toStringAsFixed(2)}'),
        const SizedBox(width: 8),
        _stat(t, 'Exp. win', ewr == null ? '—' : '$ewr%'),
      ]),
      const SizedBox(height: 12),
      if (g != null && g['moneyBack'] == true) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: t.yes.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.yes.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Icon(Icons.verified_user_rounded, size: 16, color: t.yes),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              'Money-back guarantee — if this basket loses, I refund your \$${(g['feeUsdc'] as num?)?.toStringAsFixed(2) ?? '0.50'} fee, settled on Arc.',
              style: TextStyle(
                  color: t.text,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600),
            )),
          ]),
        ),
      ],
      if (picks.isEmpty)
        Text('No +EV picks clear the bar right now — holding cash is fine.',
            style: TextStyle(color: t.textMuted, fontSize: 12.5)),
      for (final pick in picks) _pickTile(t, pick as Map<String, dynamic>),
      const SizedBox(height: 6),
      if (p['riskNote'] != null)
        Text('⚠ ${p['riskNote']}',
            style: TextStyle(color: t.textMuted, fontSize: 11.5, height: 1.3)),
      const SizedBox(height: 4),
      if (p['disclaimer'] != null)
        Text('${p['disclaimer']}',
            style: TextStyle(color: t.textSubtle, fontSize: 10)),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: _ghostBtn(t, 'Build a new plan', () {
          setState(() {
            _plan = null;
          });
        }),
      ),
    ]);
  }

  Widget _pickTile(PulsThemeColors t, Map<String, dynamic> pick) {
    final side = '${pick['side'] ?? ''}';
    final isYes = side == 'YES';
    final size = (pick['sizeUsdc'] as num?)?.toDouble() ?? 0;
    final pct = pick['sizePct'];
    final tier = '${pick['tier'] ?? ''}';
    final cons = pick['consensusYes'];
    return Tactile(
      onTap: () => _open(pick['link'] as String?),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: t.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.border)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _tierBadge(t, tier),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: (isYes ? t.yes : t.no).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5)),
              child: Text(side,
                  style: TextStyle(
                      color: isYes ? t.yes : t.no,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
            const Spacer(),
            Text('\$${size.toStringAsFixed(2)}${pct != null ? ' · $pct%' : ''}',
                style: TextStyle(
                    color: t.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text('${pick['title'] ?? pick['slug'] ?? ''}',
              style: TextStyle(
                  color: t.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25)),
          if (pick['rationale'] != null) ...[
            const SizedBox(height: 3),
            Text('${pick['rationale']}',
                style: TextStyle(
                    color: t.textMuted, fontSize: 11.5, height: 1.3)),
          ],
          const SizedBox(height: 5),
          Row(children: [
            if (cons != null)
              Text('Consensus $cons¢ YES',
                  style: TextStyle(color: t.textSubtle, fontSize: 10.5)),
            const Spacer(),
            Icon(Icons.open_in_new_rounded, size: 13, color: t.brand),
            const SizedBox(width: 3),
            Text('Open market',
                style: TextStyle(
                    color: t.brand,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }

  // ── small UI helpers ──────────────────────────────────────────────────────
  Widget _badge(PulsThemeColors t, String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: TextStyle(
                color: c, fontSize: 9.5, fontWeight: FontWeight.w800)),
      );

  Widget _stat(PulsThemeColors t, String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
              color: t.surfaceRaised, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: t.text, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: t.textMuted, fontSize: 10)),
          ]),
        ),
      );

  Widget _riskChip(PulsThemeColors t, String value, String label) {
    final sel = _risk == value;
    return Expanded(
      child: Tactile(
        onTap: () => setState(() => _risk = value),
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? t.brand : t.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? t.brand : t.border),
          ),
          child: Text(label,
              style: TextStyle(
                  color: sel ? Colors.white : t.text,
                  fontSize: 11.5,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _tierBadge(PulsThemeColors t, String tier) {
    final c = tier == 'core'
        ? t.yes
        : tier == 'hedge'
            ? const Color(0xFF8B5CF6)
            : t.brand;
    final label = tier.isEmpty ? 'pick' : tier;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(5)),
      child: Text(label.toUpperCase(),
          style:
              TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  Widget _primaryBtn(PulsThemeColors t, String label, VoidCallback? onTap) =>
      Tactile(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: onTap == null
                ? null
                : LinearGradient(
                    colors: [t.brand, const Color(0xFFEC4899)]),
            color: onTap == null ? t.border : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800)),
        ),
      );

  Widget _ghostBtn(PulsThemeColors t, String label, VoidCallback onTap) =>
      Tactile(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.border),
          ),
          child: Text(label,
              style: TextStyle(
                  color: t.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      );
}

import 'package:flutter/material.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../profile/profile_screen.dart' show GlassCard;

/// Alpha — paid premium analysis (creator layer).
///
/// "Forecaster = creator, paid per read." Each premium forecast shows a free
/// teaser; the full thesis unlocks for a sub-cent USDC micro-payment that goes
/// straight to the creator (real on-chain transfer, visible in the Earnings
/// tab). Backed by GET /api/alpha/list, GET /api/alpha/:id, POST /api/alpha/:id/unlock.
///
/// Live payments are gated server-side by ALPHA_PAID_ENABLED; when off, the UI
/// honestly shows "activates at launch" instead of charging.
class AlphaScreen extends StatefulWidget {
  const AlphaScreen({super.key});

  @override
  State<AlphaScreen> createState() => _AlphaScreenState();
}

class _AlphaScreenState extends State<AlphaScreen> {
  bool _loading = true;
  String? _error;
  bool _live = false;
  List<Map<String, dynamic>> _signals = [];
  bool _loaded = false;

  // signalId -> full thesis (once unlocked + fetched)
  final Map<String, String> _theses = {};
  final Set<String> _busy = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await WalletServiceScope.of(context).getAlphaList();
      if (!mounted) return;
      setState(() {
        _live = data['live'] == true;
        _signals = ((data['signals'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception:', '').trim();
        _loading = false;
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _viewUnlocked(String id) async {
    if (_theses.containsKey(id)) return;
    setState(() => _busy.add(id));
    try {
      final data = await WalletServiceScope.of(context).getAlphaSignal(id);
      final signal = data['signal'] as Map<String, dynamic>?;
      final thesis = signal?['thesis'] as String?;
      if (thesis != null && mounted) setState(() => _theses[id] = thesis);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _unlock(Map<String, dynamic> sig) async {
    final id = sig['id'] as String;
    final wallet = WalletServiceScope.of(context);
    if (wallet.state.userId == null) {
      _snack('Sign in to unlock premium analysis.');
      return;
    }
    final price = (sig['priceUsdc'] as num?)?.toDouble() ?? 0;
    final confirmed = await _confirmUnlock(context.puls, sig['title']?.toString() ?? 'this analysis', price);
    if (confirmed != true) return;

    setState(() => _busy.add(id));
    try {
      final res = await wallet.unlockAlpha(id);
      if (!mounted) return;
      if (res['ok'] == true) {
        final signal = res['signal'] as Map<String, dynamic>?;
        final thesis = signal?['thesis'] as String?;
        setState(() {
          if (thesis != null) _theses[id] = thesis;
          final idx = _signals.indexWhere((s) => s['id'] == id);
          if (idx >= 0) _signals[idx] = {..._signals[idx], 'unlocked': true};
        });
        _snack(res['alreadyUnlocked'] == true
            ? 'Already unlocked — opening analysis.'
            : 'Unlocked • \$${price.toStringAsFixed(price < 0.01 ? 4 : 2)} paid to creator.');
      } else {
        // Gated (live:false) — honest "coming at launch".
        _snack(res['message']?.toString() ?? 'Paid analysis activates at launch.');
      }
    } catch (e) {
      _snack(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<bool?> _confirmUnlock(PulsThemeColors t, String title, double price) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Text('Unlock analysis',
                style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              'Unlock the full thesis for "$title". A one-time \$${price.toStringAsFixed(price < 0.01 ? 4 : 2)} USDC '
              'nanopayment goes directly to the creator (settled on Arc — shows in the Earnings tab).',
              style: TextStyle(color: t.textSubtle, fontSize: 13, height: 1.4),
            ),
            if (!_live) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Paid unlocks activate at launch — no charge right now.',
                    style: TextStyle(color: t.brand, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Unlock for \$${price.toStringAsFixed(price < 0.01 ? 4 : 2)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_loading) return Center(child: CircularProgressIndicator(color: t.brand));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: t.no, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(backgroundColor: t.brand),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: t.brand,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: t.brand, size: 20),
              const SizedBox(width: 8),
              Text('Premium analysis',
                  style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pay creators per read. Each forecast unlocks for a sub-cent USDC nanopayment on Arc.',
            style: TextStyle(color: t.textSubtle, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          ..._signals.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _AlphaCard(
                  signal: s,
                  thesis: _theses[s['id']],
                  busy: _busy.contains(s['id']),
                  onUnlock: () => _unlock(s),
                  onView: () => _viewUnlocked(s['id'] as String),
                  t: t,
                ),
              )),
        ],
      ),
    );
  }
}

class _AlphaCard extends StatelessWidget {
  const _AlphaCard({
    required this.signal,
    required this.thesis,
    required this.busy,
    required this.onUnlock,
    required this.onView,
    required this.t,
  });

  final Map<String, dynamic> signal;
  final String? thesis;
  final bool busy;
  final VoidCallback onUnlock;
  final VoidCallback onView;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final unlocked = signal['unlocked'] == true;
    final stance = (signal['stance'] ?? '').toString();
    final isYes = stance == 'YES';
    final conf = ((signal['confidence'] as num?)?.toDouble() ?? 0) * 100;
    final price = (signal['priceUsdc'] as num?)?.toDouble() ?? 0;
    final edge = (signal['edgeBps'] as num?)?.toInt() ?? 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(signal['title']?.toString() ?? 'Premium forecast',
                    style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isYes ? t.yes : t.no).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(stance,
                    style: TextStyle(color: isYes ? t.yes : t.no, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _meta(Icons.bolt_rounded, '${conf.toStringAsFixed(0)}% conf'),
              const SizedBox(width: 12),
              _meta(Icons.trending_up_rounded, '+$edge bps'),
              const SizedBox(width: 12),
              _meta(Icons.schedule_rounded, signal['horizon']?.toString() ?? '—'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            unlocked && thesis != null ? thesis! : (signal['teaser']?.toString() ?? ''),
            style: TextStyle(color: t.textSubtle, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 6),
          Text('by @${signal['creatorHandle'] ?? 'puls'}',
              style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (unlocked && thesis != null)
            Row(
              children: [
                Icon(Icons.lock_open_rounded, size: 16, color: t.yes),
                const SizedBox(width: 6),
                Text('Unlocked', style: TextStyle(color: t.yes, fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: busy ? null : (unlocked ? onView : onUnlock),
                icon: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(unlocked ? Icons.menu_book_rounded : Icons.lock_outline_rounded, size: 18, color: Colors.white),
                label: Text(
                  unlocked ? 'View analysis' : 'Unlock for \$${price.toStringAsFixed(price < 0.01 ? 4 : 2)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.brand,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: t.textMuted),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../payments/payment_receipt.dart';
import '../payments/payment_receipt_sheet.dart';
import '../profile/profile_screen.dart' show GlassCard;
import 'alpha_actions.dart';

/// Alpha — paid premium analysis (creator layer).
///
/// "Forecaster = creator, paid per read." Each premium forecast shows a free
/// teaser; the full thesis unlocks for a sub-cent USDC micro-payment that goes
/// straight to the creator (real on-chain transfer, visible in the Earnings
/// tab). Backed by GET /api/alpha/list, GET /api/alpha/:id, POST /api/alpha/:id/unlock.
///
/// Live payments are gated server-side by ALPHA_PAID_ENABLED; when off, the UI
/// honestly shows "activates at launch" instead of charging.
/// Fixed one-tap tip amount (USDC). Server validates against TIP_PRESETS.
const double _kTipAmount = 0.05;

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
    // Tiered friction: confirm once per device, then unlocks are one-tap.
    if (AlphaFriction.unlockNeedsConfirm) {
      final confirmed = await _confirmUnlock(context.puls, sig['title']?.toString() ?? 'this analysis', price);
      if (confirmed != true) return;
      AlphaFriction.markUnlockConfirmed();
    }

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
        if (res['alreadyUnlocked'] == true) {
          _snack('Already unlocked — opening analysis.');
        } else {
          if (!mounted) return;
          await PaymentReceiptSheet.show(
            context,
            PaymentReceipt.fromResponse(
              res,
              amountUsd: price,
              creatorHandle: '@${sig['creatorHandle'] ?? 'puls'}',
            ),
          );
        }
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

  // One-tap tip to the forecaster — fires after a 5s Undo window, then settles
  // a small real USDC nanopayment and shows the unified receipt sheet.
  void _tip(Map<String, dynamic> sig) {
    final id = sig['id'] as String;
    final wallet = WalletServiceScope.of(context);
    if (wallet.state.userId == null) {
      _snack('Sign in to tip forecasters.');
      return;
    }
    final handle = '@${sig['creatorHandle'] ?? 'puls'}';
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final tip = DeferredTip(
      delay: const Duration(seconds: 5),
      onFire: () async {
        messenger.hideCurrentSnackBar(); // clear the "Tipping…" bar before the receipt
        try {
          final res = await wallet.tipCreator(amountUsdc: _kTipAmount, context: 'alpha:$id');
          if (!mounted) return;
          await PaymentReceiptSheet.show(
            context,
            PaymentReceipt.fromResponse(res, amountUsd: _kTipAmount, creatorHandle: handle),
          );
        } catch (e) {
          _snack(e.toString().replaceAll('Exception:', '').trim());
        }
      },
      onUndo: () => messenger.hideCurrentSnackBar(),
    )..start();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text('Tipping \$${_kTipAmount.toStringAsFixed(2)} to $handle'),
        action: SnackBarAction(label: 'Undo', onPressed: tip.cancel),
      ),
    );
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
                  onTip: () => _tip(s),
                  tipAmount: _kTipAmount,
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
    required this.onTip,
    required this.tipAmount,
    required this.t,
  });

  final Map<String, dynamic> signal;
  final String? thesis;
  final bool busy;
  final VoidCallback onUnlock;
  final VoidCallback onView;
  final VoidCallback onTip;
  final double tipAmount;
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
          if (unlocked && thesis != null)
            _MarkdownLite(text: thesis!, t: t)
          else
            Text(
              signal['teaser']?.toString() ?? '',
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
                const Spacer(),
                // One-tap tip: thank the forecaster with a small USDC nanopayment.
                TextButton.icon(
                  onPressed: busy ? null : onTip,
                  icon: Icon(Icons.volunteer_activism_rounded, size: 16, color: t.brand),
                  label: Text('Tip \$${tipAmount.toStringAsFixed(2)}',
                      style: TextStyle(color: t.brand, fontSize: 12, fontWeight: FontWeight.w800)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            )
          else
            _ShimmerUnlockButton(
              price: price,
              unlocked: unlocked,
              busy: busy,
              onPressed: busy ? null : (unlocked ? onView : onUnlock),
              t: t,
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

/// Minimal markdown renderer for unlocked alpha theses — no extra dependency.
/// Handles headings (#/##/###), full-line bold labels (**...**), bullet lists
/// (- ...) and inline **bold** spans. Anything else renders as a paragraph.
class _MarkdownLite extends StatelessWidget {
  const _MarkdownLite({required this.text, required this.t});

  final String text;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];
    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(heading.group(2)!.replaceAll('**', ''),
              style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w900)),
        ));
        continue;
      }
      final fullBold = RegExp(r'^\*\*(.+?)\*\*:?$').firstMatch(trimmed);
      if (fullBold != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(fullBold.group(1)!.replaceAll('**', ''),
              style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w800)),
        ));
        continue;
      }
      final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Icon(Icons.circle, size: 5, color: t.brand),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: t.textSubtle, fontSize: 13, height: 1.45),
                    children: _inlineSpans(bullet.group(1)!),
                  ),
                ),
              ),
            ],
          ),
        ));
        continue;
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(
          text: TextSpan(
            style: TextStyle(color: t.textSubtle, fontSize: 13, height: 1.5),
            children: _inlineSpans(trimmed),
          ),
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  List<TextSpan> _inlineSpans(String line) {
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    var index = 0;
    for (final m in re.allMatches(line)) {
      if (m.start > index) spans.add(TextSpan(text: line.substring(index, m.start)));
      spans.add(TextSpan(
        text: m.group(1),
        style: TextStyle(color: t.text, fontWeight: FontWeight.w800),
      ));
      index = m.end;
    }
    if (index < line.length) spans.add(TextSpan(text: line.substring(index)));
    if (spans.isEmpty) spans.add(TextSpan(text: line));
    return spans;
  }
}

class _ShimmerUnlockButton extends StatefulWidget {
  const _ShimmerUnlockButton({
    required this.price,
    required this.unlocked,
    required this.busy,
    required this.onPressed,
    required this.t,
  });

  final double price;
  final bool unlocked;
  final bool busy;
  final VoidCallback? onPressed;
  final PulsThemeColors t;

  @override
  State<_ShimmerUnlockButton> createState() => _ShimmerUnlockButtonState();
}

class _ShimmerUnlockButtonState extends State<_ShimmerUnlockButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final unlocked = widget.unlocked;
    final busy = widget.busy;

    if (unlocked) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: widget.onPressed,
          icon: const Icon(Icons.menu_book_rounded, size: 18, color: Colors.white),
          label: const Text('View analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: t.brand,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final x = _ctrl.value;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment(x * 3 - 2, 0),
              end: Alignment(x * 3 - 1, 0),
              colors: [
                t.brand,
                t.brand.withValues(alpha: 0.85),
                PulsColors.brandMint, // pulse highlight (logo mint), was indigo
                t.brand.withValues(alpha: 0.85),
                t.brand,
              ],
              stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: t.brand.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: widget.onPressed,
            icon: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.white),
            label: Text(
              busy ? 'Unlocking…' : 'Unlock for \$${widget.price.toStringAsFixed(widget.price < 0.01 ? 4 : 2)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        );
      },
    );
  }
}

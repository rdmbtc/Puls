import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart' show backendUrl, appBaseUrl;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_snack.dart';
import '../../app/puls_app.dart';

/// Refer-and-win contest card for the Profile.
///
/// Mechanic (RDM's contest): invite friends with your link; each friend who
/// signs in **and makes a real prediction** counts. Invite 2 qualifying friends
/// and you're entered into a random draw for the prizes.
///
/// "Real" tracking is done entirely client-side (no backend deploy needed):
///   • `/api/referrals/me` → my code, share link, and who claimed my code.
///   • `/api/profile/:userId` (public) → each invitee's completed trades, so we
///     can tell who has actually predicted vs who only signed up.
/// The link itself is auto-attributed on sign-in (see WalletService +
/// main._captureReferralCode), so sharing the link is all the inviter does.
class ReferralContestCard extends StatefulWidget {
  const ReferralContestCard({super.key});

  @override
  State<ReferralContestCard> createState() => _ReferralContestCardState();
}

class _ReferralContestCardState extends State<ReferralContestCard> {
  static const int _goal = 2; // qualifying friends needed to enter the draw

  // The contest runs through Jun 29 (device-local time); after that the whole
  // card auto-hides — no redeploy needed.
  static final DateTime _contestEnd = DateTime(2026, 6, 30);

  bool _loading = true;
  String? _link;
  int _invitedCount = 0;
  int _predictedCount = 0;
  List<_Invitee> _invitees = const [];

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Run once; needs the InheritedWidget scope, which isn't ready in initState.
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final wallet = WalletServiceScope.of(context);
    try {
      final data = await wallet.getReferralInfo();
      final code = data['code'] as String?;
      final invitedRaw = (data['invited'] as List?) ?? const [];
      final invited = [
        for (final r in invitedRaw)
          _Invitee(
            userId: (r as Map)['userId'] as String? ?? '',
            name: (r['displayName'] as String?)?.trim().isNotEmpty == true
                ? r['displayName'] as String
                : 'Friend',
          ),
      ];

      if (mounted) {
        setState(() {
          _link = data['link'] as String? ??
              (code != null ? '$appBaseUrl/?ref=$code' : null);
          _invitedCount =
              (data['invitedCount'] as num?)?.toInt() ?? invited.length;
          _invitees = invited;
          _loading = false;
        });
      }

      // Resolve which invitees have actually predicted (made a completed trade).
      await _resolvePredicted(invited);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Hit the public profile endpoint for each invitee (capped) and count those
  /// with at least one completed trade as "predicted".
  Future<void> _resolvePredicted(List<_Invitee> invited) async {
    final sample = invited.take(12).toList();
    var predicted = 0;
    final updated = <_Invitee>[];
    for (final inv in sample) {
      var didPredict = false;
      if (inv.userId.isNotEmpty) {
        try {
          final r = await http
              .get(Uri.parse('$backendUrl/api/profile/${inv.userId}'))
              .timeout(const Duration(seconds: 8));
          if (r.statusCode == 200) {
            final d = jsonDecode(r.body) as Map<String, dynamic>;
            final trades = (d['trades'] as List?) ?? const [];
            final tc = ((d['stats'] as Map?)?['tradesCount'] as num?)?.toInt() ?? 0;
            didPredict = trades.isNotEmpty || tc > 0;
          }
        } catch (_) {/* treat as not-yet-predicted */}
      }
      if (didPredict) predicted++;
      updated.add(inv.copyWith(predicted: didPredict));
    }
    if (mounted) {
      setState(() {
        _predictedCount = predicted;
        _invitees = updated;
      });
    }
  }

  String get _shareText =>
      "🤖 I'm predicting on Puls — markets where you trade against live AI "
      "agents. Think you can beat them? It's free: sign in with Google and get "
      'testnet USDC to play. Join with my link 👇';

  void _copyLink() {
    if (_link == null) return;
    Clipboard.setData(ClipboardData(text: _link!));
    PulsSnack.show(context, 'Referral link copied!',
        duration: const Duration(seconds: 2));
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) PulsSnack.error(context, "Couldn't open share sheet");
    }
  }

  void _shareX() {
    if (_link == null) return;
    final t = Uri.encodeComponent(_shareText);
    final u = Uri.encodeComponent(_link!);
    _open('https://twitter.com/intent/tweet?text=$t&url=$u');
  }

  void _shareTelegram() {
    if (_link == null) return;
    final t = Uri.encodeComponent(_shareText);
    final u = Uri.encodeComponent(_link!);
    _open('https://t.me/share/url?url=$u&text=$t');
  }

  void _shareWhatsApp() {
    if (_link == null) return;
    final msg = Uri.encodeComponent('$_shareText\n$_link');
    _open('https://wa.me/?text=$msg');
  }

  @override
  Widget build(BuildContext context) {
    // Auto-expire: once Jun 29 has passed, the contest disappears entirely.
    if (DateTime.now().isAfter(_contestEnd)) return const SizedBox.shrink();

    final t = context.puls;
    final ws = WalletServiceScope.of(context).state;
    final signedIn = ws.userId != null && !ws.isExternalWallet;

    // Web3 guests can't earn a referral code (verified accounts only).
    if (ws.isExternalWallet) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(t.brand.withValues(alpha: 0.14), t.surfaceRaised),
            t.surfaceRaised.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.brand.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(t),
          const SizedBox(height: 16),
          _prizes(t),
          const SizedBox(height: 16),
          if (!signedIn)
            _signInHint(t)
          else if (_loading)
            _loadingRow(t)
          else ...[
            _progress(t),
            const SizedBox(height: 16),
            _linkBox(t),
            const SizedBox(height: 14),
            _shareRow(t),
            if (_invitees.isNotEmpty) ...[
              const SizedBox(height: 16),
              _inviteeList(t),
            ],
          ],
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _header(PulsThemeColors t) => Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [t.brand, PulsColors.brandMint]),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Refer & Win',
                    style: TextStyle(
                        color: t.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4)),
                const SizedBox(height: 2),
                Text('Invite 2 friends who each make a prediction',
                    style: TextStyle(color: t.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      );

  // ── Prizes ─────────────────────────────────────────────────────────────
  Widget _prizes(PulsThemeColors t) {
    Widget chip(String emoji, String label, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            chip('🏆', 'Grand Prize\nworth \$100', PulsColors.amber),
            const SizedBox(width: 8),
            chip('💰', '1,000\ntestnet USDC', t.brand),
            const SizedBox(width: 8),
            chip('💵', '500\ntestnet USDC', PulsColors.brandMint),
          ],
        ),
        const SizedBox(height: 8),
        Text('Ends Jun 29 · 3 winners drawn at random from everyone who qualifies.',
            style: TextStyle(color: t.textSubtle, fontSize: 11.5)),
      ],
    );
  }

  // ── Progress to entry ────────────────────────────────────────────────────
  Widget _progress(PulsThemeColors t) {
    final entered = _predictedCount >= _goal;
    final frac = (_predictedCount / _goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: entered ? t.yes.withValues(alpha: 0.4) : t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entered
                      ? "You're entered into the draw 🎉"
                      : 'Your progress to entry',
                  style: TextStyle(
                      color: entered ? t.yes : t.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800),
                ),
              ),
              Text('$_predictedCount / $_goal predicted',
                  style: TextStyle(
                      color: t.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Stack(
              children: [
                Container(height: 8, color: t.surfaceRaised),
                FractionallySizedBox(
                  widthFactor: frac == 0 ? 0.02 : frac,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                        gradient: entered
                            ? null
                            : const LinearGradient(
                                colors: [PulsColors.brandMint, Color(0xFFEC4899)]),
                        color: entered ? t.yes : null),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_invitedCount joined · $_predictedCount made a prediction. '
            'Only friends who actually predict count.',
            style: TextStyle(color: t.textSubtle, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Link box ───────────────────────────────────────────────────────────
  Widget _linkBox(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR INVITE LINK',
                    style: TextStyle(
                        color: t.textSubtle,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
                const SizedBox(height: 3),
                Text(
                  _link ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _copyLink,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.brand,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text('Copy',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Share row (Beat-the-AI framing) ───────────────────────────────────────
  Widget _shareRow(PulsThemeColors t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.smart_toy_rounded, size: 14, color: t.brand),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Challenge a friend to beat the AI',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _shareBtn(t, 'Share on X', Icons.close_rounded, _shareX,
                bg: const Color(0xFF0F1419), fg: Colors.white, primary: true),
            const SizedBox(width: 8),
            _iconShareBtn(t, Icons.send_rounded, _shareTelegram,
                tip: 'Telegram'),
            const SizedBox(width: 8),
            _iconShareBtn(t, Icons.chat_rounded, _shareWhatsApp,
                tip: 'WhatsApp'),
          ],
        ),
      ],
    );
  }

  Widget _shareBtn(PulsThemeColors t, String label, IconData icon,
      VoidCallback onTap,
      {required Color bg, required Color fg, bool primary = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      color: fg,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconShareBtn(PulsThemeColors t, IconData icon, VoidCallback onTap,
      {required String tip}) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: t.border),
          ),
          child: Icon(icon, size: 17, color: t.brand),
        ),
      ),
    );
  }

  // ── Invitee status list ───────────────────────────────────────────────────
  Widget _inviteeList(PulsThemeColors t) {
    final show = _invitees.take(4).toList();
    final more = _invitees.length - show.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final inv in show)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  inv.predicted
                      ? Icons.check_circle_rounded
                      : Icons.hourglass_bottom_rounded,
                  size: 15,
                  color: inv.predicted ? t.yes : t.textSubtle,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(inv.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: t.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ),
                Text(inv.predicted ? 'predicted' : 'joined — not yet',
                    style: TextStyle(
                        color: inv.predicted ? t.yes : t.textSubtle,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        if (more > 0)
          Text('+$more more',
              style: TextStyle(color: t.textSubtle, fontSize: 11)),
      ],
    );
  }

  // ── States ────────────────────────────────────────────────────────────────
  Widget _signInHint(PulsThemeColors t) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
        ),
        child: Row(
          children: [
            Icon(Icons.login_rounded, size: 16, color: t.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sign in with Google to get your invite link and enter the draw.',
                style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _loadingRow(PulsThemeColors t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: t.brand)),
            const SizedBox(width: 12),
            Text('Loading your invite link…',
                style: TextStyle(color: t.textMuted, fontSize: 12.5)),
          ],
        ),
      );
}

class _Invitee {
  const _Invitee({required this.userId, required this.name, this.predicted = false});
  final String userId;
  final String name;
  final bool predicted;

  _Invitee copyWith({bool? predicted}) =>
      _Invitee(userId: userId, name: name, predicted: predicted ?? this.predicted);
}

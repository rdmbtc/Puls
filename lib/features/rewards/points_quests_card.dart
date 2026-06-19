import 'package:flutter/material.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/count_up_text.dart';
import '../../core/widgets/confetti_burst.dart';

/// Points HUD + Onboarding Quests card.
///
/// Drives activation/retention (Traction): a level badge + XP progress bar, and
/// a checklist of quests with one-tap Claim (server-validated) + confetti.
/// Self-contained: fetches /api/points/me and /api/quests via WalletService.
class PointsQuestsCard extends StatefulWidget {
  const PointsQuestsCard({super.key, this.compact = false});

  /// compact = HUD only (level + XP bar), used in the app shell/profile header.
  final bool compact;

  @override
  State<PointsQuestsCard> createState() => _PointsQuestsCardState();
}

class _PointsQuestsCardState extends State<PointsQuestsCard> {
  Map<String, dynamic>? _points;
  List<Map<String, dynamic>> _quests = const [];
  bool _loading = true;
  bool _failed = false;
  bool _play = false;
  String? _claiming;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final wallet = WalletServiceScope.of(context);
    // Not signed in → nothing to show (quests/points are per-user).
    if (wallet.state.userId == null) {
      if (mounted) setState(() { _loading = false; _failed = true; });
      return;
    }
    try {
      final results = await Future.wait([wallet.getPoints(), wallet.getQuests()]);
      if (!mounted) return;
      setState(() {
        _points = results[0];
        _quests = ((results[1]['quests'] as List?) ?? const [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  Future<void> _claim(String key) async {
    if (_claiming != null) return;
    setState(() => _claiming = key);
    final wallet = WalletServiceScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await wallet.claimQuest(key);
      if (res['ok'] == true) {
        setState(() => _play = true);
        Future.delayed(const Duration(milliseconds: 1400), () { if (mounted) setState(() => _play = false); });
        messenger.showSnackBar(SnackBar(content: Text('+${res['points'] ?? ''} XP claimed 🎉')));
        await _load();
      } else {
        messenger.showSnackBar(SnackBar(content: Text('${res['error'] ?? 'Not claimable yet'}')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Claim failed: $e')));
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_loading) {
      return const SizedBox(height: 4);
    }
    // Not signed in or load failed → don't render (avoids a misleading
    // "all quests complete" empty state for anonymous users).
    if (_failed) return const SizedBox.shrink();
    final p = _points ?? const {};
    final total = (p['total'] as num?)?.toInt() ?? 0;
    final level = (p['level'] as num?)?.toInt() ?? 1;
    final nextAt = (p['nextLevelAt'] as num?)?.toInt() ?? 50;
    final streak = (p['streakDays'] as num?)?.toInt() ?? 0;
    // XP progress within the current level band.
    final prevAt = 50 * (level - 1) * (level - 1);
    final span = (nextAt - prevAt).clamp(1, 1 << 30);
    final progress = ((total - prevAt) / span).clamp(0.0, 1.0);

    final hud = _hud(t, level, total, nextAt, streak, progress);
    if (widget.compact) return hud;

    final claimable = _quests.where((q) => q['status'] == 'completed').toList();
    final pending = _quests.where((q) => q['status'] == 'in_progress').toList();
    final claimed = _quests.where((q) => q['status'] == 'claimed').length;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              hud,
              const SizedBox(height: 14),
              Row(children: [
                Icon(Icons.flag_rounded, size: 15, color: t.brand),
                const SizedBox(width: 6),
                Text('Quests', style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('$claimed/${_quests.length} done',
                    style: TextStyle(color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              ...claimable.map((q) => _questRow(t, q, claimable: true)),
              ...pending.map((q) => _questRow(t, q, claimable: false)),
              if (claimable.isEmpty && pending.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('All quests complete — nice. New ones each season. 🏆',
                      style: TextStyle(color: t.textMuted, fontSize: 12.5)),
                ),
            ],
          ),
        ),
        Positioned.fill(child: IgnorePointer(child: ConfettiBurst(play: _play))),
      ],
    );
  }

  Widget _hud(PulsThemeColors t, int level, int total, int nextAt, int streak, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [PulsColors.brandMint, t.brand]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('LVL $level', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
          ),
          const SizedBox(width: 10),
          CountUpText(
            total.toDouble(),
            builder: (_, v) => Text('${v.round()} XP',
                style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w900)),
          ),
          const Spacer(),
          if (streak > 0)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔥', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 3),
              Text('$streak-day', style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(children: [
            Container(height: 8, color: t.surfaceRaised),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 8,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [PulsColors.brandMint, t.brand])),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Text('${(nextAt - total).clamp(0, 1 << 30)} XP to level ${level + 1}',
            style: TextStyle(color: t.textSubtle, fontSize: 10.5)),
      ],
    );
  }

  Widget _questRow(PulsThemeColors t, Map<String, dynamic> q, {required bool claimable}) {
    final title = q['title'] as String? ?? '';
    final pts = (q['points'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(claimable ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 18, color: claimable ? t.yes : t.textSubtle),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        if (claimable)
          GestureDetector(
            onTap: _claiming == q['key'] ? null : () => _claim(q['key'] as String),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(9)),
              child: Text(_claiming == q['key'] ? '…' : '+$pts XP',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
          )
        else
          Text('+$pts', style: TextStyle(color: t.textSubtle, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

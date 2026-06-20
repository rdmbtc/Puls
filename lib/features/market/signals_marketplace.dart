import 'package:flutter/material.dart';
import '../../core/widgets/puls_snack.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_loader.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/creator_signal.dart';
import 'market_detail_screen.dart';
import 'researched_sources.dart';
import 'signal_extras.dart';
import 'view_prediction_link.dart';

/// Signals Marketplace — a single live feed of EVERY published signal (from AI
/// creator-agents like Atlas/Nova/Sage and from humans). Each card shows the
/// author, the on-chain attestation, and a one-tap Unlock (x402 USDC per-read).
///
/// This is the "AI alpha market" surface: agents publish here, and anyone —
/// human or agent — buys. It also makes the agent economy visible at a glance.
class SignalsMarketplace extends StatefulWidget {
  const SignalsMarketplace({super.key});

  @override
  State<SignalsMarketplace> createState() => _SignalsMarketplaceState();
}

class _SignalsMarketplaceState extends State<SignalsMarketplace> {
  List<CreatorSignal> _signals = [];
  final Map<String, _Author> _authors = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final wallet = WalletServiceScope.of(context);
      final data = await wallet.getSignals(); // no creatorUserId → all published
      final list = ((data['signals'] as List?) ?? [])
          .map((e) => CreatorSignal.fromJson(e as Map<String, dynamic>))
          .where((s) => s.isPublished)
          .toList();
      // Rank: proven creators first (higher resolved win-rate, more resolved
      // signals as a tie-break), then freshest. Unproven ('new') creators sort
      // below proven ones but above stale ones, ordered by recency.
      double score(CreatorSignal s) {
        final tr = s.trackRecord;
        if (tr != null && tr.hasRecord) {
          return 1000 + (tr.winRate! * 100) + (tr.resolved.clamp(0, 9) * 0.1);
        }
        return 0; // unproven
      }
      list.sort((a, b) {
        final byScore = score(b).compareTo(score(a));
        if (byScore != 0) return byScore;
        final at = a.publishedAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.publishedAt?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at); // freshest first
      });
      // Resolve author display from the roster (agents) — best-effort.
      try {
        final roster = await wallet.getAgentRoster();
        for (final a in (roster['agents'] as List? ?? [])) {
          final m = a as Map<String, dynamic>;
          _authors['agent_swarm_${m['key']}'] = _Author(m['name'] as String? ?? 'Agent', true);
        }
      } catch (_) {}
      // Known house creators.
      _authors.putIfAbsent('agent_sage', () => _Author('Sage 🔮', true));
      _authors.putIfAbsent('house_pulse', () => _Author('Pulse 🤖', true));
      if (mounted) setState(() { _signals = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _unlock(CreatorSignal s) async {
    final wallet = WalletServiceScope.of(context);
    final snack = PulsSnack.of(context);
    try {
      final res = await wallet.unlockSignal(s.id);
      if (res['live'] == false) {
        snack.show('${res['message'] ?? 'Unlock activates at launch.'}');
        return;
      }
      setState(() => _loading = true);
      await _fetch();
      if (mounted) snack.success('Unlocked — thesis revealed');
    } catch (e) {
      snack.error('Unlock failed: $e');
    }
  }

  _Author _authorFor(String userId) {
    if (_authors.containsKey(userId)) return _authors[userId]!;
    final isAgent = userId.contains('agent');
    return _Author(isAgent ? 'Puls Agent 🤖' : 'Puls Trader', isAgent);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(40), child: PulsLoader());
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _header(t),
          const SizedBox(height: 14),
          if (_error != null)
            Text("Couldn't load signals.", style: TextStyle(color: t.textMuted, fontSize: 13))
          else if (_signals.isEmpty)
            _empty(t)
          else
            ..._signals.expand((s) => [
                  _MarketSignalCard(
                    signal: s,
                    author: _authorFor(s.creatorUserId),
                    onUnlock: (!s.unlocked) ? () => _unlock(s) : null,
                  ),
                  const SizedBox(height: 10),
                ]),
        ],
      ),
    );
  }

  Widget _header(PulsThemeColors t) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [t.brand.withValues(alpha: 0.14), t.brand.withValues(alpha: 0.02)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.brand.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: t.brand, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Alpha Market',
                      style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text('Live signals from autonomous AI agents — ranked by track record, attested on Arc, unlock per-read with USDC.',
                      style: TextStyle(color: t.textMuted, fontSize: 12, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _empty(PulsThemeColors t) => const PulsEmptyState(
        title: 'No published signals yet',
        message: 'Creator signals will appear here once traders publish their calls.',
        icon: Icons.auto_awesome_rounded,
        compact: true,
      );
}

class _Author {
  const _Author(this.name, this.isAgent);
  final String name;
  final bool isAgent;
}

class _MarketSignalCard extends StatelessWidget {
  const _MarketSignalCard({required this.signal, required this.author, this.onUnlock});
  final CreatorSignal signal;
  final _Author author;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final revealed = signal.stanceVisible;
    final isYes = signal.stance == 'YES';
    final sideColor = !revealed ? t.textMuted : (isYes ? t.yes : t.no);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: author.isAgent ? t.brandSubtle : t.surfaceRaised,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: author.isAgent ? t.brand.withValues(alpha: 0.3) : t.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (author.isAgent) ...[Icon(Icons.smart_toy_rounded, size: 11, color: t.brand), const SizedBox(width: 4)],
                  Text(author.name, style: TextStyle(color: author.isAgent ? t.brand : t.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              ),
              if (signal.trackRecord != null) ...[
                const SizedBox(width: 6),
                _trackRecordBadge(t, signal.trackRecord!),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: sideColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: revealed
                    ? Text(signal.stance!, style: TextStyle(color: sideColor, fontSize: 11, fontWeight: FontWeight.w900))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.lock_rounded, size: 10, color: sideColor),
                        const SizedBox(width: 3),
                        Text('YES / NO', style: TextStyle(color: sideColor, fontSize: 11, fontWeight: FontWeight.w900)),
                      ]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(signal.title, style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
          if (signal.marketQuestion != null && signal.marketQuestion!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(signal.marketQuestion!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.textSubtle, fontSize: 12)),
          ],
          if (signal.hasMarketLink) ...[
            const SizedBox(height: 6),
            ViewPredictionLink(slug: signal.marketSlug!),
            const SizedBox(height: 6),
            SignalLiveOdds(signal: signal),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (signal.confidence != null) _chip(t, '${(signal.confidence! * 100).round()}% conf'),
            if ((signal.edgeBps ?? 0) > 0) _chip(t, '+${signal.edgeBps} bps edge'),
            if (signal.horizon != null && signal.horizon!.isNotEmpty) _chip(t, signal.horizon!),
            _chip(t, '\$${signal.priceUsdc.toStringAsFixed(3)}/read'),
          ]),
          const SizedBox(height: 12),
          if (signal.hasThesis)
            Text(signal.thesis!, style: TextStyle(color: t.text, fontSize: 13, height: 1.45))
          else
            Text(signal.teaser ?? 'Premium analysis — unlock to read the full thesis.',
                style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4)),
          if (signal.hasSources) ...[
            const SizedBox(height: 12),
            ResearchedSources(sources: signal.sources),
          ] else if (signal.sourcesCount > 0) ...[
            const SizedBox(height: 12),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_rounded, size: 12, color: t.textSubtle),
              const SizedBox(width: 5),
              Text('${signal.sourcesCount} researched source${signal.sourcesCount == 1 ? '' : 's'} — unlock to view',
                  style: TextStyle(color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ],
          if (signal.onchain?.explorer != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(signal.onchain!.explorer!), mode: LaunchMode.externalApplication),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: t.brandSubtle, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.brand.withValues(alpha: 0.35))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified_rounded, size: 13, color: t.brand),
                  const SizedBox(width: 6),
                  Text('Attested on Arc', style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  Icon(Icons.open_in_new_rounded, size: 11, color: t.brand.withValues(alpha: 0.7)),
                ]),
              ),
            ),
          ],
          if (onUnlock != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: Text('Unlock \$${signal.priceUsdc.toStringAsFixed(3)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.brand, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            SignalFreshness(publishedAt: signal.publishedAt),
            const Spacer(),
            ShareSignalButton(signal: signal, authorName: author.name),
          ]),
        ],
      ),
    );
  }

  Widget _chip(PulsThemeColors t, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(6), border: Border.all(color: t.border)),
        child: Text(label, style: TextStyle(color: t.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600)),
      );

  Widget _trackRecordBadge(PulsThemeColors t, CreatorTrackRecord tr) {
    if (!tr.hasRecord) {
      // Nothing resolved yet — honest "new" tag, not a fake win-rate.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(5), border: Border.all(color: t.border)),
        child: Text('new', style: TextStyle(color: t.textSubtle, fontSize: 9.5, fontWeight: FontWeight.w700)),
      );
    }
    final pct = (tr.winRate! * 100).round();
    final good = pct >= 50;
    final c = good ? t.yes : t.no;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.military_tech_rounded, size: 10, color: c),
        const SizedBox(width: 3),
        Text('$pct% · ${tr.correct}/${tr.resolved}', style: TextStyle(color: c, fontSize: 9.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

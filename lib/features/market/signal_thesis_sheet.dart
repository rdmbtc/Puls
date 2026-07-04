import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_sheet.dart';
import '../../core/widgets/signal_markdown.dart';
import '../../data/models/creator_signal.dart';
import 'researched_sources.dart';
import 'signal_extras.dart' show SignalBondBadge;

/// Bottom-sheet reader for an unlocked creator signal's full thesis.
///
/// Replaces the previous inline-thesis rendering across the Signals surfaces
/// (marketplace card, creator-profile section, AI insight card, Alpha screen):
/// the feed stays compact (teaser + meta + "Read full thesis" button) and the
/// long-form 1500-3500-char markdown thesis is read here, in a 92%-height sheet
/// with a reading-progress bar, serif body, and the researched sources below.
class SignalThesisSheet extends StatefulWidget {
  const SignalThesisSheet({
    super.key,
    required this.signal,
    required this.authorName,
    this.authorPfp,
    this.authorIsAgent = false,
    this.tipAmount,
    this.onTip,
  });

  final CreatorSignal signal;
  final String authorName;
  final String? authorPfp;
  final bool authorIsAgent;

  /// If non-null + [onTip] non-null → a Tip button is shown in the footer.
  final double? tipAmount;
  final VoidCallback? onTip;

  /// Present the sheet. Convenience wrapper around [PulsSheet.show].
  static Future<void> show(
    BuildContext context, {
    required CreatorSignal signal,
    required String authorName,
    String? authorPfp,
    bool authorIsAgent = false,
    double? tipAmount,
    VoidCallback? onTip,
  }) {
    return PulsSheet.show(
      context,
      builder: (_) => SignalThesisSheet(
        signal: signal,
        authorName: authorName,
        authorPfp: authorPfp,
        authorIsAgent: authorIsAgent,
        tipAmount: tipAmount,
        onTip: onTip,
      ),
    );
  }

  @override
  State<SignalThesisSheet> createState() => _SignalThesisSheetState();
}

class _SignalThesisSheetState extends State<SignalThesisSheet> {
  final ScrollController _scroll = ScrollController();
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final max = _scroll.position.maxScrollExtent;
    final cur = _scroll.offset;
    if (!mounted || max <= 0) return;
    final p = (cur / max).clamp(0.0, 1.0);
    if ((p - _progress).abs() > 0.005) setState(() => _progress = p);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final sig = widget.signal;
    final revealed = sig.stanceVisible;
    final isYes = sig.stance == 'YES';
    final sideColor = !revealed ? t.textMuted : (isYes ? t.yes : t.no);

    return PulsSheetSurface(
      scrollable: false,
      showHandle: false,
      padding: EdgeInsets.zero,
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PulsDragHandle(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (widget.authorPfp != null)
                      ClipOval(child: Image.asset(widget.authorPfp!, width: 22, height: 22, fit: BoxFit.cover))
                    else if (widget.authorIsAgent)
                      Icon(Icons.smart_toy_rounded, size: 16, color: t.brand),
                    if (widget.authorPfp != null || widget.authorIsAgent) const SizedBox(width: 6),
                    Text(widget.authorName,
                        style: TextStyle(
                            color: widget.authorIsAgent ? t.brand : t.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (sig.trackRecord != null && sig.trackRecord!.hasRecord) ...[
                      _trackRecordBadge(t, sig.trackRecord!),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: sideColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        revealed ? sig.stance! : 'YES / NO',
                        style: TextStyle(color: sideColor, fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  sig.title,
                  style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w900, height: 1.25, letterSpacing: -0.3),
                ),
                if (sig.marketQuestion != null && sig.marketQuestion!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(sig.marketQuestion!, style: TextStyle(color: t.textSubtle, fontSize: 12.5, height: 1.4)),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (sig.bond != null) SignalBondBadge(bond: sig.bond!),
                    if (sig.confidence != null) _meta(t, Icons.bolt_rounded, '${(sig.confidence! * 100).round()}% conf'),
                    if ((sig.edgeBps ?? 0) > 0) _meta(t, Icons.trending_up_rounded, '+${sig.edgeBps} bps'),
                    if (sig.horizon != null && sig.horizon!.isNotEmpty) _meta(t, Icons.schedule_rounded, sig.horizon!),
                    _meta(t, Icons.travel_explore_rounded, '${sig.sourcesCount} source${sig.sourcesCount == 1 ? '' : 's'}'),
                    _meta(t, Icons.payments_rounded, '\$${sig.priceUsdc.toStringAsFixed(3)}/read'),
                  ],
                ),
                const SizedBox(height: 10),
                // Reading-progress bar — reflects scroll position through thesis.
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 2,
                    backgroundColor: t.surfaceRaised,
                    valueColor: AlwaysStoppedAnimation<Color>(t.brand),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: t.border),

          // ── Body — scrollable markdown thesis + sources + on-chain + tip
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sig.hasThesis)
                    SignalMarkdown(data: sig.thesis!)
                  else
                    Text(
                      sig.teaser ?? 'Premium analysis — unlock to read the full thesis.',
                      style: TextStyle(color: t.textMuted, fontSize: 13.5, height: 1.55),
                    ),
                  const SizedBox(height: 20),
                  if (sig.hasSources) ...[
                    ResearchedSources(sources: sig.sources),
                    const SizedBox(height: 16),
                  ],
                  if (sig.onchain?.explorer != null) ...[
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse(sig.onchain!.explorer!), mode: LaunchMode.externalApplication),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: t.brandSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: t.brand.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 13, color: t.brand),
                            const SizedBox(width: 6),
                            Text('Attested on Arc',
                                style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 6),
                            Icon(Icons.open_in_new_rounded, size: 11, color: t.brand.withValues(alpha: 0.7)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.tipAmount != null && widget.onTip != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: widget.onTip,
                        icon: Icon(Icons.volunteer_activism_rounded, size: 16, color: t.brand),
                        label: Text('Tip \$${widget.tipAmount!.toStringAsFixed(2)}',
                            style: TextStyle(color: t.brand, fontSize: 13, fontWeight: FontWeight.w800)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: t.brand.withValues(alpha: 0.4))),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(PulsThemeColors t, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(6), border: Border.all(color: t.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: t.textMuted),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: t.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _trackRecordBadge(PulsThemeColors t, CreatorTrackRecord tr) {
    final pct = (tr.winRate! * 100).round();
    final good = pct >= 50;
    final c = good ? t.yes : t.no;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.military_tech_rounded, size: 10, color: c),
        const SizedBox(width: 3),
        Text('$pct% · ${tr.correct}/${tr.resolved}',
            style: TextStyle(color: c, fontSize: 9.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_video_illustration.dart';

/// The AI layer over a market: shows three "sources of truth" — the crowd
/// (Polymarket consensus), the AI panel (swarm agent consensus), lets the user
/// ask an agent to defend a side with live sources, and lists AI-found
/// correlations to other markets. Hides itself when there's nothing to show.
class AiOraclePanel extends StatefulWidget {
  const AiOraclePanel({super.key, required this.slug, this.question});
  final String slug;
  final String? question;

  @override
  State<AiOraclePanel> createState() => _AiOraclePanelState();
}

class _AiOraclePanelState extends State<AiOraclePanel> {
  Map<String, dynamic>? _oracle;
  List<dynamic> _correlations = const [];
  bool _loading = true;

  // Ask-agent state
  bool _asking = false;
  Map<String, dynamic>? _answer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wallet = WalletServiceScope.of(context);
    try {
      final o = await wallet.getOracle(widget.slug);
      if (mounted) setState(() { _oracle = o; });
    } catch (e) {
      debugPrint('[Puls] oracle load failed for ${widget.slug}: $e');
    }
    try {
      final c = await wallet.getOracleCorrelations(widget.slug);
      if (mounted) setState(() { _correlations = (c['correlations'] as List?) ?? const []; });
    } catch (e) {
      debugPrint('[Puls] oracle correlations load failed for ${widget.slug}: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _ask(String side) async {
    if (_asking) return;
    setState(() { _asking = true; _answer = null; });
    final wallet = WalletServiceScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await wallet.askAgent(slug: widget.slug, question: widget.question, side: side);
      if (res['ok'] == true) {
        if (mounted) setState(() => _answer = res);
      } else {
        messenger.showSnackBar(SnackBar(content: Text('${res['error'] ?? 'Ask failed'}')));
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Sign in to ask an agent')));
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_loading) return const SizedBox.shrink();
    final o = _oracle;
    final crowdYes = (o?['crowdYes'] as num?)?.toDouble();
    final aiYes = (o?['aiYes'] as num?)?.toDouble();
    final agentCount = (o?['agentCount'] as num?)?.toInt() ?? 0;
    // Nothing to show at all → hide.
    if (crowdYes == null && aiYes == null && _correlations.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [t.brand.withValues(alpha: 0.10), t.surface]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.brand.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.hub_rounded, color: t.brand, size: 18),
                    const SizedBox(width: 8),
                    Text('AI Oracle Panel', style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                    const Spacer(),
                    if (agentCount > 0)
                      Text('$agentCount agents', style: TextStyle(color: t.textSubtle, fontSize: 11)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Two reads on this market: the crowd vs the AI swarm.',
                      style: TextStyle(color: t.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PulsVideoIllustration(
              asset: 'assets/illustrations/3d-enterprise-ai-icon-app-button-for-artificial-intelligence.mp4',
              width: 48,
              height: 48,
              fallback: Icon(Icons.hub_rounded, size: 24, color: t.brand),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _gauge(t, 'Crowd', 'Polymarket', crowdYes, t.textMuted)),
          const SizedBox(width: 12),
          Expanded(child: _gauge(t, 'AI Panel', agentCount > 0 ? 'swarm consensus' : 'no votes yet', aiYes, t.brand)),
        ]),
        // Divergence callout
        if (crowdYes != null && aiYes != null) ...[
          const SizedBox(height: 10),
          _divergence(t, crowdYes, aiYes),
        ],
        const SizedBox(height: 14),
        // Ask an agent
        Text('Ask an agent to defend a side', style: TextStyle(color: t.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _askBtn(t, 'Why YES?', 'YES')),
          const SizedBox(width: 8),
          Expanded(child: _askBtn(t, 'Why NO?', 'NO')),
        ]),
        if (_asking) ...[
          const SizedBox(height: 12),
          Row(children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: t.brand)),
            const SizedBox(width: 8),
            Text('Agent is researching…', style: TextStyle(color: t.textMuted, fontSize: 12)),
          ]),
        ],
        if (_answer != null) ...[
          const SizedBox(height: 12),
          _answerCard(t, _answer!),
        ],
        // Correlations
        if (_correlations.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('AI-found correlations', style: TextStyle(color: t.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final c in _correlations) _correlationRow(t, c as Map<String, dynamic>),
        ],
      ]),
    );
  }

  Widget _gauge(PulsThemeColors t, String label, String sub, double? yes, Color color) {
    final pct = yes != null ? (yes * 100).round() : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(color: t.textSubtle, fontSize: 9.5)),
        const SizedBox(height: 8),
        Text(pct != null ? '$pct%' : '—', style: TextStyle(color: t.text, fontSize: 24, fontWeight: FontWeight.w900)),
        Text('YES', style: TextStyle(color: t.textSubtle, fontSize: 9.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: yes ?? 0,
            minHeight: 5,
            backgroundColor: t.surfaceRaised,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }

  Widget _divergence(PulsThemeColors t, double crowd, double ai) {
    final diff = ((ai - crowd) * 100).round();
    if (diff.abs() < 5) {
      return Text('The crowd and the AI panel agree (within ${diff.abs()} pts).',
          style: TextStyle(color: t.textMuted, fontSize: 11.5, fontStyle: FontStyle.italic));
    }
    final aiHigher = diff > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: t.brand.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
      child: Text(
        'The AI panel is ${diff.abs()} pts ${aiHigher ? 'more' : 'less'} bullish than the crowd — a divergence worth a look.',
        style: TextStyle(color: t.text, fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _askBtn(PulsThemeColors t, String label, String side) {
    final c = side == 'YES' ? t.yes : t.no;
    return OutlinedButton(
      onPressed: _asking ? null : () => _ask(side),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: c.withValues(alpha: 0.6)),
        foregroundColor: c,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }

  Widget _answerCard(PulsThemeColors t, Map<String, dynamic> a) {
    final side = (a['side'] as String?) ?? '';
    final agent = (a['agent'] as String?) ?? 'Agent';
    final answer = (a['answer'] as String?) ?? '';
    final sources = (a['sources'] as List?) ?? const [];
    final c = side == 'YES' ? t.yes : t.no;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.smart_toy_rounded, size: 13, color: c),
          const SizedBox(width: 5),
          Text('$agent defends $side', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Text(answer, style: TextStyle(color: t.text, fontSize: 13, height: 1.5)),
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in sources)
              InkWell(
                onTap: () {
                  final url = s['url'] as String?;
                  if (url != null) { final u = Uri.tryParse(url); if (u != null) launchUrl(u, mode: LaunchMode.externalApplication); }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(7), border: Border.all(color: t.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.link_rounded, size: 11, color: t.brand),
                    const SizedBox(width: 4),
                    Text((s['source'] as String?) ?? 'source', style: TextStyle(color: t.text, fontSize: 10.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _correlationRow(PulsThemeColors t, Map<String, dynamic> c) {
    final positive = (c['direction'] as String?) == 'positive';
    final dirColor = positive ? t.yes : t.no;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(positive ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 15, color: dirColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((c['question'] as String?) ?? '', style: TextStyle(color: t.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text((c['why'] as String?) ?? '', style: TextStyle(color: t.textMuted, fontSize: 11.5, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/puls_loader.dart';
import '../../core/widgets/puls_emoji_text.dart';
import '../../core/utils/agent_pfp.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/puls_sheet.dart';
import '../market/market_detail_screen.dart';
import 'swarm_view.dart';

/// "AI Colony" — one live, reverse-chronological stream of the WHOLE swarm's
/// actions. Each event reads like a story: 🔍 researched → 💸 paid a peer for
/// alpha (with an on-chain memo) → 🧠 reasoned → ⚡ traded, every payment/trade
/// linking to Arcscan. This is the demo centrepiece: the agent economy, live.
class ColonyFeed extends StatefulWidget {
  final List<Map<String, dynamic>> agents;
  const ColonyFeed({super.key, this.agents = const []});

  @override
  State<ColonyFeed> createState() => _ColonyFeedState();
}

class _ColonyFeedState extends State<ColonyFeed> {
  List<Map<String, dynamic>> _events = const [];
  bool _loading = true;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/agents/feed?limit=40'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('bad status');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final events = ((body['events'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_loading) {
      return const PulsLoader();
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            sliver: SliverToBoxAdapter(child: _header(t)),
          ),
          if (_events.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.border),
                  ),
                  child: Text(
                    'The colony is warming up — agent actions will stream here.',
                    style: TextStyle(color: t.textMuted, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList.builder(
                itemCount: _events.length,
                itemBuilder: (context, index) => RepaintBoundary(
                  child: _EventCard(
                    event: _events[index],
                    ago: timeAgo,
                    agents: widget.agents,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(PulsThemeColors t) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            t.brand.withValues(alpha: 0.15),
            t.brand.withValues(alpha: 0.02)
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.brand.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(Icons.stream_rounded, color: t.brand, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const AnimatedGradientText('AI Colony — live',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text(
                  'Every action the swarm takes — research, paying peers for alpha, reasoning, trading — as it happens on Arc.',
                  style: TextStyle(
                      color: t.textMuted, fontSize: 12, height: 1.35)),
            ]),
          ),
        ]),
      );
}

class _EventCard extends StatelessWidget {
  const _EventCard(
      {required this.event, required this.ago, required this.agents});
  final Map<String, dynamic> event;
  final String Function(DateTime) ago;
  final List<Map<String, dynamic>> agents;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final name = event['agentName'] as String? ?? 'Agent';
    final action = event['action'] as String? ?? '';
    final isGo = action == 'go';
    final isCreate = action == 'create_market';
    final isSell = action == 'sell';
    final side = event['side'] as String?;
    final amount = (event['amount'] as num?)?.toDouble();
    final question = event['question'] as String? ?? '';
    final slug =
        (event['slug'] ?? event['marketId'] ?? event['marketSlug']) as String?;
    final reasoning = event['reasoning'] as String? ?? '';
    final brain = event['brain'] as String?;
    final shift = event['sentimentShift'] as Map<String, dynamic>?;
    final review = event['signalReview'] as Map<String, dynamic>?;
    final alphaPaid = (event['alphaPaid'] as num?)?.toDouble();
    final alphaTxId = event['alphaTxId'] as String?;
    final alphaMemo = event['alphaMemo'] == true;
    final txHash = event['txHash'] as String?;
    final isStream = action == 'stream';
    final isStreamSkip = action == 'stream_skip';
    final ratePerSec = (event['ratePerSecUsdc'] as num?)?.toDouble();
    final streamed = (event['streamedUsdc'] as num?)?.toDouble();
    final stopReason = event['stopReason'] as String?;
    final sources = (event['sources'] as List?) ?? const [];
    final at =
        DateTime.tryParse(event['at'] as String? ?? '') ?? DateTime.now();

    return GestureDetector(
        onTap: () {
          final key = event['agentKey'] as String?;
          if (key != null) {
            final agentMap = agents.cast<Map<String, dynamic>?>().firstWhere(
                (a) => (a?['key'] as String?) == key,
                orElse: () => null);
            PulsSheet.show(context,
                builder: (ctx) =>
                    AgentDetailSheet(agentKey: key, agentMap: agentMap));
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Agent + time + verdict
              Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: [PulsColors.brandMint, t.brand]),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: () {
                    final p = agentPfpAsset(name);
                    if (p != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset(p,
                            width: 30, height: 30, fit: BoxFit.cover),
                      );
                    }
                    return Icon(
                        isCreate
                            ? Icons.add_chart_rounded
                            : isSell
                                ? Icons.sell_rounded
                                : (isStream || isStreamSkip)
                                    ? Icons.water_drop_rounded
                                    : isGo
                                        ? Icons.bolt_rounded
                                        : Icons.pause_rounded,
                        color: Colors.white,
                        size: 16);
                  }(),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          color: t.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isGo
                        ? (side == 'NO' ? t.noBg : t.yesBg)
                        : isStream
                            ? t.brand.withValues(alpha: 0.14)
                            : t.surfaceRaised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: t.border),
                  ),
                  child: Text(
                    isCreate
                        ? 'NEW MARKET'
                        : isSell
                            ? 'SOLD $side'
                            : isStream
                                ? 'STREAMED \$${(streamed ?? 0).toStringAsFixed(4)}'
                                : isStreamSkip
                                    ? 'PASSED'
                                    : isGo
                                        ? 'BUY $side \$${amount?.toStringAsFixed(2) ?? ''}'
                                        : 'HOLD',
                    style: TextStyle(
                        color: isCreate
                            ? t.brand
                            : isSell
                                ? (side == 'NO' ? t.no : t.yes)
                                : isStream
                                    ? t.brand
                                    : isGo
                                        ? (side == 'NO' ? t.no : t.yes)
                                        : t.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ]),
              if (shift != null) ...[
                const SizedBox(height: 9),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: t.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.sync_alt_rounded, size: 13, color: t.brand),
                    const SizedBox(width: 5),
                    Flexible(
                        child: Text(
                            'Sentiment shift: ${shift['from']} → ${shift['to']}',
                            style: TextStyle(
                                color: t.brand,
                                fontSize: 11,
                                fontWeight: FontWeight.w800))),
                  ]),
                ),
              ],
              if (question.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.3)),
              ],
              // Step chips: the story of this decision
              const SizedBox(height: 9),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (sources.isNotEmpty)
                  _step(t, '🔍', 'researched ${sources.length} sources'),
                if (review != null)
                  _step(t, review['verdict'] == 'buy' ? '✅' : '❌',
                      '${review['verdict'] == 'buy' ? 'bought' : 'skipped'} ${_shortName(review['creator'])}\'s signal'),
                if (alphaPaid != null && alphaPaid > 0)
                  _step(t, '💸',
                      'paid \$${alphaPaid.toStringAsFixed(3)} for alpha'),
                if (brain != null && brain.isNotEmpty)
                  _step(t, '🧠', 'reasoned with AI'),
                if (isGo) _step(t, '⚡', 'traded $side on Arc'),
                if (isStream)
                  _step(t, '⚡',
                      'streamed \$${(ratePerSec ?? 0).toStringAsFixed(4)}/s on Arc'),
                if (isStream && stopReason != null && stopReason.isNotEmpty)
                  _step(t, '⏹', stopReason),
              ]),
              if (reasoning.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(reasoning,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: t.textMuted, fontSize: 12, height: 1.4)),
              ],
              const SizedBox(height: 9),
              Row(children: [
                Text(ago(at),
                    style: TextStyle(color: t.textSubtle, fontSize: 11)),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [
                        if (slug != null && slug.isNotEmpty)
                          InkWell(
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    MarketDetailScreen(marketId: slug),
                              ));
                            },
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.insert_chart_outlined_rounded,
                                  size: 13, color: t.brand),
                              const SizedBox(width: 4),
                              Text('view market',
                                  style: TextStyle(
                                      color: t.brand,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        if (alphaMemo)
                          _MemoBadge(
                              txId: (alphaTxId != null &&
                                      alphaTxId.startsWith('0x'))
                                  ? alphaTxId
                                  : null),
                        if (alphaTxId != null && alphaTxId.startsWith('0x'))
                          _link(t, Icons.swap_horiz_rounded, 'alpha tx',
                              'https://testnet.arcscan.app/tx/$alphaTxId'),
                        if (txHash != null && txHash.startsWith('0x'))
                          _link(t, Icons.receipt_long_rounded, 'trade',
                              'https://testnet.arcscan.app/tx/$txHash'),
                      ]),
                ),
              ]),
            ],
          ),
        ));
  }

  String _shortName(dynamic creator) {
    final s = creator?.toString() ?? 'peer';
    return s.replaceAll('agent_swarm_', '').replaceAll('agent_', '');
  }

  Widget _step(PulsThemeColors t, String emoji, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.border),
        ),
        child: PulsEmojiText('$emoji  $label',
            style: TextStyle(
                color: t.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600)),
      );

  Widget _link(PulsThemeColors t, IconData icon, String label, String url) =>
      InkWell(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: t.brand),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: t.brand, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// "📝 on-chain memo" badge — links to the Arc Memo tx when available.
class _MemoBadge extends StatelessWidget {
  const _MemoBadge({this.txId});
  final String? txId;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return InkWell(
      onTap: txId == null
          ? null
          : () => launchUrl(Uri.parse('https://testnet.arcscan.app/tx/$txId'),
              mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: t.brandSubtle,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: t.brand.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const PulsEmojiText('📝', emojiSize: 11),
          const SizedBox(width: 3),
          Text('on-chain memo',
              style: TextStyle(
                  color: t.brand, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

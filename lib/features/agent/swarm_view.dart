import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_sheet.dart';
import '../../core/widgets/puls_loader.dart';
import 'colony_feed.dart';

/// "Swarm" — the in-app home of the autonomous AI agent colony.
///
/// A live grid of every agent from /api/agents/roster (name, LLM brain, role,
/// USDC balance, ERC-8004 id, last action). Tapping an agent opens an in-app
/// detail sheet with its persona + thought stream (recent decisions, peer-signal
/// reviews, and clickable Arc tx receipts) — never leaving the app shell.
class SwarmView extends StatefulWidget {
  const SwarmView({super.key});

  @override
  State<SwarmView> createState() => _SwarmViewState();
}

class _SwarmViewState extends State<SwarmView> {
  List<Map<String, dynamic>> _agents = const [];
  bool _loading = true;
  Timer? _refresh;
  int _seg = 0; // 0 = Live colony feed, 1 = Agents grid

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/agents/roster'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('bad status');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final agents = ((body['agents'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (!mounted) return;
      setState(() {
        _agents = agents;
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
    if (_agents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'The agent swarm is warming up — agents will appear here as they wake.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textMuted, fontSize: 14),
          ),
        ),
      );
    }

    final traders = _agents.where((a) => a['role'] == 'trader').length;
    final creators = _agents.where((a) => a['role'] == 'creator').length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: _segmentBar(t),
        ),
        Expanded(
          child: _seg == 0
              ? const ColonyFeed()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      _header(t, traders, creators),
                      const SizedBox(height: 16),
                      LayoutBuilder(builder: (context, c) {
                        final cols = c.maxWidth > 520 ? 3 : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _agents.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 176,
                          ),
                          itemBuilder: (_, i) => _AgentCard(
                            agent: _agents[i],
                            onTap: () => _openDetail(_agents[i]),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _segmentBar(PulsThemeColors t) {
    Widget seg(int i, IconData icon, String label) {
      final sel = _seg == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _seg = i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: sel ? t.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 15, color: sel ? Colors.white : t.textMuted),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: sel ? Colors.white : t.textMuted, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: t.border),
      ),
      child: Row(children: [
        seg(0, Icons.stream_rounded, 'Live Colony'),
        seg(1, Icons.grid_view_rounded, 'Agents'),
      ]),
    );
  }

  void _openDetail(Map<String, dynamic> agent) {
    PulsSheet.show<void>(
      context,
      builder: (_) => _AgentDetailSheet(agent: agent),
    );
  }

  Widget _header(PulsThemeColors t, int traders, int creators) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            t.brand.withValues(alpha: 0.15),
            t.brand.withValues(alpha: 0.02)
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.brand.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.hub_rounded, color: t.brand, size: 22),
              const SizedBox(width: 10),
              Text('The Swarm',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: t.yesBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: t.yes, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text('LIVE',
                      style: TextStyle(
                          color: t.yes,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              '${_agents.length} autonomous AI agents live on Arc — $traders traders, $creators creators. Each has its own LLM brain, Circle wallet & ERC-8004 identity. They research, trade, and buy each other\'s signals — no human in the loop.',
              style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
      );
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent, required this.onTap});
  final Map<String, dynamic> agent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final name = agent['name'] as String? ?? 'Agent';
    final role = agent['role'] as String? ?? 'trader';
    final brain = agent['brain'] as String? ?? '';
    final balance = (agent['balance'] as num?)?.toDouble() ?? 0;
    final erc = agent['erc8004Id']?.toString();
    final isCreator = role == 'creator';
    final decisions = (agent['recentDecisions'] as List?) ?? const [];
    final last = decisions.isNotEmpty ? decisions.first as Map<String, dynamic> : null;
    final signal = agent['signal'] as Map<String, dynamic>?;

    String lastLine;
    if (isCreator && signal != null) {
      lastLine = 'Signal: ${signal['title'] ?? '—'}';
    } else if (last != null) {
      final act = last['action'] as String? ?? '';
      if (act == 'go') {
        lastLine = '${last['side'] ?? ''} \$${(last['amount'] as num?)?.toStringAsFixed(2) ?? ''} · ${last['question'] ?? ''}';
      } else {
        lastLine = 'Holding — no +EV this cycle';
      }
    } else {
      lastLine = 'Warming up…';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: isCreator
                      ? [t.brand, PulsColors.brandMint]
                      : [PulsColors.brandMint, t.brand]),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(isCreator ? Icons.lightbulb_rounded : Icons.bolt_rounded,
                    color: Colors.white, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isCreator ? t.brand.withValues(alpha: 0.12) : t.surfaceRaised,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: t.border),
                ),
                child: Text(isCreator ? 'creator' : 'trader',
                    style: TextStyle(color: t.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            if (brain.isNotEmpty)
              Row(children: [
                Icon(Icons.memory_rounded, size: 11, color: t.textSubtle),
                const SizedBox(width: 3),
                Expanded(
                  child: Text('AI engine',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: t.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w600)),
                ),
              ]),
            const SizedBox(height: 8),
            Text(lastLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.textMuted, fontSize: 11, height: 1.35)),
            const Spacer(),
            Row(children: [
              Text('\$${balance.toStringAsFixed(2)}',
                  style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w900)),
              const SizedBox(width: 3),
              Text('USDC', style: TextStyle(color: t.textSubtle, fontSize: 9.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (erc != null && erc.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.yesBg,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('#$erc',
                      style: TextStyle(color: t.yes, fontSize: 8.5, fontWeight: FontWeight.w800)),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _AgentDetailSheet extends StatelessWidget {
  const _AgentDetailSheet({required this.agent});
  final Map<String, dynamic> agent;

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final name = agent['name'] as String? ?? 'Agent';
    final role = agent['role'] as String? ?? 'trader';
    final brain = agent['brain'] as String? ?? '';
    final persona = agent['persona'] as String? ?? '';
    final balance = (agent['balance'] as num?)?.toDouble() ?? 0;
    final erc = agent['erc8004Id']?.toString();
    final address = agent['address'] as String? ?? '';
    final decisions = ((agent['recentDecisions'] as List?) ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final maxH = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH, maxWidth: 560),
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  t.brand.withValues(alpha: 0.16),
                  t.brand.withValues(alpha: 0.02)
                ]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(name,
                        style: TextStyle(color: t.text, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Icon(Icons.close_rounded, color: t.textMuted, size: 22),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  if (persona.isNotEmpty)
                    Text(persona,
                        style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (brain.isNotEmpty) _chip(t, Icons.memory_rounded, 'AI engine'),
                    _chip(t, Icons.workspace_premium_rounded, role),
                    _chip(t, Icons.attach_money_rounded, '${balance.toStringAsFixed(2)} USDC'),
                    if (erc != null && erc.isNotEmpty)
                      _chip(t, Icons.fingerprint_rounded, 'ERC-8004 #$erc',
                          onTap: address.isEmpty ? null : () => launchUrl(
                              Uri.parse('https://testnet.arcscan.app/address/$address'))),
                  ]),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                children: [
                  Text('Thought stream',
                      style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Every decision below was made autonomously by this agent.',
                      style: TextStyle(color: t.textMuted, fontSize: 12)),
                  const SizedBox(height: 12),
                  if (decisions.isEmpty)
                    Text('No decisions yet — this agent is warming up.',
                        style: TextStyle(color: t.textMuted, fontSize: 13))
                  else
                    ...decisions.map((d) => _thoughtCard(t, d)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thoughtCard(PulsThemeColors t, Map<String, dynamic> d) {
    final action = d['action'] as String? ?? '';
    final isGo = action == 'go';
    final side = d['side'] as String?;
    final amount = (d['amount'] as num?)?.toDouble();
    final reasoning = d['reasoning'] as String? ?? '';
    final question = d['question'] as String? ?? '';
    final txHash = d['txHash'] as String?;
    final at = DateTime.tryParse(d['at'] as String? ?? '') ?? DateTime.now();
    final review = d['signalReview'] as Map<String, dynamic>?;
    final alphaPaid = (d['alphaPaid'] as num?)?.toDouble();
    final alphaTxId = d['alphaTxId'] as String?;
    final alphaMemo = d['alphaMemo'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isGo ? (side == 'NO' ? t.noBg : t.yesBg) : t.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: t.border),
              ),
              child: Text(
                isGo ? 'BUY $side \$${amount?.toStringAsFixed(2) ?? ''}' : 'HOLD',
                style: TextStyle(
                    color: isGo ? (side == 'NO' ? t.no : t.yes) : t.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800),
              ),
            ),
            const Spacer(),
            Text(_ago(at), style: TextStyle(color: t.textSubtle, fontSize: 10.5)),
          ]),
          if (question.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
          // Peer-signal review (agent reviewing another agent's alpha)
          if (review != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: t.border),
              ),
              child: Row(children: [
                Icon(review['verdict'] == 'buy' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 14, color: review['verdict'] == 'buy' ? t.yes : t.no),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${review['verdict'] == 'buy' ? 'Bought' : 'Skipped'} ${review['creator'] ?? 'peer'}\'s signal — ${review['note'] ?? ''}',
                    style: TextStyle(color: t.textMuted, fontSize: 11, height: 1.35),
                  ),
                ),
              ]),
            ),
          ],
          if (reasoning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(reasoning,
                style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.45)),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 6, children: [
            if (alphaPaid != null && alphaPaid > 0)
              InkWell(
                onTap: (alphaTxId != null && alphaTxId.startsWith('0x'))
                    ? () => launchUrl(Uri.parse('https://testnet.arcscan.app/tx/$alphaTxId'))
                    : null,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.swap_horiz_rounded, size: 13, color: t.brand),
                  const SizedBox(width: 4),
                  Text('paid \$${alphaPaid.toStringAsFixed(3)} for alpha',
                      style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            if (alphaMemo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: t.brand.withValues(alpha: 0.35)),
                ),
                child: Text('📝 on-chain memo',
                    style: TextStyle(color: t.brand, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            if (txHash != null && txHash.startsWith('0x'))
              InkWell(
                onTap: () => launchUrl(Uri.parse('https://testnet.arcscan.app/tx/$txHash')),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_rounded, size: 13, color: t.brand),
                  const SizedBox(width: 4),
                  Text('trade on Arcscan',
                      style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _chip(PulsThemeColors t, IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: t.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: t.brand),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: t.text, fontSize: 11.5, fontWeight: FontWeight.w700)),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 10, color: t.textSubtle),
          ],
        ]),
      ),
    );
  }
}

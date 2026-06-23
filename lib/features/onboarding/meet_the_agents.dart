import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/agent_pfp.dart';
import '../../core/widgets/puls_emoji_text.dart';
import '../../core/widgets/puls_video_illustration.dart';

/// "Meet the agents" — the live AI economy on the landing page.
/// Pulls the autonomous-agent roster from the backend and shows each agent's
/// brain, persona, on-chain ERC-8004 identity, USDC balance and latest move.
/// Renders nothing if the backend is unreachable — the landing must never break.
class MeetTheAgentsSection extends StatefulWidget {
  const MeetTheAgentsSection({super.key});

  @override
  State<MeetTheAgentsSection> createState() => _MeetTheAgentsSectionState();
}

class _Agent {
  const _Agent({
    required this.name,
    required this.role,
    required this.brain,
    required this.persona,
    required this.address,
    required this.balance,
    required this.erc8004Id,
    required this.lastMove,
  });
  final String name;
  final String role;
  final String brain;
  final String persona;
  final String address;
  final double balance;
  final String erc8004Id;
  final String lastMove;
}

const _agentPalette = [
  Color(0xFFEC4899),
  Color(0xFF0EA5E9),
  Color(0xFF8B5CF6),
  Color(0xFF16A34A),
  Color(0xFFD97706),
  Color(0xFF14B8A6),
];

class _MeetTheAgentsSectionState extends State<MeetTheAgentsSection> {
  List<_Agent> _agents = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/agents/roster'))
          .timeout(const Duration(seconds: 8));
      if (!mounted || res.statusCode != 200) return;
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['enabled'] == false) return;
      final raw = body['agents'] as List<dynamic>? ?? const [];
      final agents = <_Agent>[];
      for (final a in raw) {
        final j = a as Map<String, dynamic>;
        String lastMove = '';
        final decisions = j['recentDecisions'] as List<dynamic>? ?? const [];
        if (decisions.isNotEmpty) {
          final d = decisions.first as Map<String, dynamic>;
          lastMove = (d['reasoning'] as String? ?? '').trim();
        }
        agents.add(_Agent(
          name: (j['name'] as String? ?? 'Agent').trim(),
          role: (j['role'] as String? ?? '').trim(),
          brain: (j['brain'] as String? ?? '').trim(),
          persona: (j['persona'] as String? ?? '').trim(),
          address: (j['address'] as String? ?? '').trim(),
          balance: (j['balance'] as num?)?.toDouble() ?? 0,
          erc8004Id: (j['erc8004Id']?.toString() ?? '').trim(),
          lastMove: lastMove,
        ));
      }
      setState(() => _agents = agents);
    } catch (_) {
      // Section simply doesn't render — landing must never break.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_agents.isEmpty) return const SizedBox.shrink();
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 600;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 48 : 96),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: t.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: t.brand.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                      color: Color(0xFF22C55E), shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(
                  'LIVE AI ECONOMY',
                  style: TextStyle(
                      color: t.brand,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${_agents.length} agents are trading right now',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: t.text,
                fontSize: isMobile ? 24 : 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                height: 1.2),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(
              'Each agent has its own LLM brain, an on-chain ERC-8004 identity '
              'and a Circle wallet. They read each other\'s signals, pay in USDC, '
              'and trade 24/7 — no human in the loop.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: t.textMuted, fontSize: isMobile ? 14 : 16, height: 1.6),
            ),
          ),
          SizedBox(height: isMobile ? 32 : 56),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 900
                  ? 3
                  : constraints.maxWidth > 600
                      ? 2
                      : 1;
              final gap = isMobile ? 12.0 : 18.0;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < _agents.length; i++)
                    SizedBox(
                      width: (constraints.maxWidth - (cols - 1) * gap) / cols,
                      child: _AgentCard(
                        agent: _agents[i],
                        color: _agentPalette[i % _agentPalette.length],
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatefulWidget {
  const _AgentCard({required this.agent, required this.color});
  final _Agent agent;
  final Color color;

  @override
  State<_AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<_AgentCard> {
  bool _hovered = false;

  bool _isEmoji(String s) => s.runes.any((r) => r > 0x2000);



  String _displayName(String name) {
    final parts = name.trim().split(' ');
    if (parts.length > 1 && _isEmoji(parts.last)) {
      return parts.sublist(0, parts.length - 1).join(' ');
    }
    return name;
  }

  String _shortAddr(String a) =>
      a.length > 12 ? '${a.substring(0, 6)}…${a.substring(a.length - 4)}' : a;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final a = widget.agent;
    final c = widget.color;
    final isCreator = a.role.toLowerCase() == 'creator';
    final roleColor = isCreator ? t.brand : const Color(0xFF14B8A6);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: _hovered
            ? Matrix4.translationValues(0.0, -5.0, 0.0)
            : Matrix4.identity(),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _hovered ? c.withValues(alpha: 0.45) : t.border),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                      color: c.withValues(alpha: 0.16),
                      blurRadius: 34,
                      offset: const Offset(0, 16))
                ]
              : [
                  BoxShadow(
                      color: t.text.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 6))
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52, height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        c,
                        Color.alphaBlend(Colors.white.withValues(alpha: 0.42), c)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: c.withValues(alpha: 0.32),
                          blurRadius: 16,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: () {
                    final p = agentPfpAsset(a.name);
                    if (p != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset(p, width: 52, height: 52, fit: BoxFit.cover),
                      );
                    }
                    return const PulsVideoIllustration(
                      asset: 'assets/illustrations/black-cute-robot-standing.mp4',
                      width: 52,
                      height: 52,
                      borderRadius: 15,
                    );
                  }(),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName(a.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: t.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 4),
                      if (a.role.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(a.role.toUpperCase(),
                              style: TextStyle(
                                  color: roleColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (a.brain.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: t.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.border),
                ),
                child: PulsEmojiText('🧠 AI engine',
                    style: TextStyle(
                        color: t.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
            if (a.persona.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(a.persona,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.textMuted, fontSize: 13.5, height: 1.55)),
            ],
            if (a.lastMove.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.withValues(alpha: 0.16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💭 LATEST MOVE',
                        style: TextStyle(
                            color: c,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(a.lastMove,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: t.text, fontSize: 12.5, height: 1.5)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  if (a.erc8004Id.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('ERC-8004 #${a.erc8004Id}',
                          style: const TextStyle(
                              color: Color(0xFF14B8A6),
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  const SizedBox(width: 9),
                  Text('${a.balance.toStringAsFixed(a.balance < 10 ? 1 : 0)} USDC',
                      style: TextStyle(
                          color: t.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (a.address.isNotEmpty)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse(
                              'https://testnet.arcscan.app/address/${a.address}'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text('${_shortAddr(a.address)} ↗',
                            style: TextStyle(
                                color: t.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

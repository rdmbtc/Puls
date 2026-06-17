import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/shimmer_text.dart';
import '../../data/models/market.dart';

/// AI Analyst brief — auto-generated thesis, key factors, and lean for a
/// market. Fetched from the backend (server-side cached), hidden on error.
class AiInsightCard extends StatefulWidget {
  const AiInsightCard({required this.market, super.key});
  final Market market;

  @override
  State<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<AiInsightCard> {
  Map<String, dynamic>? _insight;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uri = Uri.parse(
        '$backendUrl/api/market/insight?slug=${Uri.encodeComponent(widget.market.slug)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 25));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _insight = json.decode(res.body) as Map<String, dynamic>;
          _loading = false;
        });
      } else {
        setState(() { _failed = true; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _failed = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_failed) return const SizedBox.shrink();

    final lean = (_insight?['lean'] as String?) ?? 'UNCERTAIN';
    final leanColor = lean == 'YES' ? t.yes : lean == 'NO' ? t.no : PulsColors.amber;
    final factors = (_insight?['factors'] as List<dynamic>? ?? const [])
        .map((f) => f.toString())
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.brand.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: t.brand.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [t.brand, t.brand.withValues(alpha: 0.6)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text('AI Analyst',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_loading)
                ShimmerText(
                  leadingDot: false,
                  highlightColor: t.brand,
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6),
                  phrases: const [
                    'ANALYZING…',
                    'READING NEWS…',
                    'WEIGHING ODDS…',
                  ],
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: leanColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    lean == 'UNCERTAIN' ? 'TOSS-UP' : 'LEANS $lean',
                    style: TextStyle(
                        color: leanColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading) ...[
            const Skeleton(height: 13),
            const SizedBox(height: 7),
            const Skeleton(height: 13, width: 260),
            const SizedBox(height: 14),
            const Skeleton(height: 11, width: 220),
            const SizedBox(height: 7),
            const Skeleton(height: 11, width: 240),
          ] else ...[
            Text(
              (_insight?['thesis'] as String?) ?? '',
              style: TextStyle(
                  color: t.text, fontSize: 13.5, height: 1.55),
            ),
            if (factors.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...factors.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: t.brand,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(f,
                              style: TextStyle(
                                  color: t.textMuted,
                                  fontSize: 12.5,
                                  height: 1.45)),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 4),
            Text(
              'Generated by Puls AI · not financial advice',
              style: TextStyle(color: t.textSubtle, fontSize: 10.5),
            ),
            ..._buildSources(t),
          ],
        ],
      ),
    );
  }

  /// Live web sources the AI read (from backend `sources`). Tappable chips.
  List<Widget> _buildSources(PulsThemeColors t) {
    final sources = (_insight?['sources'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (sources.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      Row(
        children: [
          Icon(Icons.travel_explore_rounded, size: 13, color: t.brand),
          const SizedBox(width: 6),
          Text('Researched the web',
              style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: sources.map((s) {
          final src = (s['source'] as String?) ?? 'source';
          final url = s['url'] as String?;
          return GestureDetector(
            onTap: url == null
                ? null
                : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: t.surfaceRaised,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: t.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(src,
                      style: TextStyle(color: t.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new_rounded, size: 10, color: t.textSubtle),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer_text.dart';
import '../../core/config.dart' show backendUrl;
import '../../data/models/market.dart';
import 'trade_preview_sheet.dart';

class CopilotMsg {
  CopilotMsg(this.isUser, this.text, {this.sources = const []});
  final bool isUser;
  final String text;
  final List<Map<String, dynamic>> sources;
}

class AiCopilotSheet extends StatefulWidget {
  const AiCopilotSheet({
    required this.market,
    super.key,
  });

  final Market market;

  static void show(BuildContext context, Market market) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: AiCopilotSheet(market: market),
        ),
      ),
    );
  }

  @override
  State<AiCopilotSheet> createState() => _AiCopilotSheetState();
}

class _AiCopilotSheetState extends State<AiCopilotSheet> {
  final _client = http.Client();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<CopilotMsg> _msgs = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _msgs.add(CopilotMsg(
      false,
      "Hello! I am your AI Trading Copilot. Ask me anything about the **${widget.market.question}** market. I can analyze recent news, market sentiment, or propose a tailored trading strategy for you.",
    ));
  }

  @override
  void dispose() {
    _client.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final uid = WalletServiceScope.of(context).state.userId;
    if (uid == null || text.trim().isEmpty || _busy) return;

    final trimmed = text.trim();
    setState(() {
      _msgs.add(CopilotMsg(true, trimmed));
      _input.clear();
      _busy = true;
    });
    _scrollDown();

    try {
      final res = await _client.post(
        Uri.parse('$backendUrl/api/copilot/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ""}',
        },
        body: jsonEncode({
          'userId': uid,
          'message': trimmed,
          'question': widget.market.question,
          'slug': widget.market.slug,
          'currentYesPrice': widget.market.yesPrice.toString(),
          'currentNoPrice': widget.market.noPrice.toString(),
        }),
      ).timeout(const Duration(seconds: 45));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) throw Exception(data['error'] ?? 'Request failed');

      setState(() {
        final srcs = (data['sources'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _msgs.add(CopilotMsg(false, data['reply'] as String? ?? 'Analysis completed.', sources: srcs));
      });
    } catch (e) {
      setState(() {
        _msgs.add(CopilotMsg(false, 'Copilot couldn\'t connect. Try again in a moment.'));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollDown();
    }
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: t.border, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: t.borderStrong.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Header info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.brandSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: t.brand, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Trading Copilot',
                        style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Market Analyst & Strategy Planner',
                        style: TextStyle(color: t.textSubtle, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded, color: t.textSubtle, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: t.border),

          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _msgs.length,
              itemBuilder: (context, idx) {
                final m = _msgs[idx];
                return FadeInUp(
                  key: ValueKey(idx),
                  duration: const Duration(milliseconds: 200),
                  from: 10,
                  child: _bubble(m, t, isDark),
                );
              },
            ),
          ),

          // suggestion pills
          if (_msgs.length == 1 && !_busy) _suggestions(t),
          if (_busy) _thinking(t),

          // Message Composer
          _composer(t),
        ],
      ),
    );
  }

  Widget _bubble(CopilotMsg m, PulsThemeColors t, bool isDark) {
    final isRec = _hasTradeRecommendation(m.text);
    final isYes = m.text.toUpperCase().contains('BUY YES');
    final align = m.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = m.isUser ? t.brand : t.surface;
    final fg = m.isUser ? Colors.white : t.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: m.isUser ? null : Border.all(color: t.border),
            ),
            child: Text(
              m.text,
              style: TextStyle(color: fg, fontSize: 13.5, height: 1.4),
            ),
          ),
          // Live web sources the copilot cited.
          if (!m.isUser && m.sources.isNotEmpty) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: m.sources.map((s) {
                  final src = (s['source'] as String?) ?? 'source';
                  final url = s['url'] as String?;
                  return GestureDetector(
                    onTap: url == null
                        ? null
                        : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: t.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.travel_explore_rounded, size: 10, color: t.brand),
                          const SizedBox(width: 4),
                          Text(src,
                              style: TextStyle(color: t.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          // Interactive Action for Trade Recommendations
          if (isRec && !m.isUser) ...[
            const SizedBox(height: 6),
            FadeInUp(
              duration: const Duration(milliseconds: 250),
              from: 8,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // close chat sheet
                  showTradePreviewSheet(
                    context: context,
                    market: widget.market,
                    side: isYes ? MarketSide.yes : MarketSide.no,
                  );
                },
                icon: Icon(
                  Icons.shopping_cart_rounded,
                  size: 14,
                  color: isYes ? t.yes : t.no,
                ),
                label: Text(
                  'Execute proposed Buy ${isYes ? "YES" : "NO"} Order',
                  style: TextStyle(fontSize: 12, color: isYes ? t.yes : t.no, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isYes ? t.yesBg : t.noBg,
                  shadowColor: Colors.transparent,
                  side: BorderSide(color: (isYes ? t.yes : t.no).withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasTradeRecommendation(String text) {
    return text.contains('[TRADE RECOMMENDATION]') || 
           (text.toUpperCase().contains('BUY YES') && text.contains('recommend')) || 
           (text.toUpperCase().contains('BUY NO') && text.contains('recommend'));
  }

  Widget _suggestions(PulsThemeColors t) {
    final items = [
      "What is the sentiment?",
      "Summarize recent news",
      "Propose trading strategy",
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((p) => GestureDetector(
              onTap: () => _send(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.brand.withValues(alpha: 0.2)),
                ),
                child: Text(
                  p,
                  style: TextStyle(color: t.brand, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            )).toList(),
      ),
    );
  }

  Widget _thinking(PulsThemeColors t) => Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ShimmerText(
            highlightColor: t.brand,
            phrases: const [
              'Reading the market…',
              'Scanning recent news…',
              'Weighing the sentiment…',
              'Crunching the odds…',
              'Drafting a strategy…',
            ],
          ),
        ),
      );

  Widget _composer(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              style: TextStyle(color: t.text, fontSize: 13.5),
              minLines: 1,
              maxLines: 3,
              onSubmitted: (_) => _send(_input.text),
              decoration: InputDecoration(
                hintText: 'Ask your copilot anything...',
                hintStyle: TextStyle(color: t.textSubtle, fontSize: 13),
                filled: true,
                fillColor: t.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _busy ? null : () => _send(_input.text),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _busy ? t.border : t.brand,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

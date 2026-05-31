import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config.dart' show backendUrl;

class _Msg {
  _Msg(this.fromAgent, this.text, {this.txId, this.contract});
  final bool fromAgent;
  final String text;
  final String? txId;
  final String? contract;
}

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final _client = http.Client();
  final _input = TextEditingController();
  final _budget = TextEditingController(text: '5');
  final _scroll = ScrollController();

  bool _started = false;
  bool _busy = false;
  String? _agentAddress;
  bool _registered = false;
  double _budgetVal = 0, _spent = 0;
  final List<_Msg> _msgs = [];

  String? get _userId => WalletServiceScope.of(context).state.userId;

  @override
  void dispose() {
    _client.close();
    _input.dispose();
    _budget.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await _client
        .post(Uri.parse('$backendUrl$path'),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Request failed');
    return data;
  }

  Future<void> _start() async {
    final uid = _userId;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final r = await _post('/api/agent/start', {'userId': uid, 'budget': _budget.text});
      setState(() {
        _started = true;
        _agentAddress = r['agentAddress'] as String?;
        _registered = r['registered'] == true;
        _budgetVal = (r['budget'] as num?)?.toDouble() ?? 0;
        _spent = (r['spent'] as num?)?.toDouble() ?? 0;
        _msgs.add(_Msg(true,
            'Agent live on Arc. I have \$${(_budgetVal - _spent).toStringAsFixed(2)} USDC to trade. Tell me what to predict — e.g. "buy 2 USDC YES on the top market".'));
      });
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final uid = _userId;
    final text = _input.text.trim();
    if (uid == null || text.isEmpty || _busy) return;
    setState(() {
      _msgs.add(_Msg(false, text));
      _input.clear();
      _busy = true;
    });
    _scrollDown();
    try {
      final r = await _post('/api/agent/chat', {'userId': uid, 'message': text});
      final trade = r['trade'] as Map<String, dynamic>?;
      setState(() {
        _msgs.add(_Msg(true, r['reply'] as String? ?? 'Done.',
            txId: trade?['txId'] as String?, contract: trade?['contractAddress'] as String?));
        if (r['remaining'] != null) _spent = _budgetVal - (r['remaining'] as num).toDouble();
      });
    } catch (e) {
      setState(() => _msgs.add(_Msg(true, '⚠️ ${e.toString().replaceAll('Exception: ', '')}')));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollDown();
    }
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  void _toast(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m.replaceAll('Exception: ', ''))));

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(Icons.smart_toy_rounded, color: t.brand, size: 22),
            const SizedBox(width: 8),
            Text('AI Agent', style: TextStyle(color: t.text, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ],
        ),
      ),
      body: SafeArea(child: _started ? _chat(t) : _setup(t)),
    );
  }

  Widget _setup(PulsThemeColors t) {
    final signedIn = _userId != null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_rounded, size: 56, color: t.brand),
            const SizedBox(height: 16),
            Text('Autonomous Trading Agent',
                style: TextStyle(color: t.text, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              'Fund a budget-capped AI agent with its own Arc wallet and ERC-8004 identity. It buys predictions for you — autonomously, on-chain.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textMuted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _budget,
              keyboardType: TextInputType.number,
              style: TextStyle(color: t.text),
              decoration: InputDecoration(
                labelText: 'Budget (USDC)',
                labelStyle: TextStyle(color: t.textMuted),
                prefixText: '\$',
                prefixStyle: TextStyle(color: t.text),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (!signedIn || _busy) ? null : _start,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(signedIn ? 'Activate Agent' : 'Sign in first',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chat(PulsThemeColors t) {
    return Column(
      children: [
        _header(t),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _msgs.length,
            itemBuilder: (_, i) => _bubble(_msgs[i], t),
          ),
        ),
        if (_busy) Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Agent is thinking…', style: TextStyle(color: t.textSubtle, fontSize: 12)),
        ),
        _composer(t),
      ],
    );
  }

  Widget _header(PulsThemeColors t) {
    final addr = _agentAddress ?? '';
    final short = addr.length > 10 ? '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}' : addr;
    final remaining = (_budgetVal - _spent).clamp(0, double.infinity);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: t.brandSubtle, shape: BoxShape.circle),
            child: Icon(Icons.smart_toy_rounded, color: t.brand, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: addr.isEmpty ? null : () => launchUrl(
                          Uri.parse('https://testnet.arcscan.app/address/$addr'),
                          mode: LaunchMode.externalApplication),
                      child: Text(short, style: TextStyle(color: t.brand, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    if (_registered) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.verified_rounded, size: 13, color: t.yes),
                      Text(' ERC-8004', style: TextStyle(color: t.yes, fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('Budget \$${remaining.toStringAsFixed(2)} / \$${_budgetVal.toStringAsFixed(2)} USDC',
                    style: TextStyle(color: t.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m, PulsThemeColors t) {
    final align = m.fromAgent ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final bg = m.fromAgent ? t.surfaceRaised : t.brand;
    final fg = m.fromAgent ? t.text : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: m.fromAgent ? Border.all(color: t.border) : null,
            ),
            child: Text(m.text, style: TextStyle(color: fg, fontSize: 14, height: 1.35)),
          ),
          if (m.txId != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://testnet.arcscan.app/tx/${m.txId}'),
                  mode: LaunchMode.externalApplication),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 13, color: t.yes),
                  const SizedBox(width: 3),
                  Text('Trade executed · View on Arcscan',
                      style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 3),
                  Icon(Icons.open_in_new_rounded, size: 11, color: t.brand),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _composer(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.border))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              style: TextStyle(color: t.text),
              minLines: 1,
              maxLines: 3,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Ask the agent to trade…',
                hintStyle: TextStyle(color: t.textSubtle),
                filled: true,
                fillColor: t.surfaceRaised,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _busy ? null : _send,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: _busy ? t.border : t.brand, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

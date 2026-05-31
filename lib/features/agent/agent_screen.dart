import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config.dart' show backendUrl;
import '../shell/web_layout.dart';

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
  int _reputation = 0;
  String? _agentId;
  double _budgetVal = 0, _spent = 0;
  final List<_Msg> _msgs = [];

  String? get _userId => WalletServiceScope.of(context).state.userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_resumed && _userId != null) {
      _resumed = true;
      _resume();
    }
  }

  bool _resumed = false;

  // Restore an existing agent on page load so funds + agent aren't "lost" after a reload.
  Future<void> _resume() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/api/agent/status?userId=$uid'))
          .timeout(const Duration(seconds: 20));
      final r = jsonDecode(res.body) as Map<String, dynamic>;
      if (r['exists'] == true && mounted) {
        final bal = double.tryParse('${r['balance']}') ?? 0;
        setState(() {
          _started = true;
          _agentAddress = r['agentAddress'] as String?;
          _registered = r['registered'] == true;
          _reputation = (r['reputation'] as num?)?.toInt() ?? 0;
          _agentId = r['agentId'] as String?;
          _budgetVal = bal;
          _spent = 0;
          _msgs.add(_Msg(true,
              'Welcome back. Your agent is live with \$${bal.toStringAsFixed(2)} USDC available. Ask me to trade, or withdraw the funds back to your wallet anytime.'));
        });
      }
    } catch (_) {}
  }

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
        _reputation = (r['reputation'] as num?)?.toInt() ?? 0;
        _agentId = r['agentId'] as String?;
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
            txId: trade?['txHash'] as String?, contract: trade?['contractAddress'] as String?));
        if (r['remaining'] != null) _spent = _budgetVal - (r['remaining'] as num).toDouble();
        if (r['reputation'] != null) _reputation = (r['reputation'] as num).toInt();
      });
      // Agent placed a trade → refresh balance + portfolio instantly.
      if (trade != null && mounted) WalletServiceScope.of(context).notifyTrade();
    } catch (e) {
      setState(() => _msgs.add(_Msg(true, '⚠️ ${e.toString().replaceAll('Exception: ', '')}')));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollDown();
    }
  }

  Future<void> _withdraw() async {
    final uid = _userId;
    if (uid == null || _busy) return;
    setState(() => _busy = true);
    try {
      final r = await _post('/api/agent/withdraw', {'userId': uid});
      final w = (r['withdrawn'] as num?)?.toDouble() ?? 0;
      setState(() {
        _spent = _budgetVal; // remaining now 0
        _msgs.add(_Msg(true,
            w > 0 ? 'Withdrew \$${w.toStringAsFixed(2)} USDC back to your wallet.' : 'Nothing to withdraw.'));
      });
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
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
      body: SafeArea(child: WebLayout(maxWidth: 720, child: _started ? _chat(t) : _setup(t))),
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
            ZoomIn(
              duration: const Duration(milliseconds: 500),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [t.brand, const Color(0xFF818CF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: t.brand.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.smart_toy_rounded, size: 42, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              child: Text('Autonomous Trading Agent',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            ),
            const SizedBox(height: 8),
            FadeInUp(
              delay: const Duration(milliseconds: 160),
              child: Text(
                'Fund a budget-capped AI agent with its own Arc wallet and on-chain ERC-8004 identity. It trades predictions for you — autonomously.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textMuted, fontSize: 14, height: 1.45),
              ),
            ),
            const SizedBox(height: 22),
            FadeInUp(
              delay: const Duration(milliseconds: 220),
              child: Column(
                children: [
                  _feature(t, Icons.account_balance_wallet_rounded, 'Its own Circle MPC wallet on Arc'),
                  _feature(t, Icons.verified_rounded, 'Verifiable ERC-8004 on-chain identity'),
                  _feature(t, Icons.shield_rounded, "Spends only what you fund — can't exceed budget"),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FadeInUp(
              delay: const Duration(milliseconds: 280),
              child: TextField(
                controller: _budget,
                keyboardType: TextInputType.number,
                style: TextStyle(color: t.text),
                decoration: InputDecoration(
                  labelText: 'Budget (USDC)',
                  labelStyle: TextStyle(color: t.textMuted),
                  prefixText: '\$',
                  prefixStyle: TextStyle(color: t.text),
                  filled: true,
                  fillColor: t.surfaceRaised,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeInUp(
              delay: const Duration(milliseconds: 320),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [5, 10, 25, 50].map((v) {
                  final sel = _budget.text == '$v';
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _budget.text = '$v'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? t.brand : t.surfaceRaised,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? t.brand : t.border),
                        ),
                        child: Text('\$$v', style: TextStyle(color: sel ? Colors.white : t.textMuted, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 360),
              child: SizedBox(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature(PulsThemeColors t, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: t.brand),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: t.textMuted, fontSize: 13.5, height: 1.3))),
          ],
        ),
      );

  Widget _chat(PulsThemeColors t) {
    return Column(
      children: [
        _header(t),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _msgs.length,
            itemBuilder: (_, i) => FadeInUp(
              key: ValueKey(i),
              duration: const Duration(milliseconds: 300),
              from: 12,
              child: _bubble(_msgs[i], t),
            ),
          ),
        ),
        if (_msgs.length <= 1 && !_busy) _suggestions(t),
        if (_busy) _thinking(t),
        _composer(t),
      ],
    );
  }

  static const _prompts = [
    'Buy \$2 YES on the top market',
    'Pick a crypto market and bet \$1',
    'What can you trade right now?',
  ];

  Widget _suggestions(PulsThemeColors t) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _prompts.map((p) => GestureDetector(
                onTap: () { _input.text = p; _send(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: t.brandSubtle,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: t.brand.withValues(alpha: 0.25)),
                  ),
                  child: Text(p, style: TextStyle(color: t.brand, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              )).toList(),
        ),
      );

  Widget _thinking(PulsThemeColors t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 16),
        child: Row(
          children: [
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.brand),
            ),
            const SizedBox(width: 8),
            Text('Agent is thinking…', style: TextStyle(color: t.textSubtle, fontSize: 12)),
          ],
        ),
      );

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
                if (_registered) ...[
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: addr.isEmpty ? null : () => launchUrl(
                        Uri.parse('https://testnet.arcscan.app/address/$addr'),
                        mode: LaunchMode.externalApplication),
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, size: 12, color: PulsColors.amber),
                        const SizedBox(width: 3),
                        Text(
                          _reputation > 0
                              ? 'Reputation: $_reputation on-chain attestation${_reputation == 1 ? '' : 's'}'
                              : 'Reputation: builds as it trades',
                          style: TextStyle(color: t.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                        if (_agentId != null) ...[
                          const SizedBox(width: 5),
                          Text('· Agent #$_agentId', style: TextStyle(color: t.textSubtle, fontSize: 10.5)),
                        ],
                        const SizedBox(width: 3),
                        Icon(Icons.open_in_new_rounded, size: 10, color: t.textSubtle),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (remaining > 0.01)
            TextButton(
              onPressed: _busy ? null : _withdraw,
              style: TextButton.styleFrom(
                foregroundColor: t.brand,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: t.brandSubtle,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Withdraw', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
          ] else if (m.contract != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: t.textSubtle)),
                const SizedBox(width: 6),
                Text('Trade submitted · confirming on-chain…',
                    style: TextStyle(color: t.textSubtle, fontSize: 11)),
              ],
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

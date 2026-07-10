import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/config.dart' show backendUrl;
import '../../core/utils/kv_store.dart';
import '../../core/utils/puls_emoji.dart';
import '../../core/widgets/tactile.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/puls_video_illustration.dart';
import '../../app/puls_app.dart';

/// Floating bottom-right widget where the AI agents proactively reach out — each
/// in its own voice — to pitch their fresh signal / blog / trade. Reads
/// `agent_dm` notifications, shows an unread badge, opens a chat-style panel,
/// and lets the user mute an agent. Proof of the swarm's liveliness.
/// Now expanded to be a full messenger to chat with any agent directly.
class AgentInboxWidget extends StatefulWidget {
  const AgentInboxWidget({super.key});

  @override
  State<AgentInboxWidget> createState() => _AgentInboxWidgetState();
}

class _AgentInboxWidgetState extends State<AgentInboxWidget> {
  static const _muteKey = 'agent_dm_muted';
  final _client = http.Client();
  Timer? _poll;
  bool _open = false;
  List<Map<String, dynamic>> _dms = [];
  Set<String> _muted = {};

  int _tabIndex = 0; // 0 = Inbox, 1 = Chat
  String? _selectedAgentKey;
  final List<Map<String, String>> _chatHistory = [];
  final TextEditingController _chatController = TextEditingController();
  bool _chatLoading = false;
  final ScrollController _chatScroll = ScrollController();

  static const _agents = [
    {'key': 'vega', 'name': 'Vega ⚡', 'role': 'Aggressive Trader'},
    {'key': 'cygnus', 'name': 'Cygnus 🛡️', 'role': 'Value Trader'},
    {'key': 'orion', 'name': 'Orion 🔭', 'role': 'Quant Analyst'},
    {'key': 'atlas', 'name': 'Atlas 📈', 'role': 'Crypto Forecaster'},
    {'key': 'nova', 'name': 'Nova 🌐', 'role': 'Politics Analyst'},
    {'key': 'striker', 'name': 'Striker ⚽', 'role': 'Football Analyst'},
  ];

  String? get _userId => WalletServiceScope.of(context).state.userId;

  @override
  void initState() {
    super.initState();
    final raw = kvGet(_muteKey) ?? '';
    _muted = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetch();
      _poll = Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _client.close();
    _chatController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    final s = Supabase.instance.client.auth.currentSession;
    if (s != null) h['Authorization'] = 'Bearer ${s.accessToken}';
    return h;
  }

  Future<void> _fetch() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/api/notifications?type=agent_dm&userId=$uid'),
              headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['notifications'] as List?) ?? const [];
      final dms = <Map<String, dynamic>>[];
      for (final n in list) {
        final m = n as Map<String, dynamic>;
        Map<String, dynamic> payload = {};
        try {
          payload = jsonDecode('${m['message']}') as Map<String, dynamic>;
        } catch (e) {
          debugPrint('[Puls] agent inbox: bad DM payload for ${m['id']}: $e');
        }
        dms.add({
          'id': m['id'],
          'read': m['read'] == true,
          'createdAt': m['created_at'],
          'fromKey': payload['fromKey'] ?? '',
          'fromName': payload['fromName'] ?? (m['title'] ?? 'Agent'),
          'body': payload['body'] ?? '',
          'ctaLabel': payload['ctaLabel'],
          'ctaUrl': payload['ctaUrl'],
        });
      }
      if (mounted) setState(() => _dms = dms);
    } catch (e) {
      debugPrint('[Puls] agent inbox fetch failed: $e');
    }
  }

  List<Map<String, dynamic>> get _visible =>
      _dms.where((d) => !_muted.contains('${d['fromKey']}')).toList();

  int get _unread => _visible.where((d) => d['read'] != true).length;

  void _openPanel() {
    setState(() => _open = true);
    // Mark visible unread DMs read (each individually, so the bell is untouched).
    final uid = _userId;
    if (uid == null) return;
    for (final d in _visible.where((d) => d['read'] != true)) {
      _client
          .post(Uri.parse('$backendUrl/api/notifications/mark-read'),
              headers: _headers,
              body: jsonEncode({'userId': uid, 'notificationId': d['id']}))
          .catchError((_) => http.Response('', 500));
      d['read'] = true;
    }
  }

  void _toggleMute(String key) {
    setState(() {
      if (_muted.contains(key)) {
        _muted.remove(key);
      } else {
        _muted.add(key);
      }
    });
    kvSet(_muteKey, _muted.join(','));
  }

  Future<void> _launch(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _selectedAgentKey == null || _chatLoading) return;
    final agent = _agents.firstWhere((a) => a['key'] == _selectedAgentKey);

    setState(() {
      _chatHistory.add({'role': 'user', 'text': text});
      _chatLoading = true;
    });
    _chatController.clear();
    _scrollToBottom();

    try {
      final res = await WalletServiceScope.of(context).chatWithAgent(
        agentKey: agent['key']!,
        message: text,
      );
      if (mounted) {
        setState(() {
          _chatHistory.add({'role': 'agent', 'text': res['reply'] ?? '...'});
          _chatLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatHistory.add({'role': 'error', 'text': 'Failed to connect.'});
          _chatLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const SizedBox.shrink();
    final t = context.puls;
    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_open) _panel(t),
          const SizedBox(height: 10),
          _fab(t),
        ],
      ),
    );
  }

  Widget _fab(PulsThemeColors t) {
    return Tactile(
      onTap: () => _open ? setState(() => _open = false) : _openPanel(),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [t.brand, const Color(0xFFEC4899)]),
            boxShadow: [
              BoxShadow(
                  color: t.brand.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Icon(_open ? Icons.close_rounded : Icons.forum_rounded,
              color: Colors.white, size: 24),
        ),
        if (!_open && _unread > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              decoration: BoxDecoration(
                  color: t.no,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.bg, width: 2)),
              alignment: Alignment.center,
              child: Text('$_unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
            ),
          ),
      ]),
    );
  }

  Widget _panel(PulsThemeColors t) {
    return Container(
      width: 360,
      height: 480,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(children: [
        _buildHeader(t),
        Divider(height: 1, color: t.border),
        Expanded(
          child: _tabIndex == 0 ? _buildInboxTab(t) : _buildChatTab(t),
        ),
      ]),
    );
  }

  Widget _buildHeader(PulsThemeColors t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      child: Row(children: [
        Icon(Icons.auto_awesome_rounded, size: 18, color: t.brand),
        const SizedBox(width: 8),
        Text('AI Swarm',
            style: TextStyle(
                color: t.text, fontSize: 15, fontWeight: FontWeight.w900)),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _headerTab(t, 'Inbox', 0),
              _headerTab(t, 'Chat', 1),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _headerTab(PulsThemeColors t, String label, int index) {
    final active = _tabIndex == index;
    return Tactile(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.surfaceRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? t.text : t.textMuted,
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600)),
      ),
    );
  }

  Widget _buildInboxTab(PulsThemeColors t) {
    final dms = _visible;
    if (dms.isEmpty) {
      return PulsEmptyState(
        title: 'No messages yet',
        message: 'Trade a bit — the agents will start pitching you their fresh signals and calls here.',
        iconWidget: PulsVideoIllustration(
          asset: 'assets/illustrations/cute-robot-with-speech-bubble-4.mp4',
          width: 100,
          height: 100,
          fallback: PulsEmoji.icon('🤖', size: 64),
        ),
        compact: true,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: dms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _dmTile(t, dms[i]),
    );
  }

  Widget _dmTile(PulsThemeColors t, Map<String, dynamic> d) {
    final key = '${d['fromKey']}';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
              radius: 11,
              backgroundColor: t.brand.withValues(alpha: 0.15),
              child: PulsEmoji.icon(_emojiFor(d['fromName']), size: 11)),
          const SizedBox(width: 7),
          Expanded(
            child: Text('${d['fromName']}',
                style: TextStyle(
                    color: t.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
          Tactile(
            onTap: () => _toggleMute(key),
            child: Icon(
                _muted.contains(key)
                    ? Icons.notifications_off_rounded
                    : Icons.notifications_active_outlined,
                size: 15,
                color: t.textMuted),
          ),
        ]),
        const SizedBox(height: 6),
        Text('${d['body']}',
            style: TextStyle(color: t.text, fontSize: 12.5, height: 1.35)),
        if (d['ctaUrl'] != null && '${d['ctaUrl']}'.isNotEmpty) ...[
          const SizedBox(height: 8),
          Tactile(
            onTap: () => _launch('${d['ctaUrl']}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [t.brand, const Color(0xFFEC4899)]),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${d['ctaLabel'] ?? 'Open'}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 5),
                const Icon(Icons.arrow_forward_rounded,
                    size: 13, color: Colors.white),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildChatTab(PulsThemeColors t) {
    if (_selectedAgentKey == null) {
      return ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: _agents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final a = _agents[i];
          return Tactile(
            onTap: () => setState(() => _selectedAgentKey = a['key']),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: t.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border)),
              child: Row(children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor: t.brand.withValues(alpha: 0.15),
                    child: PulsEmoji.icon(_emojiFor(a['name']), size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${a['name']}',
                          style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w900)),
                      Text('${a['role']}',
                          style: TextStyle(color: t.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.chat_bubble_outline_rounded, color: t.brand, size: 18),
              ]),
            ),
          );
        },
      );
    }

    final agent = _agents.firstWhere((a) => a['key'] == _selectedAgentKey);
    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: t.surfaceRaised,
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Row(children: [
            Tactile(
              onTap: () => setState(() {
                _selectedAgentKey = null;
                _chatHistory.clear();
              }),
              child: Icon(Icons.arrow_back_rounded, color: t.textMuted, size: 20),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
                radius: 10,
                backgroundColor: t.brand.withValues(alpha: 0.15),
                child: PulsEmoji.icon(_emojiFor(agent['name']), size: 10)),
            const SizedBox(width: 8),
            Text('${agent['name']}',
                style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ),
        // Chat History
        Expanded(
          child: _chatHistory.isEmpty
              ? Center(
                  child: Text('Say hello to ${agent['name']}!',
                      style: TextStyle(color: t.textMuted, fontSize: 12)))
              : ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _chatHistory.length + (_chatLoading ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _chatHistory.length) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: t.surfaceRaised,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final msg = _chatHistory[i];
                    final isUser = msg['role'] == 'user';
                    final isError = msg['role'] == 'error';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 240),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser ? t.brand : (isError ? t.no.withValues(alpha: 0.2) : t.surfaceRaised),
                          borderRadius: BorderRadius.circular(12),
                          border: isUser ? null : Border.all(color: t.border),
                        ),
                        child: Text('${msg['text']}',
                            style: TextStyle(
                              color: isUser ? Colors.white : (isError ? t.no : t.text),
                              fontSize: 13,
                              height: 1.3,
                            )),
                      ),
                    );
                  },
                ),
        ),
        // Chat Input
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.bg,
            border: Border(top: BorderSide(color: t.border)),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: TextStyle(color: t.text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(color: t.textMuted, fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.brand),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              Tactile(
                onTap: _chatLoading ? null : _sendMessage,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _chatLoading ? t.surfaceRaised : t.brand,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _emojiFor(dynamic name) {
    final n = '$name';
    final match = RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true)
        .firstMatch(n);
    return match?.group(0) ?? '🤖';
  }
}

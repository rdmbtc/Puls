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
        } catch (_) {}
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
    } catch (_) {}
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
    final dms = _visible;
    return Container(
      width: 340,
      constraints: const BoxConstraints(maxHeight: 460),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
          child: Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: t.brand),
            const SizedBox(width: 8),
            Text('AI Agents',
                style: TextStyle(
                    color: t.text, fontSize: 15, fontWeight: FontWeight.w900)),
            const Spacer(),
            Text('they reach out to you',
                style: TextStyle(color: t.textMuted, fontSize: 10.5)),
          ]),
        ),
        Divider(height: 1, color: t.border),
        Flexible(
          child: dms.isEmpty
              ? PulsEmptyState(
                  title: 'No messages yet',
                  message:
                      'Trade a bit — the agents will start pitching you their fresh signals and calls here.',
                  iconWidget: const PulsVideoIllustration(
                    asset: 'assets/illustrations/cute-robot-with-speech-bubble-4.mp4',
                    width: 100,
                    height: 100,
                  ),
                  compact: true,
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: dms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _dmTile(t, dms[i]),
                ),
        ),
      ]),
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

  String _emojiFor(dynamic name) {
    final n = '$name';
    final match = RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true)
        .firstMatch(n);
    return match?.group(0) ?? '🤖';
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_snack.dart';
import '../../app/puls_app.dart';

class UserChatScreen extends StatefulWidget {
  final String targetUserId;
  final String? targetUserName;

  const UserChatScreen({
    super.key,
    required this.targetUserId,
    this.targetUserName,
  });

  @override
  State<UserChatScreen> createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  
  List<dynamic> _messages = [];
  bool _loading = true;
  Timer? _polling;

  @override
  void initState() {
    super.initState();
    _fetch();
    _polling = Timer.periodic(const Duration(seconds: 3), (_) => _fetch(bg: true));
  }

  @override
  void dispose() {
    _polling?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool bg = false}) async {
    final uid = WalletServiceScope.of(context).state.userId;
    if (uid == null) return;

    try {
      // NOTE: Using backend URL directly (for prod replace with env)
      final res = await http.get(Uri.parse('https://api.puls.dev/api/messages/${widget.targetUserId}?userId=$uid'));
      if (res.statusCode == 200) {
        final List<dynamic> msgs = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _messages = msgs;
            _loading = false;
          });
          if (!bg && _scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        }
      }
    } catch (e) {
      if (!bg && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;

    final uid = WalletServiceScope.of(context).state.userId;
    if (uid == null) {
      PulsSnack.error(context, 'Sign in to message.');
      return;
    }

    _ctrl.clear();
    setState(() {
      _messages.add({
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': uid,
        'target_id': widget.targetUserId,
        'body': body,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      await http.post(
        Uri.parse('https://api.puls.dev/api/messages/${widget.targetUserId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': uid,
          'body': body,
        }),
      );
      _fetch(bg: true);
    } catch (e) {
      if (mounted) PulsSnack.error(context, 'Failed to send.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = WalletServiceScope.of(context).state.userId;
    final t = context.puls;
    
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text(widget.targetUserName ?? 'Chat', style: TextStyle(color: t.text, fontSize: 16)),
        iconTheme: IconThemeData(color: t.textSubtle),
        elevation: 0,
        shape: Border(bottom: BorderSide(color: t.border)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading 
              ? Center(child: CircularProgressIndicator(color: t.brand))
              : _messages.isEmpty
                ? Center(child: Text('No messages yet. Say hi!', style: TextStyle(color: t.textSubtle)))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final isMe = m['user_id'] == myUid;
                      final dt = DateTime.parse(m['created_at']).toLocal();

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: const BoxConstraints(maxWidth: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? t.brand.withAlpha(51) : t.surfaceRaised,
                            border: Border.all(color: isMe ? t.brand.withAlpha(128) : t.border),
                            borderRadius: BorderRadius.circular(12).copyWith(
                              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                              bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['body'], style: TextStyle(color: t.text, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(color: t.textSubtle.withAlpha(178), fontSize: 10)
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(top: BorderSide(color: t.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: TextStyle(color: t.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: t.textSubtle),
                        filled: true,
                        fillColor: t.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send_rounded, color: t.brand),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

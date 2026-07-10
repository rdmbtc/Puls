import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../app/puls_app.dart';
import 'user_chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<dynamic> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final uid = WalletServiceScope.of(context).state.userId;
    if (uid == null) return;

    try {
      final res = await http.get(Uri.parse('https://api.puls.dev/api/messages?userId=$uid'));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _conversations = jsonDecode(res.body);
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = WalletServiceScope.of(context).state.userId;
    final t = context.puls;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text('Messages', style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textSubtle),
        elevation: 0,
        shape: Border(bottom: BorderSide(color: t.border)),
      ),
      body: uid == null
          ? Center(child: Text('Sign in to view messages', style: TextStyle(color: t.textSubtle)))
          : _loading
              ? Center(child: CircularProgressIndicator(color: t.brand))
              : _conversations.isEmpty
                  ? Center(child: Text('No active conversations', style: TextStyle(color: t.textSubtle)))
                  : ListView.separated(
                      itemCount: _conversations.length,
                      separatorBuilder: (context, index) => Divider(color: t.border, height: 1),
                      itemBuilder: (context, i) {
                        final conv = _conversations[i];
                        final partnerId = conv['user_id'] == uid ? conv['target_id'] : conv['user_id'];
                        final isMe = conv['user_id'] == uid;
                        final dt = DateTime.parse(conv['created_at']).toLocal();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: t.surfaceRaised,
                            backgroundImage: NetworkImage('https://api.dicebear.com/7.x/identicon/png?seed=$partnerId&size=64'),
                          ),
                          title: Text(partnerId, style: TextStyle(color: t.text, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Row(
                            children: [
                              if (isMe) Icon(Icons.check, size: 12, color: t.textSubtle),
                              if (isMe) const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  conv['body'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: t.textSubtle),
                                ),
                              ),
                            ],
                          ),
                          trailing: Text(timeAgoShort(dt, includeYears: true), style: TextStyle(color: t.textSubtle, fontSize: 12)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserChatScreen(targetUserId: partnerId),
                              ),
                            ).then((_) => _fetch());
                          },
                        );
                      },
                    ),
    );
  }
}

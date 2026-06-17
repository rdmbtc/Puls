import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config.dart' show backendUrl;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/agent_badge.dart';
import '../../core/widgets/puls_avatar.dart';

class Comment {
  Comment({
    required this.id,
    required this.body,
    required this.authorName,
    required this.authorAvatar,
    required this.isAgent,
    required this.likeCount,
    required this.likedByMe,
    required this.isMine,
    required this.createdAt,
    this.parentId,
    this.replies = const [],
  });

  final String id;
  final String body;
  final String authorName;
  final String? authorAvatar;
  final bool isAgent;
  final int likeCount;
  final bool likedByMe;
  final bool isMine;
  final DateTime createdAt;
  final String? parentId;
  final List<Comment> replies;

  factory Comment.fromJson(Map<String, dynamic> j) {
    final author = j['author'] as Map<String, dynamic>? ?? {};
    return Comment(
      id: '${j['id']}',
      body: j['body'] as String? ?? '',
      authorName: author['displayName'] as String? ?? 'Anonymous',
      authorAvatar: author['avatarUrl'] as String?,
      isAgent: author['isAgent'] == true,
      likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
      likedByMe: j['likedByMe'] == true,
      isMine: j['isMine'] == true,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      parentId: j['parentId']?.toString(),
      replies: (j['replies'] as List?)
              ?.map((r) => Comment.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class CommentThread extends StatefulWidget {
  const CommentThread({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final String targetType;
  final String targetId;

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  List<Comment> _comments = [];
  bool _loading = true;
  String? _error;
  final _inputCtrl = TextEditingController();
  String? _replyToId;
  String? _replyToName;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Map<String, String> get _authHeaders {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    return headers;
  }

  Future<void> _fetch() async {
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/comments?target_type=${widget.targetType}&target_id=${widget.targetId}&limit=50'),
        headers: _authHeaders,
      );
      if (res.statusCode != 200) throw Exception('Couldn\'t load comments');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['comments'] as List? ?? [])
          .map((c) => Comment.fromJson(c as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() { _comments = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _send() async {
    final body = _inputCtrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final payload = <String, dynamic>{
        'target_type': widget.targetType,
        'target_id': widget.targetId,
        'body': body,
      };
      if (_replyToId != null) payload['parent_id'] = _replyToId;
      final res = await http.post(
        Uri.parse('$backendUrl/api/comments'),
        headers: _authHeaders,
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        _inputCtrl.clear();
        _replyToId = null;
        _replyToName = null;
        await _fetch();
      }
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _toggleLike(String commentId) async {
    try {
      await http.post(
        Uri.parse('$backendUrl/api/comments/$commentId/like'),
        headers: _authHeaders,
      );
      await _fetch();
    } catch (_) {}
  }

  Future<void> _delete(String commentId) async {
    try {
      await http.delete(
        Uri.parse('$backendUrl/api/comments/$commentId'),
        headers: _authHeaders,
      );
      await _fetch();
    } catch (_) {}
  }

  void _startReply(String id, String name) {
    setState(() { _replyToId = id; _replyToName = name; });
    _inputCtrl.clear();
  }

  void _cancelReply() {
    setState(() { _replyToId = null; _replyToName = null; });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_loading) return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: CircularProgressIndicator(color: t.brand, strokeWidth: 2),
    ));
    if (_error != null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'COMMENTS',
            style: TextStyle(
              color: t.textSubtle,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'No comments yet — drop your take below.',
              style: TextStyle(color: t.textMuted, fontSize: 13),
            ),
          ),
        ..._comments.map((c) => _CommentCard(
          comment: c,
          t: t,
          onReply: (id) => _startReply(id, c.authorName),
          onLike: _toggleLike,
          onDelete: _delete,
        )),
        const SizedBox(height: 12),
        _buildInput(t),
      ],
    );
  }

  Widget _buildInput(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyToName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text('Replying to $_replyToName',
                      style: TextStyle(color: t.textMuted, fontSize: 11)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: Icon(Icons.close_rounded, size: 16, color: t.textMuted),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(color: t.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _replyToId != null ? 'Write a reply…' : 'Add a comment…',
                    hintStyle: TextStyle(color: t.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.brand),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sending ? null : _send,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: t.brand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.t,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
  });

  final Comment comment;
  final PulsThemeColors t;
  final void Function(String id) onReply;
  final void Function(String id) onLike;
  final void Function(String id) onDelete;

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PulsAvatar(
                url: comment.authorAvatar,
                name: comment.authorName,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: t.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (comment.isAgent) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.smart_toy_rounded, size: 11, color: AgentBadge.agentColor),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          _ago(comment.createdAt),
                          style: TextStyle(color: t.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      comment.body,
                      style: TextStyle(color: t.text, fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => onLike(comment.id),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                comment.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 14,
                                color: comment.likedByMe ? t.no : t.textMuted,
                              ),
                              if (comment.likeCount > 0) ...[
                                const SizedBox(width: 3),
                                Text(
                                  '${comment.likeCount}',
                                  style: TextStyle(
                                    color: comment.likedByMe ? t.no : t.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => onReply(comment.id),
                          child: Text(
                            'Reply',
                            style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (comment.isMine) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => onDelete(comment.id),
                            child: Text(
                              'Delete',
                              style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 4),
              child: Column(
                children: comment.replies.map((r) => _ReplyCard(
                  reply: r,
                  t: t,
                  onLike: onLike,
                  onDelete: onDelete,
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.reply,
    required this.t,
    required this.onLike,
    required this.onDelete,
  });

  final Comment reply;
  final PulsThemeColors t;
  final void Function(String id) onLike;
  final void Function(String id) onDelete;

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulsAvatar(
            url: reply.authorAvatar,
            name: reply.authorName,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        reply.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (reply.isAgent) ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.smart_toy_rounded, size: 10, color: AgentBadge.agentColor),
                    ],
                    const SizedBox(width: 5),
                    Text(_ago(reply.createdAt), style: TextStyle(color: t.textMuted, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(reply.body, style: TextStyle(color: t.text, fontSize: 13, height: 1.35)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => onLike(reply.id),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            reply.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 12,
                            color: reply.likedByMe ? t.no : t.textMuted,
                          ),
                          if (reply.likeCount > 0) ...[
                            const SizedBox(width: 2),
                            Text('${reply.likeCount}',
                                style: TextStyle(color: reply.likedByMe ? t.no : t.textMuted, fontSize: 10)),
                          ],
                        ],
                      ),
                    ),
                    if (reply.isMine) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => onDelete(reply.id),
                        child: Text('Delete', style: TextStyle(color: t.textMuted, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

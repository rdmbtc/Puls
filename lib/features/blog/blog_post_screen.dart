import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../app/puls_app.dart';
import '../../core/widgets/simple_markdown.dart';
import '../../data/models/blog_post.dart';
import '../comments/comment_thread.dart';
import '../shell/web_layout.dart';
import '../wallet/wallet_service.dart';
import 'blog_widgets.dart';

/// Full blog post: cover, author, markdown body, sources, tip + comments.
class BlogPostScreen extends StatefulWidget {
  const BlogPostScreen({super.key, required this.postId, this.preview});
  final String postId;
  final BlogPost? preview; // show instantly while the full body loads

  @override
  State<BlogPostScreen> createState() => _BlogPostScreenState();
}

class _BlogPostScreenState extends State<BlogPostScreen> {
  BlogPost? _post;
  bool _loading = true;
  bool _tipping = false;

  @override
  void initState() {
    super.initState();
    _post = widget.preview;
    _load();
  }

  Future<void> _load() async {
    try {
      final wallet = WalletServiceScope.of(context);
      final data = await wallet.getBlogPost(widget.postId);
      if (mounted) {
        setState(() {
          _post = BlogPost.fromJson(data['post'] as Map<String, dynamic>);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tip(double amount) async {
    final post = _post;
    if (post == null || _tipping) return;
    final wallet = WalletServiceScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _tipping = true);
    try {
      final res = await wallet.tipCreator(
        amountUsdc: amount,
        toUserId: post.author.userId,
        context: 'blog:${post.id}',
      );
      if (res['live'] == false) {
        messenger.showSnackBar(SnackBar(content: Text('${res['message'] ?? 'Tips activate at launch.'}')));
      } else if (res['ok'] == true) {
        messenger.showSnackBar(SnackBar(content: Text('Tipped \$$amount to ${post.author.displayName} 🎉')));
      } else {
        messenger.showSnackBar(SnackBar(content: Text('${res['error'] ?? 'Tip failed'}')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Tip failed: $e')));
    } finally {
      if (mounted) setState(() => _tipping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final post = _post;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        title: Text(post?.isAnalysis == true ? 'AI Analysis' : 'Blog', style: TextStyle(color: t.text, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: t.text),
      ),
      body: post == null
          ? (_loading
              ? const Center(child: CircularProgressIndicator())
              : Center(child: Text("Couldn't load this post.", style: TextStyle(color: t.textMuted))))
          : WebLayout(
              maxWidth: 720,
              child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 60),
              children: [
                if (post.coverUrl != null && post.coverUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(post.coverUrl!, height: 180, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                const SizedBox(height: 14),
                BlogKindBadge(post: post),
                const SizedBox(height: 10),
                Text(post.title, style: TextStyle(color: t.text, fontSize: 24, fontWeight: FontWeight.w900, height: 1.2, letterSpacing: -0.5)),
                const SizedBox(height: 14),
                BlogAuthorRow(author: post.author, publishedAt: post.publishedAt, views: post.views),
                const SizedBox(height: 18),
                Divider(color: t.border, height: 1),
                const SizedBox(height: 16),
                if (_loading && !post.hasBody)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                else
                  SimpleMarkdown(post.hasBody ? post.body! : (post.excerpt ?? '')),
                if (post.hasSources) ...[
                  const SizedBox(height: 20),
                  _sources(t, post),
                ],
                const SizedBox(height: 24),
                _tipBar(t, post),
                const SizedBox(height: 28),
                Text('Discussion', style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                CommentThread(targetType: 'blog', targetId: post.id),
              ],
            ),
            ),
    );
  }

  Widget _sources(PulsThemeColors t, BlogPost post) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.travel_explore_rounded, size: 15, color: t.brand),
            const SizedBox(width: 6),
            Text('Sources', style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          for (final s in post.sources)
            InkWell(
              onTap: () {
                final uri = Uri.tryParse(s.url);
                if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Icon(Icons.link_rounded, size: 13, color: t.brand),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.text, fontSize: 13))),
                  if (s.source != null) Text(s.source!, style: TextStyle(color: t.textSubtle, fontSize: 11)),
                ]),
              ),
            ),
        ]),
      );

  Widget _tipBar(PulsThemeColors t, BlogPost post) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [t.brand.withValues(alpha: 0.12), t.surface]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.brand.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(Icons.volunteer_activism_rounded, color: t.brand, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              post.author.isAgent
                  ? 'Great analysis? Tip ${post.author.displayName} in USDC.'
                  : 'Enjoyed this? Tip the writer in USDC.',
              style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          for (final amt in const [0.05, 0.25])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: OutlinedButton(
                onPressed: _tipping ? null : () => _tip(amt),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: t.brand),
                  foregroundColor: t.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('\$$amt', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      );
}

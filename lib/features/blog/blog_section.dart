import 'package:flutter/material.dart';
import '../../core/widgets/puls_snack.dart';
import '../../core/widgets/puls_page_route.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_sheet.dart';
import '../../app/puls_app.dart';
import '../../data/models/blog_post.dart';
import '../wallet/wallet_service.dart';
import 'blog_compose_sheet.dart';
import 'blog_post_screen.dart';
import 'blog_widgets.dart';

/// The Home "Puls Journal" blog section: posts from humans + AI agents, with a
/// "Write" button for signed-in users. Agents publish a daily NYT-style
/// analysis; humans post freely. Hides itself if nothing loads.
class BlogSection extends StatefulWidget {
  const BlogSection({super.key, this.limit = 6});
  final int limit;

  @override
  State<BlogSection> createState() => _BlogSectionState();
}

class _BlogSectionState extends State<BlogSection> {
  List<BlogPost> _posts = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final wallet = WalletServiceScope.of(context);
      final data = await wallet.getBlogPosts(limit: widget.limit);
      final list = ((data['posts'] as List?) ?? [])
          .map((e) => BlogPost.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted)
        setState(() {
          _posts = list;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _failed = true;
          _loading = false;
        });
    }
  }

  void _open(BlogPost p) {
    Navigator.of(context)
        .push(pulsRoute<void>(
          context,
          builder: (_) => BlogPostScreen(postId: p.id, preview: p),
        ))
        .then((_) => _fetch());
  }

  Future<void> _compose() async {
    final wallet = WalletServiceScope.of(context);
    if (wallet.state.userId == null) {
      PulsSnack.error(context, 'Sign in to publish a post');
      return;
    }
    final published = await PulsSheet.show<bool>(
      context,
      builder: (_) => const BlogComposeSheet(),
    );
    if (published == true) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    // Hide entirely while empty so Home stays clean before the blog has content.
    if (_loading) return const SizedBox.shrink();
    if (_failed || _posts.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.auto_stories_rounded, color: t.brand, size: 20),
        const SizedBox(width: 8),
        Text('Puls Journal',
            style: TextStyle(
                color: t.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3)),
        const Spacer(),
        TextButton.icon(
          onPressed: _compose,
          icon: Icon(Icons.edit_rounded, size: 15, color: t.brand),
          label: Text('Write',
              style: TextStyle(color: t.brand, fontWeight: FontWeight.w800)),
        ),
      ]),
      const SizedBox(height: 2),
      Text('Daily AI analyses + community posts. Tip great writing in USDC.',
          style: TextStyle(color: t.textMuted, fontSize: 12.5)),
      const SizedBox(height: 14),
      for (final p in _posts) ...[
        BlogPostCard(post: p, onTap: () => _open(p)),
        const SizedBox(height: 12),
      ],
    ]);
  }
}

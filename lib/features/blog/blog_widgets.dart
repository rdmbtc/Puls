import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/blog_post.dart';

String blogRelativeTime(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${(d.inDays / 7).floor()}w ago';
}

/// "AI ANALYSIS" / "COMMUNITY" pill that distinguishes agent vs human posts.
class BlogKindBadge extends StatelessWidget {
  const BlogKindBadge({super.key, required this.post});
  final BlogPost post;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isAi = post.isAnalysis || post.author.isAgent;
    final label = isAi ? 'AI ANALYSIS' : 'COMMUNITY';
    final c = isAi ? t.brand : t.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isAi ? Icons.smart_toy_rounded : Icons.people_rounded, size: 11, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: c, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
      ]),
    );
  }
}

/// Author avatar + name (+ agent badge) + relative time and views.
class BlogAuthorRow extends StatelessWidget {
  const BlogAuthorRow({super.key, required this.author, this.publishedAt, this.views = 0});
  final BlogAuthor author;
  final DateTime? publishedAt;
  final int views;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Row(children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: t.surfaceRaised,
        backgroundImage: author.avatarUrl.isNotEmpty ? NetworkImage(author.avatarUrl) : null,
        child: author.avatarUrl.isEmpty ? Icon(Icons.person, size: 16, color: t.textMuted) : null,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(author.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.text, fontSize: 13.5, fontWeight: FontWeight.w800))),
            if (author.isAgent) ...[
              const SizedBox(width: 5),
              Icon(Icons.verified_rounded, size: 13, color: t.brand),
            ],
          ]),
          const SizedBox(height: 1),
          Text(
            [
              if (publishedAt != null) blogRelativeTime(publishedAt),
              if (views > 0) '$views views',
            ].join(' · '),
            style: TextStyle(color: t.textSubtle, fontSize: 11),
          ),
        ]),
      ),
    ]);
  }
}

/// A blog feed card (cover thumbnail optional, kind badge, title, excerpt,
/// author, tags). Tapping opens the post.
class BlogPostCard extends StatelessWidget {
  const BlogPostCard({super.key, required this.post, required this.onTap});
  final BlogPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            BlogKindBadge(post: post),
            const Spacer(),
            if (post.publishedAt != null)
              Text(blogRelativeTime(post.publishedAt), style: TextStyle(color: t.textSubtle, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          if (post.coverUrl != null && post.coverUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(post.coverUrl!, height: 130, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
            const SizedBox(height: 10),
          ],
          Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w900, height: 1.25, letterSpacing: -0.3)),
          if (post.excerpt != null && post.excerpt!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(post.excerpt!, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.45)),
          ],
          const SizedBox(height: 12),
          BlogAuthorRow(author: post.author, publishedAt: null, views: post.views),
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final tag in post.tags.take(4))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(6), border: Border.all(color: t.border)),
                  child: Text('#$tag', style: TextStyle(color: t.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600)),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// A long-form Blog post authored by a human or an autonomous AI agent.
/// Agents publish daily NYT-style analyses (kind == 'analysis') grounded in
/// live web research; humans post freely (kind == 'post').
class BlogPost {
  const BlogPost({
    required this.id,
    required this.title,
    required this.author,
    this.excerpt,
    this.body,
    this.coverUrl,
    this.tags = const [],
    this.sources = const [],
    this.kind = 'post',
    this.views = 0,
    this.featured = false,
    this.publishedAt,
  });

  final String id;
  final String title;
  final BlogAuthor author;
  final String? excerpt;
  final String? body; // markdown — present on the detail fetch
  final String? coverUrl;
  final List<String> tags;
  final List<BlogSource> sources;
  final String kind; // 'post' | 'analysis'
  final int views;
  final bool featured;
  final DateTime? publishedAt;

  bool get isAnalysis => kind == 'analysis';
  bool get hasBody => body != null && body!.isNotEmpty;
  bool get hasSources => sources.isNotEmpty;

  factory BlogPost.fromJson(Map<String, dynamic> j) => BlogPost(
        id: '${j['id']}',
        title: j['title'] as String? ?? '',
        author: BlogAuthor.fromJson(
            (j['author'] as Map<String, dynamic>?) ?? const {}),
        excerpt: j['excerpt'] as String?,
        body: j['body'] as String?,
        coverUrl: j['coverUrl'] as String?,
        tags: (j['tags'] as List?)?.map((e) => '$e').toList() ?? const [],
        sources: (j['sources'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(BlogSource.fromJson)
                .toList() ??
            const [],
        kind: j['kind'] as String? ?? 'post',
        views: (j['views'] as num?)?.toInt() ?? 0,
        featured: j['featured'] == true,
        publishedAt: DateTime.tryParse(j['publishedAt'] as String? ?? ''),
      );
}

class BlogAuthor {
  const BlogAuthor({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.isAgent,
  });

  final String userId;
  final String displayName;
  final String avatarUrl;
  final bool isAgent;

  factory BlogAuthor.fromJson(Map<String, dynamic> j) => BlogAuthor(
        userId: j['userId'] as String? ?? '',
        displayName: j['displayName'] as String? ?? 'Puls Writer',
        avatarUrl: j['avatarUrl'] as String? ?? '',
        isAgent: j['isAgent'] == true,
      );
}

class BlogSource {
  const BlogSource({required this.title, required this.url, this.source});

  final String title;
  final String url;
  final String? source;

  factory BlogSource.fromJson(Map<String, dynamic> j) => BlogSource(
        title: (j['title'] as String?)?.trim().isNotEmpty == true
            ? j['title'] as String
            : (j['source'] as String? ?? j['url'] as String? ?? 'Source'),
        url: j['url'] as String? ?? '',
        source: j['source'] as String?,
      );
}

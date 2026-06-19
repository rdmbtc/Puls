/// A premium creator forecast ("signal") — drafted, published with an on-chain
/// attestation on Arc, and sold per-read via x402 USDC nanopayments.
class CreatorSignal {
  CreatorSignal({
    required this.id,
    required this.creatorUserId,
    required this.title,
    required this.stance,
    required this.priceUsdc,
    required this.status,
    this.marketQuestion,
    this.marketSlug,
    this.marketLink,
    this.sources = const [],
    this.confidence,
    this.edgeBps,
    this.horizon,
    this.teaser,
    this.thesis,
    this.unlocked = false,
    this.isOwner = false,
    this.onchain,
    this.analytics,
    this.publishedAt,
  });

  final String id;
  final String creatorUserId;
  final String title;
  final String stance; // 'YES' | 'NO'
  final double priceUsdc;
  final String status; // 'draft' | 'published' | 'archived'
  final String? marketQuestion;
  final String? marketSlug;
  final String? marketLink;
  final List<SignalSource> sources;
  final double? confidence; // 0..1
  final int? edgeBps;
  final String? horizon;
  final String? teaser;
  final String? thesis; // present only when unlocked or owner
  final bool unlocked;
  final bool isOwner;
  final SignalOnchain? onchain;
  final SignalAnalytics? analytics;
  final DateTime? publishedAt;

  bool get isPublished => status == 'published';
  bool get isDraft => status == 'draft';
  bool get hasThesis => thesis != null && thesis!.isNotEmpty;
  bool get hasMarketLink => (marketSlug != null && marketSlug!.isNotEmpty);
  bool get hasSources => sources.isNotEmpty;

  factory CreatorSignal.fromJson(Map<String, dynamic> j) {
    return CreatorSignal(
      id: '${j['id']}',
      creatorUserId: j['creatorUserId'] as String? ?? '',
      title: j['title'] as String? ?? '',
      stance: (j['stance'] as String? ?? 'YES').toUpperCase(),
      priceUsdc: (j['priceUsdc'] as num?)?.toDouble() ?? 0,
      status: j['status'] as String? ?? 'draft',
      marketQuestion: j['marketQuestion'] as String?,
      marketSlug: j['marketSlug'] as String?,
      marketLink: j['marketLink'] as String?,
      sources: (j['sources'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(SignalSource.fromJson)
              .toList() ??
          const [],
      confidence: (j['confidence'] as num?)?.toDouble(),
      edgeBps: (j['edgeBps'] as num?)?.toInt(),
      horizon: j['horizon'] as String?,
      teaser: j['teaser'] as String?,
      thesis: j['thesis'] as String?,
      unlocked: j['unlocked'] == true,
      isOwner: j['isOwner'] == true,
      onchain: j['onchain'] is Map<String, dynamic>
          ? SignalOnchain.fromJson(j['onchain'] as Map<String, dynamic>)
          : null,
      analytics: j['analytics'] is Map<String, dynamic>
          ? SignalAnalytics.fromJson(j['analytics'] as Map<String, dynamic>)
          : null,
      publishedAt: DateTime.tryParse(j['publishedAt'] as String? ?? ''),
    );
  }
}

/// A live web source the creator researched for a signal (proof of grounding).
class SignalSource {
  const SignalSource({required this.title, required this.url, this.source});

  final String title;
  final String url;
  final String? source; // hostname, e.g. "espn.com"

  factory SignalSource.fromJson(Map<String, dynamic> j) => SignalSource(
        title: (j['title'] as String?)?.trim().isNotEmpty == true
            ? j['title'] as String
            : (j['source'] as String? ?? j['url'] as String? ?? 'Source'),
        url: j['url'] as String? ?? '',
        source: j['source'] as String?,
      );
}

/// On-chain attestation proof for a published signal.
class SignalOnchain {
  SignalOnchain({required this.tx, this.signalId, this.contentHash, this.explorer});

  final String tx;
  final String? signalId;
  final String? contentHash;
  final String? explorer;

  factory SignalOnchain.fromJson(Map<String, dynamic> j) => SignalOnchain(
        tx: j['tx'] as String? ?? '',
        signalId: j['signalId'] as String?,
        contentHash: j['contentHash'] as String?,
        explorer: j['explorer'] as String?,
      );
}

/// Per-signal creator analytics.
class SignalAnalytics {
  SignalAnalytics({required this.views, required this.unlocks, required this.revenueUsdc, this.conversion});

  final int views;
  final int unlocks;
  final double revenueUsdc;
  final double? conversion;

  factory SignalAnalytics.fromJson(Map<String, dynamic> j) => SignalAnalytics(
        views: (j['views'] as num?)?.toInt() ?? 0,
        unlocks: (j['unlocks'] as num?)?.toInt() ?? 0,
        revenueUsdc: (j['revenueUsdc'] as num?)?.toDouble() ?? 0,
        conversion: (j['conversion'] as num?)?.toDouble(),
      );
}

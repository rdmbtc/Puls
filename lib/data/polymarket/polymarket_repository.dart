import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/config.dart' show backendUrl;
import '../models/market.dart';

class PolymarketRepository {
  int _offset = 0;

  Future<List<Market>> fetchMarkets({int limit = 100}) async {
    // Fetch two pages of 50 in parallel for 100 total, rotating offset each refresh
    final off1 = _offset;
    final off2 = _offset + 50;
    _offset = (_offset + 100) % 500; // cycle through top 500

    final results = await Future.wait([
      _fetch(50, off1),
      _fetch(50, off2),
      _fetchWorldCup(),
    ]);

    // Merge, de-duplicating by id/slug (a WC market may also be in the feed page).
    final seen = <String>{};
    final markets = <Market>[];
    for (final m in [...results[0], ...results[1], ...results[2]]) {
      final key = m.id.isNotEmpty ? m.id : m.slug;
      if (key.isEmpty || seen.add(key)) markets.add(m);
    }
    // Pin deployed (pre-warmed) markets first for instant sub-second trades
    markets.sort((a, b) {
      final aDep = a.contractAddress != null ? 1 : 0;
      final bDep = b.contractAddress != null ? 1 : 0;
      return bDep - aDep;
    });
    return markets;
  }

  /// Pulls live World Cup 2026 markets straight from Polymarket (real consensus
  /// odds), so the dedicated "World Cup" feed category is always populated with
  /// many YES/NO questions (winner per team, top scorer, etc.) — not just the
  /// few that happen to land on the top-volume feed page.
  Future<List<Market>> _fetchWorldCup() async {
    const slugs = ['world-cup-winner'];
    final out = <Market>[];
    for (final slug in slugs) {
      try {
        final uri = Uri.parse('https://gamma-api.polymarket.com/events?slug=$slug');
        final res = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) continue;
        final events = json.decode(res.body) as List<dynamic>;
        if (events.isEmpty) continue;
        final ev = events.first as Map<String, dynamic>;
        final mkts = (ev['markets'] as List<dynamic>?) ?? const [];
        for (final raw in mkts) {
          final j = raw as Map<String, dynamic>;
          // Skip closed/inactive/zero-liquidity placeholder team slots.
          if (j['closed'] == true || j['active'] == false) continue;
          final m = _parse(j);
          if (m == null) continue;
          // _parse already infers the "World Cup" category from the FIFA
          // question text — just collect the parsed markets.
          out.add(m);
        }
      } catch (_) {
        // best-effort — never break the feed because of the WC fetch
      }
    }
    return out;
  }

  /// Fetches a single market by slug — used for share deep links (/m/<slug>)
  /// when the market isn't in the currently loaded feed page.
  Future<Market?> fetchMarketBySlug(String slug) async {
    // 1) Polymarket gamma API (open CORS) — covers real Polymarket markets.
    try {
      final uri = Uri.parse(
        'https://gamma-api.polymarket.com/markets?slug=${Uri.encodeQueryComponent(slug)}',
      );
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final list = json.decode(res.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final market = _parse(list.first as Map<String, dynamic>);
          if (market != null) return market;
        }
      }
    } catch (_) {
      // fall through to backend
    }
    // 2) Puls backend — covers custom user-created markets.
    try {
      final uri = Uri.parse(
        '$backendUrl/api/market/info?slug=${Uri.encodeQueryComponent(slug)}',
      );
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = json.decode(res.body) as Map<String, dynamic>;
        return _parse({
          'id': slug,
          'slug': slug,
          'question': j['question'] ?? slug,
          'contractAddress': j['contractAddress'],
          'yesPrice': j['yesPrice'],
          'noPrice': j['noPrice'],
          'outcomePrices': '["${j['yesPrice'] ?? 0.5}","${j['noPrice'] ?? 0.5}"]',
          'volumeNum': j['totalVolume'],
          'endDate': j['deadline'] != null
              ? DateTime.fromMillisecondsSinceEpoch((j['deadline'] as num).toInt() * 1000)
                  .toIso8601String()
              : null,
        });
      }
    } catch (_) {
      // not found anywhere
    }
    return null;
  }

  Future<List<Market>> _fetch(int limit, int offset) async {
    final uri = Uri.parse(
      '$backendUrl/api/markets?limit=$limit&offset=$offset',
    );
    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];
    final list = json.decode(res.body) as List<dynamic>;
    return list
        .map((j) => _parse(j as Map<String, dynamic>))
        .whereType<Market>()
        .toList();
  }

  Market? _parse(Map<String, dynamic> j) {
    try {
      final rawPrices = j['outcomePrices'] as String? ?? '["0.5","0.5"]';
      final prices = (json.decode(rawPrices) as List)
          .map((p) => double.tryParse(p.toString()) ?? 0.5)
          .toList();
      if (prices.length < 2) return null;

      String category = _inferCategory(j);

      final volNum = (j['volumeNum'] as num?)?.toDouble() ??
          double.tryParse(j['volume']?.toString() ?? '0') ?? 0;
      final liqNum = (j['liquidityNum'] as num?)?.toDouble() ??
          double.tryParse(j['liquidity']?.toString() ?? '0') ?? 0;
      final trend = (j['oneDayPriceChange'] as num?)?.toDouble() ?? 0.0;
      final endRaw = j['endDate'] as String? ?? j['endDateIso'] as String?;
      final deadline = endRaw != null
          ? DateTime.tryParse(endRaw) ?? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30));

      // Freshly deployed on-chain LMSR pools sit at exactly 50/50 until the
      // first trade — that's "no price discovery yet", not a real signal.
      // Prefer Polymarket's live odds in that case so the feed shows real
      // market prices instead of a wall of 50¢ placeholders.
      final onchainYes = (j['yesPrice'] as num?)?.toDouble();
      final onchainNo = (j['noPrice'] as num?)?.toDouble();
      final hasPriceDiscovery =
          onchainYes != null && (onchainYes - 0.5).abs() > 0.001;
      final yesPrice = hasPriceDiscovery ? onchainYes : prices[0];
      final noPrice =
          hasPriceDiscovery ? (onchainNo ?? (1 - yesPrice)) : prices[1];

      return Market(
        id: j['id']?.toString() ?? j['slug']?.toString() ?? '',
        slug: j['slug'] as String? ?? '',
        contractAddress: j['contractAddress'] as String?,
        question: j['question'] as String? ?? '',
        category: category,
        context: j['description'] as String? ?? '',
        yesPrice: yesPrice.clamp(0.01, 0.99),
        noPrice: noPrice.clamp(0.01, 0.99),
        volume: _fmt(volNum),
        liquidity: _fmt(liqNum),
        deadline: deadline,
        trend: trend,
        isFeatured: j['featured'] == true || j['new'] == true,
        tags: [category],
        history: const [],
        comments: const [],
        news: const [],
        imageUrl: j['image'] as String? ?? '',
        volume24hr: (j['volume24hr'] as num?)?.toDouble() ?? 0,
        lastTradePrice: (j['lastTradePrice'] as num?)?.toDouble() ?? prices[0],
        bestBid: (j['bestBid'] as num?)?.toDouble() ?? 0,
        bestAsk: (j['bestAsk'] as num?)?.toDouble() ?? 0,
        spread: (j['spread'] as num?)?.toDouble() ?? 0,
        clobTokenId: _firstClobToken(j['clobTokenIds']),
        liquidityNum: liqNum,
        competitive: (j['competitive'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  String _inferCategory(Map<String, dynamic> j) {
    // 1. Try tags inside events (sometimes present)
    final events = j['events'] as List<dynamic>?;
    if (events != null && events.isNotEmpty) {
      final ev = events.first as Map<String, dynamic>;
      final tags = ev['tags'] as List<dynamic>?;
      if (tags != null && tags.isNotEmpty) {
        final label = (tags.first as Map)['label'] as String?;
        if (label != null && label.isNotEmpty) return label;
      }
      // 2. Use seriesSlug to infer category
      final series = ev['series'];
      String? slug;
      if (series is List && series.isNotEmpty) {
        slug = (series.first as Map)['slug'] as String?;
      } else if (series is Map) {
        slug = series['slug'] as String?;
      }
      if (slug != null) {
        if (slug.contains('nba') || slug.contains('nfl') || slug.contains('nhl') ||
            slug.contains('mlb') || slug.contains('soccer') || slug.contains('football') ||
            slug.contains('basketball') || slug.contains('tennis') || slug.contains('golf') ||
            slug.contains('ufc') || slug.contains('boxing') || slug.contains('cricket') ||
            slug.contains('counter-strike') || slug.contains('esport') || slug.contains('dota') ||
            slug.contains('league-of-legends') || slug.contains('valorant')) {
          return _slugToCategory(slug);
        }
      }
      // 3. Use event title keywords
      final title = (ev['title'] as String? ?? '').toLowerCase();
      return _titleToCategory(title);
    }
    // 4. Fall back to market question keywords
    final q = (j['question'] as String? ?? '').toLowerCase();
    return _titleToCategory(q);
  }

  String _slugToCategory(String slug) {
    if (slug.contains('counter-strike') || slug.contains('esport') ||
        slug.contains('dota') || slug.contains('valorant') || slug.contains('league-of-legends')) { return 'Esports'; }
    if (slug.contains('nba') || slug.contains('basketball')) { return 'Basketball'; }
    if (slug.contains('nfl') || slug.contains('football')) { return 'Football'; }
    if (slug.contains('nhl') || slug.contains('hockey')) { return 'Hockey'; }
    if (slug.contains('mlb') || slug.contains('baseball')) { return 'Baseball'; }
    if (slug.contains('soccer')) { return 'Soccer'; }
    if (slug.contains('tennis')) { return 'Tennis'; }
    if (slug.contains('golf')) { return 'Golf'; }
    if (slug.contains('ufc') || slug.contains('boxing') || slug.contains('mma')) { return 'Combat Sports'; }
    if (slug.contains('cricket')) { return 'Cricket'; }
    return 'Sports';
  }

  String _titleToCategory(String text) {
    // World Cup gets its own first-class category (real Polymarket markets).
    if (text.contains('world cup') || text.contains('fifa')) { return 'World Cup'; }
    if (text.contains('bitcoin') || text.contains('crypto') || text.contains('eth') ||
        text.contains('btc') || text.contains('solana') || text.contains('token') ||
        text.contains('defi') || text.contains('nft')) { return 'Crypto'; }
    if (text.contains('election') || text.contains('president') || text.contains('senate') ||
        text.contains('congress') || text.contains('vote') || text.contains('trump') ||
        text.contains('democrat') || text.contains('republican') || text.contains('poll')) { return 'Politics'; }
    if (text.contains('stock') || text.contains('ipo') || text.contains('market cap') ||
        text.contains('nasdaq') || text.contains('s&p') || text.contains('fed') ||
        text.contains('interest rate') || text.contains('gdp') || text.contains('inflation')) { return 'Finance'; }
    if (text.contains('ai') || text.contains('openai') || text.contains('gpt') ||
        text.contains('spacex') || text.contains('tesla') || text.contains('apple') ||
        text.contains('google') || text.contains('microsoft') || text.contains('tech')) { return 'Tech'; }
    if (text.contains('oil') || text.contains('gold') || text.contains('silver') ||
        text.contains('commodity') || text.contains('crude') || text.contains('gas')) { return 'Commodities'; }
    if (text.contains('nba') || text.contains('nfl') || text.contains('soccer') ||
        text.contains('tennis') || text.contains('golf') || text.contains('ufc') ||
        text.contains('cricket') || text.contains('counter-strike') || text.contains('esport')) { return 'Sports'; }
    if (text.contains('oscar') || text.contains('grammy') || text.contains('movie') ||
        text.contains('show') || text.contains('celebrity') || text.contains('music')) { return 'Entertainment'; }
    if (text.contains('climate') || text.contains('weather') || text.contains('hurricane') ||
        text.contains('earthquake') || text.contains('science')) { return 'Science'; }
    return 'General';
  }

  String _fmt(double v) {
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  String _firstClobToken(dynamic raw) {
    if (raw == null) return '';
    try {
      final list = json.decode(raw.toString()) as List;
      return list.isNotEmpty ? list.first.toString() : '';
    } catch (_) {
      return '';
    }
  }
}

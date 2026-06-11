import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../models/market.dart';

/// Fetches YES price history for a market.
///
/// Polymarket-mirrored markets use the CLOB prices-history API. Markets
/// without a CLOB token (e.g. user-created markets) fall back to the Puls
/// backend, which reconstructs the YES-price series from recorded trades.
/// Returns a list of prices (0.0–1.0) ordered oldest→newest.
class PriceHistoryService {
  static const _clob = 'https://clob.polymarket.com';

  // Simple in-memory caches
  static final _cache = <String, List<double>>{};
  static final _backendCache = <String, List<double>>{};

  /// Preferred entry point: picks the best available source for [market].
  static Future<List<double>> fetchForMarket(Market market) async {
    if (market.clobTokenId.isNotEmpty) {
      final clobHistory = await fetch(market.clobTokenId);
      if (clobHistory.isNotEmpty) return clobHistory;
    }
    return fetchFromBackend(market.slug);
  }

  static Future<List<double>> fetch(String clobTokenId) async {
    if (clobTokenId.isEmpty) return [];
    if (_cache.containsKey(clobTokenId)) return _cache[clobTokenId]!;

    try {
      final uri = Uri.parse(
        '$_clob/prices-history?market=$clobTokenId&interval=1d&fidelity=60',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final history = (data['history'] as List? ?? [])
          .map((e) => (e['p'] as num).toDouble())
          .toList();
      _cache[clobTokenId] = history;
      return history;
    } catch (_) {
      return [];
    }
  }

  /// YES-price series derived from on-chain trades recorded by the backend.
  static Future<List<double>> fetchFromBackend(String slug) async {
    if (slug.isEmpty) return [];
    if (_backendCache.containsKey(slug)) return _backendCache[slug]!;

    try {
      final uri = Uri.parse(
        '$backendUrl/api/market/price-history?slug=${Uri.encodeComponent(slug)}&hours=720',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final history = (data['points'] as List? ?? [])
          .map((e) => ((e as Map<String, dynamic>)['yesPrice'] as num).toDouble())
          .toList();
      if (history.isNotEmpty) _backendCache[slug] = history;
      return history;
    } catch (_) {
      return [];
    }
  }
}

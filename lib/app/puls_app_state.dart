import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart' show appUrl;
import '../core/utils/kv_store.dart';
import '../core/utils/trade_math.dart';
import '../data/mock/mock_market_repository.dart';
import '../data/models/market.dart';
import '../data/models/position.dart';
import '../data/polymarket/polymarket_repository.dart';

enum FeedStatus { loading, loaded, error }

class PulsAppState extends ChangeNotifier {
  static PulsAppState? instance;

  PulsAppState({required this.mockRepo}) {
    instance = this;
    _positions = List<Position>.from(mockRepo.initialPositions);
    _watchlistIds = mockRepo.initialWatchlistIds.toSet();
    // Restore the saved theme so a dark/light choice survives a reload.
    final savedTheme = kvGet(_kThemeKey);
    if (savedTheme == 'dark') {
      themeMode = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      themeMode = ThemeMode.light;
    }
    // AI Oracle Panel is opt-in (off by default) — restore the saved choice.
    aiOracleEnabled = kvGet(_kOracleKey) == 'on';
    // Reduce-motion: null = follow the OS setting; 'on'/'off' = explicit override.
    final savedReduceMotion = kvGet(_kReduceMotionKey);
    if (savedReduceMotion == 'on') {
      reduceMotionOverride = true;
    } else if (savedReduceMotion == 'off') {
      reduceMotionOverride = false;
    }
    _loadMarkets();
  }

  static const String _kThemeKey = 'puls_theme_mode';
  static const String _kOracleKey = 'puls_ai_oracle';
  static const String _kReduceMotionKey = 'puls_reduce_motion';

  final MockMarketRepository mockRepo;
  final _polymarket = PolymarketRepository();

  List<Market> _markets = [];
  List<Position> _positions = [];
  Set<String> _watchlistIds = {};

  FeedStatus feedStatus = FeedStatus.loading;
  String? feedError;

  bool onboardingComplete = false;
  ThemeMode themeMode = ThemeMode.light;
  bool fastBuyEnabled = false;
  double fastBuyAmount = 1.0;
  // AI Oracle Panel on market detail — opt-in, off by default.
  bool aiOracleEnabled = false;
  /// Reduce-motion override: null = follow the OS setting, true/false = explicit.
  bool? reduceMotionOverride;

  List<Market> get markets => List.unmodifiable(_markets);
  List<Position> get positions => List.unmodifiable(_positions);
  List<String> get watchlistIds => List.unmodifiable(_watchlistIds);

  List<String> get categories {
    final cats = _markets
        .where((m) => !m.createdByAgent)
        .map((m) => m.category)
        .toSet()
        .toList();
    cats.sort();
    // Agent-created markets get their own category instead of polluting the feed.
    if (_markets.any((m) => m.createdByAgent)) cats.add('AI Agents');
    return cats;
  }

  // Rank by real Pulse engagement first (holders/trades/comments); fall back to
  // external Polymarket volume only to order the zero-Pulse-activity tail.
  static int _byHotness(Market a, Market b) {
    final p = b.pulsScore.compareTo(a.pulsScore);
    return p != 0 ? p : b.volumeNum.compareTo(a.volumeNum);
  }

  /// The main feed: untraded, NON-agent markets, hottest (most trading
  /// activity) first. Agent-created markets are surfaced separately via
  /// [agentMarkets] / the "AI Agents" category.
  List<Market> get feedMarkets {
    final tradedIds = _positions.map((p) => p.marketId).toSet();
    final fresh = _markets
        .where((m) => !tradedIds.contains(m.id) && !m.createdByAgent)
        .toList()
      ..sort(_byHotness);
    return fresh.isNotEmpty ? fresh : _markets;
  }

  /// Agent-created markets ("AI Agents" category), hottest first.
  List<Market> get agentMarkets {
    final tradedIds = _positions.map((p) => p.marketId).toSet();
    return _markets
        .where((m) => m.createdByAgent && !tradedIds.contains(m.id))
        .toList()
      ..sort(_byHotness);
  }

  List<Market> get watchlistMarkets =>
      _markets.where((m) => _watchlistIds.contains(m.id)).toList();

  Market marketById(String id) =>
      _markets.firstWhere((m) => m.id == id);

  /// Resolves a market by slug for share deep links (/m/<slug>). Checks the
  /// loaded feed first; otherwise fetches the single market and adds it to the
  /// feed so detail screens can look it up by id.
  Future<Market?> ensureMarketBySlug(String slug) async {
    for (final m in _markets) {
      if (m.slug == slug || m.id == slug) return m;
    }
    final fetched = await _polymarket.fetchMarketBySlug(slug);
    if (fetched == null) return null;
    _markets = [fetched, ..._markets];
    notifyListeners();
    return fetched;
  }

  bool isWatchlisted(String marketId) => _watchlistIds.contains(marketId);

  Future<void> _loadMarkets() async {
    feedStatus = FeedStatus.loading;
    notifyListeners();
    try {
      debugPrint('[Puls] Fetching Polymarket markets…');
      final fetched = await _polymarket.fetchMarkets(limit: 100);
      _markets = fetched;
      debugPrint('[Puls] Loaded ${_markets.length} markets');
      feedStatus = FeedStatus.loaded;
    } catch (e, st) {
      debugPrint('[Puls] Fetch error: $e\n$st');
      feedError = e.toString();
      feedStatus = FeedStatus.error;
    }
    notifyListeners();
  }

  Future<void> refresh() => _loadMarkets();

  void completeOnboarding() {
    // On the marketing landing host (pulsmarket.tech) the product lives on the
    // app subdomain — send the visitor there so pulsmarket.tech stays the
    // landing and app.pulsmarket.tech is the app. Elsewhere (the app subdomain
    // itself, or local dev) just reveal the in-app shell.
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'pulsmarket.tech' || host == 'www.pulsmarket.tech') {
        launchUrl(Uri.parse(appUrl), webOnlyWindowName: '_self');
        return;
      }
    }
    onboardingComplete = true;
    notifyListeners();
  }

  void toggleThemeMode() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    // Persist so the choice is kept across reloads/sessions.
    kvSet(_kThemeKey, themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  void toggleFastBuy() {
    fastBuyEnabled = !fastBuyEnabled;
    notifyListeners();
  }

  void toggleAiOracle() {
    aiOracleEnabled = !aiOracleEnabled;
    kvSet(_kOracleKey, aiOracleEnabled ? 'on' : 'off');
    notifyListeners();
  }

  /// Set the reduce-motion override (true = reduce, false = full motion).
  /// Overrides the OS "reduce motion" setting app-wide.
  void setReduceMotion(bool value) {
    reduceMotionOverride = value;
    kvSet(_kReduceMotionKey, value ? 'on' : 'off');
    notifyListeners();
  }

  void setFastBuyAmount(double amount) {
    fastBuyAmount = amount;
    notifyListeners();
  }

  void toggleWatchlist(String marketId) {
    if (_watchlistIds.contains(marketId)) {
      _watchlistIds.remove(marketId);
    } else {
      _watchlistIds.add(marketId);
    }
    notifyListeners();
  }

  Position addDemoPosition({
    required Market market,
    required MarketSide side,
    required double amount,
  }) {
    final price = side == MarketSide.yes ? market.yesPrice : market.noPrice;
    final shares = TradeMath.estimatedShares(amount: amount, price: price);
    final position = Position(
      id: 'pos-${DateTime.now().microsecondsSinceEpoch}',
      marketId: market.id,
      question: market.question,
      side: side,
      amount: amount,
      entryPrice: price,
      currentPrice: price,
      shares: shares,
      openedAt: DateTime.now(),
    );
    _positions.insert(0, position);
    notifyListeners();
    return position;
  }
}

class PulsStateScope extends InheritedNotifier<PulsAppState> {
  const PulsStateScope({
    required PulsAppState super.notifier,
    required super.child,
    super.key,
  });

  static PulsAppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PulsStateScope>();
    assert(scope != null, 'PulsStateScope not found');
    return scope!.notifier!;
  }

  static PulsAppState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PulsStateScope>()?.notifier;
}

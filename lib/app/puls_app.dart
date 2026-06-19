import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/puls_page_route.dart';
import '../data/mock/mock_market_repository.dart';
import '../features/market/market_detail_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/puls_shell.dart';
import '../features/wallet/wallet_service.dart';
import 'puls_app_state.dart';

class PulsApp extends StatefulWidget {
  const PulsApp({super.key});

  @override
  State<PulsApp> createState() => _PulsAppState();
}

class _PulsAppState extends State<PulsApp> {
  late final PulsAppState _state;
  final _walletService = WalletService();
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// Slug from a share deep link (https://pulsmarket.tech/m/<slug> redirects
  /// to /?m=<slug>). Held until the shell + market feed are ready, then the
  /// market detail screen is pushed once.
  String? _pendingDeepLinkSlug;
  bool _deepLinkOpening = false;

  @override
  void initState() {
    super.initState();
    _state = PulsAppState(mockRepo: MockMarketRepository());
    _pendingDeepLinkSlug = _parseDeepLinkSlug(Uri.base);
  }

  static String? _parseDeepLinkSlug(Uri uri) {
    final q = uri.queryParameters['m'];
    if (q != null && q.trim().isNotEmpty) return q.trim();
    final segs = uri.pathSegments;
    if (segs.length >= 2 && segs[0] == 'm' && segs[1].trim().isNotEmpty) {
      return segs[1].trim();
    }
    return null;
  }

  void _maybeOpenDeepLink(bool shellVisible) {
    final slug = _pendingDeepLinkSlug;
    if (slug == null || _deepLinkOpening || !shellVisible) return;
    if (_state.feedStatus == FeedStatus.loading) return;
    _deepLinkOpening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final market = await _state.ensureMarketBySlug(slug);
      _pendingDeepLinkSlug = null;
      if (market == null) return; // unknown slug — stay on the feed
      _navigatorKey.currentState?.push(
        pulsRoute<void>(
          _navigatorKey.currentContext,
          builder: (_) => MarketDetailScreen(marketId: market.id),
        ),
      );
    });
  }

  @override
  void dispose() {
    _walletService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_state, _walletService]),
      builder: (context, _) {
        final shellVisible = _state.onboardingComplete ||
            _walletService.state.userId != null ||
            _pendingDeepLinkSlug != null; // cold /m/<slug> visitors land in-app
        _maybeOpenDeepLink(shellVisible);
        return WalletServiceScope(
          service: _walletService,
          child: PulsStateScope(
            notifier: _state,
            child: MaterialApp(
              title: 'Puls',
              debugShowCheckedModeBanner: false,
              navigatorKey: _navigatorKey,
              theme: PulsTheme.light(),
              darkTheme: PulsTheme.dark(),
              themeMode: _state.themeMode,
              home: shellVisible ? const PulsShell() : const OnboardingScreen(),
            ),
          ),
        );
      },
    );
  }
}

// ── InheritedNotifier scope for WalletService ─────────────────────────────────
class WalletServiceScope extends InheritedNotifier<WalletService> {
  const WalletServiceScope({
    required WalletService service,
    required super.child,
    super.key,
  }) : super(notifier: service);

  static WalletService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<WalletServiceScope>();
    assert(scope != null, 'WalletServiceScope not found');
    return scope!.notifier!;
  }
}

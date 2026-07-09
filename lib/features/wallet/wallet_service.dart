import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart' show backendUrl;
import '../../core/utils/kv_store.dart';
import 'web3_wallet_bridge.dart' as web3;
const _backendUrl = backendUrl;

final _supabase = Supabase.instance.client;

class WalletState {
  const WalletState({
    this.userId,
    this.walletId,
    this.walletAddress,
    this.usdcBalance = '0',
    this.isLoading = false,
    this.error,
    this.isExternalWallet = false,
  });

  final String? userId;
  final String? walletId;
  final String? walletAddress;
  final String usdcBalance;
  final bool isLoading;
  final String? error;
  final bool isExternalWallet;

  bool get hasWallet => walletId != null || isExternalWallet;

  WalletState copyWith({
    String? userId,
    String? walletId,
    String? walletAddress,
    String? usdcBalance,
    bool? isLoading,
    String? error,
    bool? isExternalWallet,
  }) =>
      WalletState(
        userId: userId ?? this.userId,
        walletId: walletId ?? this.walletId,
        walletAddress: walletAddress ?? this.walletAddress,
        usdcBalance: usdcBalance ?? this.usdcBalance,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isExternalWallet: isExternalWallet ?? this.isExternalWallet,
      );
}

class WalletService extends ChangeNotifier {
  WalletState _state = const WalletState();
  WalletState get state => _state;
  Timer? _refreshTimer;
  final http.Client _client = http.Client();

  /// Bumped whenever a trade is placed (by the user or the agent) so other
  /// screens (Portfolio) can reload instantly instead of waiting on realtime.
  final ValueNotifier<int> tradeSignal = ValueNotifier<int>(0);

  /// Call after any trade to trigger an instant balance refresh + portfolio reload.
  void notifyTrade() {
    refreshBalance();
    tradeSignal.value++;
  }

  WalletService() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && _state.userId == null) {
        _onSignedIn(data.session!.user);
      } else if (data.session == null) {
        _refreshTimer?.cancel();
        _state = const WalletState();
        notifyListeners();
      }
    });
    final existing = _supabase.auth.currentSession;
    if (existing != null) _onSignedIn(existing.user);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _client.close();
    tradeSignal.dispose();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => refreshBalance());
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    _setState(_state.copyWith(isLoading: true, error: null));
    try {
      // On web, redirectTo must be the current app URL (not localhost)
      String? redirectTo;
      if (kIsWeb) {
        // Use the current page origin so it works on any deployment
        redirectTo = Uri.base.origin;
      } else {
        redirectTo = 'io.supabase.puls://login-callback';
      }
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> signOut() async {
    if (_state.isExternalWallet) {
      web3.disconnectBrowserWallet();
    } else {
      await _supabase.auth.signOut();
    }
    _refreshTimer?.cancel();
    _state = const WalletState();
    notifyListeners();
  }

  // ── External wallet (MetaMask) ────────────────────────────────────────────

  /// Connect an external browser wallet (MetaMask, etc.)
  Future<void> signInWithExternalWallet() async {
    if (!kIsWeb) return;
    _setState(_state.copyWith(isLoading: true, error: null));
    try {
      final result = await web3.connectBrowserWallet();
      if (result.error != null) {
        _setState(_state.copyWith(isLoading: false, error: result.error));
        return;
      }
      final address = result.address!;
      final userId = 'eth_$address';
      _setState(_state.copyWith(
        userId: userId,
        walletAddress: address,
        isExternalWallet: true,
        isLoading: false,
      ));
      // Fetch balance from chain
      await _fetchBalanceFromChain(address);
      _startPeriodicRefresh();
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Whether a browser wallet (MetaMask) is available.
  bool get hasBrowserWalletAvailable => kIsWeb && web3.hasBrowserWallet();

  void _onSignedIn(User user) {
    final userId = 'supabase_${user.id}';
    _setState(_state.copyWith(userId: userId, isLoading: true));
    _getOrCreateWallet(userId);
  }

  // ── Wallet — auto-created by backend, no WebView needed ───────────────────

  Future<void> _getOrCreateWallet(String userId) async {
    try {
      final res = await _post('/api/wallet/get-or-create', {'userId': userId});
      final address = res['address'] as String? ?? '';
      final balance = res['usdcBalance'] as String? ?? '0';
      _setState(_state.copyWith(
        walletId: res['walletId'] as String,
        walletAddress: address,
        usdcBalance: balance,
        isLoading: false,
      ));
      if (address.isNotEmpty) {
        _fetchBalanceFromChain(address);
      } else {
        debugPrint('[Puls] wallet address empty from backend, balance: $balance');
      }
      _startPeriodicRefresh();
      // Fire-and-forget: if this user arrived via a friend's ?ref= link, attribute
      // the referral now that they have a verified account + wallet.
      _maybeClaimReferral();
    } catch (e) {
      debugPrint('[Puls] get-or-create error: $e');
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Attribute a pending referral (captured from a `?ref=CODE` link at startup)
  /// once the user has a verified account. Idempotent server-side — claiming
  /// twice, self-referring, or using a bad code all fail harmlessly. We clear
  /// the stored code afterward either way so it never retries in a loop.
  /// External (web3 guest) wallets are read-only server-side, so skip them.
  Future<void> _maybeClaimReferral() async {
    final userId = _state.userId;
    if (userId == null || !userId.startsWith('supabase_')) return;
    final code = kvGet('puls_ref');
    if (code == null || code.isEmpty) return;
    try {
      await _post('/api/referrals/claim', {'userId': userId, 'code': code});
    } catch (_) {
      // Invalid / self / already-claimed — nothing to do.
    } finally {
      kvRemove('puls_ref');
    }
  }

  Future<void> refreshBalance() async {
    if (_state.userId == null) return;
    if (_state.walletAddress != null && _state.walletAddress!.isNotEmpty) {
      await _fetchBalanceFromChain(_state.walletAddress!);
      return;
    }
    // No address yet — reload wallet info from backend
    await reloadWallet();
  }

  /// Re-fetches wallet info from backend (address + balance).
  Future<void> reloadWallet() async {
    if (_state.userId == null) return;
    try {
      final res = await _post('/api/wallet/get-or-create', {'userId': _state.userId!});
      final address = res['address'] as String? ?? '';
      _setState(_state.copyWith(
        walletId: res['walletId'] as String? ?? _state.walletId,
        walletAddress: address.isNotEmpty ? address : _state.walletAddress,
        usdcBalance: res['usdcBalance'] as String? ?? _state.usdcBalance,
        isLoading: false,
      ));
      if (address.isNotEmpty) _fetchBalanceFromChain(address);
    } catch (_) {}
  }

  /// Reads USDC balance directly from Arc Testnet via eth_call — no backend needed.
  Future<void> _fetchBalanceFromChain(String address) async {
    const publicRpc = 'https://rpc.testnet.arc.network';
    const usdc = '0x3600000000000000000000000000000000000000';
    final padded = address.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');
    final data = '0x70a08231$padded';
    try {
      // Try backend RPC Proxy first (which hides credentials and supports CORS on web)
      try {
        const proxyUrl = '$_backendUrl/api/rpc-proxy';
        final res = await _client.post(
          Uri.parse(proxyUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'method': 'eth_call',
            'params': [{'to': usdc, 'data': data}, 'latest'],
            'id': 1,
          }),
        ).timeout(const Duration(seconds: 4));
        final result = (jsonDecode(res.body) as Map)['result'] as String?;
        if (result != null && result.length >= 2) {
          final raw = BigInt.tryParse(result.replaceFirst('0x', ''), radix: 16) ?? BigInt.zero;
          final balance = raw / BigInt.from(1000000);
          _setState(_state.copyWith(usdcBalance: balance.toStringAsFixed(2)));
          return;
        }
      } catch (e) {
        debugPrint('[Puls] RPC proxy balance fetch failed: $e');
      }

      // Fallback to public RPC with retry
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final res = await _client.post(
            Uri.parse(publicRpc),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'eth_call',
              'params': [{'to': usdc, 'data': data}, 'latest'],
              'id': 1,
            }),
          ).timeout(const Duration(seconds: 8));
          final result = (jsonDecode(res.body) as Map)['result'] as String?;
          if (result != null && result.length >= 2) {
            final raw = BigInt.tryParse(result.replaceFirst('0x', ''), radix: 16) ?? BigInt.zero;
            final balance = raw / BigInt.from(1000000);
            _setState(_state.copyWith(usdcBalance: balance.toStringAsFixed(2)));
            return;
          }
          break; // got a response but no usable result — don't retry
        } catch (e) {
          debugPrint('[Puls] Public RPC attempt ${attempt + 1} failed: $e');
          if (attempt == 0) await Future.delayed(const Duration(seconds: 2));
        }
      }
    } catch (e) {
      debugPrint('[Puls] chain balance error: $e');
      // Fallback to backend balance endpoint
      try {
        if (_state.userId != null) {
          final res = await _get('/api/wallet/balance', {'userId': _state.userId!});
          _setState(_state.copyWith(
            usdcBalance: res['usdcBalance'] as String? ?? _state.usdcBalance,
          ));
        }
      } catch (_) {}
    }
  }

  // ── Trade ─────────────────────────────────────────────────────────────────

  /// Fire-and-forget: deploy the market's on-chain LMSR contract ahead of a
  /// trade (e.g. when its detail screen opens) so the user's first buy/sell
  /// doesn't wait on a cold deploy. Server-side no-op if already deployed.
  void prewarmMarket(String slug, int deadline) {
    if (slug.isEmpty) return;
    _post('/api/market/activate', {'slug': slug, 'deadline': deadline})
        .then((_) {}, onError: (_) {});
  }

  Future<Map<String, dynamic>> buyPosition({
    required bool isYes,
    required double usdcAmount,
    required String question,
    required String slug,
    required int deadline,
    double entryPrice = 0.5,
    String? contractAddress,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    if (!_state.hasWallet) throw Exception('No wallet');

    // Optimistic balance update: subtract transaction amount immediately (1ms UI response)
    final currentVal = double.tryParse(_state.usdcBalance) ?? 0.0;
    final newVal = (currentVal - usdcAmount).clamp(0.0, double.infinity);
    _setState(_state.copyWith(usdcBalance: newVal.toStringAsFixed(2)));

    try {
      if (_state.isExternalWallet) {
        String addr = contractAddress ?? '';
        if (addr.isEmpty) {
          final activateRes = await _post('/api/market/activate', {
            'slug': slug,
            'deadline': deadline,
          });
          addr = activateRes['contractAddress'] as String? ?? '';
          if (addr.isEmpty) throw Exception('Failed to activate prediction market contract');
        }
        final web3Res = await web3.buyPositionOnChain(isYes, usdcAmount, addr);
        if (web3Res.error != null) throw Exception(web3Res.error!);
        
        final txHash = web3Res.txHash!;
        await _post('/api/trade/save-external', {
          'userId': _state.userId!,
          'side': isYes ? 'YES' : 'NO',
          'usdcAmount': usdcAmount.toStringAsFixed(6),
          'entryPrice': entryPrice.toStringAsFixed(4),
          'question': question,
          'txHash': txHash,
          'marketId': addr,
        });
        
        refreshBalance();
        return {'txId': txHash, 'state': 'COMPLETE'};
      }

      // Cold markets deploy their LMSR contract on-chain inside this request
      // (several seconds), so give the first trade a generous timeout — a 15s
      // cap was causing a "Future not completed" error on the first buy.
      final res = await _post('/api/trade/buy', {
        'userId': _state.userId!,
        'side': isYes ? 'YES' : 'NO',
        'usdcAmount': usdcAmount.toStringAsFixed(6),
        'question': question,
        'entryPrice': entryPrice.toStringAsFixed(4),
        'slug': slug,
        'deadline': deadline,
      }, timeout: contractAddress == null
          ? const Duration(seconds: 75)
          : const Duration(seconds: 30));

      // Trigger a sync in the background immediately
      refreshBalance();
      // Instant portfolio update: the trade row already exists server-side, so
      // listeners (portfolio) can show the position right away and then poll it
      // from pending -> confirmed without a page reload.
      notifyTrade();
      return res;
    } catch (e) {
      // Revert optimistic update on failure by fetching real balance
      refreshBalance();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sellPosition({
    required bool isYes,
    required double shares,
    required String question,
    required String slug,
    required int deadline,
    double entryPrice = 0.5,
    String? contractAddress,
    String owner = 'user',
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    if (!_state.hasWallet) throw Exception('No wallet');

    // Agent-bought positions are held by the user's AI-agent (MPC) wallet, so they
    // must be sold server-side from that wallet — never via the browser wallet.
    final isAgentPosition = owner == 'agent';

    // Optimistic balance update: estimate payout based on entryPrice (1ms UI update)
    final currentVal = double.tryParse(_state.usdcBalance) ?? 0.0;
    final estimatedPayout = shares * entryPrice;
    final newVal = currentVal + estimatedPayout;
    _setState(_state.copyWith(usdcBalance: newVal.toStringAsFixed(2)));

    try {
      if (_state.isExternalWallet && !isAgentPosition) {
        String addr = contractAddress ?? '';
        if (addr.isEmpty) {
          final activateRes = await _post('/api/market/activate', {
            'slug': slug,
            'deadline': deadline,
          });
          addr = activateRes['contractAddress'] as String? ?? '';
          if (addr.isEmpty) throw Exception('Failed to retrieve contract address for selling');
        }
        final web3Res = await web3.sellPositionOnChain(isYes, shares, addr);
        if (web3Res.error != null) throw Exception(web3Res.error!);
        
        final txHash = web3Res.txHash!;
        final estimatedPayout = shares * entryPrice;
        await _post('/api/trade/save-external', {
          'userId': _state.userId!,
          'side': isYes ? 'YES' : 'NO',
          'usdcAmount': (-estimatedPayout).toStringAsFixed(6), // Estimated USDC payout (reconciled by webhook)
          'entryPrice': entryPrice.toStringAsFixed(4),
          'question': question,
          'txHash': txHash,
          'marketId': addr,
        });
        
        refreshBalance();
        return {'txId': txHash, 'state': 'COMPLETE'};
      }

      final res = await _post('/api/trade/sell', {
        'userId': _state.userId!,
        'side': isYes ? 'YES' : 'NO',
        'shares': shares.toStringAsFixed(6),
        'question': question,
        'entryPrice': entryPrice.toStringAsFixed(4),
        'slug': slug,
        'deadline': deadline,
        'owner': owner,
        if (contractAddress != null && contractAddress.isNotEmpty) 'contractAddress': contractAddress,
      }, timeout: const Duration(seconds: 30));

      // Trigger a sync in the background immediately
      refreshBalance();
      return res;
    } catch (e) {
      // Revert optimistic update on failure by fetching real balance
      refreshBalance();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> claimWinnings({String? contractAddress, String? slug}) async {
    if (_state.userId == null) throw Exception('Not signed in');
    
    if (_state.isExternalWallet) {
      if (contractAddress == null || contractAddress.isEmpty) {
        throw Exception('Market contract address not available');
      }
      final addr = contractAddress;
      final web3Res = await web3.claimOnChain(addr);
      if (web3Res.error != null) throw Exception(web3Res.error!);
      
      final txHash = web3Res.txHash!;
      await _post('/api/trade/save-external', {
        'userId': _state.userId!,
        'side': 'CLAIM',
        'usdcAmount': '0',
        'entryPrice': '0',
        'question': 'Claim Winnings',
        'txHash': txHash,
        'marketId': addr,
      });
      
      refreshBalance();
      return {'txId': txHash, 'state': 'COMPLETE'};
    }
    
    final res = await _post('/api/trade/claim', {
      'userId': _state.userId!,
      'slug': slug ?? '',
      if (contractAddress != null && contractAddress.isNotEmpty) 'contractAddress': contractAddress,
    });
    // Refresh immediately + again after 8s for on-chain confirmation
    refreshBalance();
    Future.delayed(const Duration(seconds: 8), refreshBalance);
    return res;
  }

  // ── Profiles & Leaderboard ────────────────────────────────────────────────
  
  Future<List<dynamic>> getLeaderboard({String sort = 'pnl', int limit = 50, String type = 'all'}) async {
    final headers = <String, String>{};
    final session = _supabase.auth.currentSession;
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    final uri = Uri.parse('$backendUrl/api/leaderboard').replace(queryParameters: {
      'sort': sort,
      'limit': limit.toString(),
      'type': type,
    });
    final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['error'] ?? 'Failed to load leaderboard');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final headers = <String, String>{};
    final session = _supabase.auth.currentSession;
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    final uri = Uri.parse('$backendUrl/api/profile/$userId');
    final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Failed to load profile');
    return data;
  }

  /// My referral code, share link, and who I've invited.
  /// Sends userId explicitly: the auth middleware can't reliably inject
  /// req.query.userId on GET requests, so without this the server inserts a
  /// null user_id and 500s. `_get` also attaches a fresh token (cold-load safe).
  Future<Map<String, dynamic>> getReferralInfo() async {
    return _get('/api/referrals/me', {
      if (_state.userId != null) 'userId': _state.userId!,
    });
  }

  /// Generate a Puls API key (for the Puls CLI / programmatic access). The raw
  /// `pk_live_…` key is returned ONCE — surface it immediately for copying.
  Future<Map<String, dynamic>> generateApiKey({String? label}) async {
    return _post('/api/keys/generate', {
      if (_state.userId != null) 'userId': _state.userId!,
      if (label != null && label.isNotEmpty) 'label': label,
    });
  }

  /// List my API keys (prefix + metadata only; never the raw key). Sends userId
  /// explicitly (GET query injection isn't reliable server-side).
  Future<List<dynamic>> listApiKeys() async {
    final r = await _get('/api/keys', {
      if (_state.userId != null) 'userId': _state.userId!,
    });
    return r['keys'] as List<dynamic>? ?? const [];
  }

  /// Revoke one of my API keys.
  Future<void> revokeApiKey(String id) async {
    await _post('/api/keys/revoke', {
      if (_state.userId != null) 'userId': _state.userId!,
      'id': id,
    });
  }

  // ── Copy-trade ────────────────────────────────────────────────────────────

  /// Whether the signed-in user is currently copying [leaderUserId].
  /// Returns { following: bool, maxPerTradeUsdc: num?, live: bool }.
  Future<Map<String, dynamic>> getCopyStatus(String leaderUserId) async {
    final headers = <String, String>{};
    final session = _supabase.auth.currentSession;
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    final uri = Uri.parse('$backendUrl/api/copy/status').replace(queryParameters: {
      if (_state.userId != null) 'userId': _state.userId!,
      'leaderUserId': leaderUserId,
    });
    final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Failed to load copy status');
    return data;
  }

  /// Start copying [leaderUserId] with a per-trade USDC spend cap.
  Future<void> copyFollow(String leaderUserId, double maxPerTradeUsdc) async {
    if (_state.userId == null) throw Exception('Not signed in');
    await _post('/api/copy/follow', {
      'userId': _state.userId!,
      'leaderUserId': leaderUserId,
      'maxPerTradeUsdc': maxPerTradeUsdc,
    });
  }

  /// Stop copying [leaderUserId].
  Future<void> copyUnfollow(String leaderUserId) async {
    if (_state.userId == null) throw Exception('Not signed in');
    await _post('/api/copy/unfollow', {
      'userId': _state.userId!,
      'leaderUserId': leaderUserId,
    });
  }

  // ── Alpha paid-analysis ─────────────────────────────────────────────────

  /// List premium forecasts. Teaser only; annotates which the user unlocked.
  /// Returns { signals: [...], live: bool, seller }.
  Future<Map<String, dynamic>> getAlphaList() async {
    final headers = <String, String>{};
    final session = _supabase.auth.currentSession;
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    final uri = Uri.parse('$backendUrl/api/alpha/list').replace(queryParameters: {
      if (_state.userId != null) 'userId': _state.userId!,
    });
    final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Failed to load alpha');
    return data;
  }

  /// Full thesis for one signal (only if unlocked). Returns { locked, signal }.
  /// 402 (locked) is returned as data, not thrown.
  Future<Map<String, dynamic>> getAlphaSignal(String id) async {
    final headers = <String, String>{};
    final session = _supabase.auth.currentSession;
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    final uri = Uri.parse('$backendUrl/api/alpha/$id').replace(queryParameters: {
      if (_state.userId != null) 'userId': _state.userId!,
    });
    final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Unlock a signal — pays the creator a per-read USDC micro-fee.
  /// Returns { ok, live?, alreadyUnlocked?, signal, receipt? }.
  Future<Map<String, dynamic>> unlockAlpha(String id) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/alpha/$id/unlock', {'userId': _state.userId!}, timeout: const Duration(seconds: 30));
  }

  // ── Creator Signals (full creator-economy content layer) ─────────────────

  /// List signals. Pass [creatorUserId] for a creator's signals (your own =
  /// drafts + analytics + thesis; others = published teasers). Returns the raw
  /// { signals: [...], live } map.
  Future<Map<String, dynamic>> getSignals({String? creatorUserId}) async {
    return _get('/api/signals', {
      if (_state.userId != null) 'userId': _state.userId!,
      if (creatorUserId != null) 'creatorUserId': creatorUserId,
    });
  }

  /// The autonomous agent swarm roster (names, brains, balances, decisions).
  Future<Map<String, dynamic>> getAgentRoster() async {
    return _get('/api/agents/roster', const {});
  }

  /// Unified AI Colony feed — every swarm agent's actions, newest first.
  Future<Map<String, dynamic>> getColonyFeed({int limit = 40}) async {
    return _get('/api/agents/feed', {'limit': '$limit'});
  }

  /// AI Oracle Panel — swarm consensus vs crowd (Polymarket) for a market.
  Future<Map<String, dynamic>> getOracle(String slug) async {
    return _get('/api/oracle/$slug', const {});
  }

  /// AI predict-to-predict correlations for a market.
  Future<Map<String, dynamic>> getOracleCorrelations(String slug) async {
    return _get('/api/oracle/correlations/$slug', const {});
  }

  /// Ask an agent to defend a side of a market with live sources.
  Future<Map<String, dynamic>> askAgent({
    required String slug,
    String? question,
    String? side,
    String? agentName,
  }) async {
    return _post('/api/oracle/ask', {
      if (_state.userId != null) 'userId': _state.userId!,
      'slug': slug,
      if (question != null) 'question': question,
      if (side != null) 'side': side,
      if (agentName != null) 'agentName': agentName,
    }, timeout: const Duration(seconds: 35));
  }

  /// Chat directly with an agent.
  Future<Map<String, dynamic>> chatWithAgent({
    required String agentKey,
    required String message,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/agents/chat', {
      'userId': _state.userId!,
      'agentKey': agentKey,
      'message': message,
    }, timeout: const Duration(seconds: 45));
  }

  /// Blog feed — posts by humans + AI agents (public).
  Future<Map<String, dynamic>> getBlogPosts({String? tag, String? author, int limit = 30}) async {
    return _get('/api/blog', {
      'limit': '$limit',
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      if (author != null && author.isNotEmpty) 'author': author,
    });
  }

  /// A single blog post with full markdown body (counts a view).
  Future<Map<String, dynamic>> getBlogPost(String id) async {
    return _get('/api/blog/$id', const {});
  }

  /// Publish a blog post (verified users). Body is markdown.
  Future<Map<String, dynamic>> createBlogPost({
    required String title,
    required String body,
    String? excerpt,
    String? coverUrl,
    List<String>? tags,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/blog', {
      'userId': _state.userId!,
      'title': title,
      'body': body,
      if (excerpt != null) 'excerpt': excerpt,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (tags != null) 'tags': tags,
    }, timeout: const Duration(seconds: 20));
  }

  /// Points/XP summary for the signed-in user (level, XP, streak).
  Future<Map<String, dynamic>> getPoints() async {
    return _get('/api/points/me', {
      if (_state.userId != null) 'userId': _state.userId!,
    });
  }

  /// Onboarding + daily quests with this user's status.
  Future<Map<String, dynamic>> getQuests() async {
    return _get('/api/quests', {
      if (_state.userId != null) 'userId': _state.userId!,
    });
  }

  /// Claim a completed quest (server re-validates). Returns { ok, awarded, points }.
  Future<Map<String, dynamic>> claimQuest(String questKey) async {
    return _post('/api/quests/claim', {
      'userId': _state.userId,
      'quest_key': questKey,
    });
  }

  /// Batch-claim every resolved+won+unclaimed position. Returns { ok, claimed }.
  Future<Map<String, dynamic>> claimAllWinnings() async {
    return _post('/api/trade/claim-all', {'userId': _state.userId},
        timeout: const Duration(seconds: 40));
  }

  /// Points/season leaderboard (humans vs agents).
  Future<List<dynamic>> getPointsLeaderboard({String type = 'all'}) async {
    final uri = Uri.parse('$_backendUrl/api/points/leaderboard')
        .replace(queryParameters: {'type': type, 'limit': '20'});
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return [];
    return jsonDecode(res.body) as List<dynamic>;
  }

  /// One signal. 402 (locked) is returned as data, not thrown.
  Future<Map<String, dynamic>> getSignal(String id) async {
    final headers = <String, String>{};
    final session = _supabase.auth.currentSession;
    if (session != null) headers['Authorization'] = 'Bearer ${session.accessToken}';
    final uri = Uri.parse('$_backendUrl/api/signals/$id').replace(queryParameters: {
      if (_state.userId != null) 'userId': _state.userId!,
    });
    final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Create a draft signal. Returns { ok, signal }.
  Future<Map<String, dynamic>> createSignal({
    required String title,
    required String thesis,
    String? marketQuestion,
    String? marketSlug,
    String stance = 'YES',
    double confidence = 0.6,
    int edgeBps = 0,
    String? horizon,
    String? teaser,
    double priceUsdc = 0.001,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/signals', {
      'userId': _state.userId!,
      'title': title,
      'thesis': thesis,
      if (marketQuestion != null) 'marketQuestion': marketQuestion,
      if (marketSlug != null) 'marketSlug': marketSlug,
      'stance': stance,
      'confidence': confidence,
      'edgeBps': edgeBps,
      if (horizon != null) 'horizon': horizon,
      if (teaser != null) 'teaser': teaser,
      'priceUsdc': priceUsdc,
    });
  }

  /// Edit a draft signal. Pass only the fields to change. Returns { ok, signal }.
  Future<Map<String, dynamic>> updateSignal(String id, Map<String, dynamic> patch) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _patch('/api/signals/$id', {'userId': _state.userId!, ...patch});
  }

  /// Publish a draft — writes the on-chain attestation. Returns { ok, attested, signal }.
  Future<Map<String, dynamic>> publishSignal(String id) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/signals/$id/publish', {'userId': _state.userId!}, timeout: const Duration(seconds: 30));
  }

  /// Archive (withdraw) a signal. Returns { ok, signal }.
  Future<Map<String, dynamic>> archiveSignal(String id) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/signals/$id/archive', {'userId': _state.userId!});
  }

  /// Unlock a signal — pays the creator a per-read USDC micro-fee.
  /// Returns { ok, live?, alreadyUnlocked?, signal, receipt? }.
  Future<Map<String, dynamic>> unlockSignal(String id) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/signals/$id/unlock', {'userId': _state.userId!}, timeout: const Duration(seconds: 30));
  }

  /// Owner-only per-signal analytics. Returns { analytics, onchain }.
  Future<Map<String, dynamic>> getSignalAnalytics(String id) async {
    return _get('/api/signals/$id/analytics', {
      if (_state.userId != null) 'userId': _state.userId!,
    });
  }

  // ── Puls Streams (pay-per-second USDC streaming on Arc) ─────────────────
  /// Public streaming config (rate/cap model, settle threshold, live flag).
  Future<Map<String, dynamic>> streamsConfig() => _get('/api/streams/config', {});

  /// Network-wide streaming totals (streamed / settled USDC, active count).
  Future<Map<String, dynamic>> streamsSummary() => _get('/api/streams/stats/summary', {});

  /// Your streams (as payer or recipient). Returns { streams }.
  Future<Map<String, dynamic>> listStreams() async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _get('/api/streams', {'userId': _state.userId!});
  }

  /// Open a stream — authorize a rate ($/sec) + cap (continuous authorization).
  Future<Map<String, dynamic>> openStream({
    String? recipientUserId,
    String? recipientAddress,
    String? resource,
    required double ratePerSecUsdc,
    required double capUsdc,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/streams/open', {
      'userId': _state.userId!,
      if (recipientUserId != null) 'recipientUserId': recipientUserId,
      if (recipientAddress != null) 'recipientAddress': recipientAddress,
      if (resource != null) 'resource': resource,
      'ratePerSecUsdc': ratePerSecUsdc,
      'capUsdc': capUsdc,
    }, timeout: const Duration(seconds: 30));
  }

  /// Heartbeat / proof-of-flow — advance the meter by the time consumed.
  Future<Map<String, dynamic>> tickStream(String id) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/streams/$id/tick', {'userId': _state.userId!});
  }

  /// Pause the meter.
  Future<Map<String, dynamic>> pauseStream(String id) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/streams/$id/pause', {'userId': _state.userId!});
  }

  /// Resume a paused stream.
  Future<Map<String, dynamic>> resumeStream(String id) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/streams/$id/resume', {'userId': _state.userId!});
  }

  /// Stop the stream — final settle of exactly what flowed.
  Future<Map<String, dynamic>> stopStream(String id) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/streams/$id/stop', {'userId': _state.userId!});
  }

  // ── Token swap (Circle App Kit: USDC <-> EURC on Arc) ────────────────────

  /// Quote a swap. Returns { ok, estimate }.
  Future<Map<String, dynamic>> estimateSwap({
    required String tokenIn,
    required String tokenOut,
    required double amountIn,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/swap/estimate', {
      'userId': _state.userId!,
      'tokenIn': tokenIn,
      'tokenOut': tokenOut,
      'amountIn': amountIn,
    }, timeout: const Duration(seconds: 30));
  }

  /// Execute a swap from the user's Circle wallet. Returns { ok, amountOut, txHash, explorerUrl }.
  Future<Map<String, dynamic>> swap({
    required String tokenIn,
    required String tokenOut,
    required double amountIn,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/swap', {
      'userId': _state.userId!,
      'tokenIn': tokenIn,
      'tokenOut': tokenOut,
      'amountIn': amountIn,
    }, timeout: const Duration(seconds: 60));
  }

  /// Withdraw USDC from the user's Puls wallet to any Arc address.
  /// Returns { ok, txHash, explorerUrl }.
  Future<Map<String, dynamic>> withdrawUsdc({
    required String to,
    required double amountUsdc,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/wallet/withdraw', {
      'userId': _state.userId!,
      'to': to,
      'amountUsdc': amountUsdc,
    }, timeout: const Duration(seconds: 60));
  }


  /// One-tap tip to a forecaster — a small real USDC nanopayment.
  /// Recipient defaults to the house creator payout; pass [toUserId] to tip a
  /// specific user, or [toAddress] for an explicit address.
  /// Returns { ok, live?, receipt? }.
  Future<Map<String, dynamic>> tipCreator({
    required double amountUsdc,
    String? toUserId,
    String? toAddress,
    String? context,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    return _post('/api/tips', {
      'userId': _state.userId!,
      'amountUsdc': amountUsdc,
      if (toUserId != null) 'toUserId': toUserId,
      if (toAddress != null) 'toAddress': toAddress,
      if (context != null) 'context': context,
    }, timeout: const Duration(seconds: 30));
  }

  Future<void> updateProfile({
    required String displayName,
    required String bio,
    required String avatarUrl,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    await _post('/api/profile/update', {
      'userId': _state.userId!,
      'displayName': displayName,
      'bio': bio,
      'avatarUrl': avatarUrl,
    });
  }

  // ── Push Notifications & FCM ──────────────────────────────────────────────

  Future<void> registerFcmToken(String token) async {
    if (_state.userId == null) return;
    try {
      await _post('/api/notifications/register-token', {
        'userId': _state.userId!,
        'fcmToken': token,
      });
    } catch (e) {
      debugPrint('[WalletService] Failed to register FCM token: $e');
    }
  }

  Future<List<dynamic>> getNotifications() async {
    if (_state.userId == null) return [];
    try {
      final res = await _get('/api/notifications', {'userId': _state.userId!});
      return res['notifications'] as List<dynamic>? ?? res as List<dynamic>? ?? [];
    } catch (e) {
      debugPrint('[WalletService] Failed to fetch notifications: $e');
      return [];
    }
  }

  Future<void> markNotificationsRead({String? notificationId}) async {
    if (_state.userId == null) return;
    try {
      await _post('/api/notifications/mark-read', {
        'userId': _state.userId!,
        if (notificationId != null) 'notificationId': notificationId,
      });
    } catch (e) {
      debugPrint('[WalletService] Failed to mark notifications as read: $e');
    }
  }

  // ── Custom Markets ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createCustomMarket({
    required String question,
    required String description,
    required String category,
    required int deadline,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    final res = await _post('/api/markets/create', {
      'userId': _state.userId!,
      'question': question,
      'description': description,
      'category': category,
      'deadline': deadline,
    });
    notifyTrade(); // refresh balance since 10 USDC is deducted
    return res;
  }

  // ── Limit Orders ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> placeLimitOrder({
    required bool isBuy,
    required bool isYes,
    required double amount,
    required double targetPrice,
    required String slug,
    required String marketId,
    required int deadline,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    if (!_state.hasWallet) throw Exception('No wallet');
    
    // Optimistically subtract USDC balance if BUY order
    if (isBuy) {
      final currentVal = double.tryParse(_state.usdcBalance) ?? 0.0;
      final newVal = (currentVal - amount).clamp(0.0, double.infinity);
      _setState(_state.copyWith(usdcBalance: newVal.toStringAsFixed(2)));
    }
    
    try {
      final res = await _post('/api/trade/limit-order', {
        'userId': _state.userId!,
        'marketId': marketId,
        'slug': slug,
        'side': isYes ? 'YES' : 'NO',
        'type': isBuy ? 'BUY' : 'SELL',
        'usdcAmount': isBuy ? amount.toStringAsFixed(6) : '0',
        'shares': !isBuy ? amount.toStringAsFixed(6) : '0',
        'targetPrice': targetPrice.toStringAsFixed(4),
      });
      
      refreshBalance();
      return res;
    } catch (e) {
      refreshBalance(); // Revert optimistic update on failure
      rethrow;
    }
  }

  Future<List<dynamic>> getLimitOrders() async {
    if (_state.userId == null) return [];
    try {
      final res = await _get('/api/trade/limit-orders', {'userId': _state.userId!});
      return res['orders'] as List<dynamic>? ?? res as List<dynamic>? ?? [];
    } catch (e) {
      debugPrint('[WalletService] Failed to fetch limit orders: $e');
      return [];
    }
  }

  Future<void> cancelLimitOrder(String orderId) async {
    if (_state.userId == null) throw Exception('Not signed in');
    await _post('/api/trade/limit-order/cancel', {
      'userId': _state.userId!,
      'orderId': orderId,
    });
    refreshBalance();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setState(WalletState s) {
    _state = s;
    notifyListeners();
  }

  /// Public: a valid access token (refreshes a stale/cold session). Use this in
  /// screens that build their own http requests so they self-heal on cold load.
  Future<String?> freshAccessToken() => _freshAccessToken();

  /// Returns a valid access token, refreshing the Supabase session when it's
  /// missing or about to expire. On a cold web load `currentSession` may not be
  /// restored yet (or the JWT is stale) — sending that makes the server reject
  /// with 401 ("token invalid"). Refreshing here means every request self-heals,
  /// so users never have to hit Retry/Reload.
  Future<String?> _freshAccessToken() async {
    final auth = _supabase.auth;
    var s = auth.currentSession;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final needsRefresh = s == null || (s.expiresAt != null && s.expiresAt! - nowSec < 60);
    if (needsRefresh) {
      try {
        final res = await auth.refreshSession().timeout(const Duration(seconds: 5));
        s = res.session ?? auth.currentSession;
      } catch (_) {
        s = auth.currentSession;
      }
    }
    return s?.accessToken;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {Duration? timeout}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final token = await _freshAccessToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final res = await _client.post(
      Uri.parse('$_backendUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(timeout ?? const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Request failed');
    return data;
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, String> params) async {
    final uri = Uri.parse('$_backendUrl$path').replace(queryParameters: params);
    final headers = <String, String>{};
    final token = await _freshAccessToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Request failed');
    return data;
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body, {Duration? timeout}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await _freshAccessToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final res = await _client.patch(
      Uri.parse('$_backendUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(timeout ?? const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Request failed');
    return data;
  }
}

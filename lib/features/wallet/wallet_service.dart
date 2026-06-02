import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart' show backendUrl;
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
    } catch (e) {
      debugPrint('[Puls] get-or-create error: $e');
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
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
    const qnRpc = 'https://rpc.quicknode.testnet.arc.network/QN_d4190f3d83544ea0ac4dd926a12e30c7';
    const publicRpc = 'https://rpc.testnet.arc.network';
    const usdc = '0x3600000000000000000000000000000000000000';
    final padded = address.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');
    final data = '0x70a08231$padded';
    try {
      if (kIsWeb) {
        // Direct RPC calls on Web fail due to CORS. Immediately throw to trigger backend fallback.
        throw Exception('CORS bypass on web');
      }

      // Try QuickNode first
      try {
        final res = await _client.post(
          Uri.parse(qnRpc),
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
        debugPrint('[Puls] QuickNode balance fetch failed, falling back to public RPC: $e');
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

      final res = await _post('/api/trade/buy', {
        'userId': _state.userId!,
        'side': isYes ? 'YES' : 'NO',
        'usdcAmount': usdcAmount.toStringAsFixed(6),
        'question': question,
        'entryPrice': entryPrice.toStringAsFixed(4),
        'slug': slug,
        'deadline': deadline,
      });

      // Trigger a sync in the background immediately
      refreshBalance();
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
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    if (!_state.hasWallet) throw Exception('No wallet');

    // Optimistic balance update: estimate payout based on entryPrice (1ms UI update)
    final currentVal = double.tryParse(_state.usdcBalance) ?? 0.0;
    final estimatedPayout = shares * entryPrice;
    final newVal = currentVal + estimatedPayout;
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
          if (addr.isEmpty) throw Exception('Failed to retrieve contract address for selling');
        }
        final web3Res = await web3.sellPositionOnChain(isYes, shares, addr);
        if (web3Res.error != null) throw Exception(web3Res.error!);
        
        final txHash = web3Res.txHash!;
        await _post('/api/trade/save-external', {
          'userId': _state.userId!,
          'side': isYes ? 'YES' : 'NO',
          'usdcAmount': (-shares).toStringAsFixed(6),
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
        if (contractAddress != null && contractAddress.isNotEmpty) 'contractAddress': contractAddress,
      });

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
  
  Future<List<dynamic>> getLeaderboard({String sort = 'pnl', int limit = 50}) async {
    final headers = <String, String>{};
    final session = _supabase.auth.currentSession;
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    final uri = Uri.parse('$backendUrl/api/leaderboard').replace(queryParameters: {
      'sort': sort,
      'limit': limit.toString(),
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

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final session = _supabase.auth.currentSession;
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    final res = await _client.post(
      Uri.parse('$_backendUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Request failed');
    return data;
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, String> params) async {
    final uri = Uri.parse('$_backendUrl$path').replace(queryParameters: params);
    final headers = <String, String>{};
    final session = _supabase.auth.currentSession;
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Request failed');
    return data;
  }
}

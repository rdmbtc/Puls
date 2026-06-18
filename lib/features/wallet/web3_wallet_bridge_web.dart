import 'dart:js_interop';
import 'web3_wallet_bridge.dart';

@JS('connectBrowserWallet')
external JSPromise<JSString> _jsConnectBrowserWallet();

@JS('disconnectBrowserWallet')
external JSString _jsDisconnectBrowserWallet();

@JS('getBrowserWalletAddress')
external JSString _jsGetBrowserWalletAddress();

@JS('hasBrowserWallet')
external JSBoolean _jsHasBrowserWallet();

@JS('buyPositionOnChain')
external JSPromise<JSString> _jsBuyPositionOnChain(JSBoolean isYes, JSString amountUsdc, JSString contractAddress);

@JS('sellPositionOnChain')
external JSPromise<JSString> _jsSellPositionOnChain(JSBoolean isYes, JSString shares, JSString contractAddress);

@JS('claimOnChain')
external JSPromise<JSString> _jsClaimOnChain(JSString contractAddress);

@JS('bridgeUsdcToArc')
external JSPromise<JSString> _jsBridgeUsdcToArc(JSString amountUsdc, JSString recipient, JSString sourceKey);

@JS('getBridgeBalances')
external JSPromise<JSString> _jsGetBridgeBalances();

bool hasBrowserWallet() {
  try {
    return _jsHasBrowserWallet().toDart;
  } catch (_) {
    return false;
  }
}

Future<WalletConnectResult> connectBrowserWallet() async {
  try {
    final resultJson = (await _jsConnectBrowserWallet().toDart).toDart;
    if (resultJson.contains('"error"')) {
      final errMsg = _extractJsonValue(resultJson, 'error');
      return WalletConnectResult(error: errMsg);
    }
    final address = _extractJsonValue(resultJson, 'address');
    return WalletConnectResult(address: address);
  } catch (e) {
    return WalletConnectResult(error: e.toString());
  }
}

void disconnectBrowserWallet() {
  try {
    _jsDisconnectBrowserWallet();
  } catch (_) {}
}

String? getBrowserWalletAddress() {
  try {
    final addr = _jsGetBrowserWalletAddress().toDart;
    return addr.isEmpty ? null : addr;
  } catch (_) {
    return null;
  }
}

Future<WalletConnectResult> buyPositionOnChain(bool isYes, double amountUsdc, String contractAddress) async {
  try {
    final resultJson = (await _jsBuyPositionOnChain(
      isYes.toJS,
      amountUsdc.toString().toJS,
      contractAddress.toJS,
    ).toDart).toDart;
    
    if (resultJson.contains('"error"')) {
      final errMsg = _extractJsonValue(resultJson, 'error');
      return WalletConnectResult(error: errMsg);
    }
    final txHash = _extractJsonValue(resultJson, 'txHash');
    return WalletConnectResult(txHash: txHash);
  } catch (e) {
    return WalletConnectResult(error: e.toString());
  }
}

Future<WalletConnectResult> sellPositionOnChain(bool isYes, double shares, String contractAddress) async {
  try {
    final resultJson = (await _jsSellPositionOnChain(
      isYes.toJS,
      shares.toString().toJS,
      contractAddress.toJS,
    ).toDart).toDart;
    
    if (resultJson.contains('"error"')) {
      final errMsg = _extractJsonValue(resultJson, 'error');
      return WalletConnectResult(error: errMsg);
    }
    final txHash = _extractJsonValue(resultJson, 'txHash');
    return WalletConnectResult(txHash: txHash);
  } catch (e) {
    return WalletConnectResult(error: e.toString());
  }
}

Future<WalletConnectResult> claimOnChain(String contractAddress) async {
  try {
    final resultJson = (await _jsClaimOnChain(contractAddress.toJS).toDart).toDart;
    
    if (resultJson.contains('"error"')) {
      final errMsg = _extractJsonValue(resultJson, 'error');
      return WalletConnectResult(error: errMsg);
    }
    final txHash = _extractJsonValue(resultJson, 'txHash');
    return WalletConnectResult(txHash: txHash);
  } catch (e) {
    return WalletConnectResult(error: e.toString());
  }
}

Future<BridgeResult> bridgeUsdcToArc(double amountUsdc, {String? recipient, String? sourceKey}) async {
  try {
    final resultJson = (await _jsBridgeUsdcToArc(amountUsdc.toString().toJS, (recipient ?? '').toJS, (sourceKey ?? '').toJS).toDart).toDart;
    if (resultJson.contains('"error"')) {
      return BridgeResult(error: _extractJsonValue(resultJson, 'error'));
    }
    final arc = _extractJsonValue(resultJson, 'arcTxHash');
    final burn = _extractJsonValue(resultJson, 'burnTxHash');
    final pending = resultJson.contains('"pending"');
    return BridgeResult(
      arcTxHash: arc.isEmpty ? null : arc,
      burnTxHash: burn.isEmpty ? null : burn,
      pending: pending && arc.isEmpty,
    );
  } catch (e) {
    return BridgeResult(error: e.toString());
  }
}

Future<BridgeBalances> getBridgeBalances() async {
  try {
    final json = (await _jsGetBridgeBalances().toDart).toDart;
    if (json.contains('"error"')) {
      return BridgeBalances(error: _extractJsonValue(json, 'error'));
    }
    final address = _extractJsonValue(json, 'address');
    // Parse the "chains" array of {key,name,usdc,symbol,explorer}.
    final chains = <BridgeBalance>[];
    final re = RegExp(r'\{[^{}]*\}');
    final arrStart = json.indexOf('"chains"');
    if (arrStart != -1) {
      for (final m in re.allMatches(json.substring(arrStart))) {
        final obj = m.group(0)!;
        final key = _extractJsonValue(obj, 'key');
        if (key.isEmpty) continue;
        chains.add(BridgeBalance(
          key: key,
          name: _extractJsonValue(obj, 'name'),
          usdc: double.tryParse(_extractJsonValue(obj, 'usdc')) ?? 0,
          symbol: _extractJsonValue(obj, 'symbol'),
          explorer: _extractJsonValue(obj, 'explorer'),
        ));
      }
    }
    return BridgeBalances(address: address.isEmpty ? null : address, chains: chains);
  } catch (e) {
    return BridgeBalances(error: e.toString());
  }
}

String _extractJsonValue(String json, String key) {
  final pattern = '"$key":"';
  final start = json.indexOf(pattern);
  if (start == -1) return '';
  final valueStart = start + pattern.length;
  final valueEnd = json.indexOf('"', valueStart);
  if (valueEnd == -1) return '';
  return json.substring(valueStart, valueEnd);
}

import 'web3_wallet_bridge.dart';

bool hasBrowserWallet() {
  return false;
}

Future<WalletConnectResult> connectBrowserWallet() async {
  return WalletConnectResult(error: 'External browser wallets are not supported on this platform.');
}

void disconnectBrowserWallet() {}

String? getBrowserWalletAddress() {
  return null;
}

Future<WalletConnectResult> buyPositionOnChain(
  bool isYes,
  double amountUsdc,
  String contractAddress,
) async {
  return WalletConnectResult(error: 'External browser wallets are not supported on this platform.');
}

Future<WalletConnectResult> sellPositionOnChain(
  bool isYes,
  double shares,
  String contractAddress,
) async {
  return WalletConnectResult(error: 'External browser wallets are not supported on this platform.');
}

Future<WalletConnectResult> claimOnChain(String contractAddress) async {
  return WalletConnectResult(error: 'External browser wallets are not supported on this platform.');
}

Future<BridgeResult> bridgeUsdcToArc(double amountUsdc, {String? recipient}) async {
  return BridgeResult(error: 'Bridging is available on the web app with a browser wallet.');
}

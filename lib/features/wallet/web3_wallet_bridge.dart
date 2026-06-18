import 'web3_wallet_bridge_stub.dart'
    if (dart.library.js_interop) 'web3_wallet_bridge_web.dart' as impl;

/// Result of a wallet connect or contract call attempt.
class WalletConnectResult {
  final String? address;
  final String? txHash;
  final String? error;
  WalletConnectResult({this.address, this.txHash, this.error});
}

/// Check if a browser wallet (MetaMask) is available.
bool hasBrowserWallet() => impl.hasBrowserWallet();

/// Connect to browser wallet. Returns address on success, error on failure.
Future<WalletConnectResult> connectBrowserWallet() => impl.connectBrowserWallet();

/// Disconnect browser wallet.
void disconnectBrowserWallet() => impl.disconnectBrowserWallet();

/// Get current connected wallet address, or null.
String? getBrowserWalletAddress() => impl.getBrowserWalletAddress();

/// Run on-chain buy position transaction.
Future<WalletConnectResult> buyPositionOnChain(bool isYes, double amountUsdc, String contractAddress) =>
    impl.buyPositionOnChain(isYes, amountUsdc, contractAddress);

/// Run on-chain sell position transaction.
Future<WalletConnectResult> sellPositionOnChain(bool isYes, double shares, String contractAddress) =>
    impl.sellPositionOnChain(isYes, shares, contractAddress);

/// Run on-chain claim winnings transaction.
Future<WalletConnectResult> claimOnChain(String contractAddress) =>
    impl.claimOnChain(contractAddress);

/// Bridge USDC from Ethereum Sepolia → Arc via Circle CCTP (Forwarding Service).
/// Returns the Arc mint tx hash on success (or burn hash + pending if still settling).
Future<BridgeResult> bridgeUsdcToArc(double amountUsdc) =>
    impl.bridgeUsdcToArc(amountUsdc);

/// Result of a CCTP bridge attempt.
class BridgeResult {
  final String? arcTxHash;
  final String? burnTxHash;
  final bool pending;
  final String? error;
  BridgeResult({this.arcTxHash, this.burnTxHash, this.pending = false, this.error});
}

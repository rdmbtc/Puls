/// Immutable value object describing a settled creator payment, shared by the
/// Alpha-unlock, tip, and copy flows so they converge on one receipt UI.
///
/// The backend may not yet return on-chain proof fields (`receipt`/`receiptId`
/// and `sellerExplorerUrl`). [fromResponse] tolerates their absence so the
/// celebratory sheet still renders — it simply hides the proof block.
class PaymentReceipt {
  const PaymentReceipt({
    required this.amountUsd,
    required this.creatorHandle,
    required this.live,
    this.receiptId,
    this.sellerExplorerUrl,
  });

  /// Amount paid, in USD/USDC.
  final double amountUsd;

  /// Display handle of the forecaster being paid, e.g. `@alphawolf`.
  final String creatorHandle;

  /// Whether the payment actually settled on-chain (vs. a launch-gated preview
  /// where the user is not charged).
  final bool live;

  /// Circle settlement receipt id (a UUID), shown as a copyable chip.
  final String? receiptId;

  /// Explorer URL for the *seller's address* page (NOT a tx hash — Circle
  /// Gateway settles in batches so `settle()` returns a UUID, not a tx hash).
  final String? sellerExplorerUrl;

  /// True when we have a verifiable Circle receipt to surface.
  bool get hasProof => receiptId != null;

  /// Builds a receipt from a pay-endpoint response, tolerating missing fields.
  factory PaymentReceipt.fromResponse(
    Map<String, dynamic> res, {
    required double amountUsd,
    required String creatorHandle,
  }) {
    final receipt = res['receipt'];
    final receiptMap =
        receipt is Map ? receipt.cast<String, dynamic>() : const <String, dynamic>{};
    final rawId = res['receiptId'] ?? receiptMap['id'];
    final rawSeller = res['sellerExplorerUrl'] ?? receiptMap['sellerExplorerUrl'];
    final id = rawId?.toString();
    final seller = rawSeller?.toString();
    final live = res['live'] == true || (res['ok'] == true && res['live'] != false);
    return PaymentReceipt(
      amountUsd: amountUsd,
      creatorHandle: creatorHandle,
      live: live,
      receiptId: (id != null && id.isNotEmpty) ? id : null,
      sellerExplorerUrl: (seller != null && seller.isNotEmpty) ? seller : null,
    );
  }
}

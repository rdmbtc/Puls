import 'package:flutter_test/flutter_test.dart';
import 'package:puls/features/payments/payment_receipt.dart';

void main() {
  test('parses receipt + seller url when present (nested)', () {
    final r = PaymentReceipt.fromResponse(
      {
        'ok': true,
        'live': true,
        'receipt': {
          'id': 'rcpt_9f2ac71',
          'sellerExplorerUrl': 'https://testnet.arcscan.app/address/0xabc',
        },
      },
      amountUsd: 0.004,
      creatorHandle: '@alphawolf',
    );
    expect(r.amountUsd, 0.004);
    expect(r.creatorHandle, '@alphawolf');
    expect(r.receiptId, 'rcpt_9f2ac71');
    expect(r.sellerExplorerUrl, 'https://testnet.arcscan.app/address/0xabc');
    expect(r.hasProof, true);
    expect(r.live, true);
  });

  test('parses top-level receiptId + sellerExplorerUrl', () {
    final r = PaymentReceipt.fromResponse(
      {
        'ok': true,
        'receiptId': 'rcpt_top',
        'sellerExplorerUrl': 'https://x/address/0x1',
      },
      amountUsd: 0.05,
      creatorHandle: '@x',
    );
    expect(r.receiptId, 'rcpt_top');
    expect(r.sellerExplorerUrl, 'https://x/address/0x1');
    expect(r.live, true);
  });

  test('degrades gracefully without proof fields', () {
    final r = PaymentReceipt.fromResponse(
      {'ok': true},
      amountUsd: 0.05,
      creatorHandle: '@degenoracle',
    );
    expect(r.receiptId, isNull);
    expect(r.sellerExplorerUrl, isNull);
    expect(r.hasProof, false);
    expect(r.live, true);
  });

  test('not-live response is flagged and shows no proof claim', () {
    final r = PaymentReceipt.fromResponse(
      {'ok': true, 'live': false},
      amountUsd: 0.05,
      creatorHandle: '@x',
    );
    expect(r.live, false);
  });

  test('empty-string proof fields treated as absent', () {
    final r = PaymentReceipt.fromResponse(
      {'ok': true, 'live': true, 'receiptId': '', 'sellerExplorerUrl': ''},
      amountUsd: 0.01,
      creatorHandle: '@y',
    );
    expect(r.receiptId, isNull);
    expect(r.sellerExplorerUrl, isNull);
    expect(r.hasProof, false);
  });
}

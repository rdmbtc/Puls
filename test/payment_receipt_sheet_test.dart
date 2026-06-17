import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/features/payments/payment_receipt.dart';
import 'package:puls/features/payments/payment_receipt_sheet.dart';

Widget _host(PaymentReceipt r) => MaterialApp(
      theme: PulsTheme.dark(),
      home: Scaffold(body: PaymentReceiptSheet(receipt: r)),
    );

void main() {
  testWidgets('renders amount, handle, and proof when present', (tester) async {
    await tester.pumpWidget(_host(const PaymentReceipt(
      amountUsd: 0.004,
      creatorHandle: '@alphawolf',
      live: true,
      receiptId: 'rcpt_9f2ac71',
      sellerExplorerUrl: 'https://testnet.arcscan.app/address/0xabc',
    )));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('@alphawolf'), findsOneWidget);
    expect(find.textContaining('0.004'), findsWidgets);
    expect(find.textContaining('CIRCLE RECEIPT'), findsOneWidget);
    expect(find.textContaining('arcscan'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('hides proof when receipt absent', (tester) async {
    await tester.pumpWidget(_host(const PaymentReceipt(
      amountUsd: 0.05,
      creatorHandle: '@degenoracle',
      live: true,
    )));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('@degenoracle'), findsOneWidget);
    expect(find.textContaining('CIRCLE RECEIPT'), findsNothing);
    expect(find.textContaining('arcscan'), findsNothing);
  });

  testWidgets('shows chip but no arcscan link when seller url missing', (tester) async {
    await tester.pumpWidget(_host(const PaymentReceipt(
      amountUsd: 0.05,
      creatorHandle: '@x',
      live: true,
      receiptId: 'rcpt_1',
    )));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('CIRCLE RECEIPT'), findsOneWidget);
    expect(find.textContaining('arcscan'), findsNothing);
  });

  testWidgets('not-live shows launch messaging, no proof', (tester) async {
    await tester.pumpWidget(_host(const PaymentReceipt(
      amountUsd: 0.05,
      creatorHandle: '@x',
      live: false,
      receiptId: 'rcpt_1',
    )));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Activates at launch'), findsOneWidget);
    expect(find.textContaining('CIRCLE RECEIPT'), findsNothing);
  });
}

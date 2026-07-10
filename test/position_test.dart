import 'package:flutter_test/flutter_test.dart';
import 'package:puls/data/models/market.dart';
import 'package:puls/data/models/position.dart';

Position _position({
  double amount = 100,
  double currentPrice = 0.6,
  double shares = 200,
}) =>
    Position(
      id: 'p1',
      marketId: 'm1',
      question: 'Will BTC hit 100k?',
      side: MarketSide.yes,
      amount: amount,
      entryPrice: 0.5,
      currentPrice: currentPrice,
      shares: shares,
      openedAt: DateTime(2024, 1, 1),
    );

void main() {
  group('Position P&L math', () {
    test('marketValue is shares times current price', () {
      expect(_position(shares: 200, currentPrice: 0.6).marketValue,
          closeTo(120, 1e-9));
    });

    test('pnl is market value minus amount (profit and loss)', () {
      // 200 * 0.6 = 120, minus 100 staked = +20
      expect(_position(amount: 100, shares: 200, currentPrice: 0.6).pnl,
          closeTo(20, 1e-9));
      // 200 * 0.4 = 80, minus 100 = -20
      expect(_position(amount: 100, shares: 200, currentPrice: 0.4).pnl,
          closeTo(-20, 1e-9));
    });

    test('pnlPercent normalizes pnl by amount', () {
      expect(_position(amount: 100, shares: 200, currentPrice: 0.6).pnlPercent,
          closeTo(0.2, 1e-9));
    });

    test('pnlPercent returns zero when amount is zero (no divide-by-zero)', () {
      expect(_position(amount: 0).pnlPercent, 0);
    });
  });
}

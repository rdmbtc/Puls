import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/utils/trade_math.dart';

void main() {
  group('TradeMath', () {
    test('calculates estimated shares from amount and price', () {
      expect(
        TradeMath.estimatedShares(amount: 50, price: 0.25),
        closeTo(200, 0.001),
      );
    });

    test('returns zero for invalid amount or price', () {
      expect(TradeMath.estimatedShares(amount: 0, price: 0.25), 0);
      expect(TradeMath.estimatedShares(amount: 50, price: 0), 0);
    });

    test('estimatedPayout mirrors estimated shares', () {
      expect(
        TradeMath.estimatedPayout(amount: 50, price: 0.25),
        closeTo(200, 0.001),
      );
      expect(TradeMath.estimatedPayout(amount: 50, price: 0), 0);
    });

    test('estimatedProfit subtracts the staked amount from the payout', () {
      // 50 / 0.25 = 200 shares, minus 50 staked = 150 profit
      expect(
        TradeMath.estimatedProfit(amount: 50, price: 0.25),
        closeTo(150, 0.001),
      );
    });

    test('estimatedProfit is a loss (negative) when the price rises to 1', () {
      // 50 / 1 = 50 payout, minus 50 staked = 0
      expect(TradeMath.estimatedProfit(amount: 50, price: 1), closeTo(0, 0.001));
    });

    test('estimatedProfit returns -amount on invalid price', () {
      expect(TradeMath.estimatedProfit(amount: 50, price: 0), -50);
    });

    test('formats prices as cents', () {
      expect(TradeMath.formatPrice(0.61), '61c');
    });

    test('formatPrice rounds to the nearest cent', () {
      expect(TradeMath.formatPrice(0.615), '62c');
      expect(TradeMath.formatPrice(0), '0c');
      expect(TradeMath.formatPrice(1), '100c');
    });

    test('formatPercent renders a rounded whole percentage', () {
      expect(TradeMath.formatPercent(0.2), '20%');
      expect(TradeMath.formatPercent(0.125), '13%');
      expect(TradeMath.formatPercent(-0.05), '-5%');
    });
  });
}

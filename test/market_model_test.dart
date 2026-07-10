import 'package:flutter_test/flutter_test.dart';
import 'package:puls/data/models/market.dart';

Market _market({
  String category = 'Crypto',
  double trend = 0.1,
  bool createdByAgent = false,
  int pulsTrades = 0,
  int pulsHolders = 0,
  int commentsCount = 0,
}) =>
    Market(
      id: 'm1',
      question: 'Will BTC hit 100k?',
      category: category,
      context: 'ctx',
      yesPrice: 0.6,
      noPrice: 0.4,
      volume: r'$1M',
      liquidity: r'$500K',
      deadline: DateTime(2030, 1, 1),
      trend: trend,
      isFeatured: false,
      tags: const ['Crypto'],
      history: const [0.5, 0.6],
      comments: const [],
      news: const [],
      slug: 'btc-100k',
      createdByAgent: createdByAgent,
      pulsTrades: pulsTrades,
      pulsHolders: pulsHolders,
      commentsCount: commentsCount,
    );

void main() {
  group('Market getters', () {
    test('trendIsPositive is true for zero and positive trend', () {
      expect(_market(trend: 0).trendIsPositive, isTrue);
      expect(_market(trend: 0.5).trendIsPositive, isTrue);
      expect(_market(trend: -0.01).trendIsPositive, isFalse);
    });

    test('displayCategory routes agent markets to "AI Agents"', () {
      expect(_market(category: 'Sports').displayCategory, 'Sports');
      expect(
        _market(category: 'Sports', createdByAgent: true).displayCategory,
        'AI Agents',
      );
    });

    test('pulsScore weights holders and comments over raw trades', () {
      final m = _market(pulsHolders: 2, pulsTrades: 3, commentsCount: 4);
      // 2*4 + 3 + 4*3 = 23
      expect(m.pulsScore, 23);
    });

    test('hasPulsActivity reflects any engagement', () {
      expect(_market().hasPulsActivity, isFalse);
      expect(_market(pulsTrades: 1).hasPulsActivity, isTrue);
      expect(_market(commentsCount: 1).hasPulsActivity, isTrue);
    });
  });

  group('Market.copyWith', () {
    test('overrides slug and contractAddress, preserves the rest', () {
      final original = _market(category: 'Sports');
      final copy =
          original.copyWith(slug: 'new-slug', contractAddress: '0xabc');

      expect(copy.slug, 'new-slug');
      expect(copy.contractAddress, '0xabc');
      expect(copy.question, original.question);
      expect(copy.category, original.category);
      expect(copy.yesPrice, original.yesPrice);
      expect(copy.commentsCount, original.commentsCount);
    });

    test('keeps existing values when no overrides are passed', () {
      final original = _market();
      final copy = original.copyWith();
      expect(copy.slug, original.slug);
      expect(copy.contractAddress, original.contractAddress);
    });
  });
}

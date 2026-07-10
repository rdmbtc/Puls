import 'package:flutter_test/flutter_test.dart';
import 'package:puls/data/models/creator_signal.dart';

void main() {
  group('CreatorSignal status getters', () {
    CreatorSignal signal({String status = 'published'}) => CreatorSignal(
          id: '1',
          creatorUserId: 'u1',
          title: 'Will it rain?',
          priceUsdc: 1.5,
          status: status,
        );

    test('isPublished / isDraft reflect status', () {
      expect(signal(status: 'published').isPublished, isTrue);
      expect(signal(status: 'published').isDraft, isFalse);
      expect(signal(status: 'draft').isDraft, isTrue);
      expect(signal(status: 'draft').isPublished, isFalse);
      expect(signal(status: 'archived').isPublished, isFalse);
      expect(signal(status: 'archived').isDraft, isFalse);
    });
  });

  group('CreatorSignal content getters', () {
    test('hasThesis is true only for non-empty thesis', () {
      expect(_signal(thesis: 'Deep dive').hasThesis, isTrue);
      expect(_signal(thesis: '').hasThesis, isFalse);
      expect(_signal().hasThesis, isFalse);
    });

    test('hasMarketLink requires a non-empty slug', () {
      expect(_signal(marketSlug: 'will-it-rain').hasMarketLink, isTrue);
      expect(_signal(marketSlug: '').hasMarketLink, isFalse);
      expect(_signal().hasMarketLink, isFalse);
    });

    test('hasSources reflects the sources list', () {
      expect(_signal().hasSources, isFalse);
      expect(
        _signal(sources: const [
          SignalSource(title: 'ESPN', url: 'https://espn.com'),
        ]).hasSources,
        isTrue,
      );
    });
  });

  group('CreatorSignal stance gating', () {
    test('stanceRevealed reflects presence of a stance string', () {
      expect(_signal(stance: 'YES').stanceRevealed, isTrue);
      expect(_signal(stance: '').stanceRevealed, isFalse);
      expect(_signal().stanceRevealed, isFalse);
    });

    test('stanceVisible hidden until unlocked or owner even if stance leaks', () {
      expect(_signal(stance: 'YES').stanceVisible, isFalse);
      expect(_signal(stance: 'YES', unlocked: true).stanceVisible, isTrue);
      expect(_signal(stance: 'YES', isOwner: true).stanceVisible, isTrue);
    });

    test('stanceVisible false when unlocked but no stance present', () {
      expect(_signal(unlocked: true).stanceVisible, isFalse);
    });
  });

  group('CreatorSignal.isFinished', () {
    test('finished when the linked market resolved', () {
      expect(_signal(marketResolved: true).isFinished, isTrue);
    });

    test('finished when the bond is no longer active', () {
      expect(
        _signal(
          bond: const SignalBond(amountUsdc: 10, status: 'slashed'),
        ).isFinished,
        isTrue,
      );
    });

    test('not finished with an active bond and unresolved market', () {
      expect(
        _signal(
          bond: const SignalBond(amountUsdc: 10, status: 'active'),
        ).isFinished,
        isFalse,
      );
      expect(_signal().isFinished, isFalse);
    });
  });

  group('CreatorSignal.fromJson', () {
    test('parses a full published payload', () {
      final s = CreatorSignal.fromJson({
        'id': 42,
        'creatorUserId': 'creator-1',
        'title': 'BTC above 100k?',
        'stance': 'yes',
        'priceUsdc': 2,
        'status': 'published',
        'marketSlug': 'btc-100k',
        'sourcesCount': 3,
        'confidence': 0.8,
        'edgeBps': 150,
        'unlocked': true,
        'isOwner': false,
        'marketResolved': true,
        'marketOutcome': true,
        'sources': [
          {'title': 'Bloomberg', 'url': 'https://bloomberg.com'},
        ],
        'creatorTrackRecord': {
          'resolved': 4,
          'correct': 3,
          'published': 6,
          'winRate': 0.75,
        },
        'bond': {'amountUsdc': 25, 'status': 'active'},
        'onchain': {'tx': '0xabc'},
        'analytics': {'views': 100, 'unlocks': 10, 'revenueUsdc': 20},
        'publishedAt': '2024-01-01T00:00:00Z',
      });

      expect(s.id, '42');
      expect(s.stance, 'YES'); // upper-cased
      expect(s.priceUsdc, 2);
      expect(s.isPublished, isTrue);
      expect(s.sourcesCount, 3);
      expect(s.confidence, 0.8);
      expect(s.edgeBps, 150);
      expect(s.sources, hasLength(1));
      expect(s.trackRecord, isNotNull);
      expect(s.trackRecord!.hasRecord, isTrue);
      expect(s.bond!.isActive, isTrue);
      expect(s.onchain!.tx, '0xabc');
      expect(s.analytics!.views, 100);
      expect(s.marketOutcome, isTrue);
      expect(s.publishedAt, DateTime.utc(2024, 1, 1));
    });

    test('applies defaults for a minimal payload', () {
      final s = CreatorSignal.fromJson({'id': 7});
      expect(s.id, '7');
      expect(s.creatorUserId, '');
      expect(s.title, '');
      expect(s.stance, isNull);
      expect(s.priceUsdc, 0);
      expect(s.status, 'draft');
      expect(s.isDraft, isTrue);
      expect(s.sources, isEmpty);
      expect(s.sourcesCount, 0);
      expect(s.trackRecord, isNull);
      expect(s.bond, isNull);
      expect(s.onchain, isNull);
      expect(s.analytics, isNull);
      expect(s.marketOutcome, isNull);
      expect(s.publishedAt, isNull);
    });
  });

  group('SignalSource.fromJson', () {
    test('uses title when present', () {
      final s = SignalSource.fromJson({
        'title': 'ESPN Report',
        'url': 'https://espn.com',
        'source': 'espn.com',
      });
      expect(s.title, 'ESPN Report');
      expect(s.url, 'https://espn.com');
      expect(s.source, 'espn.com');
    });

    test('falls back to source then url then generic label', () {
      expect(
        SignalSource.fromJson({'source': 'espn.com', 'url': 'https://espn.com'})
            .title,
        'espn.com',
      );
      expect(
        SignalSource.fromJson({'title': '  ', 'url': 'https://x.com'}).title,
        'https://x.com',
      );
      expect(SignalSource.fromJson({}).title, 'Source');
      expect(SignalSource.fromJson({}).url, '');
    });
  });

  group('CreatorTrackRecord', () {
    test('hasRecord requires resolved signals and a win rate', () {
      const withRecord =
          CreatorTrackRecord(resolved: 2, correct: 1, published: 3, winRate: 0.5);
      expect(withRecord.hasRecord, isTrue);

      const noResolved =
          CreatorTrackRecord(resolved: 0, correct: 0, published: 3, winRate: 0.5);
      expect(noResolved.hasRecord, isFalse);

      const noWinRate =
          CreatorTrackRecord(resolved: 2, correct: 1, published: 3);
      expect(noWinRate.hasRecord, isFalse);
    });

    test('fromJson defaults missing values', () {
      final t = CreatorTrackRecord.fromJson({});
      expect(t.resolved, 0);
      expect(t.correct, 0);
      expect(t.published, 0);
      expect(t.winRate, isNull);
    });
  });

  group('SignalBond', () {
    test('status getters', () {
      expect(const SignalBond(amountUsdc: 1, status: 'active').isActive, isTrue);
      expect(
          const SignalBond(amountUsdc: 1, status: 'slashed').isSlashed, isTrue);
      expect(const SignalBond(amountUsdc: 1, status: 'returned').isReturned,
          isTrue);
    });

    test('link prefers a real tx hash over the explorer', () {
      const withTx = SignalBond(
        amountUsdc: 1,
        status: 'active',
        tx: '0xdeadbeef',
        explorer: 'https://explorer',
      );
      expect(withTx.link, 'https://testnet.arcscan.app/tx/0xdeadbeef');
    });

    test('link falls back to explorer when tx is missing or not a hash', () {
      const circleId = SignalBond(
        amountUsdc: 1,
        status: 'active',
        tx: 'circle-123',
        explorer: 'https://explorer',
      );
      expect(circleId.link, 'https://explorer');
      expect(
        const SignalBond(amountUsdc: 1, status: 'active').link,
        isNull,
      );
    });

    test('fromJson parses fields with defaults', () {
      final b = SignalBond.fromJson({'amountUsdc': 5, 'status': 'returned'});
      expect(b.amountUsdc, 5);
      expect(b.isReturned, isTrue);

      final def = SignalBond.fromJson({});
      expect(def.amountUsdc, 0);
      expect(def.status, 'active');
    });
  });

  group('SignalOnchain / SignalAnalytics fromJson', () {
    test('onchain parses tx and optional fields', () {
      final o = SignalOnchain.fromJson({'tx': '0x1', 'explorer': 'https://e'});
      expect(o.tx, '0x1');
      expect(o.explorer, 'https://e');
      expect(SignalOnchain.fromJson({}).tx, '');
    });

    test('analytics parses counters with defaults', () {
      final a = SignalAnalytics.fromJson(
          {'views': 5, 'unlocks': 2, 'revenueUsdc': 3.5, 'conversion': 0.4});
      expect(a.views, 5);
      expect(a.unlocks, 2);
      expect(a.revenueUsdc, 3.5);
      expect(a.conversion, 0.4);

      final def = SignalAnalytics.fromJson({});
      expect(def.views, 0);
      expect(def.revenueUsdc, 0);
      expect(def.conversion, isNull);
    });
  });
}

CreatorSignal _signal({
  String? stance,
  String? thesis,
  String? marketSlug,
  List<SignalSource> sources = const [],
  bool unlocked = false,
  bool isOwner = false,
  bool marketResolved = false,
  SignalBond? bond,
}) =>
    CreatorSignal(
      id: '1',
      creatorUserId: 'u1',
      title: 'Signal',
      priceUsdc: 1,
      status: 'published',
      stance: stance,
      thesis: thesis,
      marketSlug: marketSlug,
      sources: sources,
      unlocked: unlocked,
      isOwner: isOwner,
      marketResolved: marketResolved,
      bond: bond,
    );

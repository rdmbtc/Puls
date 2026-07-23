import '../models/market.dart';
import '../models/position.dart';

/// Repository of initial mock state used before the real Polymarket feed
/// and backend data load. Positions and watchlist are intentionally empty
/// — the app loads real data from Supabase + Polymarket API on startup.
class MockMarketRepository {
  List<String> get categories => const [
        'Politics',
        'Crypto',
        'Sports',
        'AI',
        'Macro',
        'Culture',
      ];

  List<String> get initialWatchlistIds => const [];

  List<Position> get initialPositions => const [];

  List<Market> get markets => [
        Market(
          id: 'fed-cut-june',
          slug: 'fed-cut-june',
          question: 'Will the Fed cut rates by June?',
          category: 'Macro',
          context:
              'Inflation prints cooled for two months, but labor data remains firm.',
          yesPrice: 0.48,
          noPrice: 0.52,
          volume: '\$14.2M',
          liquidity: '\$910K',
          deadline: DateTime(2026, 6, 18),
          trend: 0.06,
          isFeatured: true,
          tags: const ['Rates', 'CPI', 'FOMC'],
          history: const [0.32, 0.35, 0.38, 0.41, 0.46, 0.44, 0.48],
          comments: const [
            MarketComment(
              author: 'MacroDesk',
              text: 'Two soft CPI prints changed the distribution.',
              sentiment: MarketSide.yes,
            ),
            MarketComment(
              author: 'BasisTrade',
              text: 'June is still too soon unless payrolls crack.',
              sentiment: MarketSide.no,
            ),
          ],
          news: const [
            MarketNews(
              source: 'Rates Wire',
              title: 'Futures move after softer services inflation data',
              age: '2h',
            ),
            MarketNews(
              source: 'Central Desk',
              title: 'Fed speakers keep optionality before June meeting',
              age: '5h',
            ),
          ],
        ),
        Market(
          id: 'ai-agent-app',
          slug: 'ai-agent-app',
          question: 'Will an AI agent app reach top 5 in the US by July?',
          category: 'AI',
          context:
              'Consumer AI apps are moving from chat to task execution and shopping.',
          yesPrice: 0.61,
          noPrice: 0.39,
          volume: '\$6.8M',
          liquidity: '\$420K',
          deadline: DateTime(2026, 7, 1),
          trend: 0.11,
          isFeatured: true,
          tags: const ['AI', 'Apps', 'Consumer'],
          history: const [0.45, 0.47, 0.51, 0.54, 0.58, 0.57, 0.61],
          comments: const [
            MarketComment(
              author: 'ModelWatch',
              text: 'Distribution matters more than model quality here.',
              sentiment: MarketSide.yes,
            ),
            MarketComment(
              author: 'AppRank',
              text: 'Top 5 is a hard bar without paid acquisition.',
              sentiment: MarketSide.no,
            ),
          ],
          news: const [
            MarketNews(
              source: 'App Index',
              title: 'AI productivity category climbs in weekly downloads',
              age: '1h',
            ),
          ],
        ),
        Market(
          id: 'btc-100k',
          slug: 'btc-100k',
          question: 'Will Bitcoin close above 100k this quarter?',
          category: 'Crypto',
          context:
              'ETF flows recovered, but volatility is rising into month end.',
          yesPrice: 0.66,
          noPrice: 0.34,
          volume: '\$22.5M',
          liquidity: '\$1.4M',
          deadline: DateTime(2026, 6, 30),
          trend: -0.03,
          isFeatured: true,
          tags: const ['BTC', 'ETF', 'Quarterly'],
          history: const [0.59, 0.64, 0.69, 0.71, 0.68, 0.67, 0.66],
          comments: const [
            MarketComment(
              author: 'VolSurface',
              text: 'Options imply big moves, but upside skew has faded.',
              sentiment: MarketSide.no,
            ),
            MarketComment(
              author: 'FlowDesk',
              text: 'ETF inflows are back above the four-week average.',
              sentiment: MarketSide.yes,
            ),
          ],
          news: const [
            MarketNews(
              source: 'Crypto Tape',
              title: 'Spot ETF inflows recover after two quiet sessions',
              age: '3h',
            ),
          ],
        ),
        Market(
          id: 'champions-final',
          slug: 'champions-final',
          question: 'Will the Champions final go to extra time?',
          category: 'Sports',
          context:
              'Both sides have conceded fewer than one goal per match in knockouts.',
          yesPrice: 0.29,
          noPrice: 0.71,
          volume: '\$3.1M',
          liquidity: '\$260K',
          deadline: DateTime(2026, 5, 30),
          trend: 0.02,
          isFeatured: true,
          tags: const ['Football', 'Final', 'Live Soon'],
          history: const [0.22, 0.24, 0.26, 0.25, 0.27, 0.28, 0.29],
          comments: const [
            MarketComment(
              author: 'MatchModel',
              text: 'The under is crowded, but late-game risk is real.',
              sentiment: MarketSide.yes,
            ),
          ],
          news: const [
            MarketNews(
              source: 'Lineups',
              title: 'Both managers expected to start defensive midfielders',
              age: '30m',
            ),
          ],
        ),
        Market(
          id: 'eth-etf-may',
          slug: 'eth-etf-may',
          question: 'Will ETH ETF net flows beat BTC this month?',
          category: 'Crypto',
          context: 'ETH products saw two strong inflow days while BTC cooled.',
          yesPrice: 0.44,
          noPrice: 0.56,
          volume: '\$7.4M',
          liquidity: '\$510K',
          deadline: DateTime(2026, 5, 31),
          trend: 0.08,
          isFeatured: true,
          tags: const ['ETH', 'ETF', 'Flows'],
          history: const [0.31, 0.35, 0.36, 0.39, 0.41, 0.43, 0.44],
          comments: const [
            MarketComment(
              author: 'ChainBeta',
              text: 'ETH has the cleaner surprise setup this month.',
              sentiment: MarketSide.yes,
            ),
          ],
          news: const [
            MarketNews(
              source: 'Fund Flow',
              title: 'ETH vehicles post strongest session since launch week',
              age: '4h',
            ),
          ],
        ),
        Market(
          id: 'summer-film',
          slug: 'summer-film',
          question: 'Will a sci-fi film top the global box office this summer?',
          category: 'Culture',
          context:
              'Franchise releases dominate the calendar, but presales are split.',
          yesPrice: 0.57,
          noPrice: 0.43,
          volume: '\$1.9M',
          liquidity: '\$140K',
          deadline: DateTime(2026, 8, 31),
          trend: -0.01,
          isFeatured: false,
          tags: const ['Film', 'Box Office', 'Summer'],
          history: const [0.49, 0.52, 0.55, 0.59, 0.58, 0.58, 0.57],
          comments: const [
            MarketComment(
              author: 'TicketTape',
              text: 'Family animation may be the real competition.',
              sentiment: MarketSide.no,
            ),
          ],
          news: const [
            MarketNews(
              source: 'Cinema Ledger',
              title: 'Presales open stronger than expected for sci-fi sequel',
              age: '8h',
            ),
          ],
        ),
      ];
}

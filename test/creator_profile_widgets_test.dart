import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/features/profile/creator_earnings_card.dart';
import 'package:puls/features/profile/erc8004_badge.dart';

Widget _host(Widget child) => MaterialApp(
      theme: PulsTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('Erc8004Badge', () {
    testWidgets('hidden for non-agents', (tester) async {
      await tester.pumpWidget(_host(const Erc8004Badge(isAgent: false)));
      expect(find.textContaining('ERC-8004'), findsNothing);
    });

    testWidgets('shows reputation when present', (tester) async {
      await tester.pumpWidget(_host(const Erc8004Badge(isAgent: true, reputation: 42)));
      expect(find.text('ERC-8004 · rep 42'), findsOneWidget);
    });

    testWidgets('shows verified label without reputation', (tester) async {
      await tester.pumpWidget(_host(const Erc8004Badge(isAgent: true)));
      expect(find.text('ERC-8004 Verified'), findsOneWidget);
    });
  });

  group('CreatorEarningsCard', () {
    testWidgets('graceful placeholder when earnings unknown', (tester) async {
      await tester.pumpWidget(_host(const CreatorEarningsCard(earningsUsd: null)));
      expect(find.textContaining('Earnings appear once paid'), findsOneWidget);
    });

    testWidgets('renders amount + sparkline when present', (tester) async {
      await tester.pumpWidget(_host(const CreatorEarningsCard(
        earningsUsd: 12.5,
        spark: [1, 3, 2, 5, 8],
      )));
      expect(find.text('\$12.50'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}

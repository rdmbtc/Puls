import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/core/widgets/state_views.dart';

Widget _host(Widget child) => MaterialApp(
      theme: PulsTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('PulsEmptyState', () {
    testWidgets('renders title and message', (tester) async {
      await tester.pumpWidget(_host(const PulsEmptyState(
        title: 'No saved markets',
        message: 'Tap the bookmark on any market.',
      )));
      await tester.pumpAndSettle();
      expect(find.text('No saved markets'), findsOneWidget);
      expect(find.text('Tap the bookmark on any market.'), findsOneWidget);
    });

    testWidgets('fires the CTA when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(PulsEmptyState(
        title: 'Nothing here',
        actionLabel: 'Browse markets',
        onAction: () => taps++,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Browse markets'), findsOneWidget);
      await tester.tap(find.text('Browse markets'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('PulsErrorState', () {
    testWidgets('shows default copy and fires retry', (tester) async {
      var retries = 0;
      await tester.pumpWidget(_host(PulsErrorState(
        onRetry: () => retries++,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('hides retry button when no callback given', (tester) async {
      await tester.pumpWidget(_host(const PulsErrorState()));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/core/widgets/puls_page_route.dart';

Widget _host(void Function(BuildContext) onContext,
        {bool reduceMotion = false}) =>
    MaterialApp(
      theme: PulsTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: Builder(
              builder: (ctx) {
                onContext(ctx);
                return const Text('home');
              },
            ),
          ),
        ),
      ),
    );

void main() {
  group('pulsRoute', () {
    testWidgets('uses an animated transition under normal motion',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_host((c) => ctx = c));
      final route = pulsRoute<void>(ctx, builder: (_) => const Text('next'))
          as TransitionRoute<void>;
      expect(route.transitionDuration, const Duration(milliseconds: 320));
    });

    testWidgets('collapses the transition to zero under reduce-motion',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_host((c) => ctx = c, reduceMotion: true));
      final route = pulsRoute<void>(ctx, builder: (_) => const Text('next'))
          as TransitionRoute<void>;
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
    });

    testWidgets('navigates and settles (no perpetual animation)',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_host((c) => ctx = c));
      Navigator.of(ctx).push(pulsRoute<void>(
        ctx,
        builder: (_) => const Scaffold(body: Text('next-screen')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('next-screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduce-motion push lands in a single frame', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_host((c) => ctx = c, reduceMotion: true));
      Navigator.of(ctx).push(pulsRoute<void>(
        ctx,
        builder: (_) => const Scaffold(body: Text('next-screen')),
      ));
      await tester.pump(); // no transition duration to wait out
      await tester.pump();
      expect(find.text('next-screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

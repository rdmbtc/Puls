import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/features/shell/puls_bottom_nav.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
      theme: PulsTheme.dark(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFF000000),
            bottomNavigationBar: child,
          ),
        ),
      ),
    );

  // The gliding pill is the AnimatedPositioned wearing the brand gradient.
  AnimatedPositioned _pill(WidgetTester tester) =>
      tester.widget<AnimatedPositioned>(
        find.descendant(
          of: find.byType(PulsBottomNav),
          matching: find.byType(AnimatedPositioned),
        ),
      );

void main() {
  testWidgets('renders all five tab labels', (tester) async {
    await tester.pumpWidget(_host(
      PulsBottomNav(index: 0, isDark: true, onTap: (_) {}),
    ));

    for (final item in PulsBottomNav.items) {
      expect(find.text(item.label), findsOneWidget);
    }
  });

  testWidgets('the single gliding pill wears the pulseGradient', (tester) async {
    await tester.pumpWidget(_host(
      PulsBottomNav(index: 0, isDark: true, onTap: (_) {}),
    ));

    // Exactly one gliding pill, not one-per-tab.
    final pills = find.descendant(
      of: find.byType(PulsBottomNav),
      matching: find.byType(AnimatedPositioned),
    );
    expect(pills, findsOneWidget);

    final deco = (_pill(tester).child as DecoratedBox).decoration as BoxDecoration;
    expect(deco.gradient, PulsColors.pulseGradient);
  });

  testWidgets('the pill glides to the right as the active index advances',
      (tester) async {
    await tester.pumpWidget(_host(
      PulsBottomNav(index: 0, isDark: true, onTap: (_) {}),
    ));
    final leftAt0 = _pill(tester).left!;

    await tester.pumpWidget(_host(
      PulsBottomNav(index: 4, isDark: true, onTap: (_) {}),
    ));
    await tester.pumpAndSettle();
    final leftAt4 = _pill(tester).left!;

    expect(leftAt4, greaterThan(leftAt0));
  });

  testWidgets('tapping a tab reports its index', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(_host(
      PulsBottomNav(index: 0, isDark: true, onTap: taps.add),
    ));

    await tester.tap(find.text('Agent'));
    await tester.pump();
    expect(taps, [3]);
  });

  testWidgets('tapping the active tab still fires onTap (refresh hook)',
      (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(_host(
      PulsBottomNav(index: 0, isDark: true, onTap: taps.add),
    ));

    await tester.tap(find.text('Feed'));
    await tester.pump();
    expect(taps, [0]);
  });

  testWidgets('reduce-motion snaps the glide instantly (settles, no hang)',
      (tester) async {
    await tester.pumpWidget(_host(
      PulsBottomNav(index: 2, isDark: true, onTap: (_) {}),
      disableAnimations: true,
    ));

    // A looping/long animation would hang pumpAndSettle; reduce-motion must not.
    await tester.pumpAndSettle();
    expect(_pill(tester).duration, Duration.zero);
  });
}

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

// The 5 cells: a dynamic "Browse" cell (Feed/Discover/Home) + 4 fixed ones.
const _browseLabel = 'Feed';
const _expectedLabels = [_browseLabel, 'Portfolio', 'Creators', 'Agent', 'Profile'];

PulsBottomNav _nav({
  required int index,
  required ValueChanged<int> onTap,
  String browseLabel = _browseLabel,
}) =>
    PulsBottomNav(
      index: index,
      isDark: true,
      onTap: onTap,
      browseLabel: browseLabel,
      browseIcon: PulsBottomNav.browseIcons.first,
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
    await tester.pumpWidget(_host(_nav(index: 0, onTap: (_) {})));

    for (final label in _expectedLabels) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('the single gliding pill wears the pulseGradient', (tester) async {
    await tester.pumpWidget(_host(_nav(index: 0, onTap: (_) {})));

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
    await tester.pumpWidget(_host(_nav(index: 0, onTap: (_) {})));
    final leftAt0 = _pill(tester).left!;

    await tester.pumpWidget(_host(_nav(index: 4, onTap: (_) {})));
    await tester.pumpAndSettle();
    final leftAt4 = _pill(tester).left!;

    expect(leftAt4, greaterThan(leftAt0));
  });

  testWidgets('tapping a tab reports its index', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(_host(_nav(index: 0, onTap: taps.add)));

    await tester.tap(find.text('Agent'));
    await tester.pump();
    expect(taps, [3]);
  });

  testWidgets('tapping the active tab still fires onTap (refresh hook)',
      (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(_host(_nav(index: 0, onTap: taps.add)));

    await tester.tap(find.text(_browseLabel));
    await tester.pump();
    expect(taps, [0]);
  });

  testWidgets('reduce-motion snaps the glide instantly (settles, no hang)',
      (tester) async {
    await tester.pumpWidget(_host(
      _nav(index: 2, onTap: (_) {}),
      disableAnimations: true,
    ));

    // A looping/long animation would hang pumpAndSettle; reduce-motion must not.
    await tester.pumpAndSettle();
    expect(_pill(tester).duration, Duration.zero);
  });
}

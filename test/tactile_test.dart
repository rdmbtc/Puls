import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/core/widgets/tactile.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: PulsTheme.dark(),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reduceMotion),
              child: child,
            ),
          ),
        ),
      ),
    );

double _scaleOf(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

void main() {
  group('Tactile', () {
    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        Tactile(behavior: HitTestBehavior.opaque, onTap: () => taps++, child: const SizedBox(width: 80, height: 40)),
      ));
      await tester.tap(find.byType(Tactile));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('scales down while pressed, restores on release',
        (tester) async {
      await tester.pumpWidget(_host(
        Tactile(behavior: HitTestBehavior.opaque, onTap: () {}, child: const SizedBox(width: 80, height: 40)),
      ));
      expect(_scaleOf(tester), 1.0);

      final gesture = await tester.startGesture(
          tester.getCenter(find.byType(Tactile)));
      await tester.pump();
      expect(_scaleOf(tester), lessThan(1.0)); // pressed

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_scaleOf(tester), 1.0); // restored
    });

    testWidgets('reduce-motion keeps scale at rest while pressed',
        (tester) async {
      await tester.pumpWidget(_host(
        Tactile(behavior: HitTestBehavior.opaque, onTap: () {}, child: const SizedBox(width: 80, height: 40)),
        reduceMotion: true,
      ));
      final gesture = await tester.startGesture(
          tester.getCenter(find.byType(Tactile)));
      await tester.pump();
      expect(_scaleOf(tester), 1.0); // no press-scale under reduce-motion
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('hover-lift registers MouseRegion enter/exit handlers',
        (tester) async {
      await tester.pumpWidget(_host(
        Tactile(
          onTap: () {},
          hoverScale: 1.04,
          child: const SizedBox(width: 80, height: 40),
        ),
      ));
      final region = tester.widget<MouseRegion>(
        find.descendant(
          of: find.byType(Tactile),
          matching: find.byType(MouseRegion),
        ).first,
      );
      expect(region.onEnter, isNotNull);
      expect(region.onExit, isNotNull);
    });
  });
}

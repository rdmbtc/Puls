import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/core/widgets/animated_count.dart';
import 'package:puls/core/widgets/pulse_dot.dart';
import 'package:puls/core/widgets/skeleton.dart';

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

void main() {
  group('reduce-motion', () {
    // A repeating animation would make pumpAndSettle time out; if these settle,
    // the perpetual loops were correctly stopped.
    testWidgets('Skeleton stops looping', (tester) async {
      await tester.pumpWidget(_host(const Skeleton(), reduceMotion: true));
      await tester.pumpAndSettle();
      expect(find.byType(Skeleton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PulseDot stops looping', (tester) async {
      await tester.pumpWidget(_host(const PulseDot(), reduceMotion: true));
      await tester.pumpAndSettle();
      expect(find.byType(PulseDot), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AnimatedCount jumps to the new value in one frame',
        (tester) async {
      double val = 10;
      late StateSetter setOuter;
      await tester.pumpWidget(_host(
        StatefulBuilder(builder: (context, setState) {
          setOuter = setState;
          return AnimatedCount(
            value: val,
            formatter: (v) => v.toStringAsFixed(0),
          );
        }),
        reduceMotion: true,
      ));
      expect(find.text('10'), findsOneWidget);

      setOuter(() => val = 90);
      await tester.pump(); // single frame — no tween under reduce-motion
      expect(find.text('90'), findsOneWidget);
    });
  });

  group('normal motion', () {
    testWidgets('AnimatedCount renders its value', (tester) async {
      await tester.pumpWidget(_host(
        AnimatedCount(value: 42, formatter: (v) => '${v.toStringAsFixed(0)}%'),
      ));
      await tester.pump();
      expect(find.text('42%'), findsOneWidget);
    });
  });
}

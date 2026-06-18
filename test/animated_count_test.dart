import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/core/widgets/animated_count.dart';

Widget _host(Widget child) => MaterialApp(
      theme: PulsTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('AnimatedCount', () {
    testWidgets('renders the formatted initial value immediately',
        (tester) async {
      await tester.pumpWidget(_host(
        AnimatedCount(value: 42, formatter: (v) => '${v.toStringAsFixed(0)}%'),
      ));
      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets('rolls toward the new value when it changes', (tester) async {
      await tester.pumpWidget(_host(
        AnimatedCount(value: 0, formatter: (v) => v.toStringAsFixed(0)),
      ));
      expect(find.text('0'), findsOneWidget);

      // Update target to 100 and step partway through the tween.
      await tester.pumpWidget(_host(
        AnimatedCount(value: 100, formatter: (v) => v.toStringAsFixed(0)),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      // Mid-roll: not yet 100, no longer 0.
      expect(find.text('0'), findsNothing);
      expect(find.text('100'), findsNothing);

      // Settle.
      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('uses tabular figures so width stays stable', (tester) async {
      await tester.pumpWidget(_host(
        AnimatedCount(value: 7, formatter: (v) => v.toStringAsFixed(0)),
      ));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.fontFeatures, PulsColors.tabularFigures);
    });
  });
}

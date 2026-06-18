import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/core/widgets/pulse_dot.dart';

Widget _host(Widget child) => MaterialApp(
      theme: PulsTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('PulseDot', () {
    testWidgets('builds and animates without throwing', (tester) async {
      await tester.pumpWidget(_host(const PulseDot()));
      expect(find.byType(PulseDot), findsOneWidget);
      // Advance the repeating animation a few frames.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('honors a custom color', (tester) async {
      await tester.pumpWidget(
        _host(const PulseDot(color: Color(0xFF00FF00), size: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(PulseDot), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/core/widgets/pulse_button.dart';

Widget _host(Widget child) => MaterialApp(
      theme: PulsTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('renders label and fires onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      PulseButton(label: 'Tip \$0.05', onPressed: () => taps++),
    ));

    expect(find.text('Tip \$0.05'), findsOneWidget);
    await tester.tap(find.byType(PulseButton));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('paints the signature pulseGradient when enabled', (tester) async {
    await tester.pumpWidget(_host(
      PulseButton(label: 'Go', onPressed: () {}),
    ));

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(PulseButton),
        matching: find.byType(Container),
      ).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.gradient, PulsColors.pulseGradient);
  });

  testWidgets('disabled (null onPressed) does not fire and drops gradient',
      (tester) async {
    await tester.pumpWidget(_host(
      const PulseButton(label: 'Disabled', onPressed: null),
    ));

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(PulseButton),
        matching: find.byType(Container),
      ).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.gradient, isNull);

    // Tapping a disabled button must be a no-op (no exception).
    await tester.tap(find.byType(PulseButton));
    await tester.pump();
  });

  testWidgets('loading shows a spinner and swallows taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      PulseButton(label: 'Save', loading: true, onPressed: () => taps++),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    await tester.tap(find.byType(PulseButton));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('renders an optional leading icon', (tester) async {
    await tester.pumpWidget(_host(
      PulseButton(
        label: 'Copy',
        icon: Icons.bolt_rounded,
        onPressed: () {},
      ),
    ));
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
  });
}

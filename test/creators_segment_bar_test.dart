import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/features/profile/creators_segment_bar.dart';

Widget _host({required String selected, required ValueChanged<String> onChanged}) =>
    MaterialApp(
      theme: PulsTheme.dark(),
      home: Scaffold(
        body: CreatorsSegmentBar(selected: selected, onChanged: onChanged),
      ),
    );

void main() {
  testWidgets('renders the three creator segments', (tester) async {
    await tester.pumpWidget(_host(selected: 'ranking', onChanged: (_) {}));
    expect(find.text('Ranking'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Humans / Agents'), findsOneWidget);
  });

  testWidgets('tapping a segment emits its value', (tester) async {
    String? picked;
    await tester.pumpWidget(_host(selected: 'ranking', onChanged: (v) => picked = v));
    await tester.tap(find.text('Alpha'));
    expect(picked, 'alpha');
    await tester.tap(find.text('Humans / Agents'));
    expect(picked, 'people');
  });

  testWidgets('tapping the already-selected segment does not emit', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_host(selected: 'alpha', onChanged: (_) => calls++));
    await tester.tap(find.text('Alpha'));
    expect(calls, 0);
  });
}

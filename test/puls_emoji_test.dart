import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/utils/puls_emoji.dart';

void main() {
  const style = TextStyle(fontSize: 14);

  group('PulsEmoji lookup', () {
    test('assetFor returns the mapped asset path', () {
      expect(PulsEmoji.assetFor('🔥'), 'assets/emoji/the-flash-sign.png');
      expect(PulsEmoji.assetFor('🤖'), 'assets/emoji/robot.png');
    });

    test('assetFor returns null for an unmapped emoji', () {
      expect(PulsEmoji.assetFor('🥑'), isNull);
    });

    test('has reflects whether an icon is registered', () {
      expect(PulsEmoji.has('⚡'), isTrue);
      expect(PulsEmoji.has('🥑'), isFalse);
    });

    test('shield variant with and without VS16 both map', () {
      expect(PulsEmoji.has('🛡️'), isTrue);
      expect(PulsEmoji.has('🛡'), isTrue);
    });
  });

  group('PulsEmoji.icon', () {
    test('returns an Image for a mapped emoji', () {
      expect(PulsEmoji.icon('🔥'), isA<Image>());
    });

    test('falls back to a Text widget for an unmapped emoji', () {
      final widget = PulsEmoji.icon('🥑');
      expect(widget, isA<Text>());
      expect((widget as Text).data, '🥑');
    });
  });

  group('PulsEmoji.richText', () {
    test('splits leading emoji from trailing text', () {
      final spans = PulsEmoji.richText('🔥 Hot Markets', style: style);
      expect(spans, hasLength(2));
      expect(spans[0], isA<WidgetSpan>());
      expect(spans[1], isA<TextSpan>());
      expect((spans[1] as TextSpan).text, ' Hot Markets');
    });

    test('handles an emoji embedded mid-string', () {
      final spans = PulsEmoji.richText('Hot 🔥 today', style: style);
      expect(spans, hasLength(3));
      expect((spans[0] as TextSpan).text, 'Hot ');
      expect(spans[1], isA<WidgetSpan>());
      expect((spans[2] as TextSpan).text, ' today');
    });

    test('returns a single text span when there is no mapped emoji', () {
      final spans = PulsEmoji.richText('plain text', style: style);
      expect(spans, hasLength(1));
      expect((spans.single as TextSpan).text, 'plain text');
    });

    test('handles a two-rune emoji (shield with VS16)', () {
      final spans = PulsEmoji.richText('🛡️ Secure', style: style);
      expect(spans, hasLength(2));
      expect(spans[0], isA<WidgetSpan>());
      expect((spans[1] as TextSpan).text, ' Secure');
    });

    test('emits consecutive emoji as separate widget spans', () {
      final spans = PulsEmoji.richText('🔥🤖', style: style);
      expect(spans, hasLength(2));
      expect(spans.every((s) => s is WidgetSpan), isTrue);
    });
  });
}

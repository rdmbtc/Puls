import 'package:flutter/material.dart';
import '../utils/puls_emoji.dart';

/// Drop-in Text replacement that auto-swaps Unicode emoji with glassmorphism PNGs.
class PulsEmojiText extends StatelessWidget {
  const PulsEmojiText(
    this.text, {
    super.key,
    this.style,
    this.emojiSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final double? emojiSize;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final size = emojiSize ?? (effectiveStyle.fontSize ?? 14) * 1.3;
    final spans = PulsEmoji.richText(text, style: effectiveStyle, emojiSize: size);
    if (spans.length == 1 && spans.first is TextSpan) {
      return Text(
        text,
        style: effectiveStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

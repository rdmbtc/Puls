import 'package:flutter/material.dart';

/// Centralized emoji→PNG registry. Every surface that previously used a
/// system Unicode emoji should go through this class so the app renders
/// premium glassmorphism icons consistently.
class PulsEmoji {
  PulsEmoji._();

  static const _base = 'assets/emoji';

  // ─── Master mapping ───
  static const Map<String, String> _map = {
    '🔥': '$_base/the-flash-sign.png',
    '🤖': '$_base/robot.png',
    '⚡': '$_base/flash-on.png',
    '🧠': '$_base/processor.png',
    '🛡️': '$_base/realtime-protection.png',
    '🛡': '$_base/realtime-protection.png', // variant without VS16
    '📈': '$_base/stocks.png',
    '📉': '$_base/area-chart.png',
    '🔮': '$_base/module.png',
    '🔭': '$_base/camera-intelligence.png',
    '🌐': '$_base/web.png',
    '⚽': '$_base/trainers.png',
    '🚀': '$_base/sprint-iteration.png',
    '🏆': '$_base/medal2.png',
    '🎯': '$_base/goal.png',
    '✅': '$_base/check.png',
    '❌': '$_base/delete-file.png',
    '💸': '$_base/online-money-transfer.png',
    '🔍': '$_base/view-file.png',
    '📝': '$_base/edit-file.png',
    '🔒': '$_base/card-security.png',
    '⭐': '$_base/visual-effects.png',
    '🌍': '$_base/worldwide-delivery.png',
    '🗳️': '$_base/privacy-policy.png',
    '🪙': '$_base/blockchain-technology.png',
    '🎬': '$_base/film-reel.png',
    '🧪': '$_base/biotech.png',
    '💻': '$_base/laptop.png',
    '💼': '$_base/briefcase.png',
    '🧑': '$_base/gender-neutral-user.png',
    '👥': '$_base/groups.png',
    '🌊': '$_base/layers.png',
  };

  /// Returns the asset path for a given emoji, or null if not mapped.
  static String? assetFor(String emoji) => _map[emoji];

  /// Whether we have a custom icon for this emoji.
  static bool has(String emoji) => _map.containsKey(emoji);

  /// Returns an Image widget (sized to match text context) or the
  /// original emoji Text as fallback.
  static Widget icon(String emoji, {double size = 18}) {
    final path = _map[emoji];
    if (path == null) return Text(emoji, style: TextStyle(fontSize: size));
    return Image.asset(
      path,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }

  /// Replaces emoji in a string like '🔥 Hot Markets' with an InlineSpan
  /// containing the PNG, preserving text flow.
  static List<InlineSpan> richText(String text, {
    required TextStyle style,
    double emojiSize = 18,
  }) {
    final spans = <InlineSpan>[];
    final runes = text.runes.toList();
    final buffer = StringBuffer();

    for (var i = 0; i < runes.length; i++) {
      final char = String.fromCharCode(runes[i]);
      // Check 1-2 char emoji (some emoji are surrogate pairs or combine with VS16)
      String? emoji;
      if (i + 1 < runes.length) {
        final twoChar = String.fromCharCodes([runes[i], runes[i + 1]]);
        if (_map.containsKey(twoChar)) {
          emoji = twoChar;
          i++; // skip next rune
        }
      }
      emoji ??= _map.containsKey(char) ? char : null;

      if (emoji != null) {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(text: buffer.toString(), style: style));
          buffer.clear();
        }
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Image.asset(
              _map[emoji]!,
              width: emojiSize,
              height: emojiSize,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ));
      } else {
        buffer.writeCharCode(runes[i]);
      }
    }
    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString(), style: style));
    }
    return spans;
  }

  /// Precache all emoji assets for instant display.
  static Future<void> precacheAll(BuildContext context) async {
    for (final path in _map.values) {
      precacheImage(AssetImage(path), context);
    }
  }
}

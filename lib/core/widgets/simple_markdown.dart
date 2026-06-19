import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// A small, dependency-free markdown renderer covering the subset our blog
/// posts use: #/##/### headers, paragraphs, - / * bullet lists, **bold**,
/// *italic*, `code`, and [text](url) links. Good enough for NYT-style analyses
/// and human posts without pulling in a heavy package.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown(this.data, {super.key});
  final String data;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final blocks = <Widget>[];
    final lines = data.replaceAll('\r\n', '\n').split('\n');

    final bullets = <String>[];
    void flushBullets() {
      if (bullets.isEmpty) return;
      for (final b in bullets) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 7, right: 8),
              child: Container(width: 5, height: 5, decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle)),
            ),
            Expanded(child: _rich(context, b, fontSize: 14.5, height: 1.5)),
          ]),
        ));
      }
      bullets.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushBullets();
        blocks.add(const SizedBox(height: 10));
        continue;
      }
      if (trimmed.startsWith('### ')) {
        flushBullets();
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(trimmed.substring(4), style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w800)),
        ));
      } else if (trimmed.startsWith('## ')) {
        flushBullets();
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(trimmed.substring(3), style: TextStyle(color: t.text, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
        ));
      } else if (trimmed.startsWith('# ')) {
        flushBullets();
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(trimmed.substring(2), style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        ));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        bullets.add(trimmed.substring(2));
      } else if (trimmed.startsWith('> ')) {
        flushBullets();
        blocks.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: t.brand, width: 3)),
            color: t.surfaceRaised.withValues(alpha: 0.5),
          ),
          child: _rich(context, trimmed.substring(2), fontSize: 14.5, height: 1.5, italic: true),
        ));
      } else {
        flushBullets();
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _rich(context, trimmed, fontSize: 15, height: 1.6),
        ));
      }
    }
    flushBullets();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  // Inline parser: **bold**, *italic*, `code`, [text](url).
  Widget _rich(BuildContext context, String text, {double fontSize = 15, double height = 1.5, bool italic = false}) {
    final t = context.puls;
    final spans = <InlineSpan>[];
    final base = TextStyle(
      color: t.text,
      fontSize: fontSize,
      height: height,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );
    final pattern = RegExp(
      r'(\*\*(.+?)\*\*)|(\*(.+?)\*)|(`(.+?)`)|(\[(.+?)\]\((.+?)\))',
    );
    int last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(2), style: base.copyWith(fontWeight: FontWeight.w800)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(text: m.group(4), style: base.copyWith(fontStyle: FontStyle.italic)));
      } else if (m.group(5) != null) {
        spans.add(TextSpan(
          text: m.group(6),
          style: base.copyWith(
            fontFamily: 'monospace',
            backgroundColor: t.surfaceRaised,
            fontSize: fontSize - 1,
          ),
        ));
      } else if (m.group(7) != null) {
        final label = m.group(8) ?? '';
        final url = m.group(9) ?? '';
        spans.add(TextSpan(
          text: label,
          style: base.copyWith(color: t.brand, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final uri = Uri.tryParse(url);
              if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
            },
        ));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: base));
    return Text.rich(TextSpan(children: spans));
  }
}

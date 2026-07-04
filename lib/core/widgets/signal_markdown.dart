import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Renders a long-form creator signal thesis as GitHub-flavored Markdown with
/// Puls-specific styling: a serif body font (Playfair Display, bundled), bold
/// numbers in the brand-adjacent ink, brand-colored H2 markers, tappable links.
///
/// Used by [SignalThesisSheet] — the bottom-sheet reader for unlocked signals.
/// Designed for 1500-3500-char theses with structure:
///   ## Verdict / ## The Case / ## Why the market is wrong
///   ## Invalidation / ## Key risks
class SignalMarkdown extends StatelessWidget {
  const SignalMarkdown({super.key, required this.data, this.maxWidth = 560});

  final String data;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: MarkdownBody(
        data: data,
        selectable: true,
        extensionSet: md.ExtensionSet.gitHubFlavored,
        onTapLink: (text, href, title) async {
          final uri = href == null ? null : Uri.tryParse(href);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            fontFamily: 'Playfair Display',
            fontFamilyFallback: const ['serif'],
            color: t.text,
            fontSize: 14.5,
            height: 1.65,
            fontWeight: FontWeight.w500,
          ),
          pPadding: const EdgeInsets.only(bottom: 6),
          h2: TextStyle(
            color: t.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.3,
            letterSpacing: -0.2,
          ),
          h2Padding: const EdgeInsets.only(top: 18, bottom: 6, left: 10),
          h3: TextStyle(
            color: t.text,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
          h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
          strong: TextStyle(
            color: t.text,
            fontWeight: FontWeight.w800,
          ),
          em: TextStyle(
            color: t.textMuted,
            fontStyle: FontStyle.italic,
          ),
          a: TextStyle(
            color: t.brand,
            decoration: TextDecoration.underline,
            decorationColor: t.brand.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
          ),
          blockSpacing: 10,
          blockquote: TextStyle(
            color: t.textMuted,
            fontStyle: FontStyle.italic,
            fontSize: 13.5,
            height: 1.55,
          ),
          blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          blockquoteDecoration: BoxDecoration(
            color: t.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: t.border, width: 3)),
          ),
          code: TextStyle(
            color: t.brand,
            fontFamily: 'monospace',
            fontSize: 13,
            backgroundColor: t.surfaceRaised,
          ),
          codeblockPadding: const EdgeInsets.all(12),
          codeblockDecoration: BoxDecoration(
            color: t.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border),
          ),
          listIndent: 18,
          listBullet: TextStyle(
            color: t.brand,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: t.border, width: 1),
              bottom: BorderSide(color: t.border, width: 1),
            ),
          ),
        ),
      ),
    );
  }
}

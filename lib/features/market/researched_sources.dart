import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/creator_signal.dart';

/// Renders the live web sources a signal was researched from as clickable
/// chips — visible proof the thesis is grounded, not hallucinated. Shared by
/// the AI Alpha marketplace and creator-profile signal cards.
class ResearchedSources extends StatelessWidget {
  const ResearchedSources({super.key, required this.sources});
  final List<SignalSource> sources;

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    final t = context.puls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.travel_explore_rounded, size: 13, color: t.textMuted),
          const SizedBox(width: 5),
          Text('Researched sources',
              style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
        ]),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in sources)
              InkWell(
                onTap: () => _open(s.url),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: t.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.link_rounded, size: 12, color: t.brand),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        s.source ?? s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.text, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

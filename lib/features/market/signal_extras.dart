import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/puls_app_state.dart';
import '../../core/config.dart' show appBaseUrl;
import '../../core/theme/app_theme.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/creator_signal.dart';

/// Compact "researched Xh ago" freshness label from publishedAt.
class SignalFreshness extends StatelessWidget {
  const SignalFreshness({super.key, required this.publishedAt});
  final DateTime? publishedAt;

  static String relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (publishedAt == null) return const SizedBox.shrink();
    final t = context.puls;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.schedule_rounded, size: 11, color: t.textSubtle),
      const SizedBox(width: 4),
      Text('researched ${relative(publishedAt!)}',
          style: TextStyle(color: t.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w600)),
    ]);
  }
}

/// A live YES/NO odds badge for the market a signal is about, plus whether the
/// signal's stance is currently "in the money". Resolves the market by slug
/// against the loaded feed; renders nothing if the market isn't loaded.
class SignalLiveOdds extends StatelessWidget {
  const SignalLiveOdds({super.key, required this.signal});
  final CreatorSignal signal;

  @override
  Widget build(BuildContext context) {
    final slug = signal.marketSlug;
    if (slug == null || slug.isEmpty) return const SizedBox.shrink();
    final t = context.puls;
    final markets = PulsStateScope.of(context).markets;
    final idx = markets.indexWhere((m) => m.slug == slug || m.id == slug);
    if (idx < 0) return const SizedBox.shrink();
    final m = markets[idx];
    final isYes = signal.stance == 'YES';
    // Price of the side the signal took.
    final sidePrice = isYes ? m.yesPrice : m.noPrice;
    final yesPct = (m.yesPrice * 100).round();
    final noPct = (m.noPrice * 100).round();
    // "In the money" = the side the signal took is currently the favourite.
    final inMoney = sidePrice >= 0.5;
    final mc = inMoney ? t.yes : t.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bolt_rounded, size: 11, color: t.brand),
        const SizedBox(width: 4),
        Text('Live', style: TextStyle(color: t.textMuted, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
        const SizedBox(width: 6),
        Text('YES $yesPct¢', style: TextStyle(color: t.yes, fontSize: 11, fontWeight: FontWeight.w800)),
        Text('  ·  ', style: TextStyle(color: t.textSubtle, fontSize: 11)),
        Text('NO $noPct¢', style: TextStyle(color: t.no, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: mc.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(5)),
          child: Text(inMoney ? 'in the money' : '${(sidePrice * 100).round()}¢ ${signal.stance}',
              style: TextStyle(color: mc, fontSize: 9.5, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// Share a signal as the linked market's deep link (which already renders a
/// rich OG image). Copies a ready-to-post line to the clipboard.
class ShareSignalButton extends StatelessWidget {
  const ShareSignalButton({super.key, required this.signal, this.authorName});
  final CreatorSignal signal;
  final String? authorName;

  String get _url {
    final slug = signal.marketSlug;
    return (slug != null && slug.isNotEmpty) ? '$appBaseUrl/m/$slug' : appBaseUrl;
  }

  String get _shareText {
    final who = (authorName != null && authorName!.isNotEmpty) ? authorName : 'A Puls creator';
    final conf = signal.confidence != null ? ' (${(signal.confidence! * 100).round()}% conf)' : '';
    return '$who calls ${signal.stance} on "${signal.title}"$conf.\n'
        'See the prediction + trade it live on Puls: $_url';
  }

  Future<void> _share(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Signal post copied — paste it on X!'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return InkWell(
      onTap: () => _share(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.ios_share_rounded, size: 13, color: t.textMuted),
          const SizedBox(width: 4),
          Text('Share', style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

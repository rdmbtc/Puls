import 'package:flutter/material.dart';
import '../../core/widgets/puls_snack.dart';
import 'package:flutter/services.dart';

import '../../core/config.dart' show appBaseUrl;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_sheet.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';

/// Bottom sheet for sharing a market via its /m/<slug> deep link.
/// Links unfurl with a rich OG card (question + live YES/NO prices)
/// in X, Telegram, Discord and Slack.
class ShareMarketSheet extends StatelessWidget {
  const ShareMarketSheet({required this.market, super.key});

  final Market market;

  static void show(BuildContext context, Market market) {
    PulsSheet.show<void>(
      context,
      builder: (_) => ShareMarketSheet(market: market),
    );
  }

  String get _url => '$appBaseUrl/m/${market.slug.isNotEmpty ? market.slug : market.id}';

  String get _shareText =>
      '"${market.question}" — YES ${TradeMath.formatPrice(market.yesPrice)} · '
      'NO ${TradeMath.formatPrice(market.noPrice)}\n'
      'Trade it live on Puls: $_url';

  Future<void> _copy(BuildContext context, String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      final snack = PulsSnack.of(context);
      Navigator.of(context).pop();
      snack.success(toast);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    return PulsSheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              'Share this market',
              style: TextStyle(
                color: t.text,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The link unfurls with live YES/NO prices in X, Telegram and Discord.',
              style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            // Link preview pill
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.surfaceRaised.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 16, color: t.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _url.replaceFirst('https://', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ShareBtn(
                    icon: Icons.link_rounded,
                    label: 'Copy link',
                    primary: true,
                    t: t,
                    onTap: () => _copy(context, _url, '✅ Link copied — paste it anywhere!'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ShareBtn(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Copy post',
                    primary: false,
                    t: t,
                    onTap: () => _copy(context, _shareText, '✅ Post copied with live prices!'),
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }
}

class _ShareBtn extends StatelessWidget {
  const _ShareBtn({
    required this.icon,
    required this.label,
    required this.primary,
    required this.t,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool primary;
  final PulsThemeColors t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: primary ? t.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: primary ? null : Border.all(color: t.border, width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: primary ? Colors.white : t.text),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: primary ? Colors.white : t.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

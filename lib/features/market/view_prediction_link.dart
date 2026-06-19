import 'package:flutter/material.dart';
import '../../core/widgets/puls_snack.dart';
import '../../core/widgets/puls_page_route.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import 'market_detail_screen.dart';

/// A tappable "View prediction" link that opens the market a Signal is about,
/// in-app (resolves the slug to a market, same path as a /m/<slug> deep link).
/// Shared by the signals marketplace and creator-profile signal cards so a
/// reader can jump straight from a signal to the prediction it references.
class ViewPredictionLink extends StatefulWidget {
  const ViewPredictionLink({super.key, required this.slug});
  final String slug;

  @override
  State<ViewPredictionLink> createState() => _ViewPredictionLinkState();
}

class _ViewPredictionLinkState extends State<ViewPredictionLink> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final appState = PulsStateScope.of(context);
    final navigator = Navigator.of(context);
    final snack = PulsSnack.of(context);
    final market = await appState.ensureMarketBySlug(widget.slug);
    if (!mounted) return;
    setState(() => _opening = false);
    if (market != null) {
      navigator.push(pulsRoute<void>(
        context,
        builder: (_) => MarketDetailScreen(marketId: market.id),
      ));
    } else {
      snack.error('Market not available right now',
          duration: const Duration(seconds: 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.show_chart_rounded, size: 13, color: t.brand),
          const SizedBox(width: 5),
          Text(_opening ? 'Opening…' : 'View prediction',
              style: TextStyle(
                  color: t.brand, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(width: 3),
          Icon(Icons.arrow_forward_rounded, size: 12, color: t.brand),
        ]),
      ),
    );
  }
}

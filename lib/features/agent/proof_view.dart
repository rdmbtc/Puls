import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'live_swarm_view.dart' show AgentSegToggle;
import 'x402_payments.dart';
import 'economy_feed.dart';

/// "Proof" — everything in the Puls economy that's verifiable on-chain on Arc.
///
/// A slim toggle switches between x402 nanopayment receipts (creator earnings +
/// agent-to-agent payments) and the Economy Explorer (every on-chain USDC move
/// across treasury, agents and creators). Both sub-views are the existing
/// widgets, reused untouched and kept warm via an [IndexedStack].
class ProofView extends StatefulWidget {
  const ProofView({super.key});

  @override
  State<ProofView> createState() => _ProofViewState();
}

class _ProofViewState extends State<ProofView> {
  int _i = 0; // 0 = x402 nanopayments, 1 = Economy Explorer

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: AgentSegToggle(
            t: t,
            index: _i,
            labels: const ['Nanopayments', 'Economy'],
            onChanged: (v) => setState(() => _i = v),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _i,
            sizing: StackFit.expand,
            children: const [X402Payments(), EconomyFeed()],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/tactile.dart';
import 'swarm_view.dart';
import 'pulse_feed.dart';

/// "Live Swarm" — the spectator home for Puls's autonomous AI agents.
///
/// A slim toggle switches between the full agent colony (every agent in the
/// swarm) and Pulse, the flagship house agent, whose every decision is shown
/// with reasoning + on-chain proof. Both sub-views are the existing widgets,
/// reused untouched and kept warm via an [IndexedStack].
class LiveSwarmView extends StatefulWidget {
  const LiveSwarmView({super.key});

  @override
  State<LiveSwarmView> createState() => _LiveSwarmViewState();
}

class _LiveSwarmViewState extends State<LiveSwarmView> {
  int _i = 0; // 0 = full swarm, 1 = Pulse (flagship)

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
            labels: const ['Swarm', 'Pulse · flagship'],
            onChanged: (v) => setState(() => _i = v),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _i,
            sizing: StackFit.expand,
            children: const [SwarmView(), PulseFeed()],
          ),
        ),
      ],
    );
  }
}

/// A slim two-pill segmented toggle matching the Puls design language.
/// Shared by the merged Agent sub-tabs (Live Swarm, Proof).
class AgentSegToggle extends StatelessWidget {
  const AgentSegToggle({
    super.key,
    required this.t,
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final PulsThemeColors t;
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final sel = i == index;
          return Expanded(
            child: Tactile(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? t.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: sel ? Colors.white : t.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

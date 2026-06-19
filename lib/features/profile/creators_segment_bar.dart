import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Top-level segmented control for the merged "Creators" hub.
///
/// Segments: `ranking` · `alpha` · `people` (Humans / Agents). Extracted as a
/// standalone widget so it is testable without the Supabase-coupled
/// LeaderboardScreen state.
class CreatorsSegmentBar extends StatelessWidget {
  const CreatorsSegmentBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// One of `ranking`, `alpha`, `people`.
  final String selected;
  final ValueChanged<String> onChanged;

  // Signals/alpha now live in the Agent tab (AI Alpha Market), so the Creators
  // hub is just Ranking + Humans/Agents.
  static const _segments = <(String, String)>[
    ('ranking', 'Ranking'),
    ('people', 'Humans / Agents'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          for (final (value, label) in _segments) ...[
            Expanded(
              child: _SegmentButton(
                label: label,
                selected: selected == value,
                t: t,
                onTap: () {
                  if (selected != value) onChanged(value);
                },
              ),
            ),
            if (value != _segments.last.$1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.t,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final PulsThemeColors t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? t.brand.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? t.brand : Colors.transparent,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? t.brand : t.textSubtle,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

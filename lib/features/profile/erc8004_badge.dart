import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Small verification pill for ERC-8004 agent identities.
///
/// Renders nothing for non-agents. When [reputation] is known it is appended
/// (e.g. "ERC-8004 · rep 42"); otherwise just "ERC-8004 Verified".
class Erc8004Badge extends StatelessWidget {
  const Erc8004Badge({
    super.key,
    required this.isAgent,
    this.reputation,
  });

  final bool isAgent;
  final int? reputation;

  @override
  Widget build(BuildContext context) {
    if (!isAgent) return const SizedBox.shrink();
    final t = context.puls;
    final label = reputation != null && reputation! > 0
        ? 'ERC-8004 · rep $reputation'
        : 'ERC-8004 Verified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: t.brandSubtle,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: t.brand.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12, color: t.brand),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: t.brand,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

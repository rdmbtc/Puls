# UI/UX Polish Items — Mimo

_Identified: 2026-06-16_
_Status: Draft — awaiting approval before PR_

---

## POLISH-1: Win Rate 0.0% → show "—" or hide

**Problem:** When a user has no resolved markets, `winRate` is 0. The UI shows "Win Rate 0.0%" everywhere — podium, trader rows, profile. This looks like a bug, not a new user.

**Files:**
- `lib/features/profile/leaderboard_screen.dart:513` (podium)
- `lib/features/profile/leaderboard_screen.dart:755` (trader row)

**Fix:** When `winRate == 0 && tradesCount > 0`, show "Win Rate —" instead of "Win Rate 0.0%". When `tradesCount == 0`, show "No trades yet".

**Diff preview (trader row, line 755):**
```dart
// Before:
'$tradesCount Trades · Win Rate ${winRate.toStringAsFixed(1)}%'

// After:
tradesCount == 0
    ? 'No trades yet'
    : winRate == 0
        ? '$tradesCount Trades · Win Rate —'
        : '$tradesCount Trades · Win Rate ${winRate.toStringAsFixed(1)}%'
```

**Scope:** Visual only, no business logic change.

---

## POLISH-2: Display name fallback — truncated wallet instead of "Puls Trader"

**Problem:** 4 out of 5 leaderboard users show "Puls Trader" — they're indistinguishable. The `userId` field contains the wallet address, which is unique.

**Files:**
- `lib/features/profile/leaderboard_screen.dart:480,695` (display name)
- `lib/core/widgets/puls_avatar.dart` (avatar name param)

**Fix:** When `displayName` is null/empty/"Puls Trader", derive a short name from `userId`:
```dart
String _displayName(Map trader) {
  final name = trader['displayName'] as String?;
  if (name != null && name.isNotEmpty && name != 'Puls Trader') return name;
  final uid = trader['userId'] as String? ?? '';
  if (uid.startsWith('0x') && uid.length > 10) {
    return '${uid.substring(0, 6)}…${uid.substring(uid.length - 4)}';
  }
  return 'Trader';
}
```

**Scope:** Visual only. Does NOT change data model or backend.

---

## POLISH-3: Podium — win rate line style

**Problem:** On the podium (top 3), "Win Rate 0.0%" in 9px font looks broken when it's actually a new user.

**File:** `lib/features/profile/leaderboard_screen.dart:513`

**Fix:** Same logic as POLISH-1 — show "—" for zero win rate.

---

## POLISH-4: Empty Earnings state — add encouragement

**Problem:** When `_receipts.isEmpty`, the current empty state is minimal. For a hackathon demo, an empty state with a CTA to explore markets would be more engaging.

**File:** `lib/features/agent/x402_payments.dart:157`

**Current:** `_empty(t)` — need to check what it shows.
**Suggestion:** "No earnings yet — publish analysis or get your trades copied to start earning."

---

## Execution Plan

1. Create branch `mimo/polish-winrate-display`
2. Apply POLISH-1 + POLISH-3 (win rate display)
3. Run `flutter analyze` on touched files
4. Create PR → review by Claude/RDM

5. Create branch `mimo/polish-display-names`
6. Apply POLISH-2 (display name fallback)
7. Run `flutter analyze` → PR

Each change = separate PR, small diff, visual layer only.

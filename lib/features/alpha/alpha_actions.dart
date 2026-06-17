import 'dart:async';

import '../../core/utils/kv_store.dart';

/// Tiered friction state for the creator-economy pay flows, kept widget-free so
/// it can be unit-tested without the (Supabase-coupled) WalletService.
class AlphaFriction {
  AlphaFriction._();

  /// Once the user has consciously confirmed a paid Alpha unlock on this
  /// device, subsequent unlocks become one-tap.
  static const _kUnlockConfirmedKey = 'alpha_unlock_confirmed_v1';

  /// True until the first unlock has been confirmed on this device.
  static bool get unlockNeedsConfirm => kvGet(_kUnlockConfirmedKey) != '1';

  /// Records that the user has confirmed an unlock at least once.
  static void markUnlockConfirmed() => kvSet(_kUnlockConfirmedKey, '1');
}

/// A tip that fires after a short [delay] unless the user taps Undo first.
///
/// Keeps the timer/cancel mechanics out of the widget so they can be tested
/// deterministically with `fakeAsync`. The caller supplies [onFire] (the actual
/// network tip) and may supply [onUndo] for UI cleanup.
class DeferredTip {
  DeferredTip({
    required this.delay,
    required this.onFire,
    this.onUndo,
  });

  final Duration delay;
  final Future<void> Function() onFire;
  final void Function()? onUndo;

  Timer? _timer;
  bool _cancelled = false;
  bool _fired = false;

  bool get cancelled => _cancelled;
  bool get fired => _fired;

  /// Schedules the tip. Calling [start] more than once is a no-op after the
  /// first fire/cancel.
  void start() {
    if (_cancelled || _fired || _timer != null) return;
    _timer = Timer(delay, () {
      if (_cancelled) return;
      _fired = true;
      onFire();
    });
  }

  /// Cancels a pending tip. Safe to call after it has already fired.
  void cancel() {
    if (_fired || _cancelled) return;
    _cancelled = true;
    _timer?.cancel();
    onUndo?.call();
  }
}

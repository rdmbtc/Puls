import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/features/alpha/alpha_actions.dart';

void main() {
  group('AlphaFriction (confirm-once)', () {
    test('first unlock needs confirm, then one-tap', () {
      // kv io impl is in-memory and fresh per test process.
      expect(AlphaFriction.unlockNeedsConfirm, true);
      AlphaFriction.markUnlockConfirmed();
      expect(AlphaFriction.unlockNeedsConfirm, false);
    });
  });

  group('DeferredTip (undo window)', () {
    test('fires after delay when not undone', () {
      fakeAsync((async) {
        var fired = 0;
        final tip = DeferredTip(
          delay: const Duration(seconds: 5),
          onFire: () async => fired++,
        )..start();
        async.elapse(const Duration(seconds: 4));
        expect(fired, 0);
        async.elapse(const Duration(seconds: 2));
        expect(fired, 1);
        expect(tip.fired, true);
        expect(tip.cancelled, false);
      });
    });

    test('does not fire when undone within window', () {
      fakeAsync((async) {
        var fired = 0;
        var undone = 0;
        final tip = DeferredTip(
          delay: const Duration(seconds: 5),
          onFire: () async => fired++,
          onUndo: () => undone++,
        )..start();
        async.elapse(const Duration(seconds: 2));
        tip.cancel();
        async.elapse(const Duration(seconds: 10));
        expect(fired, 0);
        expect(undone, 1);
        expect(tip.cancelled, true);
        expect(tip.fired, false);
      });
    });

    test('cancel after fire is a no-op', () {
      fakeAsync((async) {
        var fired = 0;
        final tip = DeferredTip(
          delay: const Duration(seconds: 1),
          onFire: () async => fired++,
        )..start();
        async.elapse(const Duration(seconds: 2));
        expect(tip.fired, true);
        tip.cancel();
        expect(tip.cancelled, false);
        expect(fired, 1);
      });
    });
  });
}

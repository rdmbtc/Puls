import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/utils/formatters.dart';

void main() {
  group('timeAgo', () {
    test('renders coarse buckets with an "ago" suffix', () {
      final now = DateTime.now();
      expect(timeAgo(now.subtract(const Duration(seconds: 30))), 'just now');
      expect(timeAgo(now.subtract(const Duration(minutes: 5))), '5m ago');
      expect(timeAgo(now.subtract(const Duration(hours: 3))), '3h ago');
      expect(timeAgo(now.subtract(const Duration(days: 2))), '2d ago');
    });

    test('honours a custom "just now" label', () {
      expect(
        timeAgo(DateTime.now(), justNow: 'Just now'),
        'Just now',
      );
    });
  });

  group('timeAgoShort', () {
    test('renders compact buckets without a suffix', () {
      final now = DateTime.now();
      expect(timeAgoShort(now.subtract(const Duration(seconds: 30))), 'now');
      expect(timeAgoShort(now.subtract(const Duration(minutes: 5))), '5m');
      expect(timeAgoShort(now.subtract(const Duration(hours: 3))), '3h');
      expect(timeAgoShort(now.subtract(const Duration(days: 2))), '2d');
    });

    test('optionally includes seconds and years', () {
      final now = DateTime.now();
      expect(
        timeAgoShort(now.subtract(const Duration(seconds: 12)),
            includeSeconds: true),
        '12s',
      );
      expect(
        timeAgoShort(now.subtract(const Duration(days: 800)),
            includeYears: true),
        '2y',
      );
    });
  });

  group('withThousands', () {
    test('groups digits by threes', () {
      expect(withThousands(0), '0');
      expect(withThousands(999), '999');
      expect(withThousands(1234), '1,234');
      expect(withThousands(1234567), '1,234,567');
      expect(withThousands(-1234567), '-1,234,567');
    });
  });

  group('compactUsd', () {
    test('abbreviates thousands and millions', () {
      expect(compactUsd(120), '\$120');
      expect(compactUsd(34000), '\$34K');
      expect(compactUsd(2400000), '\$2.4M');
    });

    test('renders a dash for non-positive values when requested', () {
      expect(compactUsd(0, dashForZero: true), '—');
      expect(compactUsd(0), '\$0');
    });
  });

  group('trimTrailingZeros', () {
    test('drops trailing zeros and dangling points', () {
      expect(trimTrailingZeros('1.2500'), '1.25');
      expect(trimTrailingZeros('3.0'), '3');
      expect(trimTrailingZeros('42'), '42');
    });
  });

  group('formatShortDateTime', () {
    test('renders day/month hour:minute', () {
      expect(formatShortDateTime('2024-03-07T14:05:00'), '7/3 14:05');
    });

    test('returns empty string for unparseable input', () {
      expect(formatShortDateTime('not-a-date'), '');
    });
  });
}

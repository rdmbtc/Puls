/// Shared formatting helpers used across the app.
///
/// These were previously re-implemented as private `_ago`, `_fmt`,
/// `_formatShares`, `_formatTime`, etc. methods in many widgets. Keeping them
/// here avoids drift between the copies and gives us one place to test.
library;

/// Relative time with an " ago" suffix, e.g. "just now", "5m ago", "3h ago",
/// "2d ago".
///
/// The input is normalised to local time so callers can pass UTC timestamps.
String timeAgo(DateTime time, {String justNow = 'just now'}) {
  final d = DateTime.now().difference(time.toLocal());
  if (d.inMinutes < 1) return justNow;
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

/// Compact relative time without the " ago" suffix, e.g. "now", "5m", "3h",
/// "2d" (and "1y" when [includeYears] is set).
///
/// When [includeSeconds] is set, durations under a minute render as "12s"
/// instead of [justNow].
String timeAgoShort(
  DateTime time, {
  String justNow = 'now',
  bool includeSeconds = false,
  bool includeYears = false,
}) {
  final d = DateTime.now().difference(time.toLocal());
  if (includeSeconds && d.inSeconds < 60) return '${d.inSeconds}s';
  if (d.inMinutes < 1) return justNow;
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (includeYears && d.inDays >= 365) return '${d.inDays ~/ 365}y';
  return '${d.inDays}d';
}

/// Formats an integer with thousands separators, e.g. 1234567 -> "1,234,567".
String withThousands(int value) {
  final negative = value < 0;
  final s = value.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return negative ? '-$b' : b.toString();
}

/// Compact USD amount, e.g. "$1.2M", "$34K", "$120".
///
/// When [dashForZero] is set, non-positive values render as "—".
String compactUsd(double v, {bool dashForZero = false}) {
  if (dashForZero && v <= 0) return '—';
  if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
  if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
  return '\$${v.toStringAsFixed(0)}';
}

/// Removes trailing zeros (and a dangling decimal point) from a fixed-decimal
/// string, e.g. "1.2500" -> "1.25", "3.0" -> "3".
String trimTrailingZeros(String value) {
  var str = value;
  while (str.contains('.') && (str.endsWith('0') || str.endsWith('.'))) {
    if (str.endsWith('.')) {
      str = str.substring(0, str.length - 1);
      break;
    }
    str = str.substring(0, str.length - 1);
  }
  return str;
}

/// Short local date/time, e.g. "7/10 14:05". Returns an empty string when the
/// input cannot be parsed.
String formatShortDateTime(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

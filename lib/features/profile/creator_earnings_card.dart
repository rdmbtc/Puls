import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Creator earnings summary with a tiny sparkline.
///
/// Degrades gracefully: when [earningsUsd] is null (backend hasn't shipped the
/// per-creator earnings endpoint yet) it shows a muted placeholder instead of a
/// fake zero. The sparkline is only drawn when at least two points are present.
class CreatorEarningsCard extends StatelessWidget {
  const CreatorEarningsCard({
    super.key,
    required this.earningsUsd,
    this.spark = const [],
  });

  final double? earningsUsd;
  final List<double> spark;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final hasData = earningsUsd != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CREATOR EARNINGS',
                  style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                if (hasData)
                  Text(
                    '\$${earningsUsd!.toStringAsFixed(earningsUsd! < 1 ? 3 : 2)}',
                    style: TextStyle(
                      color: t.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  )
                else
                  Text(
                    'Earnings appear once paid',
                    style: TextStyle(color: t.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                if (hasData) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Paid to this creator on Arc',
                    style: TextStyle(color: t.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (spark.length >= 2) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 84,
              height: 40,
              child: CustomPaint(painter: _SparkPainter(spark, t.brand)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.points, this.color);

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final lo = points.reduce((a, b) => a < b ? a : b);
    final hi = points.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : (hi - lo);
    final dx = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = dx * i;
      final y = size.height - ((points[i] - lo) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.points != points || old.color != color;
}

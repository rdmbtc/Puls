import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class MarketChart extends StatelessWidget {
  const MarketChart({
    required this.values,
    required this.color,
    super.key,
  });

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.puls;
    final spots = values
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();

    // Draw-in reveal: the line sweeps in from the left on first build.
    return TweenAnimationBuilder<double>(
      key: ValueKey(values.length),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, reveal, child) => ShaderMask(
        shaderCallback: (rect) => LinearGradient(
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, reveal, (reveal + 0.12).clamp(0.0, 1.0)],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: child,
      ),
      child: _chart(tokens, spots),
    );
  }

  Widget _chart(PulsThemeColors tokens, List<FlSpot> spots) {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 1,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 0.25,
            getDrawingHorizontalLine: (_) => FlLine(
              color: tokens.border.withValues(alpha: 0.55),
              strokeWidth: 1,
            ),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.16),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

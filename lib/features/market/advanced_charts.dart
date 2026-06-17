import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';

class CandleData {
  CandleData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.time,
  });

  final double open;
  final double high;
  final double low;
  final double close;
  final DateTime time;
}

class CandlestickChart extends StatefulWidget {
  const CandlestickChart({
    required this.prices,
    required this.upColor,
    required this.downColor,
    super.key,
  });

  final List<double> prices;
  final Color upColor;
  final Color downColor;

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart> {
  int? _hoveredIndex;

  List<CandleData> _generateCandles() {
    if (widget.prices.length < 4) {
      // Create fallback candles from raw prices
      return widget.prices.asMap().entries.map((e) {
        final val = e.value;
        return CandleData(
          open: val * 0.98,
          high: val * 1.02,
          low: val * 0.96,
          close: val,
          time: DateTime.now().subtract(Duration(days: widget.prices.length - e.key)),
        );
      }).toList();
    }

    final List<CandleData> candles = [];
    // Chunk the price points into groups of 4 to make each candle
    const chunkSize = 4;
    for (int i = 0; i < widget.prices.length; i += chunkSize) {
      final chunk = widget.prices.skip(i).take(chunkSize).toList();
      if (chunk.isEmpty) continue;
      final open = chunk.first;
      final close = chunk.last;
      final high = chunk.reduce((a, b) => a > b ? a : b);
      final low = chunk.reduce((a, b) => a < b ? a : b);
      
      // Add slight variance to high/low if they are exactly equal to avoid flat wicks
      final adjustedHigh = high == low ? high * 1.01 : high;
      final adjustedLow = high == low ? low * 0.99 : low;

      candles.add(CandleData(
        open: open,
        high: adjustedHigh.clamp(0.01, 0.99),
        low: adjustedLow.clamp(0.01, 0.99),
        close: close,
        time: DateTime.now().subtract(Duration(days: (widget.prices.length - i) ~/ chunkSize)),
      ));
    }
    return candles;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final candles = _generateCandles();
    if (candles.isEmpty) {
      return Center(
        child: Text('No candlestick data yet — need more price history.', style: TextStyle(color: t.textSubtle, fontSize: 12)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Column(
          children: [
            // Hover Tooltip Header
            Container(
              height: 24,
              alignment: Alignment.center,
              child: _hoveredIndex != null && _hoveredIndex! < candles.length
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _infoText('O', candles[_hoveredIndex!].open, t),
                        const SizedBox(width: 8),
                        _infoText('H', candles[_hoveredIndex!].high, t),
                        const SizedBox(width: 8),
                        _infoText('L', candles[_hoveredIndex!].low, t),
                        const SizedBox(width: 8),
                        _infoText('C', candles[_hoveredIndex!].close, t),
                        const SizedBox(width: 8),
                        Text(
                          candles[_hoveredIndex!].close >= candles[_hoveredIndex!].open ? '▲' : '▼',
                          style: TextStyle(
                            color: candles[_hoveredIndex!].close >= candles[_hoveredIndex!].open
                                ? widget.upColor
                                : widget.downColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Hover candles to inspect OHLC levels',
                      style: TextStyle(color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
            ),
            const SizedBox(height: 8),
            // Custom Painter Canvas
            Expanded(
              child: GestureDetector(
                onPanUpdate: (details) => _handleTouch(details.localPosition, candles, width),
                onPanDown: (details) => _handleTouch(details.localPosition, candles, width),
                onTapUp: (details) => _handleTouch(details.localPosition, candles, width),
                child: CustomPaint(
                  size: Size(width, height - 32),
                  painter: _CandlePainter(
                    candles: candles,
                    upColor: widget.upColor,
                    downColor: widget.downColor,
                    textColor: t.textSubtle,
                    gridColor: t.border,
                    hoveredIndex: _hoveredIndex,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleTouch(Offset localPos, List<CandleData> candles, double totalWidth) {
    final candleWidth = totalWidth / candles.length;
    final int idx = (localPos.dx / candleWidth).floor().clamp(0, candles.length - 1);
    if (_hoveredIndex != idx) {
      setState(() => _hoveredIndex = idx);
    }
  }

  Widget _infoText(String label, double val, PulsThemeColors t) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: t.textMuted),
        children: [
          TextSpan(text: '$label: ', style: TextStyle(color: t.textSubtle, fontWeight: FontWeight.bold)),
          TextSpan(text: '${(val * 100).toStringAsFixed(1)}¢', style: TextStyle(color: t.text, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({
    required this.candles,
    required this.upColor,
    required this.downColor,
    required this.textColor,
    required this.gridColor,
    required this.hoveredIndex,
  });

  final List<CandleData> candles;
  final Color upColor;
  final Color downColor;
  final Color textColor;
  final Color gridColor;
  final int? hoveredIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final double maxVal = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final double minVal = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final double pad = (maxVal - minVal) < 0.02 ? 0.05 : (maxVal - minVal) * 0.1;
    final double yMax = (maxVal + pad).clamp(0.0, 1.0);
    final double yMin = (minVal - pad).clamp(0.0, 1.0);

    // Draw Grid Lines (Horizontal)
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = size.height * i / gridLines;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      
      // Draw grid text label
      final gridVal = yMax - (yMax - yMin) * i / gridLines;
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(gridVal * 100).toStringAsFixed(0)}¢',
          style: TextStyle(color: textColor, fontSize: 8, fontFamily: 'monospace'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(4, y - 10));
    }

    final double candleWidth = size.width / candles.length;
    final double bodyPadding = candleWidth * 0.2;

    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final isUp = candle.close >= candle.open;
      final color = isUp ? upColor : downColor;

      final double xCenter = candleWidth * i + candleWidth / 2;

      // Map values to pixels
      double mapY(double val) {
        return size.height - ((val - yMin) / (yMax - yMin) * size.height);
      }

      final double yHigh = mapY(candle.high);
      final double yLow = mapY(candle.low);
      final double yOpen = mapY(candle.open);
      final double yClose = mapY(candle.close);

      // Draw hovered index highlight column
      if (i == hoveredIndex) {
        final highlightPaint = Paint()
          ..color = color.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(candleWidth * i, 0, candleWidth, size.height),
          highlightPaint,
        );
      }

      // Draw Wick Line
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(xCenter, yHigh), Offset(xCenter, yLow), wickPaint);

      // Draw Body Rect
      final bodyPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final double top = yOpen < yClose ? yOpen : yClose;
      final double bottom = yOpen > yClose ? yOpen : yClose;
      
      // Ensure body has at least a small height to be visible even if open == close
      final bodyHeight = (bottom - top).clamp(2.0, double.infinity);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            candleWidth * i + bodyPadding,
            top,
            candleWidth - bodyPadding * 2,
            bodyHeight,
          ),
          const Radius.circular(2),
        ),
        bodyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CandlePainter oldDelegate) {
    return oldDelegate.candles != candles || oldDelegate.hoveredIndex != hoveredIndex;
  }
}

class DepthChart extends StatelessWidget {
  const DepthChart({
    required this.currentPrice,
    required this.t,
    super.key,
  });

  final double currentPrice;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    // Generate simulated Order Book Bids vs Asks around currentPrice
    final List<FlSpot> bids = [];
    final List<FlSpot> asks = [];

    // Bids: from 0.01 up to currentPrice (volume grows cumulative as price goes down)
    const bidSteps = 10;
    for (int i = 0; i <= bidSteps; i++) {
      final price = 0.05 + (currentPrice - 0.06) * i / bidSteps;
      // Cumulative volume: higher volume at lower prices
      final vol = 8000.0 * (bidSteps - i + 1) / bidSteps + 500.0;
      bids.add(FlSpot(price, vol));
    }
    
    // Asks: from currentPrice up to 0.99 (volume grows cumulative as price goes up)
    const askSteps = 10;
    for (int i = 0; i <= askSteps; i++) {
      final price = (currentPrice + 0.01) + (0.95 - currentPrice - 0.01) * i / askSteps;
      // Cumulative volume: higher volume at higher prices
      final vol = 8500.0 * (i + 1) / askSteps + 500.0;
      asks.add(FlSpot(price, vol));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('YES Bids', style: TextStyle(color: t.yes, fontSize: 10, fontWeight: FontWeight.bold)),
            Text('Spread: 1¢', style: TextStyle(color: t.textSubtle, fontSize: 10, fontWeight: FontWeight.w600)),
            Text('NO Bids', style: TextStyle(color: t.no, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 0.20,
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${(v * 100).toStringAsFixed(0)}¢',
                        style: TextStyle(color: t.textSubtle, fontSize: 9, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => t.surface,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final isBid = spot.barIndex == 0;
                      return LineTooltipItem(
                        'Price: ${(spot.x * 100).toStringAsFixed(0)}¢\nDepth: \$${spot.y.toStringAsFixed(0)}',
                        TextStyle(color: isBid ? t.yes : t.no, fontSize: 11, fontWeight: FontWeight.bold),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                // Bids Curve (YES Bids)
                LineChartBarData(
                  spots: bids,
                  isCurved: true,
                  color: t.yes,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        t.yes.withValues(alpha: 0.18),
                        t.yes.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                // Asks Curve (NO Bids)
                LineChartBarData(
                  spots: asks,
                  isCurved: true,
                  color: t.no,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        t.no.withValues(alpha: 0.18),
                        t.no.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

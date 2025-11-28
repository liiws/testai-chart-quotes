import 'package:flutter/material.dart';
import '../models/quote.dart';
import 'candlestick_painter.dart';

class CandlestickChart extends StatelessWidget {
  final List<Quote> quotes;
  final bool showSMA;
  final int smaPeriod;

  const CandlestickChart({
    super.key,
    required this.quotes,
    this.showSMA = false,
    this.smaPeriod = 7,
  });

  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) {
      return const Center(
        child: Text(
          'No data available. Click Refresh to load quotes.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // Calculate SMA values if enabled
    List<double?> smaValues = [];
    if (showSMA && quotes.isNotEmpty && smaPeriod > 0) {
      smaValues = _calculateSMA(quotes, smaPeriod);
    }

    // Calculate min and max values for scaling (include SMA if shown)
    double minPrice = quotes.map((q) => q.low).reduce((a, b) => a < b ? a : b);
    double maxPrice = quotes.map((q) => q.high).reduce((a, b) => a > b ? a : b);
    
    // Include SMA values in min/max calculation
    if (showSMA && smaValues.isNotEmpty) {
      for (final sma in smaValues) {
        if (sma != null) {
          if (sma < minPrice) minPrice = sma;
          if (sma > maxPrice) maxPrice = sma;
        }
      }
    }
    
    // Add some padding
    double priceRange = maxPrice - minPrice;
    minPrice -= priceRange * 0.1;
    maxPrice += priceRange * 0.1;

    return LayoutBuilder(
      builder: (context, constraints) {
        const leftPadding = 60.0;
        const bottomPadding = 30.0;
        const topPadding = 10.0;
        const rightPadding = 10.0;

        final chartWidth = constraints.maxWidth - leftPadding - rightPadding;
        final chartHeight = constraints.maxHeight - topPadding - bottomPadding;

        return Stack(
          children: [
            // Grid and border
            CustomPaint(
              painter: GridPainter(
                minPrice: minPrice,
                maxPrice: maxPrice,
                leftPadding: leftPadding,
                topPadding: topPadding,
                chartWidth: chartWidth,
                chartHeight: chartHeight,
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            ),
            // Y-axis labels
            Positioned(
              left: 0,
              top: topPadding,
              bottom: bottomPadding,
              width: leftPadding,
              child: _buildYAxisLabels(minPrice, maxPrice, chartHeight),
            ),
            // X-axis labels
            Positioned(
              left: leftPadding,
              right: rightPadding,
              bottom: 0,
              height: bottomPadding,
              child: _buildXAxisLabels(chartWidth),
            ),
            // Candlesticks and SMA
            Positioned(
              left: leftPadding,
              top: topPadding,
              right: rightPadding,
              bottom: bottomPadding,
              child: CustomPaint(
                painter: CandlestickPainter(
                  quotes: quotes,
                  minPrice: minPrice,
                  maxPrice: maxPrice,
                  showSMA: showSMA,
                  smaValues: smaValues,
                ),
                size: Size(chartWidth, chartHeight),
              ),
            ),
          ],
        );
      },
    );
  }

  List<double?> _calculateSMA(List<Quote> quotes, int period) {
    final smaValues = <double?>[];
    
    for (int i = 0; i < quotes.length; i++) {
      if (i < period - 1) {
        // Not enough data points yet
        smaValues.add(null);
      } else {
        // Calculate SMA: sum of closes for the last 'period' candles
        double sum = 0.0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += quotes[j].close;
        }
        smaValues.add(sum / period);
      }
    }
    
    return smaValues;
  }

  Widget _buildYAxisLabels(double minPrice, double maxPrice, double chartHeight) {
    final priceRange = maxPrice - minPrice;
    final intervals = 10;
    final step = priceRange / intervals;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(intervals + 1, (index) {
        final price = maxPrice - (step * index);
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Text(
            price.toStringAsFixed(4),
            style: const TextStyle(fontSize: 10),
          ),
        );
      }),
    );
  }

  Widget _buildXAxisLabels(double chartWidth) {
    if (quotes.isEmpty) return const SizedBox();
    
    final spacing = chartWidth / quotes.length;
    final labelCount = quotes.length > 20 ? 10 : quotes.length;
    final step = (quotes.length / labelCount).ceil();

    return CustomPaint(
      painter: XAxisLabelsPainter(
        quotes: quotes,
        spacing: spacing,
        step: step,
      ),
      size: Size(chartWidth, 30),
    );
  }
}

class GridPainter extends CustomPainter {
  final double minPrice;
  final double maxPrice;
  final double leftPadding;
  final double topPadding;
  final double chartWidth;
  final double chartHeight;

  GridPainter({
    required this.minPrice,
    required this.maxPrice,
    required this.leftPadding,
    required this.topPadding,
    required this.chartWidth,
    required this.chartHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines
    final priceRange = maxPrice - minPrice;
    final intervals = 10;
    final step = priceRange / intervals;

    for (int i = 0; i <= intervals; i++) {
      final y = topPadding + (chartHeight / intervals) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        paint,
      );
    }

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(
        leftPadding,
        topPadding,
        chartWidth,
        chartHeight,
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}

class XAxisLabelsPainter extends CustomPainter {
  final List<Quote> quotes;
  final double spacing;
  final int step;

  XAxisLabelsPainter({
    required this.quotes,
    required this.spacing,
    required this.step,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = const TextStyle(
      fontSize: 10,
      color: Colors.black87,
    );

    for (int i = 0; i < quotes.length; i += step) {
      final quote = quotes[i];
      final x = (i + 0.5) * spacing;
      final text = '${quote.date.month}/${quote.date.day}';
      
      final textSpan = TextSpan(text: text, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, (size.height - textPainter.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(XAxisLabelsPainter oldDelegate) => false;
}


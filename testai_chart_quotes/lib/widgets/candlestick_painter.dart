import 'package:flutter/material.dart';
import '../models/quote.dart';

class CandlestickPainter extends CustomPainter {
  final List<Quote> quotes;
  final double minPrice;
  final double maxPrice;
  final double candleWidth;
  final bool showSMA;
  final List<double?> smaValues;

  CandlestickPainter({
    required this.quotes,
    required this.minPrice,
    required this.maxPrice,
    this.candleWidth = 8.0,
    this.showSMA = false,
    this.smaValues = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (quotes.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final wickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final spacing = size.width / quotes.length;
    final priceRange = maxPrice - minPrice;
    final scaleY = size.height / priceRange;
    
    // Adjust candle width based on spacing
    final adjustedCandleWidth = (spacing * 0.6).clamp(4.0, 12.0);

    for (int i = 0; i < quotes.length; i++) {
      final quote = quotes[i];
      final x = (i + 0.5) * spacing;

      // Calculate Y positions (flipped because canvas Y=0 is at top)
      final highY = (maxPrice - quote.high) * scaleY;
      final lowY = (maxPrice - quote.low) * scaleY;
      final openY = (maxPrice - quote.open) * scaleY;
      final closeY = (maxPrice - quote.close) * scaleY;

      // Determine if bullish (green) or bearish (red)
      final isBullish = quote.close >= quote.open;
      final topY = isBullish ? closeY : openY;
      final bottomY = isBullish ? openY : closeY;

      // Draw wick (high-low line)
      wickPaint.color = isBullish ? Colors.green.shade700 : Colors.red.shade700;
      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        wickPaint,
      );

      // Draw body (open-close rectangle)
      paint.color = isBullish ? Colors.green : Colors.red;
      paint.style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, (topY + bottomY) / 2),
          width: adjustedCandleWidth,
          height: (topY - bottomY).abs().clamp(1.0, double.infinity),
        ),
        paint,
      );

      // Draw body border
      paint.style = PaintingStyle.stroke;
      paint.color = isBullish ? Colors.green.shade900 : Colors.red.shade900;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, (topY + bottomY) / 2),
          width: adjustedCandleWidth,
          height: (topY - bottomY).abs().clamp(1.0, double.infinity),
        ),
        paint,
      );
    }

    // Draw SMA line if enabled
    if (showSMA && smaValues.isNotEmpty) {
      final smaPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final path = Path();
      bool isFirstPoint = true;

      for (int i = 0; i < quotes.length && i < smaValues.length; i++) {
        final sma = smaValues[i];
        if (sma != null) {
          final x = (i + 0.5) * spacing;
          final y = (maxPrice - sma) * scaleY;

          if (isFirstPoint) {
            path.moveTo(x, y);
            isFirstPoint = false;
          } else {
            path.lineTo(x, y);
          }
        }
      }

      canvas.drawPath(path, smaPaint);
    }
  }

  @override
  bool shouldRepaint(CandlestickPainter oldDelegate) {
    return oldDelegate.quotes != quotes ||
        oldDelegate.minPrice != minPrice ||
        oldDelegate.maxPrice != maxPrice ||
        oldDelegate.showSMA != showSMA ||
        oldDelegate.smaValues != smaValues;
  }
}


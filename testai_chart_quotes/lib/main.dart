import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

// Simple candle model for our chart (date + OHLC)
class Candle {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  Candle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: QuotesHomePage(),
    );
  }
}

class QuotesHomePage extends StatefulWidget {
  const QuotesHomePage({super.key});

  @override
  State<QuotesHomePage> createState() => _QuotesHomePageState();
}

class _QuotesHomePageState extends State<QuotesHomePage> {
  final TextEditingController _daysController = TextEditingController(text: "50");
  List<Candle> _candles = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Currency Quotes EUR/USD"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Days",
                      hintText: "Enter number of days",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          int days = int.tryParse(_daysController.text) ?? 50;
                          setState(() {
                            _isLoading = true;
                          });

                          try {
                            final apiKey = "demo"; // <-- SET YOUR ALPHA VANTAGE API KEY HERE
                            final url =
                                "https://www.alphavantage.co/query?function=FX_DAILY&from_symbol=EUR&to_symbol=USD&apikey=$apiKey";
                            final response = await http.get(Uri.parse(url));
                            if (response.statusCode == 200) {
                                final data = response.body;
                                // print(data);
                                final candles = _parseAlphaVantageToCandles(data, days);
                                print("PARSED ${candles.length} CANDLES:");
                                for (var c in candles) {
                                  print("Candle: date=${c.date}, o=${c.open}, h=${c.high}, l=${c.low}, c=${c.close}");
                                }
                                setState(() {
                                  _candles = candles.isEmpty ? [] : candles;
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Failed to fetch data")),
                                );
                              }
                            } catch (_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Network error")),
                              );
                            }
                            setState(() {
                              _isLoading = false;
                            });
                        },
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Refresh"),
                ),
              ],
            ),
          ),
          Expanded(
            child: _candles.isEmpty
                ? const Center(child: Text("No valid chart data available.\nTry again later or check your API key."))
                : Padding(
                  padding: const EdgeInsets.all(8),
                  child: CustomCandlesChart(candles: _candles),
                ),
          ),
        ],
      ),
    );
  }

  List<Candle> _parseAlphaVantageToCandles(String jsonString, int days) {
    try {
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(
          (jsonDecode(jsonString) as Map<dynamic, dynamic>));
      final timeSeries =
          decoded["Time Series FX (Daily)"] as Map<String, dynamic>?;
      if (timeSeries == null) return [];
      final sortedDates = timeSeries.keys.toList()
        ..sort((a, b) => b.compareTo(a)); // sort descending (newest first)
      final List<Candle> candles = [];
      for (int i = 0; i < sortedDates.length && candles.length < days; i++) {
        final dayData = timeSeries[sortedDates[i]];
        try {
          final open = double.parse(dayData["1. open"]);
          final high = double.parse(dayData["2. high"]);
          final low = double.parse(dayData["3. low"]);
          final close = double.parse(dayData["4. close"]);
          if ([open, high, low, close].any((v) => !v.isFinite)) {
            // skip broken points
            continue;
          }
          candles.add(
            Candle(
              date: DateTime.parse(sortedDates[i]),
              open: open,
              high: high,
              low: low,
              close: close,
            ),
          );
        } catch (_) {
          // skip if data missing or non-numeric
          continue;
        }
      }
      return candles.reversed.toList(); // so chart is oldest left, latest right
    } catch (_) {
      return [];
    }
  }
}

/// Cross-platform simple candlestick chart using CustomPainter.
/// Requires: List<Candle> candles, all with finite values.
class CustomCandlesChart extends StatelessWidget {
  final List<Candle> candles;
  const CustomCandlesChart({required this.candles, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final valid = candles.where((c) =>
        [c.open, c.high, c.low, c.close].every((x) => x.isFinite)).toList();
    if (valid.isEmpty) {
      return const Center(child: Text("No valid candles to display."));
    }
    // Limit to the last 40 candles for visibility
    final chartCandles = valid.length > 40 ? valid.sublist(valid.length - 40) : valid;
    return AspectRatio(
      aspectRatio: 1.7,
      child: CustomPaint(
        painter: _CustomCandlesPainter(chartCandles),
        child: Container(),
      ),
    );
  }
}

class _CustomCandlesPainter extends CustomPainter {
  final List<Candle> candles;
  _CustomCandlesPainter(this.candles);

  @override
  void paint(Canvas canvas, Size size) {
    final minPrice = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final maxPrice = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final priceRange = (maxPrice - minPrice) == 0 ? 1 : (maxPrice - minPrice);
    final candleWidth = size.width / candles.length * 0.7;
    final spacing = size.width / candles.length;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final isBull = c.close >= c.open;
      final color = isBull ? Colors.green : Colors.red;

      final double x = spacing * i + spacing / 2;
      final double yOpen  = size.height * (1 - (c.open - minPrice) / priceRange);
      final double yClose = size.height * (1 - (c.close - minPrice) / priceRange);
      final double yHigh  = size.height * (1 - (c.high - minPrice) / priceRange);
      final double yLow   = size.height * (1 - (c.low - minPrice) / priceRange);

      // Wick (high-low)
      canvas.drawLine(
          Offset(x, yHigh), Offset(x, yLow),
          Paint()
            ..color = color
            ..strokeWidth = 2);

      // Body (open-close)
      double top = yOpen;
      double bottom = yClose;
      if (yOpen > yClose) {
        top = yClose;
        bottom = yOpen;
      }
      final rect = Rect.fromLTRB(
        x - candleWidth / 2,
        top,
        x + candleWidth / 2,
        bottom == top ? bottom + 1 : bottom,
      );
      canvas.drawRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_CustomCandlesPainter oldDelegate) =>
      oldDelegate.candles != candles;
}

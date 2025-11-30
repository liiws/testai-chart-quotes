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
                  child: CandleStickChartWidget(candles: _candles),
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

/// This is a replacement for 'candlesticks' package: renders candles with fl_chart
class CandleStickChartWidget extends StatelessWidget {
  final List<dynamic> candles; // List<Candle>

  const CandleStickChartWidget({required this.candles, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) {
      return const Center(child: Text("No chart data."));
    }
    final candleData = candles;
    final visible = candleData.length > 40
        ? candleData.sublist(candleData.length - 40)
        : candleData;
    return AspectRatio(
      aspectRatio: 1.7,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: CandlestickChart(
          candles: visible,
        ),
      ),
    );
  }
}

class CandlestickChart extends StatelessWidget {
  final List<dynamic> candles;
  const CandlestickChart({required this.candles, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final minLow = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final maxHigh = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    return CandlestickChart(
      candles: List.generate(candles.length, (i) {
        final c = candles[i];
        return CandlestickChartCandleData(
          x: i,
          open: c.open,
          high: c.high,
          low: c.low,
          close: c.close,
        );
      }),
    );
  }
}

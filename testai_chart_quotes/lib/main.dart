import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:candlesticks/candlesticks.dart';

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
                  child: Builder(
                    builder: (context) {
                      // Defensive: check for all prices identical, or outliers causing bad values
                      final candles = List<Candle>.from(_candles);
                      bool allPricesSame = candles
                        .every((c) => c.open == candles[0].open && c.high == candles[0].high && c.low == candles[0].low && c.close == candles[0].close);
                      if (allPricesSame) {
                        final epsilon = 0.00001;
                        candles[0] = Candle(
                          date: candles[0].date,
                          open: candles[0].open + epsilon,
                          high: candles[0].high + epsilon,
                          low: candles[0].low + epsilon,
                          close: candles[0].close + epsilon,
                          volume: candles[0].volume,
                        );
                      }
                      final validCandles = candles.where((c) =>
                        c.open.isFinite &&
                        c.high.isFinite &&
                        c.low.isFinite &&
                        c.close.isFinite &&
                        c.open > 0 && c.high > 0 && c.low > 0 && c.close > 0
                      ).toList();
                      return validCandles.isEmpty
                        ? const Center(child: Text("No valid chart data available."))
                        : Candlesticks(
                            candles: validCandles.length > 20 ? validCandles.sublist(validCandles.length-20) : validCandles,
                          );
                    },
                  ),
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
              volume: 0,
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

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
                                final candles = _parseAlphaVantageToCandles(data, days);
                                setState(() {
                                  _candles = candles;
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
                ? const Center(child: Text("No data yet. Click Refresh to load chart."))
                : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Candlesticks(
                    candles: _candles,
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
        candles.add(
          Candle(
            date: DateTime.parse(sortedDates[i]),
            open: double.parse(dayData["1. open"]),
            high: double.parse(dayData["2. high"]),
            low: double.parse(dayData["3. low"]),
            close: double.parse(dayData["4. close"]),
            volume: 0,
          ),
        );
      }
      return candles.reversed.toList(); // so chart is oldest left, latest right
    } catch (_) {
      return [];
    }
  }
}

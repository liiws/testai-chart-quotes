import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:candlesticks/candlesticks.dart';

// Fetches candles from Alpha Vantage FX_DAILY API, returning List<Candle> from candlesticks package
Future<List<Candle>> fetchForexCandles({int days = 50}) async {
  const apiKey = 'YOUR_ALPHA_VANTAGE_API_KEY'; // Replace with your API key
  const symbolFrom = 'EUR';
  const symbolTo = 'USD';
  final url = Uri.parse(
      'https://www.alphavantage.co/query?function=FX_DAILY&from_symbol=$symbolFrom&to_symbol=$symbolTo&outputsize=compact&apikey=$apiKey');
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw Exception('Failed to load quotes');
  }
  final Map<String, dynamic> data = jsonDecode(response.body);
  final timeseries = data['Time Series FX (Daily)'];
  if (timeseries == null || timeseries is! Map) {
    throw Exception('Malformed API response');
  }

  final candles = <Candle>[];
  // Alpha Vantage returns as {newest:..., older:...}. We want ascending date.
  final sortedDates = (timeseries.keys.toList()..sort((a, b) => a.compareTo(b)));
  for (final dateStr in sortedDates.take(days)) {
    final entry = timeseries[dateStr];
    candles.add(Candle(
      date: DateTime.parse(dateStr),
      open: double.parse(entry['1. open']),
      high: double.parse(entry['2. high']),
      low: double.parse(entry['3. low']),
      close: double.parse(entry['4. close']),
      volume: 0,
    ));
  }
  return candles;
}

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  List<Candle> _candles = [];
  String _interval = "1D";
  final TextEditingController _daysController = TextEditingController(text: "50");
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _refreshQuotes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    int days = int.tryParse(_daysController.text) ?? 50;
    try {
      final candles = await fetchForexCandles(days: days);
      setState(() {
        _candles = candles;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Top bar with TextField for days and refresh button
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[200],
                child: Row(
                  children: [
                    Text(
                      "Days:",
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _daysController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _refreshQuotes,
                      child: _loading
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text("Refresh"),
                    ),
                    SizedBox(width: 24),
                    Text(
                      'Currency Quotes - EUR/USD',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text("Error: $_error", style: TextStyle(color: Colors.red)),
                ),
              Expanded(
                child: Candlesticks(
                  candles: _candles,
                  interval: _interval,
                  onIntervalChange: (String _) async { return; },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

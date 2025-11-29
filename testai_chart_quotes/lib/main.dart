import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:candlesticks/candlesticks.dart';

// Fetches candles from Alpha Vantage FX_DAILY API, returning List<Candle> from candlesticks package
Future<List<Candle>> fetchForexCandles({int days = 50}) async {
  const apiKey = 'demo'; // Replace with your API key
  const symbolFrom = 'EUR';
  const symbolTo = 'USD';
  final url = Uri.parse(
      'https://www.alphavantage.co/query?function=FX_DAILY&from_symbol=$symbolFrom&to_symbol=$symbolTo&apikey=$apiKey');
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw Exception('Failed to load quotes (status ${response.statusCode}).');
  }
  final Map<String, dynamic> data = jsonDecode(response.body);
  if (data.containsKey('Error Message') || data.containsKey('Note') || data.containsKey('Information')) {
    throw Exception((data['Error Message'] ?? data['Note'] ?? data['Information']).toString());
  }
  final timeseries = data['Time Series FX (Daily)'];
  if (timeseries == null || timeseries is! Map) {
    throw Exception('Malformed API response or invalid API key/usage.');
  }

  final List<MapEntry<String, dynamic>> sortedEntries = timeseries.entries
      .where((e) => e.value != null)
      .cast<MapEntry<String, dynamic>>()
      .toList()
      ..sort((a, b) => a.key.compareTo(b.key)); // ascending date

  final List<Candle> validCandles = [];
  for (final entry in sortedEntries) {
    try {
      final open = double.parse(entry.value['1. open']);
      final high = double.parse(entry.value['2. high']);
      final low = double.parse(entry.value['3. low']);
      final close = double.parse(entry.value['4. close']);
      if ([open, high, low, close].any((val) => val.isNaN || val.isInfinite)) continue;
      validCandles.add(Candle(
        date: DateTime.parse(entry.key),
        open: open,
        high: high,
        low: low,
        close: close,
        volume: 0,
      ));
    } catch (e) {
      continue;
    }
  }
  if (validCandles.length < days) {
    throw Exception(
        'Received only ${validCandles.length} valid data points, fewer than requested ($days). Check your API key, try fewer days, or try again later.');
  }
  // Only return the most recent N valid candles (ascending order expected by the package)
  return validCandles.sublist(validCandles.length - days);
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

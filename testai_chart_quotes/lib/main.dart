
import 'package:flutter/material.dart';
import 'package:candlesticks/candlesticks.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MainApp());
}


class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: QuotesHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class QuotesHomePage extends StatefulWidget {
  const QuotesHomePage({super.key});

  @override
  State<QuotesHomePage> createState() => _QuotesHomePageState();
}

class _QuotesHomePageState extends State<QuotesHomePage> {
  final TextEditingController _daysController = TextEditingController(text: '50');
  List<Candle> _candles = [];
  bool _loading = false;
  String? _error;

  Future<void> _fetchQuotes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final days = int.tryParse(_daysController.text) ?? 50;
    final apiKey = "demo"; // Replace with your Alpha Vantage API key
    final url = Uri.parse(
        'https://www.alphavantage.co/query?function=FX_DAILY&from_symbol=EUR&to_symbol=USD&apikey=$apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final timeSeries = data['Time Series FX (Daily)'] as Map<String, dynamic>?;
        if (timeSeries == null) {
          setState(() {
            _error = 'No data found.';
            _candles = [];
            _loading = false;
          });
          return;
        }
        final entries = timeSeries.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)); // oldest to newest
        final clampedDays = days.clamp(1, entries.length);
        final lastEntries = entries.takeLast(clampedDays).toList();
        final candles = lastEntries.map((entry) {
          final date = DateTime.parse(entry.key);
          final values = entry.value as Map<String, dynamic>;
          return Candle(
            date: date,
            open: double.parse(values['1. open']),
            high: double.parse(values['2. high']),
            low: double.parse(values['3. low']),
            close: double.parse(values['4. close']),
            volume: 0,
          );
        }).toList();
        setState(() {
          _candles = candles;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load data.';
          _candles = [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _candles = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EUR/USD Quotes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('Days:'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _fetchQuotes,
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Refresh'),
                ),
                if (_error != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]
              ],
            ),
          ),
          Expanded(
            child: _candles.isEmpty
                ? const Center(child: Text('No data.'))
                : Candlesticks(
                    candles: _candles,
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }
}

extension TakeLastExtension<E> on List<E> {
  Iterable<E> takeLast(int n) => skip(length - n < 0 ? 0 : length - n);
}

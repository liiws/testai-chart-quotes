import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
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
      home: CurrencyQuotesApp(),
    );
  }
}

class CurrencyQuotesApp extends StatefulWidget {
  const CurrencyQuotesApp({Key? key}) : super(key: key);

  @override
  State<CurrencyQuotesApp> createState() => _CurrencyQuotesAppState();
}

class _CurrencyQuotesAppState extends State<CurrencyQuotesApp> {
  final TextEditingController _daysController = TextEditingController(text: '50');
  List<CandleData> _candles = [];
  bool _loading = false;
  String? _error;

  Future<void> _fetchCandles() async {
    final days = int.tryParse(_daysController.text) ?? 50;
    setState(() {
      _loading = true;
      _candles = [];
      _error = null;
    });

    const apiKey = 'demo'; // Replace with your Alpha Vantage API Key
    final url = 'https://www.alphavantage.co/query?function=FX_DAILY&from_symbol=EUR&to_symbol=USD&apikey=$apiKey&outputsize=compact';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('Time Series FX (Daily)')) {
          final series = data['Time Series FX (Daily)'] as Map<String, dynamic>;
          final sortedDates = series.keys.toList()..sort((a, b) => b.compareTo(a));
          final candles = <CandleData>[];
          for (final date in sortedDates.take(days)) {
            final candle = series[date];
            candles.add(CandleData(
              date: DateTime.parse(date),
              open: double.parse(candle['1. open']),
              high: double.parse(candle['2. high']),
              low: double.parse(candle['3. low']),
              close: double.parse(candle['4. close']),
            ));
          }
          setState(() {
            _candles = candles.reversed.toList(); // Oldest to latest
          });
        } else if (data.containsKey('Error Message')) {
          setState(() {
            _error = data['Error Message'];
          });
        } else {
          setState(() {
            _error = 'Unexpected response format.';
          });
        }
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch data: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EUR/USD Currency Quotes')),
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
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _fetchCandles,
                  child: _loading ? const SizedBox(width:16, height:16, child:CircularProgressIndicator(strokeWidth:2)) : const Text('Refresh'),
                ),
                if (_error != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(color: Colors.red), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _candles.isEmpty
                ? const Center(child: Text('No data loaded.'))
                : SfCartesianChart(
                    primaryXAxis: DateTimeAxis(),
                    series: <CandleSeries<CandleData, DateTime>>[
                      CandleSeries<CandleData, DateTime>(
                        dataSource: _candles,
                        xValueMapper: (CandleData d, _) => d.date,
                        lowValueMapper: (CandleData d, _) => d.low,
                        highValueMapper: (CandleData d, _) => d.high,
                        openValueMapper: (CandleData d, _) => d.open,
                        closeValueMapper: (CandleData d, _) => d.close,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class CandleData {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  CandleData({required this.date, required this.open, required this.high, required this.low, required this.close});
}

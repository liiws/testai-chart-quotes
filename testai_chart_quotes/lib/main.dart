// lib/main.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_charts/charts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EUR/USD Quotes',
      home: CurrencyChartPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CandleData {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;

  CandleData(this.date, this.open, this.high, this.low, this.close);
}

class CurrencyChartPage extends StatefulWidget {
  @override
  State<CurrencyChartPage> createState() => _CurrencyChartPageState();
}

class _CurrencyChartPageState extends State<CurrencyChartPage> {
  final TextEditingController daysController = TextEditingController(text: '50');
  List<CandleData> candleData = [];
  bool loading = false;
  String? error;

  Future<void> loadQuotes() async {
    setState(() {
      loading = true;
      error = null;
    });

    final int days = int.tryParse(daysController.text) ?? 50;
    final apiKey = '<YOUR_ALPHA_VANTAGE_API_KEY>'; // <-- insert your key
    final url =
        'https://www.alphavantage.co/query?function=FX_DAILY&from_symbol=EUR&to_symbol=USD&outputsize=compact&apikey=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey("Time Series FX (Daily)")) {
          final ts = data["Time Series FX (Daily)"];
          final items = <CandleData>[];
          final sortedKeys = ts.keys.toList()..sort();
          for (var i = 0; i < days && i < sortedKeys.length; i++) {
            final dateStr = sortedKeys[sortedKeys.length - 1 - i];
            final entry = ts[dateStr];
            items.add(
              CandleData(
                DateTime.parse(dateStr),
                double.parse(entry['1. open']),
                double.parse(entry['2. high']),
                double.parse(entry['3. low']),
                double.parse(entry['4. close']),
              ),
            );
          }
          setState(() {
            candleData = items.reversed.toList();
          });
        } else {
          setState(() {
            error = 'API Error: ${data["Error Message"] ?? data.toString()}';
          });
        }
      } else {
        setState(() {
          error = 'Network error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EUR/USD Chart')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Days',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: loading ? null : loadQuotes,
                  child: loading ? const CircularProgressIndicator() : const Text('Refresh'),
                ),
                if (error != null) ...[
                  const SizedBox(width: 15),
                  Expanded(child: Text(error!, style: const TextStyle(color: Colors.red))),
                ]
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: candleData.isEmpty
                  ? const Center(child: Text('No data. Click Refresh!'))
                  : SfCartesianChart(
                      primaryXAxis: DateTimeAxis(),
                      series: <CandleSeries>[
                        CandleSeries<CandleData, DateTime>(
                          dataSource: candleData,
                          xValueMapper: (CandleData c, _) => c.date,
                          lowValueMapper: (CandleData c, _) => c.low,
                          highValueMapper: (CandleData c, _) => c.high,
                          openValueMapper: (CandleData c, _) => c.open,
                          closeValueMapper: (CandleData c, _) => c.close,
                        )
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
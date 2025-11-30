import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
      home: QuoteHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class QuoteHomePage extends StatefulWidget {
  const QuoteHomePage({Key? key}) : super(key: key);

  @override
  State<QuoteHomePage> createState() => _QuoteHomePageState();
}

class _QuoteHomePageState extends State<QuoteHomePage> {
  final TextEditingController _daysController = TextEditingController(text: '50');
  bool _loading = false;
  List<CandleStickData> _candles = [];
  String? _error;

  Future<void> _fetchQuotes() async {
    setState(() {
      _loading = true;
      _error = null;
      _candles = [];
    });
    final days = int.tryParse(_daysController.text) ?? 50;
    final apiKey = 'demo';
    if (apiKey.startsWith('<YOUR')) {
      setState(() {
        _loading = false;
        _error = 'Please set your Alpha Vantage API key in the source code.';
      });
      return;
    }
    final url =
      'https://www.alphavantage.co/query?function=FX_DAILY&from_symbol=EUR&to_symbol=USD&apikey=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('HTTP error: \\${response.statusCode}');
      }
      final data = json.decode(response.body);
      if (!data.containsKey('Time Series FX (Daily)')) {
        throw Exception(data['Error Message'] ?? data['Note'] ?? 'No prices found');
      }
      final prices = data['Time Series FX (Daily)'] as Map<String, dynamic>;
      final candles = prices.entries
          .take(days)
          .map((e) => CandleStickData.fromMap(e.key, e.value))
          .toList();
      setState(() {
        _candles = candles.reversed.toList();
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Days:'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _daysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _fetchQuotes,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  if (_loading) ...[
                    const SizedBox(width: 16),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ]
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                // Chart widget goes here
                child: _candles.isEmpty
                    ? const Center(child: Text('No data. Click refresh.'))
                    : CandleChartWidget(candles: _candles),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CandleStickData {
  final DateTime date;
  final double open, high, low, close;

  CandleStickData({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  factory CandleStickData.fromMap(String dateStr, Map map) {
    return CandleStickData(
      date: DateTime.parse(dateStr),
      open: double.parse(map['1. open']),
      high: double.parse(map['2. high']),
      low: double.parse(map['3. low']),
      close: double.parse(map['4. close']),
    );
  }
}

class CandleChartWidget extends StatelessWidget {
  final List<CandleStickData> candles;
  const CandleChartWidget({Key? key, required this.candles}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CandlestickChart(
      candles: candles,
    );
  }
}

class CandlestickChart extends StatelessWidget {
  final List<CandleStickData> candles;
  const CandlestickChart({Key? key, required this.candles}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This is a simple use of CandleStickChart from fl_chart. Expand for more axes/labels/style as needed.
    if (candles.isEmpty) {
      return const Center(child: Text('No Candle Data'));
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: CandlestickChartPainterWidget(candles: candles),
      ),
    );
  }
}

class CandlestickChartPainterWidget extends StatelessWidget {
  final List<CandleStickData> candles;
  const CandlestickChartPainterWidget({Key? key, required this.candles}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Render candlesticks using fl_chart
    // x axis: index or date; y axis: price
    final minY = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final maxY = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    return CandleStickChart(
      CandleStickChartData(
        candleData: [
          for (int i = 0; i < candles.length; i++)
            CandleStickChartItem(
              x: i.toDouble(),
              open: candles[i].open,
              high: candles[i].high,
              low: candles[i].low,
              close: candles[i].close,
            ),
        ],
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.round();
                if (idx < 0 || idx >= candles.length) return const SizedBox();
                final dt = candles[idx].date;
                // Show every 10th tick to reduce clutter
                if (idx % 10 == 0 || idx == candles.length - 1) {
                  return Text('${dt.month}/${dt.day}');
                }
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
  }
}

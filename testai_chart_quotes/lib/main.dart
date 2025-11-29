
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
      debugShowCheckedModeBanner: false,
      home: QuotesHomePage(),
    );
  }
}

class QuotesHomePage extends StatefulWidget {
  const QuotesHomePage({Key? key}) : super(key: key);

  @override
  State<QuotesHomePage> createState() => _QuotesHomePageState();
}

class _QuotesHomePageState extends State<QuotesHomePage> {
  static const String apiKey = 'YOUR_ALPHA_VANTAGE_API_KEY'; // TODO: Insert your API key here
  static const String apiBase = 'https://www.alphavantage.co/query';

  final TextEditingController _daysController = TextEditingController(text: '50');
  bool isLoading = false;
  String? errorMessage;
  List<CandleData> candles = [];

  Future<void> fetchQuotes() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      candles = [];
    });
    final int days = int.tryParse(_daysController.text) ?? 50;
    final url = Uri.parse('$apiBase?function=FX_DAILY&from_symbol=EUR&to_symbol=USD&apikey=$apiKey&outputsize=compact');
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        setState(() { errorMessage = 'HTTP error: \\${response.statusCode}'; isLoading = false; });
        return;
      }
      final data = json.decode(response.body);
      if (data['Time Series FX (Daily)'] == null) {
        setState(() { errorMessage = data['Note'] ?? data['Error Message'] ?? 'Unexpected API error.'; isLoading = false; });
        return;
      }
      final timeseries = Map<String, dynamic>.from(data['Time Series FX (Daily)']);
      final sortedDates = timeseries.keys.toList()..sort((a, b) => b.compareTo(a));
      final candlesTmp = <CandleData>[];
      for(final date in sortedDates.take(days)) {
        final q = timeseries[date];
        candlesTmp.add(
          CandleData(
            date: date,
            open: double.tryParse(q['1. open']) ?? 0,
            high: double.tryParse(q['2. high']) ?? 0,
            low: double.tryParse(q['3. low']) ?? 0,
            close: double.tryParse(q['4. close']) ?? 0,
          )
        );
      }
      setState(() { candles = candlesTmp.reversed.toList(); isLoading = false; });
    } catch (e) {
      setState(() { errorMessage = 'Failed to load data.'; isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EUR/USD Quotes (Alpha Vantage)'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Days:'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isLoading ? null : fetchQuotes,
                  child: isLoading ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Text('Refresh'),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(width: 24),
                  Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
                ],
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: candles.isEmpty
                ? const Center(child: Text('No data. Set days and click Refresh.'))
                : CandleChartWidget(candles: candles),
            ),
          ),
        ],
      ),
    );
  }
}

class CandleData {
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;

  CandleData({required this.date, required this.open, required this.high, required this.low, required this.close});
}

class CandleChartWidget extends StatelessWidget {
  final List<CandleData> candles;
  const CandleChartWidget({Key? key, required this.candles}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CandlestickChartWidget(candles: candles);
  }
}

class CandlestickChartWidget extends StatelessWidget {
  final List<CandleData> candles;
  const CandlestickChartWidget({Key? key, required this.candles}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) {
      return const Center(child: Text('No data.'));
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < candles.length && (idx % 5 == 0 || idx == candles.length - 1)) {
                    return Text(candles[idx].date.substring(5), style: const TextStyle(fontSize: 10));
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          barGroups: [
            for (int i = 0; i < candles.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: candles[i].high,
                    fromY: candles[i].low,
                    color: candles[i].close >= candles[i].open ? Colors.green : Colors.red,
                    width: 7,
                    borderRadius: BorderRadius.zero,
                    rodStackItems: [
                      BarChartRodStackItem(candles[i].open, candles[i].close, candles[i].close >= candles[i].open ? Colors.green : Colors.red),
                    ],
                  )
                ],
              ),
          ],
        ),
      ),
    );
  }
}
}

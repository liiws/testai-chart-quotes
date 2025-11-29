import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

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

enum Period { m1, m5, m30, h1, h4, d }

class _CurrencyQuotesAppState extends State<CurrencyQuotesApp> {
  final TextEditingController _daysController = TextEditingController(text: '50');
  List<CandleData> _candles = [];
  bool _loading = false;
  String? _error;
  Period _period = Period.d; // default to daily
  bool _showSMA = true;
  final TextEditingController _smaPeriodController = TextEditingController(text: '7');

  static const periodLabels = {
    Period.m1: 'M1', Period.m5: 'M5', Period.m30: 'M30', Period.h1: 'H1', Period.h4: 'H4', Period.d: 'D',
  };

  static const periodInterval = {
    Period.m1: '1min',
    Period.m5: '5min',
    Period.m30: '30min',
    Period.h1: '60min',
    Period.h4: '240min',
  };

  Future<void> _logError(String message) async {
    final logFile = File('error_log.txt');
    final now = DateTime.now().toIso8601String();
    await logFile.writeAsString('$now: $message\n', mode: FileMode.append);
  }

  Future<void> _fetchCandles() async {
    final days = int.tryParse(_daysController.text);
    if (days == null || days < 1 || days > 500) {
      setState(() {
        _error = 'Please enter a valid number of days (1-500).';
      });
      return;
    }
    setState(() {
      _loading = true;
      _candles = [];
      _error = null;
    });

    const apiKey = 'demo'; // Replace with your Alpha Vantage API Key
    String url;
    if (_period == Period.d) {
      url = 'https://www.alphavantage.co/query?function=FX_DAILY&from_symbol=EUR&to_symbol=USD&apikey=$apiKey';
    } else {
      final interval = periodInterval[_period]!;
      url = 'https://www.alphavantage.co/query?function=FX_INTRADAY&from_symbol=EUR&to_symbol=USD&interval=$interval&outputsize=full&apikey=$apiKey';
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String? seriesKey = _period == Period.d
          ? 'Time Series FX (Daily)'
          : data.keys.firstWhere((k) => k.contains('Time Series FX (Intraday)'), orElse: () => '');
        if (seriesKey != null && data.containsKey(seriesKey)) {
          final series = data[seriesKey] as Map<String, dynamic>;
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
            _candles = candles.reversed.toList();
          });
        } else if (data.containsKey('Error Message')) {
          await _logError('Error Message: ' + data['Error Message']);
          setState(() {
            _error = data['Error Message'];
          });
        } else if (data.containsKey('Note')) {
          await _logError('Note: ' + data['Note']);
          setState(() {
            _error = data['Note'];
          });
        } else if (data.containsKey('Information')) {
          await _logError('Information: ' + data['Information']);
          setState(() {
            _error = data['Information'];
          });
        } else {
          await _logError('Unexpected response: ' + response.body);
          setState(() {
            _error = 'Unexpected response format: \n' + response.body;
          });
        }
      } else {
        await _logError('HTTP error: ' + response.statusCode.toString() + ' Body: ' + response.body);
        setState(() {
          _error = 'Error:  {response.statusCode}';
        });
      }
    } catch (e) {
      await _logError('Exception: ' + e.toString());
      setState(() {
        _error = 'Failed to fetch data: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  List<_SMAData> _computeSMA(List<CandleData> candles, int period) {
    // If too short, return all as null except first period-1, which are empty
    final sma = <_SMAData>[];
    for (int i = 0; i < candles.length; i++) {
      if (i + 1 >= period) {
        double sum = 0;
        for (int j = i + 1 - period; j <= i; j++) sum += candles[j].close;
        double avg = sum / period;
        sma.add(_SMAData(date: candles[i].date, value: avg));
      } else {
        sma.add(_SMAData(date: candles[i].date, value: null));
      }
    }
    return sma;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EUR/USD Currency Quotes')),
      body: Column(
        children: [
          // Timeframe buttons bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: Period.values.map((p) {
                final selected = p == _period;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selected ? Theme.of(context).colorScheme.primary : null,
                      foregroundColor: selected ? Colors.white : null,
                      elevation: selected ? 2 : 0,
                    ),
                    onPressed: selected || _loading
                        ? null
                        : () async {
                            setState(() { _period = p; });
                            await _fetchCandles();
                          },
                    child: Text(periodLabels[p]!),
                  ),
                );
              }).toList(),
            ),
          ),
          // --- SMA controls row ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Checkbox(
                  value: _showSMA,
                  onChanged: _loading
                    ? null
                    : (val) => setState(() { _showSMA = val ?? true; }),
                ),
                const Text('Show Simple Moving Average'),
                const SizedBox(width: 16),
                const Text('Period:'),
                const SizedBox(width: 6),
                SizedBox(
                  width: 48,
                  child: TextField(
                    controller: _smaPeriodController,
                    enabled: _showSMA && !_loading,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}), // updates chart
                  ),
                ),
              ],
            ),
          ),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _candles.isEmpty
                    ? const Center(child: Text('No data loaded.'))
                    : SfCartesianChart(
                        primaryXAxis: DateTimeAxis(),
                        series: <CartesianSeries<dynamic, DateTime>>[
                          CandleSeries<CandleData, DateTime>(
                            dataSource: _candles,
                            xValueMapper: (CandleData d, _) => d.date,
                            lowValueMapper: (CandleData d, _) => d.low,
                            highValueMapper: (CandleData d, _) => d.high,
                            openValueMapper: (CandleData d, _) => d.open,
                            closeValueMapper: (CandleData d, _) => d.close,
                          ),
                          if (_showSMA)
                            ...(() {
                              int period = int.tryParse(_smaPeriodController.text) ?? 7;
                              if (period < 1) period = 1;
                              if (period > _candles.length) period = _candles.length;
                              final smaData = _computeSMA(_candles, period)
                                  .where((d) => d.value != null).toList();
                              return [
                                LineSeries<_SMAData, DateTime>(
                                  dataSource: smaData,
                                  xValueMapper: (d, _) => d.date,
                                  yValueMapper: (d, _) => d.value,
                                  color: Colors.blue,
                                  width: 2,
                                  name: 'SMA ($period)',
                                )
                              ];
                            })(),
                        ],
                        legend: Legend(isVisible: _showSMA),
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

// Helper for SMA
class _SMAData {
  final DateTime date;
  final double? value;
  _SMAData({required this.date, required this.value});
}

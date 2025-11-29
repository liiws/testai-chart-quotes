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

enum Timeframe { m1, m5, m30, h1, h4, d }

class _CurrencyQuotesAppState extends State<CurrencyQuotesApp> {
      bool _showSMA = true;
      final TextEditingController _smaPeriodController = TextEditingController(text: '7');
      String? _smaPeriodError;

      int get _smaPeriod {
        final v = int.tryParse(_smaPeriodController.text);
        return (v != null && v > 0) ? v : 7;
      }

      void _validateSmaPeriod() {
        final text = _smaPeriodController.text;
        if (text.isEmpty) {
          setState(() => _smaPeriodError = 'Enter period');
        } else {
          final value = int.tryParse(text);
          if (value == null || value <= 0) {
            setState(() => _smaPeriodError = 'Enter a positive integer');
          } else {
            setState(() => _smaPeriodError = null);
          }
        }
      }

      List<SmaData> _calculateSMA(List<CandleData> candles, int period) {
        if (candles.length < period) return [];
        final List<SmaData> sma = [];
        for (int i = period - 1; i < candles.length; i++) {
          final window = candles.sublist(i - period + 1, i + 1);
          final avg = window.map((c) => c.close).reduce((a, b) => a + b) / period;
          sma.add(SmaData(date: candles[i].date, value: avg));
        }
        return sma;
      }
    String _tfLabel(Timeframe tf) {
      switch (tf) {
        case Timeframe.m1:
          return 'M1';
        case Timeframe.m5:
          return 'M5';
        case Timeframe.m30:
          return 'M30';
        case Timeframe.h1:
          return 'H1';
        case Timeframe.h4:
          return 'H4';
        case Timeframe.d:
          return 'D';
      }
    }
  Timeframe _currentTimeframe = Timeframe.d;
  String? _daysError;

  bool get _isDaysValid {
    final text = _daysController.text;
    if (text.isEmpty) return false;
    final value = int.tryParse(text);
    return value != null && value > 0 && value <= 5000;
  }

  void _validateDays() {
    final text = _daysController.text;
    if (text.isEmpty) {
      setState(() => _daysError = 'Enter number of days');
    } else {
      final value = int.tryParse(text);
      if (value == null || value <= 0) {
        setState(() => _daysError = 'Enter a positive integer');
      } else if (value > 5000) {
        setState(() => _daysError = 'Maximum is 5000');
      } else {
        setState(() => _daysError = null);
      }
    }
  }

    Future<void> _logError(String message) async {
      final now = DateTime.now().toIso8601String();
      final logLine = '[$now] $message\n';
      try {
        final file = File('error_log.txt');
        await file.writeAsString(logLine, mode: FileMode.append, flush: true);
      } catch (e) {
        // Ignore logging errors
      }
    }
  final TextEditingController _daysController = TextEditingController(text: '50');
  List<CandleData> _candles = [];
  bool _loading = false;
  String? _error;

  Future<void> _fetchCandles({Timeframe? tf}) async {
    final days = int.tryParse(_daysController.text) ?? 50;
    final timeframe = tf ?? _currentTimeframe;
    setState(() {
      _loading = true;
      _candles = [];
      _error = null;
      if (tf != null) _currentTimeframe = tf;
    });

    const apiKey = 'demo'; // Replace with your Alpha Vantage API Key
    String url;
    String? timeSeriesKey;
    String? interval;
    switch (timeframe) {
      case Timeframe.m1:
        interval = '1min';
        break;
      case Timeframe.m5:
        interval = '5min';
        break;
      case Timeframe.m30:
        interval = '30min';
        break;
      case Timeframe.h1:
        interval = '60min';
        break;
      case Timeframe.h4:
        interval = '60min'; // Will group by 4h later
        break;
      case Timeframe.d:
        interval = null;
        break;
    }
    if (interval != null) {
      url = 'https://www.alphavantage.co/query?function=FX_INTRADAY&from_symbol=EUR&to_symbol=USD&interval=$interval&apikey=$apiKey';
      timeSeriesKey = 'Time Series FX ($interval)';
    } else {
      url = 'https://www.alphavantage.co/query?function=FX_DAILY&from_symbol=EUR&to_symbol=USD&apikey=$apiKey';
      timeSeriesKey = 'Time Series FX (Daily)';
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey(timeSeriesKey)) {
          final series = data[timeSeriesKey] as Map<String, dynamic>;
          final sortedDates = series.keys.toList()..sort((a, b) => b.compareTo(a));
          List<CandleData> candles = [];
          if (timeframe == Timeframe.h4) {
            // Group 60min candles into 4h candles
            final grouped = <DateTime, List<Map<String, dynamic>>>{};
            for (final dateStr in sortedDates.take(days * 4)) {
              final dt = DateTime.parse(dateStr);
              final groupKey = DateTime(dt.year, dt.month, dt.day, (dt.hour ~/ 4) * 4);
              grouped.putIfAbsent(groupKey, () => []).add(series[dateStr]);
            }
            final groupedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
            for (final key in groupedKeys.take(days)) {
              final group = grouped[key]!;
              try {
                final opens = group.map((e) => double.parse(e['1. open'])).toList();
                final highs = group.map((e) => double.parse(e['2. high'])).toList();
                final lows = group.map((e) => double.parse(e['3. low'])).toList();
                final closes = group.map((e) => double.parse(e['4. close'])).toList();
                candles.add(CandleData(
                  date: key,
                  open: opens.first,
                  high: highs.reduce((a, b) => a > b ? a : b),
                  low: lows.reduce((a, b) => a < b ? a : b),
                  close: closes.last,
                ));
              } catch (e) {
                await _logError('Parse error for 4h group $key: $e, data: $group');
              }
            }
            candles = candles.reversed.toList();
          } else {
            for (final date in sortedDates.take(days)) {
              try {
                final candle = series[date];
                candles.add(CandleData(
                  date: DateTime.parse(date),
                  open: double.parse(candle['1. open']),
                  high: double.parse(candle['2. high']),
                  low: double.parse(candle['3. low']),
                  close: double.parse(candle['4. close']),
                ));
              } catch (e) {
                await _logError('Parse error for date $date: $e, data: ${series[date]}');
              }
            }
            candles = candles.reversed.toList();
          }
          setState(() {
            _candles = candles;
          });
        } else if (data.containsKey('Error Message')) {
          await _logError('API Error Message: ${data['Error Message']}');
          setState(() {
            _error = data['Error Message'];
          });
        } else if (data.containsKey('Note')) {
          await _logError('API Note: ${data['Note']}');
          setState(() {
            _error = data['Note'];
          });
        } else if (data.containsKey('Information')) {
          await _logError('API Information: ${data['Information']}');
          setState(() {
            _error = data['Information'];
          });
        } else {
          await _logError('Unexpected response format: ${response.body}');
          setState(() {
            _error = 'Unexpected response format: \n${response.body}';
          });
        }
      } else {
        await _logError('HTTP error: ${response.statusCode}, body: ${response.body}');
        setState(() {
          _error = 'Error: ${response.statusCode}';
        });
      }
    } catch (e, st) {
      await _logError('Exception: $e\nStack: $st');
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
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                // Timeframe buttons
                for (final tf in Timeframe.values) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentTimeframe == tf ? Theme.of(context).colorScheme.primary : Colors.grey[300],
                        foregroundColor: _currentTimeframe == tf ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: _loading || _currentTimeframe == tf ? null : () => _fetchCandles(tf: tf),
                      child: Text(_tfLabel(tf)),
                    ),
                  ),
                ],
                const SizedBox(width: 16),
                // SMA Checkbox and Period
                Row(
                  children: [
                    Checkbox(
                      value: _showSMA,
                      onChanged: (v) {
                        setState(() => _showSMA = v ?? true);
                      },
                    ),
                    const Text('Show Simple Moving Average'),
                    const SizedBox(width: 8),
                    const Text('Period:'),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: _smaPeriodController,
                        enabled: _showSMA,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          errorText: _smaPeriodError,
                          isDense: true,
                        ),
                        onChanged: (_) => _validateSmaPeriod(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                const Text('Days:'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      errorText: _daysError,
                      isDense: true,
                    ),
                    onChanged: (_) => _validateDays(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading || !_isDaysValid ? null : () => _fetchCandles(),
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
            child: Stack(
              children: [
                _candles.isEmpty
                    ? const Center(child: Text('No data loaded.'))
                    : SfCartesianChart(
                        primaryXAxis: DateTimeAxis(),
                        series: <ChartSeries<dynamic, DateTime>>[
                          CandleSeries<CandleData, DateTime>(
                            dataSource: _candles,
                            xValueMapper: (CandleData d, _) => d.date,
                            lowValueMapper: (CandleData d, _) => d.low,
                            highValueMapper: (CandleData d, _) => d.high,
                            openValueMapper: (CandleData d, _) => d.open,
                            closeValueMapper: (CandleData d, _) => d.close,
                          ),
                          if (_showSMA && _smaPeriodError == null && _candles.length >= _smaPeriod)
                            LineSeries<SmaData, DateTime>(
                              dataSource: _calculateSMA(_candles, _smaPeriod),
                              xValueMapper: (SmaData d, _) => d.date,
                              yValueMapper: (SmaData d, _) => d.value,
                              color: Colors.orange,
                              width: 2,
                              name: 'SMA',
                            ),
                        ],
                      ),
                if (_loading)
                  Container(
                    color: Colors.black.withOpacity(0.2),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
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

class SmaData {
  final DateTime date;
  final double value;
  SmaData({required this.date, required this.value});
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';

class CandleData {
  final DateTime date;
  final double high;
  final double low;
  final double open;
  final double close;

  CandleData({
    required this.date,
    required this.high,
    required this.low,
    required this.open,
    required this.close,
  });
}

Future<void> _log(String message) async {
  try {
    final logDir = Directory('logs');
    await logDir.create(recursive: true);
    final logFile = File('${logDir.path}/app.log');
    final timestamp = DateTime.now().toIso8601String();
    await logFile.writeAsString(
      '$timestamp: $message\n',
      mode: FileMode.append,
    );
  } catch (e) {
    debugPrint('Logger failed: $e');
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _daysController = TextEditingController(
    text: '50',
  );
  List<CandleData> _candles = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await _log('Refresh started with days: ${_daysController.text}');

    setState(() {
      _isLoading = true;
      _candles = [];
    });

    try {
      final days = int.tryParse(_daysController.text)!;

      // Replace 'demo' with your Alpha Vantage API key
      final response = await http
          .get(
            Uri.parse(
              'https://www.alphavantage.co/query?function=FX_DAILY&from_symbol=EUR&to_symbol=USD&apikey=demo',
            ),
          )
          .timeout(const Duration(seconds: 30));

      await _log('API response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['Error Message'] != null) {
        throw Exception('API Error: ${data['Error Message']}');
      }
      if (data['Note'] != null) {
        throw Exception('API Note: ${data['Note']}');
      }

      final timeSeries =
          data['Time Series FX (Daily)'] as Map<String, dynamic>?;

      if (timeSeries == null || timeSeries.isEmpty) {
        throw Exception('No time series data found');
      }

      final List<CandleData> candles = [];
      final entries = timeSeries.entries.take(days);
      for (final entry in entries) {
        try {
          final values = entry.value as Map<String, dynamic>;
          final date = DateTime.parse(entry.key);
          candles.add(
            CandleData(
              date: date,
              open: double.parse(values['1. open']!),
              high: double.parse(values['2. high']!),
              low: double.parse(values['3. low']!),
              close: double.parse(values['4. close']!),
            ),
          );
        } catch (parseErr) {
          await _log('Parse error for ${entry.key}: $parseErr');
        }
      }
      candles.sort((a, b) => a.date.compareTo(b.date));
      await _log('Loaded ${candles.length} candles');
      setState(() {
        _candles = candles;
      });
    } catch (e) {
      final errorMsg = e.toString();
      await _log('Refresh error: $errorMsg');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Currency Quotes',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(title: const Text('EUR/USD Quotes')),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _daysController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Days',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return 'Enter number of days';
                              final days = int.tryParse(value);
                              if (days == null) return 'Invalid number';
                              if (days < 1 || days > 365)
                                return 'Days must be 1-365';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    _refresh();
                                  }
                                },
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _candles.isEmpty && !_isLoading
                      ? const Center(
                          child: Text('Press Refresh to load EUR/USD data'),
                        )
                      : SfCartesianChart(
                          trackballBehavior: TrackballBehavior(
                            enable: true,
                            activationMode: ActivationMode.singleTap,
                          ),
                          primaryXAxis: DateTimeAxis(),
                          series: <CandleSeries<CandleData, DateTime>>[
                            CandleSeries<CandleData, DateTime>(
                              dataSource: _candles,
                              xValueMapper: (CandleData data, _) => data.date,
                              highValueMapper: (CandleData data, _) =>
                                  data.high,
                              lowValueMapper: (CandleData data, _) => data.low,
                              openValueMapper: (CandleData data, _) =>
                                  data.open,
                              closeValueMapper: (CandleData data, _) =>
                                  data.close,
                            ),
                          ],
                        ),
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading EUR/USD data...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(const MainApp());
}

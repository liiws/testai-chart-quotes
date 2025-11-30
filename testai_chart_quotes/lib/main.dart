import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Simple candle model for our chart (date + OHLC)
class Candle {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  Candle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: QuotesHomePage(),
    );
  }
}

class QuotesHomePage extends StatefulWidget {
  const QuotesHomePage({super.key});

  @override
  State<QuotesHomePage> createState() => _QuotesHomePageState();
}

class _QuotesHomePageState extends State<QuotesHomePage> {
  final TextEditingController _daysController = TextEditingController(text: "50");
  List<Candle> _candles = [];
  bool _isLoading = false;

  // --- SMA state ---
  bool _smaEnabled = true;
  final TextEditingController _smaPeriodController = TextEditingController(text: "7");

  // timeframes: id as AlphaVantage param, txt as button label, avFn as the query function
  static const _timeframeButtons = [
    {"id": "M1", "txt": "M1"},
    {"id": "M5", "txt": "M5"},
    {"id": "M30", "txt": "M30"},
    {"id": "H1", "txt": "H1"},
    {"id": "H4", "txt": "H4"},
    {"id": "D", "txt": "D"},
  ];

  String _currentTf = "D";

  void _onTimeframePressed(String tf) async {
    setState(() => _currentTf = tf);
    String input = _daysController.text.trim();
    int? days = int.tryParse(input);
    if (days == null || days < 1 || days > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid number of days (1-200).")),
      );
      return;
    }
    await _loadQuotes(days, tf);
  }

  Future<void> _loadQuotes(int days, String tf) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiKey = "demo"; // <-- SET YOUR ALPHA VANTAGE API KEY HERE
      final url = _alphaVantageUrl(tf, apiKey);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = response.body;
        try {
          final candles = _parseAlphaVantageToCandles(data, days, tf);
          print("PARSED ${candles.length} CANDLES:");
          for (var c in candles) {
            print("Candle: date=${c.date}, o=${c.open}, h=${c.high}, l=${c.low}, c=${c.close}");
          }
          setState(() {
            _candles = candles.isEmpty ? [] : candles;
          });
        } catch (e, st) {
          await logError("Parse error: $e\n$st\n$data");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error parsing quotes data.")),
          );
        }
      } else {
        final errorMsg = "HTTP error: ${response.statusCode}\n${response.body}";
        await logError(errorMsg);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch data (network error).")),
        );
      }
    } catch (e, st) {
      await logError("Exception: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network or logic error (see log.txt)")),
      );
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Currency Quotes EUR/USD"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                for (final tf in _timeframeButtons)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: OutlinedButton(
                      onPressed: _isLoading || _currentTf == tf['id'] ? null : () => _onTimeframePressed(tf['id']!),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _currentTf == tf['id'] ? Colors.blue : null,
                        foregroundColor: _currentTf == tf['id'] ? Colors.white : null,
                      ),
                      child: Text(tf['txt']!),
                    ),
                  ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _smaEnabled,
                      onChanged: _isLoading
                          ? null
                          : (val) {
                              setState(() {
                                _smaEnabled = val ?? false;
                              });
                            },
                    ),
                    const Text("Show Simple Moving Average"),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 54,
                      child: TextField(
                        controller: _smaPeriodController,
                        keyboardType: TextInputType.number,
                        enabled: !_isLoading && _smaEnabled,
                        decoration: const InputDecoration(
                          labelText: "Period",
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        ),
                        onChanged: (_) => setState((){}),
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Days input
                    SizedBox(
                      width: 65,
                      child: TextField(
                        controller: _daysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Days",
                          hintText: "Enter days",
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          String input = _daysController.text.trim();
                          int? days = int.tryParse(input);
                          if (days == null || days < 1 || days > 200) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Enter a valid number of days (1-200)."),
                              ),
                            );
                            return;
                          }
                          await _loadQuotes(days, _currentTf);
                        },
                  child: _isLoading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            const Text("Loading..."),
                          ],
                        )
                      : const Text("Refresh"),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                _candles.isEmpty
                    ? const Center(child: Text("No valid chart data available.\nTry again later or check your API key."))
                    : Padding(
                        padding: const EdgeInsets.all(8),
                        child: CustomCandlesChart(
                          candles: _candles,
                          smaEnabled: _smaEnabled,
                          smaPeriod: int.tryParse(_smaPeriodController.text) ?? 7,
                        ),
                      ),
                if (_isLoading)
                  Container(
                    color: Colors.white54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Candle> _parseAlphaVantageToCandles(String jsonString, int days, String tf) {
    try {
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(
          (jsonDecode(jsonString) as Map<dynamic, dynamic>));
      String k;
      if (tf == "D") {
        k = "Time Series FX (Daily)";
      } else if (tf == "H4" || tf == "H1" || tf == "M30" || tf == "M5" || tf == "M1") {
        k = "Time Series FX (${_tfAlphaVantage(tf)})";
      } else {
        k = "Time Series FX (Daily)";
      }
      final timeSeries =
          decoded[k] as Map<String, dynamic>?;
      if (timeSeries == null) return [];
      final sortedDates = timeSeries.keys.toList()
        ..sort((a, b) => b.compareTo(a)); // sort descending (newest first)
      final List<Candle> candles = [];
      for (int i = 0; i < sortedDates.length && candles.length < days; i++) {
        final item = timeSeries[sortedDates[i]];
        try {
          final open = double.parse(item["1. open"]);
          final high = double.parse(item["2. high"]);
          final low = double.parse(item["3. low"]);
          final close = double.parse(item["4. close"]);
          if ([open, high, low, close].any((v) => !v.isFinite)) {
            continue;
          }
          candles.add(
            Candle(
              date: DateTime.parse(sortedDates[i]),
              open: open,
              high: high,
              low: low,
              close: close,
            ),
          );
        } catch (_) {
          continue;
        }
      }
      return candles.reversed.toList();
    } catch (_) {
      return [];
    }
  }

  String _alphaVantageUrl(String tf, String apiKey) {
    if (tf == "D") {
      return "https://www.alphavantage.co/query?function=FX_DAILY&from_symbol=EUR&to_symbol=USD&apikey=$apiKey";
    } else {
      // intraday: 1min, 5min, 30min, 60min ("M1","M5","M30","H1") => requires FX_INTRADAY API
      final interval = _tfAlphaVantage(tf);
      return "https://www.alphavantage.co/query?function=FX_INTRADAY&from_symbol=EUR&to_symbol=USD&interval=$interval&apikey=$apiKey";
    }
  }

  String _tfAlphaVantage(String tf) {
    switch (tf) {
      case "M1":
        return "1min";
      case "M5":
        return "5min";
      case "M30":
        return "30min";
      case "H1":
        return "60min";
      case "H4":
        return "4min"; // not officially supported, can fallback to "60min"
      default:
        return "1min";
    }
  }
}

Future<void> logError(String message) async {
  try {
    final now = DateTime.now().toIso8601String();
    final Directory dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'log.txt'));
    await file.writeAsString(
      "[$now] $message\n",
      mode: FileMode.append,
      flush: true,
    );
  } catch (e) {
    // ignore log errors to avoid recursion
  }
}
 
/// Cross-platform simple candlestick chart using CustomPainter.
/// Requires: List<Candle> candles, all with finite values.
class CustomCandlesChart extends StatelessWidget {
  final List<Candle> candles;
  final bool smaEnabled;
  final int smaPeriod;
  const CustomCandlesChart({
    required this.candles,
    this.smaEnabled = false,
    this.smaPeriod = 7,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final valid = candles.where((c) =>
        [c.open, c.high, c.low, c.close].every((x) => x.isFinite)).toList();
    if (valid.isEmpty) {
      return const Center(child: Text("No valid candles to display."));
    }
    // Limit to the last 40 candles for visibility
    final chartCandles = valid.length > 40 ? valid.sublist(valid.length - 40) : valid;
    final List<SmaDot>? smaDots;
    if (smaEnabled && smaPeriod > 1 && chartCandles.length >= smaPeriod) {
      smaDots = _calcSma(chartCandles, smaPeriod);
    } else {
      smaDots = null;
    }
    return AspectRatio(
      aspectRatio: 1.7,
      child: CustomPaint(
        painter: _CustomCandlesPainter(chartCandles, smaDots: smaDots),
        child: Container(),
      ),
    );
  }
}

// Utility class and function for SMA line
class SmaDot {
  final double x, y;
  SmaDot(this.x, this.y);
}

List<SmaDot> _calcSma(List<Candle> candles, int period) {
  if (candles.length < period) return [];
  final closes = candles.map((c) => c.close).toList();
  final minPrice = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
  final maxPrice = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
  final priceRange = (maxPrice - minPrice) == 0 ? 1 : (maxPrice - minPrice);

  List<SmaDot> dots = [];
  for (int i = period - 1; i < closes.length; i++) {
    double sum = 0;
    for (int j = 0; j < period; j++) {
      sum += closes[i - j];
    }
    double sma = sum / period;
    final idx = i;
    dots.add(SmaDot(
      idx.toDouble(),
      (1 - (sma - minPrice) / priceRange),
    ));
  }
  return dots;
}

class _CustomCandlesPainter extends CustomPainter {
  final List<Candle> candles;
  final List<SmaDot>? smaDots;

  _CustomCandlesPainter(this.candles, {this.smaDots});

  @override
  void paint(Canvas canvas, Size size) {
    final minPrice = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final maxPrice = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final priceRange = (maxPrice - minPrice) == 0 ? 1 : (maxPrice - minPrice);
    final candleWidth = size.width / candles.length * 0.7;
    final spacing = size.width / candles.length;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final isBull = c.close >= c.open;
      final color = isBull ? Colors.green : Colors.red;

      final double x = spacing * i + spacing / 2;
      final double yOpen  = size.height * (1 - (c.open - minPrice) / priceRange);
      final double yClose = size.height * (1 - (c.close - minPrice) / priceRange);
      final double yHigh  = size.height * (1 - (c.high - minPrice) / priceRange);
      final double yLow   = size.height * (1 - (c.low - minPrice) / priceRange);

      // Wick (high-low)
      canvas.drawLine(
          Offset(x, yHigh), Offset(x, yLow),
          Paint()
            ..color = color
            ..strokeWidth = 2);

      // Body (open-close)
      double top = yOpen;
      double bottom = yClose;
      if (yOpen > yClose) {
        top = yClose;
        bottom = yOpen;
      }
      final rect = Rect.fromLTRB(
        x - candleWidth / 2,
        top,
        x + candleWidth / 2,
        bottom == top ? bottom + 1 : bottom,
      );
      canvas.drawRect(rect, Paint()..color = color);
    }

    // Draw SMA line if present
    if (smaDots != null && smaDots!.length > 1) {
      final smaPaint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 2;
      final xscale = size.width / candles.length;
      for (int i = 1; i < smaDots!.length; i++) {
        final prev = smaDots![i - 1];
        final next = smaDots![i];
        final p1 = Offset(
          xscale * (prev.x + 0.5),
          size.height * prev.y
        );
        final p2 = Offset(
          xscale * (next.x + 0.5),
          size.height * next.y
        );
        canvas.drawLine(p1, p2, smaPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_CustomCandlesPainter oldDelegate) =>
      oldDelegate.candles != candles ||
      oldDelegate.smaDots != smaDots;
}

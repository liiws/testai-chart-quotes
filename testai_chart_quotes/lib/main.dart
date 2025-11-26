import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'models/quote.dart';
import 'services/alpha_vantage_service.dart';
import 'services/logger_service.dart';
import 'widgets/candlestick_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logger
  final logger = LoggerService();
  await logger.initialize();
  
  // Handle Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) async {
    await logger.error(
      'Flutter error: ${details.exception}',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };

  // Handle platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error('Platform error', error, stack).catchError((e) {
      // If logging fails, at least print it
      print('Failed to log platform error: $e');
    });
    return true;
  };

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Currency Quotes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const QuotesPage(),
    );
  }
}

class QuotesPage extends StatefulWidget {
  const QuotesPage({super.key});

  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> {
  final TextEditingController _daysController = TextEditingController(text: '50');
  final AlphaVantageService _apiService = AlphaVantageService();
  final LoggerService _logger = LoggerService();
  List<Quote> _quotes = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _logger.info('QuotesPage initialized');
  }

  @override
  void dispose() {
    _daysController.dispose();
    _logger.info('QuotesPage disposed');
    super.dispose();
  }

  Future<void> _loadQuotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final daysText = _daysController.text.trim();
      await _logger.debug('User requested quotes for: $daysText days');

      if (daysText.isEmpty) {
        throw ArgumentError('Days field cannot be empty');
      }

      final days = int.tryParse(daysText);
      if (days == null) {
        throw FormatException('Invalid number format: $daysText');
      }

      if (days <= 0) {
        throw ArgumentError('Days must be greater than 0, got: $days');
      }

      if (days > 500) {
        throw ArgumentError('Days cannot exceed 500, got: $days');
      }

      await _logger.info('Loading $days days of EUR/USD quotes');

      final quotes = await _apiService.fetchEURUSDQuotes(days);
      
      if (quotes.isEmpty) {
        await _logger.warning('API returned empty quotes list');
        throw Exception('No quotes data available');
      }

      await _logger.info('Successfully loaded ${quotes.length} quotes');
      
      setState(() {
        _quotes = quotes;
        _isLoading = false;
        _errorMessage = null;
      });
    } on ArgumentError catch (e, stackTrace) {
      await _logger.error('Invalid input argument', e, stackTrace);
      _handleError('Invalid input: ${e.message}');
    } on FormatException catch (e, stackTrace) {
      await _logger.error('Format error', e, stackTrace);
      _handleError('Invalid number format. Please enter a valid number.');
    } catch (e, stackTrace) {
      await _logger.error('Error loading quotes', e, stackTrace);
      _handleError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _handleError(String errorMessage) {
    setState(() {
      _errorMessage = errorMessage;
      _isLoading = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top controls
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text(
                  'Days:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadQuotes,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isLoading ? 'Loading...' : 'Refresh'),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Chart area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : CandlestickChart(quotes: _quotes),
            ),
          ),
        ],
      ),
    );
  }
}

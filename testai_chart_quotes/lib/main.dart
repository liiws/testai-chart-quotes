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
  String? _daysValidationError;
  Timeframe _currentTimeframe = Timeframe.d; // Default to Daily

  @override
  void initState() {
    super.initState();
    _logger.info('QuotesPage initialized');
    _daysController.addListener(_validateDays);
    _validateDays(); // Validate initial value
  }

  @override
  void dispose() {
    _daysController.removeListener(_validateDays);
    _daysController.dispose();
    _logger.info('QuotesPage disposed');
    super.dispose();
  }

  void _validateDays() {
    final daysText = _daysController.text.trim();
    String? error;

    if (daysText.isEmpty) {
      error = 'Days field cannot be empty';
    } else {
      final days = int.tryParse(daysText);
      if (days == null) {
        error = 'Please enter a valid number';
      } else if (days <= 0) {
        error = 'Days must be greater than 0';
      } else if (days > 500) {
        error = 'Days cannot exceed 500';
      }
    }

    if (_daysValidationError != error) {
      setState(() {
        _daysValidationError = error;
      });
    }
  }

  bool get _isDaysInputValid {
    return _daysValidationError == null;
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

      await _logger.info('Loading $days days of EUR/USD quotes with timeframe ${_currentTimeframe.name}');

      final quotes = await _apiService.fetchEURUSDQuotes(days, timeframe: _currentTimeframe);
      
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

  void _onTimeframeChanged(Timeframe timeframe) {
    if (timeframe != _currentTimeframe) {
      setState(() {
        _currentTimeframe = timeframe;
      });
      // Automatically load quotes for the new timeframe
      _loadQuotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Timeframe buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeframeButton('M1', Timeframe.m1),
                const SizedBox(width: 8),
                _buildTimeframeButton('M5', Timeframe.m5),
                const SizedBox(width: 8),
                _buildTimeframeButton('M30', Timeframe.m30),
                const SizedBox(width: 8),
                _buildTimeframeButton('H1', Timeframe.h1),
                const SizedBox(width: 8),
                _buildTimeframeButton('H4', Timeframe.h4),
                const SizedBox(width: 8),
                _buildTimeframeButton('D', Timeframe.d),
              ],
            ),
          ),
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
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3), // Max 3 digits (500 max)
                    ],
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red.shade700),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red.shade700, width: 2),
                      ),
                      errorText: _daysValidationError,
                      errorMaxLines: 2,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      helperText: 'Range: 1-500',
                      helperMaxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: (_isLoading || !_isDaysInputValid) ? null : _loadQuotes,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading quotes...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : CandlestickChart(quotes: _quotes),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeButton(String label, Timeframe timeframe) {
    final isSelected = _currentTimeframe == timeframe;
    return ElevatedButton(
      onPressed: _isLoading ? null : () => _onTimeframeChanged(timeframe),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        foregroundColor: isSelected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(50, 36),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

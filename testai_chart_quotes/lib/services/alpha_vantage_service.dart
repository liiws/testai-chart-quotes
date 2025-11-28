import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quote.dart';
import 'logger_service.dart';

enum Timeframe {
  m1('1min', 'FX_INTRADAY', 'Time Series FX (1min)'),
  m5('5min', 'FX_INTRADAY', 'Time Series FX (5min)'),
  m30('30min', 'FX_INTRADAY', 'Time Series FX (30min)'),
  h1('60min', 'FX_INTRADAY', 'Time Series FX (60min)'),
  h4('30min', 'FX_INTRADAY', 'Time Series FX (30min)'), // Use 30min and aggregate to 4h
  d('', 'FX_DAILY', 'Time Series FX (Daily)');

  final String interval;
  final String function;
  final String timeSeriesKey;

  const Timeframe(this.interval, this.function, this.timeSeriesKey);
}

class AlphaVantageService {
  // IMPORTANT: Replace 'demo' with your own free API key from https://www.alphavantage.co/support/#api-key
  // The demo key has very limited rate limits. Get your free key to avoid rate limit errors.
  static const String _apiKey = 'demo';
  static const String _baseUrl = 'https://www.alphavantage.co/query';
  final LoggerService _logger = LoggerService();

  Future<List<Quote>> fetchEURUSDQuotes(int days, {Timeframe timeframe = Timeframe.d}) async {
    final startTime = DateTime.now();
    
    try {
      // Validate input
      if (days <= 0) {
        throw ArgumentError('Days must be greater than 0, got: $days');
      }
      if (days > 500) {
        throw ArgumentError('Days cannot exceed 500, got: $days');
      }

      await _logger.info('Fetching EUR/USD quotes for $days days with timeframe ${timeframe.name}');

      String urlString;
      List<String> intervalsToTry = [];
      
      if (timeframe == Timeframe.d) {
        // Daily timeframe
        urlString = '$_baseUrl?function=${timeframe.function}&from_symbol=EUR&to_symbol=USD&apikey=$_apiKey';
      } else if (timeframe == Timeframe.h4) {
        // For H4, try multiple intervals as fallback
        intervalsToTry = ['5min', '15min', '30min', '60min'];
        urlString = '$_baseUrl?function=FX_INTRADAY&from_symbol=EUR&to_symbol=USD&interval=${intervalsToTry[2]}&apikey=$_apiKey';
      } else {
        // Intraday timeframe
        urlString = '$_baseUrl?function=${timeframe.function}&from_symbol=EUR&to_symbol=USD&interval=${timeframe.interval}&apikey=$_apiKey';
      }

      final url = Uri.parse(urlString);

      await _logger.debug('API Request URL: ${url.toString().replaceAll(_apiKey, '***')}');

      http.Response response;
      try {
        response = await http.get(url).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Request timeout after 30 seconds');
          },
        );
      } catch (e, stackTrace) {
        await _logger.error(
          'Network error while fetching quotes',
          e,
          stackTrace,
        );
        rethrow;
      }

      await _logger.debug('API Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorMsg = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        await _logger.error(
          'API request failed',
          Exception(errorMsg),
        );
        throw Exception('Failed to load quotes: HTTP ${response.statusCode}');
      }

      if (response.body.isEmpty) {
        await _logger.error('API returned empty response body');
        throw Exception('API returned empty response');
      }

      Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (e, stackTrace) {
        await _logger.error(
          'Failed to parse JSON response',
          e,
          stackTrace,
        );
        throw Exception('Invalid JSON response from API: $e');
      }

      // Check for API errors
      if (data.containsKey('Error Message')) {
        final errorMsg = data['Error Message'] as String;
        await _logger.error('API Error Message: $errorMsg');
        throw Exception('API Error: $errorMsg');
      }

      if (data.containsKey('Note')) {
        final note = data['Note'] as String;
        await _logger.warning('API Note: $note');
        throw Exception('API Rate Limit: $note');
      }

      // Check for Information key (often contains error messages)
      if (data.containsKey('Information')) {
        final info = data['Information'] as String;
        await _logger.error('API Information: $info');
        
        // For H4, try different intervals as fallback
        if (timeframe == Timeframe.h4 && intervalsToTry.isNotEmpty) {
          await _logger.info('H4 with 30min not available, trying alternative intervals');
          
          for (final interval in intervalsToTry) {
            if (interval == '30min') continue; // Already tried this
            try {
              await _logger.info('Trying H4 with interval: $interval');
              final fallbackUrl = Uri.parse(
                '$_baseUrl?function=FX_INTRADAY&from_symbol=EUR&to_symbol=USD&interval=$interval&apikey=$_apiKey',
              );
              final fallbackResponse = await http.get(fallbackUrl).timeout(
                const Duration(seconds: 30),
              );
              
              if (fallbackResponse.statusCode == 200 && fallbackResponse.body.isNotEmpty) {
                final fallbackData = json.decode(fallbackResponse.body) as Map<String, dynamic>;
                
                if (fallbackData.containsKey('Information')) {
                  continue; // This interval also not available
                }
                
                // Find the time series key
                final timeSeriesKeys = fallbackData.keys.where((key) => 
                  key.toString().startsWith('Time Series FX')).toList();
                
                if (timeSeriesKeys.isNotEmpty) {
                  await _logger.info('H4 fallback successful with interval: $interval');
                  return await _processTimeSeriesData(
                    fallbackData,
                    timeSeriesKeys.first,
                    timeframe,
                    days,
                    startTime,
                  );
                }
              }
            } catch (e) {
              await _logger.warning('H4 fallback with $interval failed: $e');
              continue;
            }
          }
        }
        
        throw Exception('API Error: $info\n\nNote: Intraday data (M1, M5, M30, H1, H4) may require a premium API key. Daily (D) data is available with the free tier.');
      }

      // Check for invalid API response
      if (!data.containsKey(timeframe.timeSeriesKey)) {
        final availableKeys = data.keys.join(", ");
        await _logger.error(
          'Invalid API response format. Expected "${timeframe.timeSeriesKey}", but got keys: $availableKeys',
        );
        
        // Try to find any Time Series FX key as fallback
        final timeSeriesKeys = data.keys.where((key) => 
          key.toString().startsWith('Time Series FX')).toList();
        
        if (timeSeriesKeys.isNotEmpty) {
          await _logger.warning('Found alternative timeSeriesKey: ${timeSeriesKeys.first}');
          // For H4, if we can't find 30min, try using what's available
          if (timeframe == Timeframe.h4 && timeSeriesKeys.isNotEmpty) {
            // Use the first available time series key
            final fallbackKey = timeSeriesKeys.first;
            final timeSeries = data[fallbackKey];
            if (timeSeries is Map<String, dynamic> && timeSeries.isNotEmpty) {
              await _logger.info('Using fallback key for H4: $fallbackKey');
              // Continue with fallback processing
              return await _processTimeSeriesData(data, fallbackKey, timeframe, days, startTime);
            }
          }
        }
        
        throw Exception('Invalid API response format. Expected "${timeframe.timeSeriesKey}". Available keys: $availableKeys');
      }

      return await _processTimeSeriesData(data, timeframe.timeSeriesKey, timeframe, days, startTime);
    } on ArgumentError catch (e, stackTrace) {
      await _logger.error(
        'Invalid argument in fetchEURUSDQuotes',
        e,
        stackTrace,
      );
      rethrow;
    } on FormatException catch (e, stackTrace) {
      await _logger.error(
        'Format error while parsing quotes',
        e,
        stackTrace,
      );
      throw Exception('Data format error: ${e.message}');
    } on http.ClientException catch (e, stackTrace) {
      await _logger.error(
        'HTTP client error',
        e,
        stackTrace,
      );
      throw Exception('Network error: ${e.message}');
    } catch (e, stackTrace) {
      await _logger.error(
        'Unexpected error fetching quotes',
        e,
        stackTrace,
      );
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Unexpected error: $e');
    }
  }

  Future<List<Quote>> _processTimeSeriesData(
    Map<String, dynamic> data,
    String timeSeriesKey,
    Timeframe timeframe,
    int days,
    DateTime startTime,
  ) async {
    final timeSeries = data[timeSeriesKey];
    if (timeSeries is! Map<String, dynamic>) {
      await _logger.error('$timeSeriesKey is not a Map');
      throw Exception('Invalid API response: $timeSeriesKey format error');
    }

    if (timeSeries.isEmpty) {
      await _logger.warning('API returned empty time series data');
      return [];
    }

    await _logger.info('Parsing ${timeSeries.length} quote entries');

    // Convert to list of quotes with error handling
    final quotes = <Quote>[];
    int parseErrors = 0;

    for (final entry in timeSeries.entries) {
      try {
        final quote = Quote.fromJson(
          entry.key,
          entry.value as Map<String, dynamic>,
        );
        quotes.add(quote);
      } catch (e, stackTrace) {
        parseErrors++;
        await _logger.warning(
          'Failed to parse quote for date ${entry.key}',
          e,
          stackTrace,
        );
        // Continue parsing other quotes instead of failing completely
      }
    }

    if (quotes.isEmpty) {
      await _logger.error('No valid quotes could be parsed. Parse errors: $parseErrors');
      throw Exception('No valid quotes found in API response');
    }

    if (parseErrors > 0) {
      await _logger.warning(
        'Parsed ${quotes.length} quotes with $parseErrors errors',
      );
    }

    // Sort by date
    quotes.sort((a, b) => a.date.compareTo(b.date));

    // For H4, aggregate data into 4-hour candles
    List<Quote> processedQuotes = quotes;
    if (timeframe == Timeframe.h4) {
      await _logger.info('Aggregating ${quotes.length} quotes into 4-hour candles');
      processedQuotes = _aggregateTo4Hour(quotes);
      await _logger.info('Created ${processedQuotes.length} 4-hour candles from ${quotes.length} input quotes');
    }

    // Filter by date range for intraday timeframes, or by count for daily
    List<Quote> result;
    if (timeframe == Timeframe.d) {
      // For daily, return the last N days
      result = processedQuotes.length > days
          ? processedQuotes.sublist(processedQuotes.length - days)
          : processedQuotes;
    } else {
      // For intraday timeframes, filter by date range (last N days from now)
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      result = processedQuotes.where((quote) => quote.date.isAfter(cutoffDate)).toList();
      
      await _logger.info(
        'Filtered ${processedQuotes.length} quotes to ${result.length} quotes within last $days days (cutoff: $cutoffDate)',
      );
      
      // Calculate expected number of periods
      int expectedPeriods;
      if (timeframe == Timeframe.h4) {
        expectedPeriods = days * 6; // 6 four-hour periods per day
      } else if (timeframe == Timeframe.h1) {
        expectedPeriods = days * 24; // 24 hours per day
      } else if (timeframe == Timeframe.m30) {
        expectedPeriods = days * 48; // 48 half-hours per day
      } else if (timeframe == Timeframe.m5) {
        expectedPeriods = days * 288; // 288 five-minute periods per day
      } else if (timeframe == Timeframe.m1) {
        expectedPeriods = days * 1440; // 1440 minutes per day
      } else {
        expectedPeriods = days * 100; // Default fallback
      }
      
      // If we have fewer candles than expected, show all available (API limitation)
      // If we have more, limit to expected amount
      if (result.length > expectedPeriods) {
        await _logger.info('Limiting result from ${result.length} to $expectedPeriods periods');
        result = result.sublist(result.length - expectedPeriods);
      } else if (result.length < expectedPeriods) {
        await _logger.warning(
          'Only ${result.length} candles available (expected $expectedPeriods). '
          'This may be due to API limitations on intraday data availability.',
        );
        // Show all available candles - don't filter further
      }
    }

    final duration = DateTime.now().difference(startTime);
    await _logger.info(
      'Successfully fetched ${result.length} quotes in ${duration.inMilliseconds}ms',
    );

    return result;
  }

  List<Quote> _aggregateTo4Hour(List<Quote> quotes) {
    if (quotes.isEmpty) return [];

    final aggregated = <Quote>[];
    Quote? currentCandle;
    DateTime? currentPeriodStart;

    for (final quote in quotes) {
      // Round down to the nearest 4-hour period (0, 4, 8, 12, 16, 20)
      final hour = quote.date.hour;
      final periodHour = (hour ~/ 4) * 4;
      final periodStart = DateTime(
        quote.date.year,
        quote.date.month,
        quote.date.day,
        periodHour,
        0,
        0,
      );

      if (currentPeriodStart == null || periodStart != currentPeriodStart!) {
        // Save previous candle if exists
        if (currentCandle != null) {
          aggregated.add(currentCandle);
        }
        // Start new 4-hour candle
        currentCandle = Quote(
          date: periodStart,
          open: quote.open,
          high: quote.high,
          low: quote.low,
          close: quote.close,
        );
        currentPeriodStart = periodStart;
      } else {
        // Aggregate into current 4-hour candle
        // Keep the first open, highest high, lowest low, and last close
        currentCandle = Quote(
          date: currentPeriodStart!,
          open: currentCandle!.open, // Keep first open
          high: currentCandle.high > quote.high ? currentCandle.high : quote.high,
          low: currentCandle.low < quote.low ? currentCandle.low : quote.low,
          close: quote.close, // Use last close
        );
      }
    }

    // Add the last candle
    if (currentCandle != null) {
      aggregated.add(currentCandle);
    }

    return aggregated;
  }
}


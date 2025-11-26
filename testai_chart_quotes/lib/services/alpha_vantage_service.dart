import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quote.dart';
import 'logger_service.dart';

class AlphaVantageService {
  // IMPORTANT: Replace 'demo' with your own free API key from https://www.alphavantage.co/support/#api-key
  // The demo key has very limited rate limits. Get your free key to avoid rate limit errors.
  static const String _apiKey = 'demo';
  static const String _baseUrl = 'https://www.alphavantage.co/query';
  final LoggerService _logger = LoggerService();

  Future<List<Quote>> fetchEURUSDQuotes(int days) async {
    final startTime = DateTime.now();
    
    try {
      // Validate input
      if (days <= 0) {
        throw ArgumentError('Days must be greater than 0, got: $days');
      }
      if (days > 500) {
        throw ArgumentError('Days cannot exceed 500, got: $days');
      }

      await _logger.info('Fetching EUR/USD quotes for $days days');

      final url = Uri.parse(
        '$_baseUrl?function=FX_DAILY&from_symbol=EUR&to_symbol=USD&apikey=$_apiKey',
      );

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

      // Check for invalid API response
      if (!data.containsKey('Time Series FX (Daily)')) {
        await _logger.error(
          'Invalid API response format. Keys: ${data.keys.join(", ")}',
        );
        throw Exception('Invalid API response format. Expected "Time Series FX (Daily)"');
      }

      final timeSeries = data['Time Series FX (Daily)'];
      if (timeSeries is! Map<String, dynamic>) {
        await _logger.error('Time Series FX (Daily) is not a Map');
        throw Exception('Invalid API response: Time Series FX (Daily) format error');
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

      // Return the last N days
      final result = quotes.length > days
          ? quotes.sublist(quotes.length - days)
          : quotes;

      final duration = DateTime.now().difference(startTime);
      await _logger.info(
        'Successfully fetched ${result.length} quotes in ${duration.inMilliseconds}ms',
      );

      return result;
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
}


import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quote.dart';

class AlphaVantageService {
  // IMPORTANT: Replace 'demo' with your own free API key from https://www.alphavantage.co/support/#api-key
  // The demo key has very limited rate limits. Get your free key to avoid rate limit errors.
  static const String _apiKey = 'demo';
  static const String _baseUrl = 'https://www.alphavantage.co/query';

  Future<List<Quote>> fetchEURUSDQuotes(int days) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?function=FX_DAILY&from_symbol=EUR&to_symbol=USD&apikey=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Failed to load quotes: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // Check for API errors
      if (data.containsKey('Error Message') || data.containsKey('Note')) {
        throw Exception(
          data['Error Message'] ?? 
          data['Note'] ?? 
          'API error. Please check your API key and rate limits.',
        );
      }

      // Check for invalid API response
      if (!data.containsKey('Time Series FX (Daily)')) {
        throw Exception('Invalid API response format');
      }

      final timeSeries = data['Time Series FX (Daily)'] as Map<String, dynamic>;
      
      // Convert to list of quotes and sort by date
      final quotes = timeSeries.entries
          .map((entry) => Quote.fromJson(entry.key, entry.value as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      // Return the last N days
      return quotes.length > days ? quotes.sublist(quotes.length - days) : quotes;
    } catch (e) {
      throw Exception('Error fetching quotes: $e');
    }
  }
}


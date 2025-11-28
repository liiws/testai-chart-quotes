class Quote {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;

  Quote({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  }) {
    // Validate data integrity
    if (high < low) {
      throw ArgumentError('High price ($high) cannot be less than low price ($low)');
    }
    if (open < 0 || high < 0 || low < 0 || close < 0) {
      throw ArgumentError('Prices cannot be negative');
    }
    if (open > high || open < low || close > high || close < low) {
      throw ArgumentError('Open and close prices must be within high-low range');
    }
  }

  factory Quote.fromJson(String dateStr, Map<String, dynamic> json) {
    try {
      // Validate date string
      if (dateStr.isEmpty) {
        throw FormatException('Date string is empty');
      }

      // Validate JSON structure
      final requiredFields = ['1. open', '2. high', '3. low', '4. close'];
      for (final field in requiredFields) {
        if (!json.containsKey(field)) {
          throw FormatException('Missing required field: $field');
        }
        if (json[field] == null) {
          throw FormatException('Null value for field: $field');
        }
      }

      // Parse date
      DateTime parsedDate;
      try {
        parsedDate = DateTime.parse(dateStr);
      } catch (e) {
        throw FormatException('Invalid date format: $dateStr', e);
      }

      // Parse prices with error handling
      double parsePrice(String field, dynamic value) {
        try {
          if (value is String) {
            final parsed = double.parse(value);
            if (parsed.isNaN || parsed.isInfinite) {
              throw FormatException('Invalid price value: $value');
            }
            return parsed;
          } else if (value is num) {
            return value.toDouble();
          } else {
            throw FormatException('Price must be a number: $value');
          }
        } catch (e) {
          throw FormatException('Failed to parse $field: $value', e);
        }
      }

      final open = parsePrice('open', json['1. open']);
      final high = parsePrice('high', json['2. high']);
      final low = parsePrice('low', json['3. low']);
      final close = parsePrice('close', json['4. close']);

      return Quote(
        date: parsedDate,
        open: open,
        high: high,
        low: low,
        close: close,
      );
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        FormatException(
          'Failed to create Quote from JSON. Date: $dateStr, Error: $e',
          e,
        ),
        stackTrace,
      );
    }
  }
}


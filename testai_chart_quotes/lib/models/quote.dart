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
  });

  factory Quote.fromJson(String dateStr, Map<String, dynamic> json) {
    return Quote(
      date: DateTime.parse(dateStr),
      open: double.parse(json['1. open'] as String),
      high: double.parse(json['2. high'] as String),
      low: double.parse(json['3. low'] as String),
      close: double.parse(json['4. close'] as String),
    );
  }
}


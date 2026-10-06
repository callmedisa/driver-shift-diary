enum Payment {
  cash('нал.'),
  card('карта');

  const Payment(this.label);
  final String label;

  static Payment parse(String value) => switch (value) {
        'cash' => Payment.cash,
        'card' => Payment.card,
        _ => throw FormatException('Unknown payment type', value),
      };
}

class Trip {
  const Trip({
    required this.id,
    required this.start,
    required this.end,
    required this.amount,
    required this.payment,
    required this.commission,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        start: json['start'] as String,
        end: json['end'] as String,
        amount: json['amount'] as int,
        payment: Payment.parse(json['payment'] as String),
        commission: json['commission'] as int,
      );

  final String id;

  /// ISO timestamps in the drivers' time zone, exactly as the server sent them.
  final String start;
  final String end;

  /// Whole tenge.
  final int amount;
  final Payment payment;
  final int commission;
}

class DaySummary {
  const DaySummary({
    required this.tripsCount,
    required this.revenue,
    required this.commission,
    required this.net,
    required this.cash,
    required this.card,
  });

  factory DaySummary.fromJson(Map<String, dynamic> json) => DaySummary(
        tripsCount: json['trips_count'] as int,
        revenue: json['revenue'] as int,
        commission: json['commission'] as int,
        net: json['net'] as int,
        cash: json['cash'] as int,
        card: json['card'] as int,
      );

  final int tripsCount;
  final int revenue;
  final int commission;
  final int net;
  final int cash;
  final int card;
}

class DayReport {
  const DayReport({required this.date, required this.summary, required this.trips});

  factory DayReport.fromJson(Map<String, dynamic> json) => DayReport(
        date: DateTime.parse(json['date'] as String),
        summary: DaySummary.fromJson(json['summary'] as Map<String, dynamic>),
        trips: [
          for (final t in json['trips'] as List<dynamic>) Trip.fromJson(t as Map<String, dynamic>),
        ],
      );

  final DateTime date;
  final DaySummary summary;
  final List<Trip> trips;
}

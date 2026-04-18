class RevenueMonthlyTotalEntry {
  final String id;
  final DateTime month;
  final int amount;

  const RevenueMonthlyTotalEntry({
    required this.id,
    required this.month,
    required this.amount,
  });

  DateTime get monthKey => DateTime(month.year, month.month, 1);

  RevenueMonthlyTotalEntry copyWith({
    String? id,
    DateTime? month,
    int? amount,
  }) {
    return RevenueMonthlyTotalEntry(
      id: id ?? this.id,
      month: month ?? this.month,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'month': monthKey.toIso8601String(),
      'amount': amount,
    };
  }

  factory RevenueMonthlyTotalEntry.fromJson(Map<String, dynamic> json) {
    final rawMonth = DateTime.parse(json['month'] as String);

    return RevenueMonthlyTotalEntry(
      id: json['id'] as String,
      month: DateTime(rawMonth.year, rawMonth.month, 1),
      amount: json['amount'] as int,
    );
  }
}
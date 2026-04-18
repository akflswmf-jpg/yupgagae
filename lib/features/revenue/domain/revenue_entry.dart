class RevenueEntry {
  final String id;
  final DateTime date;
  final int? amount;
  final bool isClosed;

  const RevenueEntry({
    required this.id,
    required this.date,
    required this.amount,
    required this.isClosed,
  }) : assert(
          (isClosed && amount == null) || (!isClosed && amount != null),
          'daily entry는 휴무/금액 규칙을 따라야 합니다.',
        );

  DateTime get dateKey => DateTime(date.year, date.month, date.day);
  DateTime get monthKey => DateTime(date.year, date.month, 1);

  RevenueEntry copyWith({
    String? id,
    DateTime? date,
    int? amount,
    bool? isClosed,
    bool clearAmount = false,
  }) {
    final nextClosed = isClosed ?? this.isClosed;
    final nextAmount = clearAmount ? null : (amount ?? this.amount);

    return RevenueEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: nextClosed ? null : nextAmount,
      isClosed: nextClosed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': dateKey.toIso8601String(),
      'amount': amount,
      'isClosed': isClosed,
    };
  }

  factory RevenueEntry.fromJson(Map<String, dynamic> json) {
    return RevenueEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      amount: json['amount'] as int?,
      isClosed: json['isClosed'] as bool? ?? false,
    );
  }
}
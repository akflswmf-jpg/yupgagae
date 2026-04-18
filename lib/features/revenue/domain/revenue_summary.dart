class RevenueSummary {
  final int todayAmount;
  final int weekAmount;
  final int monthAmount;

  const RevenueSummary({
    required this.todayAmount,
    required this.weekAmount,
    required this.monthAmount,
  });

  const RevenueSummary.empty()
      : todayAmount = 0,
        weekAmount = 0,
        monthAmount = 0;
}
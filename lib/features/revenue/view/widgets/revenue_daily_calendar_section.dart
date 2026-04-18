import 'package:flutter/material.dart';

import 'package:yupgagae/features/revenue/domain/revenue_entry.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_monthly_revenue_calendar.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_section_block.dart';

class RevenueDailyCalendarSection extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final RevenueEntry? selectedEntry;
  final String monthLabel;
  final Map<int, RevenueEntry> entryMap;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;
  final Color borderColor;
  final Color accentColor;
  final Color accentSoftColor;

  const RevenueDailyCalendarSection({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.selectedEntry,
    required this.monthLabel,
    required this.entryMap,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectDay,
    required this.borderColor,
    required this.accentColor,
    required this.accentSoftColor,
  });

  @override
  Widget build(BuildContext context) {
    return RevenueSectionBlock(
      title: '월간 캘린더',
      borderColor: borderColor,
      child: RevenueMonthlyRevenueCalendar(
        month: month,
        selectedDate: selectedDate,
        selectedEntry: selectedEntry,
        onPrevMonth: onPrevMonth,
        onNextMonth: onNextMonth,
        onSelectDay: onSelectDay,
        monthLabel: monthLabel,
        entryMap: entryMap,
        accentColor: accentColor,
        accentSoftColor: accentSoftColor,
      ),
    );
  }
}
import 'package:flutter/material.dart';

import 'package:yupgagae/features/revenue/domain/revenue_entry.dart';
import 'package:yupgagae/features/revenue/view/revenue_theme_tokens.dart';
import 'package:yupgagae/features/revenue/view/revenue_view_formatters.dart';

class RevenueMonthlyRevenueCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final RevenueEntry? selectedEntry;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;
  final String monthLabel;
  final Map<int, RevenueEntry> entryMap;
  final Color accentColor;
  final Color accentSoftColor;

  const RevenueMonthlyRevenueCalendar({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.selectedEntry,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectDay,
    required this.monthLabel,
    required this.entryMap,
    required this.accentColor,
    required this.accentSoftColor,
  });

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final startOffset = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final today = DateTime.now();

    final cells = List<_CalendarCellData>.generate(42, (index) {
      final calendarDay = index - startOffset + 1;
      final isOutside = calendarDay <= 0 || calendarDay > daysInMonth;
      final col = index % 7;
      final isSunday = col == 0;
      final isSaturday = col == 6;

      if (isOutside) {
        return _CalendarCellData.empty(
          isSunday: isSunday,
          isSaturday: isSaturday,
        );
      }

      final date = DateTime(month.year, month.month, calendarDay);
      final entry = entryMap[calendarDay];

      final isToday =
          today.year == date.year &&
          today.month == date.month &&
          today.day == date.day;

      final isSelected =
          selectedDate.year == date.year &&
          selectedDate.month == date.month &&
          selectedDate.day == date.day;

      return _CalendarCellData(
        day: calendarDay,
        date: date,
        entry: entry,
        isOutside: false,
        isToday: isToday,
        isSelected: isSelected,
        isSaturday: isSaturday,
        isSunday: isSunday,
      );
    });

    final rows = List<List<_CalendarCellData>>.generate(
      6,
      (row) => cells.sublist(row * 7, row * 7 + 7),
    );

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CalendarArrowButton(
                icon: Icons.chevron_left_rounded,
                onTap: onPrevMonth,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: kRevenueTextMain,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              _CalendarArrowButton(
                icon: Icons.chevron_right_rounded,
                onTap: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              _WeekdayHeaderLabel('일', isSunday: true),
              _WeekdayHeaderLabel('월'),
              _WeekdayHeaderLabel('화'),
              _WeekdayHeaderLabel('수'),
              _WeekdayHeaderLabel('목'),
              _WeekdayHeaderLabel('금'),
              _WeekdayHeaderLabel('토', isSaturday: true),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            children: List.generate(rows.length, (rowIndex) {
              final row = rows[rowIndex];

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(row.length, (colIndex) {
                  final cell = row[colIndex];

                  return Expanded(
                    child: _CalendarDayCell(
                      day: cell.day,
                      entry: cell.entry,
                      isOutside: cell.isOutside,
                      isToday: cell.isToday,
                      isSelected: cell.isSelected,
                      isSaturday: cell.isSaturday,
                      isSunday: cell.isSunday,
                      onTap: cell.date == null
                          ? null
                          : () => onSelectDay(cell.date!),
                      accentColor: accentColor,
                      accentSoftColor: accentSoftColor,
                    ),
                  );
                }),
              );
            }),
          ),
          const SizedBox(height: 12),
          _CalendarSelectedInfoBar(
            selectedDate: selectedDate,
            selectedEntry: selectedEntry,
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }
}

class _CalendarCellData {
  final int day;
  final DateTime? date;
  final RevenueEntry? entry;
  final bool isOutside;
  final bool isToday;
  final bool isSelected;
  final bool isSaturday;
  final bool isSunday;

  const _CalendarCellData({
    required this.day,
    required this.date,
    required this.entry,
    required this.isOutside,
    required this.isToday,
    required this.isSelected,
    required this.isSaturday,
    required this.isSunday,
  });

  factory _CalendarCellData.empty({
    required bool isSaturday,
    required bool isSunday,
  }) {
    return _CalendarCellData(
      day: 0,
      date: null,
      entry: null,
      isOutside: true,
      isToday: false,
      isSelected: false,
      isSaturday: isSaturday,
      isSunday: isSunday,
    );
  }
}

class _CalendarArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CalendarArrowButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF3F4F6),
        ),
        child: Icon(
          icon,
          size: 22,
          color: const Color(0xFF9AA0A6),
        ),
      ),
    );
  }
}

class _WeekdayHeaderLabel extends StatelessWidget {
  final String label;
  final bool isSaturday;
  final bool isSunday;

  const _WeekdayHeaderLabel(
    this.label, {
    this.isSaturday = false,
    this.isSunday = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color = const Color(0xFF9AA0A6);
    if (isSunday) color = const Color(0xFFE15B6C);

    return Expanded(
      child: SizedBox(
        height: 28,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final RevenueEntry? entry;
  final bool isOutside;
  final bool isToday;
  final bool isSelected;
  final bool isSaturday;
  final bool isSunday;
  final VoidCallback? onTap;
  final Color accentColor;
  final Color accentSoftColor;

  const _CalendarDayCell({
    required this.day,
    required this.entry,
    required this.isOutside,
    required this.isToday,
    required this.isSelected,
    required this.isSaturday,
    required this.isSunday,
    required this.onTap,
    required this.accentColor,
    required this.accentSoftColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutside) {
      return const SizedBox(
        height: 84,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Color(0xFFF0F1F3),
                width: 1,
              ),
            ),
          ),
        ),
      );
    }

    Color dayColor = const Color(0xFF30343A);
    if (isSunday) dayColor = const Color(0xFFE15B6C);

    final isClosed = entry?.isClosed ?? false;
    final amount = entry?.amount;
    final hasAmount = amount != null && !isClosed;

    final markerColor = isClosed
        ? const Color(0xFFB8BDC7)
        : hasAmount
            ? accentColor
            : Colors.transparent;

    String subLabel = '';
    Color subLabelColor = kRevenueTextSub;

    if (isClosed) {
      subLabel = '휴무';
      subLabelColor = const Color(0xFF98A2B3);
    } else if (hasAmount) {
      subLabel = formatCompactMoney(amount);
      subLabelColor = accentColor;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 84,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Color(0xFFF0F1F3),
              width: 1,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isSelected ? kRevenueTextMain : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(
                            color: const Color(0xFFCDD1D7),
                            width: 1.2,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : dayColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 16,
                child: Center(
                  child: Text(
                    subLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isClosed ? 10.5 : 10,
                      height: 1.0,
                      color: subLabelColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  color: markerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarSelectedInfoBar extends StatelessWidget {
  final DateTime selectedDate;
  final RevenueEntry? selectedEntry;
  final Color accentColor;

  const _CalendarSelectedInfoBar({
    required this.selectedDate,
    required this.selectedEntry,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final left = formatDate(selectedDate);

    String right = '기록 없음';
    Color rightColor = kRevenueTextSub;

    if (selectedEntry != null) {
      if (selectedEntry!.isClosed) {
        right = '휴무';
        rightColor = const Color(0xFF98A2B3);
      } else if (selectedEntry!.amount != null) {
        right = formatMoney(selectedEntry!.amount!);
        rightColor = accentColor;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            left,
            style: const TextStyle(
              fontSize: 12.5,
              color: kRevenueTextSub,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            right,
            style: TextStyle(
              fontSize: 13,
              color: rightColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
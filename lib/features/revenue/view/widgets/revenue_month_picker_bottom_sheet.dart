import 'package:flutter/material.dart';

const Color _revenueSurfaceSoft = Color(0xFFF8F6F6);
const Color _revenueTextMain = Color(0xFF111111);

class RevenueMonthPickerBottomSheet extends StatefulWidget {
  final DateTime initialMonth;
  final Color accentColor;
  final Color accentSoftColor;
  final Color borderColor;

  const RevenueMonthPickerBottomSheet({
    super.key,
    required this.initialMonth,
    required this.accentColor,
    required this.accentSoftColor,
    required this.borderColor,
  });

  @override
  State<RevenueMonthPickerBottomSheet> createState() =>
      _RevenueMonthPickerBottomSheetState();
}

class _RevenueMonthPickerBottomSheetState
    extends State<RevenueMonthPickerBottomSheet> {
  late int visibleYear;
  late int selectedMonth;

  @override
  void initState() {
    super.initState();
    visibleYear = widget.initialMonth.year;
    selectedMonth = widget.initialMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(18, 14, 18, bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD0D5DD),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SheetArrowButton(
                icon: Icons.chevron_left_rounded,
                onTap: () {
                  setState(() {
                    visibleYear -= 1;
                  });
                },
                borderColor: widget.borderColor,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$visibleYear년',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _revenueTextMain,
                    ),
                  ),
                ),
              ),
              _SheetArrowButton(
                icon: Icons.chevron_right_rounded,
                onTap: () {
                  setState(() {
                    visibleYear += 1;
                  });
                },
                borderColor: widget.borderColor,
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
            ),
            itemBuilder: (context, index) {
              final month = index + 1;
              final selected =
                  visibleYear == widget.initialMonth.year && month == selectedMonth;

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).pop(DateTime(visibleYear, month, 1));
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? widget.accentSoftColor : _revenueSurfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? widget.accentColor : widget.borderColor,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$month월',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? widget.accentColor
                          : const Color(0xFF344054),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SheetArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color borderColor;

  const _SheetArrowButton({
    required this.icon,
    required this.onTap,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _revenueSurfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, color: _revenueTextMain),
      ),
    );
  }
}
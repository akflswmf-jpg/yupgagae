import 'package:flutter/material.dart';

import 'package:yupgagae/features/revenue/controller/revenue_controller.dart';

const Color _revenueTextSub = Color(0xFF667085);

class RevenueModeSegment extends StatelessWidget {
  final RevenueInputMode selectedMode;
  final ValueChanged<RevenueInputMode> onChanged;
  final Color accentColor;
  final Color borderColor;

  const RevenueModeSegment({
    super.key,
    required this.selectedMode,
    required this.onChanged,
    required this.accentColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: '일별 입력',
              selected: selectedMode == RevenueInputMode.daily,
              onTap: () => onChanged(RevenueInputMode.daily),
              accentColor: accentColor,
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: '월별 입력',
              selected: selectedMode == RevenueInputMode.monthlyTotal,
              onTap: () => onChanged(RevenueInputMode.monthlyTotal),
              accentColor: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : _revenueTextSub,
            ),
          ),
        ),
      ),
    );
  }
}
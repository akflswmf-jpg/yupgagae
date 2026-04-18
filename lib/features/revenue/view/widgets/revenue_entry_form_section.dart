import 'package:flutter/material.dart';

import 'package:yupgagae/features/revenue/view/revenue_theme_tokens.dart';

class RevenueEntryFormSection extends StatelessWidget {
  final String title;
  final String dateLabelTitle;
  final String dateLabelValue;
  final VoidCallback onPickDate;
  final TextEditingController amountController;
  final ValueNotifier<bool> isClosedNotifier;
  final bool isDailyMode;
  final bool isMonthlyTotalMode;
  final bool isSaving;
  final bool hasExisting;
  final String? errorMessage;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onDelete;
  final Color accentColor;
  final Color strongAccentColor;
  final Color borderColor;
  final Color surfaceColor;

  const RevenueEntryFormSection({
    super.key,
    required this.title,
    required this.dateLabelTitle,
    required this.dateLabelValue,
    required this.onPickDate,
    required this.amountController,
    required this.isClosedNotifier,
    required this.isDailyMode,
    required this.isMonthlyTotalMode,
    required this.isSaving,
    required this.hasExisting,
    required this.errorMessage,
    required this.onSubmit,
    required this.onDelete,
    required this.accentColor,
    required this.strongAccentColor,
    required this.borderColor,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: kRevenueTextMain,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            _DateSelectTile(
              label: dateLabelTitle,
              dateLabel: dateLabelValue,
              onTap: onPickDate,
              accentColor: strongAccentColor,
              borderColor: borderColor,
              surfaceColor: surfaceColor,
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: isClosedNotifier,
              builder: (context, isClosed, _) {
                return RepaintBoundary(
                  child: _RevenueAmountField(
                    controller: amountController,
                    enabled: isMonthlyTotalMode ? true : !isClosed,
                    labelText: isDailyMode ? '일 매출 입력' : '월 매출 입력',
                    hintText: isDailyMode ? '예: 180000' : '예: 5400000',
                    onSubmitted: (_) => onSubmit(),
                    accentColor: accentColor,
                    borderColor: borderColor,
                  ),
                );
              },
            ),
            if (isDailyMode) ...[
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: isClosedNotifier,
                builder: (context, isClosed, _) {
                  return RepaintBoundary(
                    child: _ClosedToggleTile(
                      isClosed: isClosed,
                      onTap: () {
                        final next = !isClosed;
                        isClosedNotifier.value = next;
                        if (next) {
                          amountController.clear();
                        }
                      },
                      accentColor: strongAccentColor,
                      borderColor: borderColor,
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 14),
            RepaintBoundary(
              child: _ActionButtons(
                hasExisting: hasExisting,
                isSaving: isSaving,
                onDelete: onDelete,
                onSubmit: onSubmit,
                strongAccentColor: strongAccentColor,
              ),
            ),
            if (errorMessage != null && errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ErrorMessageBox(message: errorMessage!),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateSelectTile extends StatelessWidget {
  final String label;
  final String dateLabel;
  final VoidCallback onTap;
  final Color accentColor;
  final Color borderColor;
  final Color surfaceColor;

  const _DateSelectTile({
    required this.label,
    required this.dateLabel,
    required this.onTap,
    required this.accentColor,
    required this.borderColor,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: accentColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kRevenueTextSub,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kRevenueTextMain,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: Color(0xFF98A2B3),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueAmountField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String labelText;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final Color accentColor;
  final Color borderColor;

  const _RevenueAmountField({
    required this.controller,
    required this.enabled,
    required this.labelText,
    required this.hintText,
    required this.accentColor,
    required this.borderColor,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        enabled: enabled,
        enableSuggestions: false,
        autocorrect: false,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: kRevenueTextMain,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          labelText: labelText,
          hintText: hintText,
          prefixIcon: Icon(
            Icons.payments_rounded,
            color: accentColor,
          ),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kRevenueTextSub,
          ),
          hintStyle: const TextStyle(
            fontSize: 14.5,
            color: Color(0xFF98A2B3),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ClosedToggleTile extends StatelessWidget {
  final bool isClosed;
  final VoidCallback onTap;
  final Color accentColor;
  final Color borderColor;

  const _ClosedToggleTile({
    required this.isClosed,
    required this.onTap,
    required this.accentColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isClosed ? kRevenuePrimarySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isClosed ? accentColor : borderColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isClosed ? accentColor : Colors.white,
                border: Border.all(
                  color: isClosed ? accentColor : const Color(0xFFD0D5DD),
                ),
              ),
              child: isClosed
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '휴무',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: kRevenueTextMain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool hasExisting;
  final bool isSaving;
  final Future<void> Function() onDelete;
  final Future<void> Function() onSubmit;
  final Color strongAccentColor;

  const _ActionButtons({
    required this.hasExisting,
    required this.isSaving,
    required this.onDelete,
    required this.onSubmit,
    required this.strongAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (hasExisting) ...[
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: isSaving ? null : () => onDelete(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kRevenueDanger,
                  side: const BorderSide(
                    color: Color(0xFFF1B5AF),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '삭제',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: isSaving ? null : () => onSubmit(),
              style: FilledButton.styleFrom(
                backgroundColor: strongAccentColor,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isSaving
                    ? (hasExisting ? '수정 중...' : '저장 중...')
                    : (hasExisting ? '수정' : '저장'),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorMessageBox extends StatelessWidget {
  final String message;

  const _ErrorMessageBox({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDA29B)),
        ),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 12.5,
            color: kRevenueDanger,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
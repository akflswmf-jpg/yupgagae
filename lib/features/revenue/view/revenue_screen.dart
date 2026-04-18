import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/revenue/controller/revenue_controller.dart';
import 'package:yupgagae/features/revenue/view/revenue_theme_tokens.dart';
import 'package:yupgagae/features/revenue/view/revenue_view_formatters.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_compare_section.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_daily_calendar_section.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_delete_confirm_dialog.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_entry_form_section.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_loading_overlay.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_mode_segment.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_month_picker_bottom_sheet.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_month_summary_overview_card.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_weekday_pattern_card.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_weekly_trend_summary_card.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  late final RevenueController c;

  final TextEditingController amountController = TextEditingController();
  final ValueNotifier<bool> isClosedNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    c = Get.find<RevenueController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncForm();
    });
  }

  @override
  void dispose() {
    amountController.dispose();
    isClosedNotifier.dispose();
    super.dispose();
  }

  Future<void> _pickDailyDate() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('ko', 'KR'),
      initialDate: c.selectedDate.value,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
      fieldHintText: '연도/월/일',
      fieldLabelText: '날짜 입력',
    );

    if (picked == null) return;

    c.setSelectedDate(picked);
    _syncForm();
  }

  Future<void> _pickMonthlyMonth() async {
    FocusScope.of(context).unfocus();

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return RevenueMonthPickerBottomSheet(
          initialMonth: c.selectedMonth.value,
          accentColor: kRevenuePrimary,
          accentSoftColor: kRevenuePrimarySoft,
          borderColor: kRevenueBorder,
        );
      },
    );

    if (picked == null) return;

    c.setSelectedMonth(picked);
    _syncForm();
  }

  void _syncForm() {
    if (c.isDailyMode) {
      final amount = c.selectedDateAmount;
      amountController.text = amount == null ? '' : amount.toString();
      isClosedNotifier.value = c.selectedDateIsClosed;
      return;
    }

    final monthlyAmount = c.selectedMonthlyTotalAmount;
    amountController.text = monthlyAmount == null ? '' : monthlyAmount.toString();
    isClosedNotifier.value = false;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final ok = c.isDailyMode
        ? await c.saveDailyEntry(
            rawAmount: amountController.text,
            isClosed: isClosedNotifier.value,
          )
        : await c.saveMonthlyTotalEntry(
            rawAmount: amountController.text,
          );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            c.isDailyMode ? '일별 매출이 저장되었습니다.' : '월 매출이 저장되었습니다.',
          ),
        ),
      );
      _syncForm();
    }
  }

  Future<void> _delete() async {
    FocusScope.of(context).unfocus();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => RevenueDeleteConfirmDialog(
        description: c.isDailyMode
            ? '선택한 날짜의 매출 입력을 삭제할까요?'
            : '선택한 월의 매출 입력을 삭제할까요?',
      ),
    );

    if (confirmed != true) return;

    final ok = c.isDailyMode
        ? await c.deleteSelectedDailyEntry()
        : await c.deleteSelectedMonthlyTotalEntry();

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            c.isDailyMode ? '일별 매출이 삭제되었습니다.' : '월 매출이 삭제되었습니다.',
          ),
        ),
      );
      _syncForm();
    }
  }

  String _buildCompareLockMessage() {
    final raw = c.comparisonLockMessage?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }
    return '일별 매출 10일 이상 입력 후 업종 지역 매출 비교를 해보세요!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kRevenueBg,
      body: SafeArea(
        child: Stack(
          children: [
            _RevenueBody(
              controller: c,
              amountController: amountController,
              isClosedNotifier: isClosedNotifier,
              onPickDailyDate: _pickDailyDate,
              onPickMonthlyMonth: _pickMonthlyMonth,
              onSave: _save,
              onDelete: _delete,
              onSyncForm: _syncForm,
              buildCompareLockMessage: _buildCompareLockMessage,
            ),
            Obx(
              () => RevenueLoadingOverlay(
                visible: c.isSaving.value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueBody extends StatelessWidget {
  final RevenueController controller;
  final TextEditingController amountController;
  final ValueNotifier<bool> isClosedNotifier;
  final Future<void> Function() onPickDailyDate;
  final Future<void> Function() onPickMonthlyMonth;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final VoidCallback onSyncForm;
  final String Function() buildCompareLockMessage;

  const _RevenueBody({
    required this.controller,
    required this.amountController,
    required this.isClosedNotifier,
    required this.onPickDailyDate,
    required this.onPickMonthlyMonth,
    required this.onSave,
    required this.onDelete,
    required this.onSyncForm,
    required this.buildCompareLockMessage,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '매출',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: kRevenueTextMain,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '입력한 매출을 기준으로 흐름과 비교 데이터를 확인해보세요.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: kRevenueTextSub,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Obx(
              () => RevenueModeSegment(
                selectedMode: controller.selectedInputMode.value,
                onChanged: (mode) {
                  controller.setInputMode(mode);
                  onSyncForm();
                },
                accentColor: kRevenuePrimary,
                borderColor: kRevenueBorder,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const SizedBox.shrink();
            }

            return const SizedBox.shrink();
          }),
        ),
        SliverToBoxAdapter(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const SizedBox.shrink();
            }

            final visibleMonth = controller.visibleMonth;
            final visibleTotal = controller.visibleTopTotal;
            final visibleRate = controller.visibleMonthOverMonthRate;
            final visibleAverage = controller.visibleAverage;
            final visibleSubTitle = controller.visibleTopSubTitle;
            final visibleSubValue = controller.visibleTopSubValueLabel;
            final visibleSecondaryTitle = controller.visibleSecondarySubTitle;
            final visibleSecondaryValue = visibleAverage == null
                ? controller.visibleSecondarySubValue
                : formatMoney(visibleAverage);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: RevenueMonthSummaryOverviewCard(
                monthLabel: formatMonth(visibleMonth),
                totalLabel: formatMoney(visibleTotal),
                topSubTitle: visibleSubTitle,
                topSubValue: visibleSubValue,
                secondarySubTitle: visibleSecondaryTitle,
                secondarySubValue: visibleSecondaryValue,
                deltaLabel: formatDeltaRate(visibleRate),
                deltaColor: deltaColor(visibleRate),
                borderColor: kRevenueBorder,
              ),
            );
          }),
        ),
        SliverToBoxAdapter(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const SizedBox.shrink();
            }

            final isDailyMode = controller.isDailyMode;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: isDailyMode
                  ? RevenueDailyCalendarSection(
                      month: controller.selectedDailyMonthStart,
                      selectedDate: controller.selectedDate.value,
                      selectedEntry: controller.selectedDateEntry,
                      monthLabel: formatMonth(controller.selectedDailyMonthStart),
                      entryMap: controller.selectedDailyMonthEntryMap,
                      onPrevMonth: () {
                        controller.moveDailyMonth(-1);
                        onSyncForm();
                      },
                      onNextMonth: () {
                        controller.moveDailyMonth(1);
                        onSyncForm();
                      },
                      onSelectDay: (date) {
                        controller.setSelectedDate(date);
                        onSyncForm();
                      },
                      borderColor: kRevenueBorder,
                      accentColor: kRevenuePrimary,
                      accentSoftColor: kRevenuePrimarySoft,
                    )
                  : RevenueEntryFormSection(
                      title: '월별 매출 입력',
                      dateLabelTitle: '기준 월',
                      dateLabelValue: formatMonth(controller.selectedMonth.value),
                      onPickDate: onPickMonthlyMonth,
                      amountController: amountController,
                      isClosedNotifier: isClosedNotifier,
                      isDailyMode: false,
                      isMonthlyTotalMode: true,
                      isSaving: controller.isSaving.value,
                      hasExisting: controller.selectedMonthlyTotalEntry != null,
                      errorMessage: controller.error.value,
                      onSubmit: onSave,
                      onDelete: onDelete,
                      accentColor: kRevenuePrimary,
                      strongAccentColor: kRevenuePrimaryDark,
                      borderColor: kRevenueBorder,
                      surfaceColor: kRevenueSurfaceSoft,
                    ),
            );
          }),
        ),
        SliverToBoxAdapter(
          child: Obx(() {
            if (controller.isLoading.value || !controller.isDailyMode) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: RevenueEntryFormSection(
                title: '일별 매출 입력',
                dateLabelTitle: '선택 날짜',
                dateLabelValue: formatDate(controller.selectedDate.value),
                onPickDate: onPickDailyDate,
                amountController: amountController,
                isClosedNotifier: isClosedNotifier,
                isDailyMode: true,
                isMonthlyTotalMode: false,
                isSaving: controller.isSaving.value,
                hasExisting: controller.selectedDateEntry != null,
                errorMessage: controller.error.value,
                onSubmit: onSave,
                onDelete: onDelete,
                accentColor: kRevenuePrimary,
                strongAccentColor: kRevenuePrimaryDark,
                borderColor: kRevenueBorder,
                surfaceColor: kRevenueSurfaceSoft,
              ),
            );
          }),
        ),
        SliverToBoxAdapter(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const SizedBox.shrink();
            }

            final hasRevenueData = controller.hasVisibleRevenueForComparison;
            final hasComparisonData = controller.hasVisibleComparisonData;
            final myTotal = controller.visibleTopTotal;
            final topPercent = controller.visibleTopPercent;
            final industryAverage = controller.visibleIndustryAverage;
            final regionAverage = controller.visibleRegionAverage;
            final industryDeltaRate = controller.visibleIndustryDeltaRate;
            final regionDeltaRate = controller.visibleRegionDeltaRate;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: RevenueCompareSection(
                hasRevenueData: hasRevenueData,
                hasComparisonData: hasComparisonData,
                baseLabel: controller.visibleComparisonBaseLabel,
                myTotal: myTotal,
                myTotalLabel: formatMoney(myTotal),
                topPercent: topPercent,
                industryAverage: industryAverage,
                industryAverageLabel: industryAverage == null
                    ? '데이터 없음'
                    : formatMoney(industryAverage),
                industryDeltaLabel: formatCompareDeltaText(industryDeltaRate),
                industryDeltaColor: deltaColor(industryDeltaRate),
                regionAverage: regionAverage,
                regionAverageLabel: regionAverage == null
                    ? '데이터 없음'
                    : formatMoney(regionAverage),
                regionDeltaLabel: formatCompareDeltaText(regionDeltaRate),
                regionDeltaColor: deltaColor(regionDeltaRate),
                accentColor: kRevenuePrimaryDark,
                accentSoftColor: kRevenuePrimarySoft,
                borderColor: kRevenueBorder,
                lockMessage: buildCompareLockMessage(),
              ),
            );
          }),
        ),
        SliverToBoxAdapter(
          child: Obx(() {
            if (controller.isLoading.value || !controller.isDailyMode) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: RevenueWeekdayPatternCard(
                points: controller.selectedDailyWeekdayPattern,
                hasData: controller.hasSelectedDailyWeekdayPatternData,
                axisMax: controller.selectedDailyWeekdayPatternAxisMax,
                moneyFormatter: formatMoney,
                borderColor: kRevenueBorder,
                accentColor: kRevenuePrimary,
                accentSoftColor: kRevenuePrimarySoft,
              ),
            );
          }),
        ),
        SliverToBoxAdapter(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: RevenueWeeklyTrendSummaryCard(
                points: controller.recent4WeekTrend,
                moneyFormatter: formatMoney,
                rangeLabelBuilder: formatWeekRangeLabel,
                deltaTextBuilder: formatWeekDeltaRate,
                deltaColorBuilder: weekDeltaColor,
                borderColor: kRevenueBorder,
              ),
            );
          }),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Obx(() {
            if (!controller.isLoading.value) {
              return const SizedBox.shrink();
            }

            return const Center(
              child: CircularProgressIndicator(),
            );
          }),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';

import 'package:yupgagae/features/revenue/controller/revenue_controller.dart';
import 'package:yupgagae/features/revenue/view/revenue_theme_tokens.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_section_block.dart';

const TextStyle _kEmptyTextStyle = TextStyle(
  fontSize: 13,
  color: kRevenueTextSub,
);

const TextStyle _kItemLabelStyle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w800,
  color: kRevenueTextMain,
);

const TextStyle _kMiniLabelStyle = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w700,
  color: kRevenueTextSub,
);

const TextStyle _kMiniValueStyle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w800,
  color: kRevenueTextMain,
);

class RevenueWeeklyTrendSummaryCard extends StatelessWidget {
  final List<RevenueWeeklyTrendPoint> points;
  final String Function(int value) moneyFormatter;
  final String Function(String rawLabel) rangeLabelBuilder;
  final String Function(int myTotal, int average) deltaTextBuilder;
  final Color Function(int myTotal, int average) deltaColorBuilder;
  final Color borderColor;

  const RevenueWeeklyTrendSummaryCard({
    super.key,
    required this.points,
    required this.moneyFormatter,
    required this.rangeLabelBuilder,
    required this.deltaTextBuilder,
    required this.deltaColorBuilder,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return RevenueSectionBlock(
        title: '최근 4주 추세',
        borderColor: borderColor,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '최근 4주 추세 데이터가 없습니다.',
            style: _kEmptyTextStyle,
          ),
        ),
      );
    }

    final items = List<_WeeklyTrendUiItem>.generate(points.length, (index) {
      final point = points[index];

      return _WeeklyTrendUiItem(
        label: rangeLabelBuilder(point.label),
        myTotalLabel: moneyFormatter(point.myTotal),
        averageLabel:
            point.industryAverage > 0 ? moneyFormatter(point.industryAverage) : '데이터 없음',
        deltaLabel: deltaTextBuilder(point.myTotal, point.industryAverage),
        deltaColor: deltaColorBuilder(point.myTotal, point.industryAverage),
      );
    });

    return RevenueSectionBlock(
      title: '최근 4주 추세',
      borderColor: borderColor,
      child: RepaintBoundary(
        child: Column(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isLast = index == items.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: _WeeklyTrendSummaryItem(
                item: item,
                borderColor: borderColor,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _WeeklyTrendUiItem {
  final String label;
  final String myTotalLabel;
  final String averageLabel;
  final String deltaLabel;
  final Color deltaColor;

  const _WeeklyTrendUiItem({
    required this.label,
    required this.myTotalLabel,
    required this.averageLabel,
    required this.deltaLabel,
    required this.deltaColor,
  });
}

class _WeeklyTrendSummaryItem extends StatelessWidget {
  final _WeeklyTrendUiItem item;
  final Color borderColor;

  const _WeeklyTrendSummaryItem({
    required this.item,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _kItemLabelStyle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.deltaLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: item.deltaColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _WeeklyMiniMetric(
                  label: '내 매출',
                  value: item.myTotalLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WeeklyMiniMetric(
                  label: '업종 평균',
                  value: item.averageLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyMiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _WeeklyMiniMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: kRevenueSurfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kRevenueBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _kMiniLabelStyle,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _kMiniValueStyle,
          ),
        ],
      ),
    );
  }
}
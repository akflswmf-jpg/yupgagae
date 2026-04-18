import 'package:flutter/material.dart';

import 'package:yupgagae/features/revenue/controller/revenue_controller.dart';
import 'package:yupgagae/features/revenue/view/revenue_theme_tokens.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_section_block.dart';

const double _kChartHeight = 196;
const double _kTrackHeight = 116;
const double _kTrackWidth = 24;
const double _kMinBarHeight = 18;
const double _kEmptyBarHeight = 8;
const double _kMaxBarVisualHeight = 112;

const TextStyle _kGuideTextStyle = TextStyle(
  fontSize: 13,
  color: kRevenueTextSub,
  height: 1.5,
);

const TextStyle _kChartTitleStyle = TextStyle(
  fontSize: 12.5,
  color: kRevenueTextSub,
  fontWeight: FontWeight.w700,
);

const TextStyle _kEmptyValueStyle = TextStyle(
  fontSize: 10.5,
  height: 1.0,
  color: kRevenueTextSub,
  fontWeight: FontWeight.w600,
);

const TextStyle _kValueStyle = TextStyle(
  fontSize: 10.5,
  height: 1.0,
  color: kRevenueTextMain,
  fontWeight: FontWeight.w800,
);

class RevenueWeekdayPatternCard extends StatelessWidget {
  final List<RevenueWeekdayPatternPoint> points;
  final bool hasData;
  final int axisMax;
  final String Function(int value) moneyFormatter;
  final Color borderColor;
  final Color accentColor;
  final Color accentSoftColor;

  const RevenueWeekdayPatternCard({
    super.key,
    required this.points,
    required this.hasData,
    required this.axisMax,
    required this.moneyFormatter,
    required this.borderColor,
    required this.accentColor,
    required this.accentSoftColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasData) {
      return RevenueSectionBlock(
        title: '요일 매출 패턴',
        borderColor: borderColor,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '이번 달 일별 매출이 쌓이면 요일별 패턴을 볼 수 있어요.',
            style: _kGuideTextStyle,
          ),
        ),
      );
    }

    final effectiveAxisMax = axisMax <= 0 ? 1 : axisMax;

    final items = List<_WeekdayBarUiItem>.generate(points.length, (index) {
      final point = points[index];
      final hasPointData = point.enteredDays > 0;
      final ratio = hasPointData ? (point.average / effectiveAxisMax) : 0.0;
      final normalizedRatio = ratio.clamp(0.0, 1.0);
      final barHeight = hasPointData
          ? (normalizedRatio * _kMaxBarVisualHeight).clamp(
              _kMinBarHeight,
              _kMaxBarVisualHeight,
            )
          : _kEmptyBarHeight;

      return _WeekdayBarUiItem(
        label: point.label,
        valueLabel: hasPointData ? _formatCompactMoney(point.average) : '-',
        barHeight: barHeight,
        hasData: hasPointData,
      );
    });

    return RevenueSectionBlock(
      title: '요일 매출 패턴',
      borderColor: borderColor,
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '이번 달 기준 요일별 평균 매출',
              style: _kChartTitleStyle,
            ),
            const SizedBox(height: 14),
            _WeekdayBarChart(
              items: items,
              accentColor: accentColor,
              accentSoftColor: accentSoftColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayBarUiItem {
  final String label;
  final String valueLabel;
  final double barHeight;
  final bool hasData;

  const _WeekdayBarUiItem({
    required this.label,
    required this.valueLabel,
    required this.barHeight,
    required this.hasData,
  });
}

class _WeekdayBarChart extends StatelessWidget {
  final List<_WeekdayBarUiItem> items;
  final Color accentColor;
  final Color accentSoftColor;

  const _WeekdayBarChart({
    required this.items,
    required this.accentColor,
    required this.accentSoftColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kChartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(items.length, (index) {
          final item = items[index];

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _WeekdayBarItem(
                item: item,
                accentColor: accentColor,
                accentSoftColor: accentSoftColor,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _WeekdayBarItem extends StatelessWidget {
  final _WeekdayBarUiItem item;
  final Color accentColor;
  final Color accentSoftColor;

  const _WeekdayBarItem({
    required this.item,
    required this.accentColor,
    required this.accentSoftColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 28,
          child: Center(
            child: Text(
              item.valueLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: item.hasData ? _kValueStyle : _kEmptyValueStyle,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: _kTrackWidth,
          height: _kTrackHeight,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: kRevenueTrack,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: _kTrackWidth,
            height: item.barHeight,
            decoration: BoxDecoration(
              color: item.hasData ? accentColor : kRevenueDisabled,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 28,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: item.hasData ? accentSoftColor : kRevenueDisabledSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: item.hasData ? accentColor : kRevenueTextSub,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatCompactMoney(int value) {
  if (value >= 100000000) {
    final eok = value / 100000000;
    final formatted = eok % 1 == 0 ? eok.toStringAsFixed(0) : eok.toStringAsFixed(1);
    return '${formatted}억';
  }

  if (value >= 10000) {
    final man = value / 10000;
    final formatted = man % 1 == 0 ? man.toStringAsFixed(0) : man.toStringAsFixed(1);
    return '${formatted}만';
  }

  return value.toString();
}
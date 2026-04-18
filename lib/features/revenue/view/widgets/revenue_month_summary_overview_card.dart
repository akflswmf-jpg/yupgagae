import 'package:flutter/material.dart';

import 'package:yupgagae/features/revenue/view/revenue_theme_tokens.dart';

class RevenueMonthSummaryOverviewCard extends StatelessWidget {
  final String monthLabel;
  final String totalLabel;
  final String topSubTitle;
  final String topSubValue;
  final String secondarySubTitle;
  final String secondarySubValue;
  final String deltaLabel;
  final Color deltaColor;
  final Color borderColor;

  const RevenueMonthSummaryOverviewCard({
    super.key,
    required this.monthLabel,
    required this.totalLabel,
    required this.topSubTitle,
    required this.topSubValue,
    required this.secondarySubTitle,
    required this.secondarySubValue,
    required this.deltaLabel,
    required this.deltaColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              _SummaryDot(),
              SizedBox(width: 8),
              Text(
                '이번 달 요약',
                style: TextStyle(
                  fontSize: 12.5,
                  color: kRevenueTextSub,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            monthLabel,
            style: const TextStyle(
              fontSize: 14,
              color: kRevenueTextSub,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            totalLabel,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: kRevenueTextMain,
              height: 1.1,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _LightSummaryMetric(
                  label: topSubTitle,
                  value: topSubValue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LightSummaryMetric(
                  label: secondarySubTitle,
                  value: secondarySubValue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LightSummaryMetric(
                  label: '전월 대비',
                  value: deltaLabel,
                  valueColor: deltaColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryDot extends StatelessWidget {
  const _SummaryDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: kRevenuePrimaryDark,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _LightSummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _LightSummaryMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: kRevenueSurfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kRevenueBorder),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: kRevenueTextSub,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor ?? kRevenueTextMain,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
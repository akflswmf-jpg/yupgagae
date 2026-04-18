import 'package:flutter/material.dart';

import 'package:yupgagae/features/revenue/view/revenue_theme_tokens.dart';
import 'package:yupgagae/features/revenue/view/widgets/revenue_section_block.dart';

const TextStyle _kEmptyGuideStyle = TextStyle(
  fontSize: 13,
  color: kRevenueTextSub,
  height: 1.5,
);

const TextStyle _kBaseLabelStyle = TextStyle(
  fontSize: 12.5,
  color: kRevenueTextSub,
  fontWeight: FontWeight.w700,
);

const TextStyle _kTrackSideLabelStyle = TextStyle(
  fontSize: 11.5,
  color: kRevenueTextSub,
  fontWeight: FontWeight.w700,
);

const TextStyle _kFootnoteStyle = TextStyle(
  fontSize: 11.8,
  height: 1.4,
  color: kRevenueTextSub,
  fontWeight: FontWeight.w600,
);

const TextStyle _kMiniCardTitleStyle = TextStyle(
  fontSize: 12.5,
  fontWeight: FontWeight.w800,
  color: Color(0xFF344054),
);

const TextStyle _kMiniCardValueStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w900,
  color: kRevenueTextMain,
  height: 1.1,
);

const TextStyle _kMiniBarLabelStyle = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w700,
  color: kRevenueTextSub,
);

class RevenueCompareSection extends StatelessWidget {
  final bool hasRevenueData;
  final bool hasComparisonData;
  final String baseLabel;
  final int myTotal;
  final String myTotalLabel;
  final int? topPercent;
  final int? industryAverage;
  final String industryAverageLabel;
  final String industryDeltaLabel;
  final Color industryDeltaColor;
  final int? regionAverage;
  final String regionAverageLabel;
  final String regionDeltaLabel;
  final Color regionDeltaColor;
  final Color accentColor;
  final Color accentSoftColor;
  final Color borderColor;
  final String? lockMessage;

  const RevenueCompareSection({
    super.key,
    required this.hasRevenueData,
    required this.hasComparisonData,
    required this.baseLabel,
    required this.myTotal,
    required this.myTotalLabel,
    required this.topPercent,
    required this.industryAverage,
    required this.industryAverageLabel,
    required this.industryDeltaLabel,
    required this.industryDeltaColor,
    required this.regionAverage,
    required this.regionAverageLabel,
    required this.regionDeltaLabel,
    required this.regionDeltaColor,
    required this.accentColor,
    required this.accentSoftColor,
    required this.borderColor,
    this.lockMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasRevenueData) {
      return RevenueSectionBlock(
        title: '이번 달 비교',
        borderColor: borderColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            lockMessage ?? '일별 매출 10일 이상 입력하면 업종·지역 평균과 비교할 수 있어요.',
            style: _kEmptyGuideStyle,
          ),
        ),
      );
    }

    final percentileText = topPercent == null ? '비교 불가' : '상위 $topPercent%';
    final percentileTextColor = topPercent == null ? kRevenueTextMain : accentColor;

    final trackMarkerRatio = topPercent == null
        ? 0.5
        : ((100 - topPercent!).clamp(0, 100)) / 100.0;

    final industryUi = _CompareMiniUiItem.fromValues(
      title: '내 업종 평균',
      valueLabel: industryAverageLabel,
      subtitle: industryDeltaLabel,
      subtitleColor: industryDeltaColor,
      myValue: myTotal,
      peerValue: industryAverage,
      accentColor: accentColor,
      accentSoftColor: accentSoftColor,
    );

    final regionUi = _CompareMiniUiItem.fromValues(
      title: '내 지역 평균',
      valueLabel: regionAverageLabel,
      subtitle: regionDeltaLabel,
      subtitleColor: regionDeltaColor,
      myValue: myTotal,
      peerValue: regionAverage,
      accentColor: accentColor,
      accentSoftColor: accentSoftColor,
    );

    return RevenueSectionBlock(
      title: '이번 달 비교',
      borderColor: borderColor,
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baseLabel,
                    style: _kBaseLabelStyle,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        percentileText,
                        style: TextStyle(
                          fontSize: 31,
                          fontWeight: FontWeight.w900,
                          color: percentileTextColor,
                          height: 1.05,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        myTotalLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF344054),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _PercentileTrack(
                    markerRatio: trackMarkerRatio,
                    accentColor: accentColor,
                    trackColor: accentSoftColor,
                  ),
                  if (!hasComparisonData) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '비교 표본이 아직 충분하지 않습니다.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: kRevenueTextSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CompareMiniCard(
                    item: industryUi,
                    borderColor: borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompareMiniCard(
                    item: regionUi,
                    borderColor: borderColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '상·하위 5%를 제외한 평균값입니다.',
              style: _kFootnoteStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareMiniUiItem {
  final String title;
  final String value;
  final String subtitle;
  final Color subtitleColor;
  final double myRatio;
  final double peerRatio;
  final Color myFillColor;
  final Color peerFillColor;

  const _CompareMiniUiItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.subtitleColor,
    required this.myRatio,
    required this.peerRatio,
    required this.myFillColor,
    required this.peerFillColor,
  });

  factory _CompareMiniUiItem.fromValues({
    required String title,
    required String valueLabel,
    required String subtitle,
    required Color subtitleColor,
    required int myValue,
    required int? peerValue,
    required Color accentColor,
    required Color accentSoftColor,
  }) {
    final safeMy = myValue < 0 ? 0 : myValue;
    final safePeer = peerValue == null || peerValue < 0 ? 0 : peerValue;
    final maxValue = (safeMy > safePeer ? safeMy : safePeer).toDouble();
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return _CompareMiniUiItem(
      title: title,
      value: valueLabel,
      subtitle: subtitle,
      subtitleColor: subtitleColor,
      myRatio: (safeMy / safeMax).clamp(0.0, 1.0),
      peerRatio: (safePeer / safeMax).clamp(0.0, 1.0),
      myFillColor: accentColor,
      peerFillColor: accentSoftColor,
    );
  }
}

class _PercentileTrack extends StatelessWidget {
  final double markerRatio;
  final Color accentColor;
  final Color trackColor;

  const _PercentileTrack({
    required this.markerRatio,
    required this.accentColor,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            Text(
              '하위',
              style: _kTrackSideLabelStyle,
            ),
            Spacer(),
            Text(
              '상위',
              style: _kTrackSideLabelStyle,
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final markerLeft = ((width - 16) * markerRatio).clamp(0.0, width - 16);

            return SizedBox(
              height: 24,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 9,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: markerLeft,
                    top: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CompareMiniCard extends StatelessWidget {
  final _CompareMiniUiItem item;
  final Color borderColor;

  const _CompareMiniCard({
    required this.item,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: _kMiniCardTitleStyle,
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: _kMiniCardValueStyle,
          ),
          const SizedBox(height: 6),
          Text(
            item.subtitle,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: item.subtitleColor,
            ),
          ),
          const SizedBox(height: 12),
          _MiniCompareBar(
            label: '내 매출',
            ratio: item.myRatio,
            fillColor: item.myFillColor,
            trackColor: const Color(0xFFF3F0EF),
          ),
          const SizedBox(height: 8),
          _MiniCompareBar(
            label: '평균',
            ratio: item.peerRatio,
            fillColor: item.peerFillColor,
            trackColor: const Color(0xFFF3F0EF),
          ),
        ],
      ),
    );
  }
}

class _MiniCompareBar extends StatelessWidget {
  final String label;
  final double ratio;
  final Color fillColor;
  final Color trackColor;

  const _MiniCompareBar({
    required this.label,
    required this.ratio,
    required this.fillColor,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _kMiniBarLabelStyle,
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final rawWidth = width * ratio;
            final barWidth = ratio <= 0 ? 0.0 : rawWidth.clamp(10.0, width);

            return Stack(
              children: [
                Container(
                  width: width,
                  height: 8,
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                if (barWidth > 0)
                  Container(
                    width: barWidth,
                    height: 8,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
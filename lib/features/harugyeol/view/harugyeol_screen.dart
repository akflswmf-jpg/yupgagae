import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/ui/app_toast.dart';
import 'package:yupgagae/features/harugyeol/controller/harugyeol_controller.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_comment.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_day_summary.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_enums.dart';

const Color _line = Color(0xFFF0ECE8);

class HarugyeolScreen extends StatefulWidget {
  const HarugyeolScreen({super.key});

  @override
  State<HarugyeolScreen> createState() => _HarugyeolScreenState();
}

class _HarugyeolScreenState extends State<HarugyeolScreen> {
  late final TextEditingController _oneLineController;
  late final Worker _oneLineWorker;

  static const Color _accent = Color(0xFFA56E5F);
  static const Color _background = Color(0xFFF8F5F2);

  static const ScrollPhysics _scrollPhysics = AlwaysScrollableScrollPhysics(
    parent: BouncingScrollPhysics(),
  );

  @override
  void initState() {
    super.initState();

    final c = Get.find<HarugyeolController>();
    _oneLineController = TextEditingController(text: c.oneLineText.value);

    _oneLineWorker = ever<String>(c.oneLineText, (value) {
      if (_oneLineController.text == value) return;

      _oneLineController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    });
  }

  @override
  void dispose() {
    _oneLineWorker.dispose();
    _oneLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HarugyeolController>();

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Obx(() {
          final auth = c.authController;

          if (!auth.isInitialized.value) {
            return CustomScrollView(
              physics: _scrollPhysics,
              slivers: const [
                SliverToBoxAdapter(child: _LoadingCard()),
                SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            );
          }
return RefreshIndicator(
            color: _accent,
            onRefresh: c.refresh,
            child: CustomScrollView(
              physics: _scrollPhysics,
              slivers: [
                SliverToBoxAdapter(child: _Header(controller: c)),
                SliverToBoxAdapter(child: _DateSwitcher(controller: c)),
                Obx(() {
                  if (c.entryGateMode == HarugyeolEntryGateMode.loading) {
                    return const SliverToBoxAdapter(child: _LoadingCard());
                  }

                  if (c.shouldShowGateFirst) {
                    return SliverToBoxAdapter(
                      child: _GateCard(
                        controller: c,
                        oneLineController: _oneLineController,
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      _ResultCard(controller: c),
                      _GraphCard(controller: c),
                      _ReasonSummaryCard(controller: c),
                      _TopCommentsCard(controller: c),
                      _MissingSlotActionCard(
                        controller: c,
                        oneLineController: _oneLineController,
                      ),
                      _InputCard(
                        controller: c,
                        oneLineController: _oneLineController,
                      ),
                    ]),
                  );
                }),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final HarugyeolController controller;

  const _Header({required this.controller});

  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '오늘 장사 어떠신가요?',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: _text,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '현재 ${controller.nowLabel.value} · 입력한 시간대의 흐름만 볼 수 있어요.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _DateSwitcher extends StatelessWidget {
  final HarugyeolController controller;

  const _DateSwitcher({required this.controller});

  static const Color _accent = Color(0xFFA56E5F);
  static const Color _muted = Color(0xFF8B949E);

  @override
  Widget build(BuildContext context) {
    final items = const [
      _DateSwitchItem(offset: 0, label: '오늘'),
      _DateSwitchItem(offset: -1, label: '어제'),
      _DateSwitchItem(offset: -2, label: '그저께'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Obx(() {
        return Row(
          children: items.map((item) {
            final selected = controller.selectedDateOffset.value == item.offset;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => controller.selectDateOffset(item.offset),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? _accent : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? _accent : const Color(0xFFE8E1DC),
                      ),
                    ),
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : _muted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }),
    );
  }
}

class _DateSwitchItem {
  final int offset;
  final String label;

  const _DateSwitchItem({required this.offset, required this.label});
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  static const Color _accent = Color(0xFFA56E5F);

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 40, 20, 12),
      child: SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.2, color: _accent),
        ),
      ),
    );
  }
}

class _GateCard extends StatelessWidget {
  final HarugyeolController controller;
  final TextEditingController oneLineController;

  const _GateCard({required this.controller, required this.oneLineController});

  static const Color _accent = Color(0xFFA56E5F);
  static const Color _card = Colors.white;
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final writableSlots = controller.writableMissingSlots;

      if (writableSlots.isNotEmpty) {
        return _InputCard(
          controller: controller,
          oneLineController: oneLineController,
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4EE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  color: _accent,
                  size: 26,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                controller.gateTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _text,
                  height: 1.22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                controller.gateDescription,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _ResultCard extends StatelessWidget {
  final HarugyeolController controller;

  const _ResultCard({required this.controller});

  static const Color _accent = Color(0xFFA56E5F);
  static const Color _card = Colors.white;
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isSummaryLoading.value;
      final summary = controller.visibleSummary;

      final compareText = controller.todayCompareText(controller.summary.value);

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: loading
              ? const SizedBox(
                  height: 104,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: _accent,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            controller.resultTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4EE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            controller.scoreBadgeText(summary),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: _accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 112,
                          height: 72,
                          child: CustomPaint(
                            painter: _GaugePainter(
                              score: summary.averageScore,
                              accent: _accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    summary.averageScoreLabel,
                                    style: const TextStyle(
                                      fontSize: 54,
                                      fontWeight: FontWeight.w900,
                                      color: _text,
                                      height: 0.95,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '/100',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: _muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (compareText.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF4EE),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFF0D8CC),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        compareText.contains('낮')
                                            ? Icons.trending_down_rounded
                                            : Icons.trending_up_rounded,
                                        size: 15,
                                        color: _accent,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        compareText,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: _accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      );
    });
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color accent;

  _GaugePainter({required this.score, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = const Color(0xFFEDE7E2)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final valuePaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFFF5A4F), accent, const Color(0xFFFFD166)],
      ).createShader(rect)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(rect, math.pi, math.pi, false, bgPaint);

    if (score > 0) {
      final sweep = math.pi * (score.clamp(0, 100) / 100);
      canvas.drawArc(rect, math.pi, sweep, false, valuePaint);
    }

    final needleAngle = math.pi + (math.pi * (score.clamp(0, 100) / 100));
    final needleLength = radius * 0.55;
    final needleEnd = Offset(
      center.dx + math.cos(needleAngle) * needleLength,
      center.dy + math.sin(needleAngle) * needleLength,
    );

    final needlePaint = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, needleEnd, needlePaint);

    final centerPaint = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 4, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.accent != accent;
  }
}

class _GraphCard extends StatelessWidget {
  final HarugyeolController controller;

  const _GraphCard({required this.controller});

  static const Color _accent = Color(0xFFA56E5F);
  static const Color _card = Colors.white;
  static const Color _text = Color(0xFF111111);

  static const List<int> _graphHours = [
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final source =
          controller.summary.value ??
          HarugyeolDaySummary.empty(controller.selectedDateKey);

      final visibleSummary = controller.visibleSummary;

      final midday = source.slotStats[HarugyeolSlot.midday]?.averageScore ?? 0;
      final evening =
          source.slotStats[HarugyeolSlot.evening]?.averageScore ?? 0;

      final canShowMidday = controller.hasSubmittedMidday;
      final canShowEvening = controller.hasSubmittedEvening;

      final hourlyPoints = _graphHours
          .map((hour) {
            return visibleSummary.averageScoreForHour(hour);
          })
          .toList(growable: false);

      final hasHourlyData = hourlyPoints.any((value) {
        return value != null && value > 0;
      });

      final fallbackPoints = <double?>[
        canShowMidday ? midday : null,
        canShowMidday ? midday : null,
        canShowMidday ? midday : null,
        canShowMidday ? midday : null,
        canShowEvening
            ? (canShowMidday && midday > 0 && evening > 0
                  ? (midday + evening) / 2
                  : evening)
            : null,
        canShowEvening ? evening : null,
        canShowEvening ? evening : null,
      ];

      final points = hasHourlyData ? hourlyPoints : fallbackPoints;

      final flowText = canShowMidday && canShowEvening
          ? controller.flowInsightText(source)
          : '';

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '시간대별 흐름',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                visibleSummary.hasData
                    ? hasHourlyData
                          ? '입력 시각 기준으로 시간대별 평균 체감을 표시합니다.'
                          : '기존 데이터는 낮/저녁 구간 평균으로 표시됩니다.'
                    : '아직 표시할 데이터가 없어요.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 150,
                    child: _ScoreAxisLabels(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 150,
                      child: CustomPaint(
                        painter: _HarugyeolLinePainter(
                          values: points,
                          accent: _accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                children: [
                  SizedBox(width: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('11시', style: _TimeLabelStyle.style),
                          Text('13시', style: _TimeLabelStyle.style),
                          Text('15시', style: _TimeLabelStyle.style),
                          Text('17시', style: _TimeLabelStyle.style),
                          Text('19시', style: _TimeLabelStyle.style),
                          Text('21시', style: _TimeLabelStyle.style),
                          Text('자정', style: _TimeLabelStyle.style),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (!canShowMidday || !canShowEvening) ...[
                const SizedBox(height: 14),
                _LockedSlotInlineGuide(controller: controller),
              ],
              if (flowText.isNotEmpty) ...[
                const SizedBox(height: 14),
                _FlowInsightCard(mainText: flowText),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _ScoreAxisLabels extends StatelessWidget {
  const _ScoreAxisLabels();

  static const List<int> _scores = [100, 80, 60, 40, 20];

  static const double _chartTop = 6;
  static const double _chartBottom = 144;
  static const double _labelHeight = 14;
  static const double _minScore = 20;
  static const double _maxScore = 100;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: _scores
          .map((score) {
            final top = _axisTopForScore(score);

            return Positioned(
              top: top,
              left: 0,
              right: 0,
              height: _labelHeight,
              child: Text(
                '$score',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8B949E),
                  height: 1,
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  static double _axisTopForScore(int score) {
    final chartHeight = _chartBottom - _chartTop;
    final normalized = ((score - _minScore) / (_maxScore - _minScore)).clamp(
      0.0,
      1.0,
    );
    final y = _chartBottom - (chartHeight * normalized);
    final top = y - (_labelHeight / 2);

    if (top < 0) return 0;
    if (top > 150 - _labelHeight) return 150 - _labelHeight;
    return top;
  }
}

class _LockedSlotInlineGuide extends StatelessWidget {
  final HarugyeolController controller;

  const _LockedSlotInlineGuide({required this.controller});

  static const Color _accent = Color(0xFFA56E5F);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lockedSlots = HarugyeolSlot.values
          .where((slot) {
            return !controller.hasSubmittedSlot(slot);
          })
          .toList(growable: false);

      if (lockedSlots.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        children: lockedSlots.map((slot) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDE7E2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 17,
                    color: _accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.lockedSlotDescription(slot),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _TimeLabelStyle {
  static const TextStyle style = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: Color(0xFF6B7280),
  );
}

class _FlowInsightCard extends StatelessWidget {
  final String mainText;

  const _FlowInsightCard({required this.mainText});

  static const Color _accent = Color(0xFFA56E5F);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1DED5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_graph_rounded, size: 18, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mainText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5F4238),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HarugyeolLinePainter extends CustomPainter {
  final List<double?> values;
  final Color accent;

  _HarugyeolLinePainter({required this.values, required this.accent});

  static const List<int> _scoreLines = [100, 80, 60, 40, 20];

  static const double _chartTop = 6;
  static const double _chartBottomPadding = 6;
  static const double _minScore = 20;
  static const double _maxScore = 100;

  @override
  void paint(Canvas canvas, Size size) {
    final chartLeft = 6.0;
    final chartRight = size.width - 6.0;
    final chartTop = _chartTop;
    final chartBottom = size.height - _chartBottomPadding;
    final chartWidth = math.max(1.0, chartRight - chartLeft);
    final chartHeight = math.max(1.0, chartBottom - chartTop);

    final gridPaint = Paint()
      ..color = const Color(0xFFF0ECE8)
      ..strokeWidth = 1;

    for (final score in _scoreLines) {
      final y = _yForScore(
        score.toDouble(),
        chartTop: chartTop,
        chartBottom: chartBottom,
        chartHeight: chartHeight,
      );

      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
    }

    final validIndexes = <int>[];

    for (int i = 0; i < values.length; i++) {
      final value = values[i];
      if (value != null && value > 0) {
        validIndexes.add(i);
      }
    }

    if (validIndexes.isEmpty) {
      final emptyPaint = Paint()
        ..color = const Color(0xFFE5E7EB)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      final y = _yForScore(
        40,
        chartTop: chartTop,
        chartBottom: chartBottom,
        chartHeight: chartHeight,
      );

      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), emptyPaint);
      return;
    }

    final points = <Offset>[];

    for (final index in validIndexes) {
      final value = values[index] ?? 0;
      final x = values.length <= 1
          ? chartLeft + chartWidth / 2
          : chartLeft + chartWidth * (index / math.max(1, values.length - 1));

      final y = _yForScore(
        value,
        chartTop: chartTop,
        chartBottom: chartBottom,
        chartHeight: chartHeight,
      );

      points.add(Offset(x, y));
    }

    if (points.length == 1) {
      final pointPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final pointBorderPaint = Paint()
        ..color = accent
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(points.first, 5.5, pointPaint);
      canvas.drawCircle(points.first, 5.5, pointBorderPaint);
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final midX = (prev.dx + current.dx) / 2;

      path.cubicTo(midX, prev.dy, midX, current.dy, current.dx, current.dy);
    }

    final areaPath = Path.from(path)
      ..lineTo(points.last.dx, chartBottom)
      ..lineTo(points.first.dx, chartBottom)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.18),
          accent.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, chartTop, size.width, chartHeight));

    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final point in points) {
      canvas.drawCircle(point, 5, pointPaint);
      canvas.drawCircle(point, 5, pointBorderPaint);
    }
  }

  double _yForScore(
    double score, {
    required double chartTop,
    required double chartBottom,
    required double chartHeight,
  }) {
    final safeScore = score.clamp(_minScore, _maxScore);
    final normalized = (safeScore - _minScore) / (_maxScore - _minScore);

    return chartBottom - (chartHeight * normalized);
  }

  @override
  bool shouldRepaint(covariant _HarugyeolLinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.accent != accent;
  }
}

class _ReasonSummaryCard extends StatelessWidget {
  final HarugyeolController controller;

  const _ReasonSummaryCard({required this.controller});

  static const Color _card = Colors.white;
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final summary = controller.visibleSummary;

      final reasonEntries = controller.visibleReasonRankEntries(summary);
      final topRow = reasonEntries.take(5).toList(growable: false);
      final bottomRow = reasonEntries.skip(5).take(5).toList(growable: false);

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.reasonTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                controller.reasonDescription,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 16),
              if (!summary.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '아직 표시할 이유 데이터가 없어요.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                    ),
                  ),
                )
              else ...[
                _ReasonRankRowGroup(entries: topRow, startRank: 1),
                const SizedBox(height: 10),
                _ReasonRankRowGroup(entries: bottomRow, startRank: 6),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _ReasonRankRowGroup extends StatelessWidget {
  final List<MapEntry<HarugyeolReason, int>> entries;
  final int startRank;

  const _ReasonRankRowGroup({required this.entries, required this.startRank});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        if (index >= entries.length) {
          return const Expanded(child: SizedBox.shrink());
        }

        final entry = entries[index];

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 4 ? 0 : 6),
            child: _ReasonRankTile(
              rank: startRank + index,
              reason: entry.key,
              count: entry.value,
            ),
          ),
        );
      }),
    );
  }
}

class _ReasonRankTile extends StatelessWidget {
  final int rank;
  final HarugyeolReason reason;
  final int count;

  const _ReasonRankTile({
    required this.rank,
    required this.reason,
    required this.count,
  });

  static const Color _accent = Color(0xFFA56E5F);
  static const Color _text = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    final reasonColor = _reasonColor(reason);
    final disabled = count <= 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      height: 82,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 7),
      decoration: BoxDecoration(
        color: disabled
            ? const Color(0xFFF8F8F8)
            : reasonColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: disabled
              ? const Color(0xFFEDE7E2)
              : reasonColor.withValues(alpha: 0.28),
        ),
      ),
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: reasonColor.withValues(alpha: 0.18),
                        blurRadius: 9,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _reasonIcon(reason),
                    size: 20,
                    color: reasonColor,
                  ),
                ),
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rank <= 3 ? _accent : const Color(0xFF6B7280),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 13,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  reason.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _text,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopCommentsCard extends StatelessWidget {
  final HarugyeolController controller;

  const _TopCommentsCard({required this.controller});

  static const Color _card = Colors.white;
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _accent = Color(0xFFA56E5F);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isCommentsLoading.value;
      final comments = controller.visibleTopComments;

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -2,
                right: -4,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showAllComments(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '더보기',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _muted,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: _muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 74),
                    child: Text(
                      '오늘의 한마디 TOP 3',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (loading)
                    const SizedBox(
                      height: 70,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: _accent,
                        ),
                      ),
                    )
                  else if (comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        '입력한 시간대에 등록된 한마디가 아직 없어요.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                        ),
                      ),
                    )
                  else
                    ...comments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final comment = entry.value;
                      final isLast = index == comments.length - 1;

                      return _TopCommentRow(
                        rank: index + 1,
                        comment: comment,
                        isLast: isLast,
                        onLike: () async {
                          try {
                            await controller.toggleCommentLike(comment);
                          } catch (e) {
                            AppToast.show(
                              controller.errorMessage.value ?? '$e',
                              title: '실패',
                              isError: true,
                            );
                          }
                        },
                      );
                    }),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showAllComments(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return _AllCommentsSheet(controller: controller);
      },
    );
  }
}

class _MissingSlotActionCard extends StatelessWidget {
  final HarugyeolController controller;
  final TextEditingController oneLineController;

  const _MissingSlotActionCard({
    required this.controller,
    required this.oneLineController,
  });

  static const Color _card = Colors.white;
  static const Color _accent = Color(0xFFA56E5F);
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final writableSlots = controller.writableMissingSlots;

      if (writableSlots.isEmpty) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '아직 잠긴 흐름이 있어요',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '추가로 체감을 남기면 해당 시간대 데이터도 열립니다.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 12),
              ...writableSlots.map((slot) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => controller.selectInputSlot(slot),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _accent,
                        side: const BorderSide(color: Color(0xFFF0D8CC)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        '${slot.shortLabel} 체감 입력하고 ${slot.shortLabel} 데이터 보기',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    });
  }
}

enum _CommentSortMode { like, latest }

class _AllCommentsSheet extends StatefulWidget {
  final HarugyeolController controller;

  const _AllCommentsSheet({required this.controller});

  @override
  State<_AllCommentsSheet> createState() => _AllCommentsSheetState();
}

class _AllCommentsSheetState extends State<_AllCommentsSheet> {
  _CommentSortMode _sortMode = _CommentSortMode.like;

  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _accent = Color(0xFFA56E5F);

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Obx(() {
            final comments = _sortedComments(controller.visibleComments);

            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '오늘의 한마디',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _text,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: _muted),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      _SortChip(
                        label: '좋아요순',
                        selected: _sortMode == _CommentSortMode.like,
                        onTap: () {
                          setState(() {
                            _sortMode = _CommentSortMode.like;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _SortChip(
                        label: '최신순',
                        selected: _sortMode == _CommentSortMode.latest,
                        onTap: () {
                          setState(() {
                            _sortMode = _CommentSortMode.latest;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: comments.isEmpty
                      ? const Center(
                          child: Text(
                            '입력한 시간대에 등록된 한마디가 아직 없어요.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _muted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: comments.length,
                          separatorBuilder: (_, __) {
                            return const Divider(
                              height: 1,
                              color: Color(0xFFF0ECE8),
                            );
                          },
                          itemBuilder: (context, index) {
                            final comment = comments[index];

                            return _AllCommentRow(
                              rank: index + 1,
                              comment: comment,
                              onLike: () async {
                                try {
                                  await controller.toggleCommentLike(comment);
                                } catch (e) {
                                  AppToast.show(
                                    controller.errorMessage.value ?? '$e',
                                    title: '실패',
                                    isError: true,
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          });
        },
      ),
    );
  }

  List<HarugyeolComment> _sortedComments(List<HarugyeolComment> source) {
    final list = source.toList();

    switch (_sortMode) {
      case _CommentSortMode.like:
        list.sort((a, b) {
          final likeCompare = b.likeCount.compareTo(a.likeCount);
          if (likeCompare != 0) return likeCompare;

          return b.createdAt.compareTo(a.createdAt);
        });
        return list;

      case _CommentSortMode.latest:
        list.sort((a, b) {
          final dateCompare = b.createdAt.compareTo(a.createdAt);
          if (dateCompare != 0) return dateCompare;

          return b.likeCount.compareTo(a.likeCount);
        });
        return list;
    }
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color _accent = Color(0xFFA56E5F);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _accent : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _accent : const Color(0xFFEDE7E2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _AllCommentRow extends StatelessWidget {
  final int rank;
  final HarugyeolComment comment;
  final VoidCallback onLike;

  const _AllCommentRow({
    required this.rank,
    required this.comment,
    required this.onLike,
  });

  static const Color _accent = Color(0xFFA56E5F);
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$rank',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: _accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              comment.text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _text,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLike,
            child: Row(
              children: [
                Icon(
                  comment.isLikedByMe
                      ? Icons.favorite
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: comment.isLikedByMe ? _accent : _muted,
                ),
                const SizedBox(width: 3),
                Text(
                  '${comment.likeCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCommentRow extends StatelessWidget {
  final int rank;
  final HarugyeolComment comment;
  final bool isLast;
  final VoidCallback onLike;

  const _TopCommentRow({
    required this.rank,
    required this.comment,
    required this.isLast,
    required this.onLike,
  });

  static const Color _accent = Color(0xFFA56E5F);
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 12, bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4EE),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              comment.text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _text,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLike,
            child: Row(
              children: [
                Icon(
                  comment.isLikedByMe
                      ? Icons.favorite
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: comment.isLikedByMe ? _accent : _muted,
                ),
                const SizedBox(width: 3),
                Text(
                  '${comment.likeCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputStepStatusBar extends StatelessWidget {
  final HarugyeolController controller;
  final HarugyeolSlot? selectedSlot;

  const _InputStepStatusBar({
    required this.controller,
    required this.selectedSlot,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InputStepPill(
            label: '낮 장사',
            status: _statusText(HarugyeolSlot.midday),
            isCurrent: _isCurrent(HarugyeolSlot.midday),
            isDone: controller.hasSubmittedSlot(HarugyeolSlot.midday),
            isLocked: _isLocked(HarugyeolSlot.midday),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InputStepPill(
            label: '저녁 장사',
            status: _statusText(HarugyeolSlot.evening),
            isCurrent: _isCurrent(HarugyeolSlot.evening),
            isDone: controller.hasSubmittedSlot(HarugyeolSlot.evening),
            isLocked: _isLocked(HarugyeolSlot.evening),
          ),
        ),
      ],
    );
  }

  bool _isCurrent(HarugyeolSlot slot) {
    return selectedSlot == slot && !controller.hasSubmittedSlot(slot);
  }

  bool _isLocked(HarugyeolSlot slot) {
    if (controller.hasSubmittedSlot(slot)) return false;
    if (_isCurrent(slot)) return false;
    return !controller.availableInputSlots.contains(slot);
  }

  String _statusText(HarugyeolSlot slot) {
    if (controller.hasSubmittedSlot(slot)) {
      return '완료';
    }

    if (_isCurrent(slot)) {
      return '입력 중';
    }

    if (_isLocked(slot)) {
      return slot == HarugyeolSlot.evening ? '17:01부터' : '대기';
    }

    return '남음';
  }
}

class _InputStepPill extends StatelessWidget {
  final String label;
  final String status;
  final bool isCurrent;
  final bool isDone;
  final bool isLocked;

  const _InputStepPill({
    required this.label,
    required this.status,
    required this.isCurrent,
    required this.isDone,
    required this.isLocked,
  });

  static const Color _accent = Color(0xFFA56E5F);
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final background = isCurrent
        ? const Color(0xFFFFF4EE)
        : isDone
        ? const Color(0xFFF4F8F3)
        : const Color(0xFFF8F8F8);

    final borderColor = isCurrent
        ? _accent
        : isDone
        ? const Color(0xFFBFD8B8)
        : const Color(0xFFEDE7E2);

    final icon = isDone
        ? Icons.check_circle_rounded
        : isCurrent
        ? Icons.edit_rounded
        : Icons.radio_button_unchecked_rounded;

    final iconColor = isCurrent
        ? _accent
        : isDone
        ? const Color(0xFF5E8F57)
        : _muted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isCurrent ? 1.4 : 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isLocked ? _muted : _text,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: iconColor,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final HarugyeolController controller;
  final TextEditingController oneLineController;

  const _InputCard({required this.controller, required this.oneLineController});

  static const Color _accent = Color(0xFFA56E5F);
  static const Color _card = Colors.white;
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final canSubmit = controller.canSubmit;
      final inputEnabled = controller.isInputEnabled;
      final selectedSlot = controller.selectedInputSlot.value;
      final writableSlots = controller.writableMissingSlots;

      if (writableSlots.isEmpty && selectedSlot == null) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InputStepStatusBar(
                controller: controller,
                selectedSlot: selectedSlot,
              ),
              const SizedBox(height: 18),
              Text(
                _inputCardTitleText(selectedSlot),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _text,
                  height: 1.18,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _inputCardDescriptionText(
                  controller: controller,
                  selectedSlot: selectedSlot,
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _muted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _inputTimeGuideText(selectedSlot),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _muted,
                  height: 1.35,
                ),
              ),
              if (writableSlots.length > 1) ...[
                const SizedBox(height: 14),
                Row(
                  children: writableSlots.map((slot) {
                    final selected = selectedSlot == slot;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: slot == writableSlots.last ? 0 : 8,
                        ),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => controller.selectInputSlot(slot),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            curve: Curves.easeOut,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFFFF4EE)
                                  : const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected ? _accent : _line,
                              ),
                            ),
                            child: Text(
                              _slotChoiceText(slot),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: selected ? _accent : _muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 18),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: inputEnabled ? 1 : 0.46,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MoodSelector(
                      controller: controller,
                      enabled: inputEnabled,
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: _line),
                    const SizedBox(height: 20),
                    const Text(
                      '이유 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '복수 선택 가능',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ReasonSelector(
                      controller: controller,
                      enabled: inputEnabled,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '오늘의 한마디',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '선택사항입니다.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: oneLineController,
                      enabled: inputEnabled,
                      maxLines: 1,
                      maxLength: HarugyeolController.maxOneLineLength,
                      onChanged: controller.changeOneLineText,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: inputEnabled ? '예: 오늘 힘들어도 다들 파이팅~' : '',
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFB0B8C1),
                          fontWeight: FontWeight.w600,
                        ),
                        filled: true,
                        fillColor: inputEnabled
                            ? const Color(0xFFFAFAFA)
                            : const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _line),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: canSubmit
                      ? () async {
                          try {
                            await controller.submit();
                            AppToast.show('하루결을 남겼어요.', title: '완료');
                          } catch (e) {
                            AppToast.show(
                              controller.errorMessage.value ?? '$e',
                              title: '실패',
                              isError: true,
                            );
                          }
                        }
                      : () {
                          AppToast.show(
                            controller.submitBlockedMessage,
                            title: '안내',
                            isError: true,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: canSubmit
                        ? _accent
                        : const Color(0xFFE5E7EB),
                    foregroundColor: canSubmit
                        ? Colors.white
                        : const Color(0xFF9CA3AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: controller.isSubmitting.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          selectedSlot == null
                              ? '등록하기'
                              : _submitButtonText(selectedSlot),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

String _inputCardTitleText(HarugyeolSlot? slot) {
  if (slot == HarugyeolSlot.midday) {
    return '낮 장사 입력';
  }

  if (slot == HarugyeolSlot.evening) {
    return '저녁 장사 입력';
  }

  return '오늘 체감 입력';
}

String _inputCardDescriptionText({
  required HarugyeolController controller,
  required HarugyeolSlot? selectedSlot,
}) {
  if (selectedSlot == HarugyeolSlot.evening &&
      controller.hasSubmittedSlot(HarugyeolSlot.midday) &&
      !controller.hasSubmittedSlot(HarugyeolSlot.evening)) {
    return '낮 장사는 완료됐어요. 지금은 저녁 장사 입력이에요.';
  }

  if (selectedSlot == HarugyeolSlot.midday &&
      !controller.hasSubmittedSlot(HarugyeolSlot.midday) &&
      controller.availableInputSlots.contains(HarugyeolSlot.evening)) {
    return '지금은 낮 장사 입력이에요. 완료하면 저녁 장사도 이어서 남길 수 있어요.';
  }

  if (selectedSlot == HarugyeolSlot.midday) {
    return '오늘 낮 분위기를 남기면 낮 시간대 흐름이 열려요.';
  }

  if (selectedSlot == HarugyeolSlot.evening) {
    return '오늘 저녁 분위기를 남기면 저녁 시간대 흐름이 열려요.';
  }

  return '낮과 저녁을 나눠 입력해요. 입력한 시간대 데이터만 열려요.';
}

String _inputTimeGuideText(HarugyeolSlot? slot) {
  if (slot == HarugyeolSlot.midday) {
    return '낮 장사 · 오늘 낮 분위기를 자정 전까지 남길 수 있어요.';
  }

  if (slot == HarugyeolSlot.evening) {
    return '저녁 장사 · 오후 5시 1분부터 자정 전까지 남길 수 있어요.';
  }

  return '낮 장사 11:00~24:00 · 저녁 장사 17:01~24:00';
}

String _submitButtonText(HarugyeolSlot slot) {
  if (slot == HarugyeolSlot.midday) {
    return '낮 장사 등록하기';
  }

  if (slot == HarugyeolSlot.evening) {
    return '저녁 장사 등록하기';
  }

  return '등록하기';
}

String _slotChoiceText(HarugyeolSlot slot) {
  if (slot == HarugyeolSlot.midday) {
    return '낮 장사';
  }

  if (slot == HarugyeolSlot.evening) {
    return '저녁 장사';
  }

  return slot.shortLabel;
}

class _MoodSelector extends StatelessWidget {
  final HarugyeolController controller;
  final bool enabled;

  const _MoodSelector({required this.controller, required this.enabled});

  static const Color _accent = Color(0xFFA56E5F);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 9,
        childAspectRatio: 0.66,
        children: HarugyeolMood.values.map((mood) {
          final selected = controller.selectedMood.value == mood;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => controller.selectMood(mood) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFF4EE) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? _accent : _line,
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_moodEmoji(mood), style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 7),
                  Text(
                    mood.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: selected ? _accent : const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${mood.score}점',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _ReasonSelector extends StatelessWidget {
  final HarugyeolController controller;
  final bool enabled;

  const _ReasonSelector({required this.controller, required this.enabled});

  static const Color _accent = Color(0xFFA56E5F);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Wrap(
        spacing: 8,
        runSpacing: 10,
        children: HarugyeolReason.values.map((reason) {
          final selected = controller.selectedReasons.contains(reason);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => controller.toggleReason(reason) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: BoxDecoration(
                color: selected ? _accent : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? _accent : const Color(0xFFEDE7E2),
                ),
              ),
              child: Text(
                reason.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : const Color(0xFF374151),
                  height: 1.15,
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

String _moodEmoji(HarugyeolMood mood) {
  switch (mood) {
    case HarugyeolMood.slow:
      return '💤';
    case HarugyeolMood.normal:
      return '🌿';
    case HarugyeolMood.good:
      return '☀️';
    case HarugyeolMood.great:
      return '🔥';
  }
}

IconData _reasonIcon(HarugyeolReason reason) {
  switch (reason) {
    case HarugyeolReason.economy:
      return Icons.query_stats_rounded;
    case HarugyeolReason.weekdayHoliday:
      return Icons.event_available_rounded;
    case HarugyeolReason.delivery:
      return Icons.delivery_dining_rounded;
    case HarugyeolReason.localMood:
      return Icons.storefront_rounded;
    case HarugyeolReason.event:
      return Icons.celebration_rounded;
    case HarugyeolReason.groupGuest:
      return Icons.groups_2_rounded;
    case HarugyeolReason.rudeGuest:
      return Icons.report_problem_rounded;
    case HarugyeolReason.unexpectedGood:
      return Icons.bolt_rounded;
    case HarugyeolReason.weather:
      return Icons.wb_sunny_rounded;
    case HarugyeolReason.etc:
      return Icons.more_horiz_rounded;
  }
}

Color _reasonColor(HarugyeolReason reason) {
  switch (reason) {
    case HarugyeolReason.economy:
      return const Color(0xFF64748B);
    case HarugyeolReason.weekdayHoliday:
      return const Color(0xFF6366F1);
    case HarugyeolReason.delivery:
      return const Color(0xFF0EA5E9);
    case HarugyeolReason.localMood:
      return const Color(0xFFA56E5F);
    case HarugyeolReason.event:
      return const Color(0xFFF59E0B);
    case HarugyeolReason.groupGuest:
      return const Color(0xFF10B981);
    case HarugyeolReason.rudeGuest:
      return const Color(0xFFDC2626);
    case HarugyeolReason.unexpectedGood:
      return const Color(0xFF8B5CF6);
    case HarugyeolReason.weather:
      return const Color(0xFFF97316);
    case HarugyeolReason.etc:
      return const Color(0xFF6B7280);
  }
}

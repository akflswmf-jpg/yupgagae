import 'package:yupgagae/features/revenue/domain/revenue_entry.dart';
import 'package:yupgagae/features/revenue/domain/revenue_monthly_total_entry.dart';

enum RevenueComparisonMode {
  dailyMonthTotal,
  monthlyTotal,
}

extension RevenueComparisonModeX on RevenueComparisonMode {
  String get key {
    switch (this) {
      case RevenueComparisonMode.dailyMonthTotal:
        return 'dailyMonthTotal';
      case RevenueComparisonMode.monthlyTotal:
        return 'monthlyTotal';
    }
  }
}

class RevenueMarketRecord {
  final String storeId;
  final String region;
  final String industry;
  final DateTime date;
  final int amount;

  const RevenueMarketRecord({
    required this.storeId,
    required this.region,
    required this.industry,
    required this.date,
    required this.amount,
  });
}

class RevenueComparisonSummary {
  final RevenueComparisonMode mode;
  final DateTime from;
  final DateTime to;

  final int? industryAverage;
  final int? regionAverage;
  final int? topPercent;

  final bool isOutlier;
  final bool isTopOutlier;
  final bool isBottomOutlier;

  final String? outlierGuideMessage;

  /// 비교 기준이 된 업종 표본 수.
  /// 서버 전환 후에는 "가게 수" 또는 "충분히 익명화된 집계 단위 수"로 해석한다.
  final int industrySampleSize;

  /// 비교 기준이 된 지역 표본 수.
  final int regionSampleSize;

  const RevenueComparisonSummary({
    required this.mode,
    required this.from,
    required this.to,
    required this.industryAverage,
    required this.regionAverage,
    required this.topPercent,
    required this.isOutlier,
    required this.isTopOutlier,
    required this.isBottomOutlier,
    required this.outlierGuideMessage,
    required this.industrySampleSize,
    required this.regionSampleSize,
  });

  factory RevenueComparisonSummary.empty({
    required RevenueComparisonMode mode,
    required DateTime from,
    required DateTime to,
  }) {
    return RevenueComparisonSummary(
      mode: mode,
      from: from,
      to: to,
      industryAverage: null,
      regionAverage: null,
      topPercent: null,
      isOutlier: false,
      isTopOutlier: false,
      isBottomOutlier: false,
      outlierGuideMessage: null,
      industrySampleSize: 0,
      regionSampleSize: 0,
    );
  }
}

class RevenueWeeklyComparisonPoint {
  final DateTime weekStart;
  final DateTime weekEnd;
  final String label;

  /// 내 주간 매출 합계.
  final int myTotal;

  /// 같은 업종의 주간 매출 합계 평균.
  /// daily record 평균이 아니라 store별 주간 합계의 평균이다.
  final int industryAverage;

  final int sampleSize;

  const RevenueWeeklyComparisonPoint({
    required this.weekStart,
    required this.weekEnd,
    required this.label,
    required this.myTotal,
    required this.industryAverage,
    required this.sampleSize,
  });
}

abstract class RevenueRepository {
  Future<List<RevenueEntry>> fetchDailyEntries();

  Future<List<RevenueMonthlyTotalEntry>> fetchMonthlyTotalEntries();

  /// 서버형 계약:
  /// 저장 후 서버/Repository가 확정한 id, date, amount, isClosed를 가진 엔트리를 반환한다.
  /// Controller는 임시 ID를 만들지 않고 이 반환값을 그대로 반영한다.
  Future<RevenueEntry> saveDailyEntry({
    required DateTime date,
    required int? amount,
    required bool isClosed,
  });

  /// 서버형 계약:
  /// 저장 후 서버/Repository가 확정한 id, month, amount를 가진 엔트리를 반환한다.
  Future<RevenueMonthlyTotalEntry> saveMonthlyTotalEntry({
    required DateTime month,
    required int amount,
  });

  Future<void> deleteDailyEntry({
    required DateTime date,
  });

  Future<void> deleteMonthlyTotalEntry({
    required DateTime month,
  });

  /// 현재 로컬/시드 데이터용 계약.
  /// 서버 전환 후에는 원자료 전체를 클라이언트로 내려주기보다
  /// 업종/지역/기간 기준 집계값을 내려주는 계약으로 분리하는 것이 맞다.
  Future<List<RevenueMarketRecord>> fetchMarketRecords({
    required DateTime from,
    required DateTime to,
  });

  /// 서버형 비교 계약:
  /// 클라이언트가 시장 원자료 전체를 받지 않고,
  /// 서버/Repository가 업종·지역·기간 기준으로 계산한 요약값만 받는다.
  ///
  /// 중요:
  /// industryAverage / regionAverage는 daily record 평균이 아니라
  /// 기간 내 store별 매출 합계의 trimmed average다.
  Future<RevenueComparisonSummary> fetchComparisonSummary({
    required RevenueComparisonMode mode,
    required String industry,
    required String region,
    required DateTime from,
    required DateTime to,
    required int myAmount,
  });

  /// 서버형 최근 4주 추세 계약:
  /// 원자료 전체가 아니라 주차별 집계 결과만 받는다.
  ///
  /// 중요:
  /// industryAverage는 daily record 평균이 아니라
  /// store별 주간 합계의 trimmed average다.
  Future<List<RevenueWeeklyComparisonPoint>> fetchRecentWeeklyComparison({
    required String industry,
    required DateTime today,
    required List<RevenueEntry> myDailyEntries,
  });
}
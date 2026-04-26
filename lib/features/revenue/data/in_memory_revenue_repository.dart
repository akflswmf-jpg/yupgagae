import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/community/domain/region_catalog.dart';
import 'package:yupgagae/features/revenue/domain/revenue_entry.dart';
import 'package:yupgagae/features/revenue/domain/revenue_monthly_total_entry.dart';
import 'package:yupgagae/features/revenue/domain/revenue_repository.dart';

class InMemoryRevenueRepository implements RevenueRepository {
  static const String _legacyEntriesKey = 'revenue.entries.v2';
  static const String _dailyEntriesKey = 'revenue.daily_entries.v3';
  static const String _monthlyTotalsKey = 'revenue.monthly_totals.v3';

  static const int _trimPercent = 5;
  static const int _trimMinSampleSize = 40;

  final List<RevenueEntry> _dailyEntries = [];
  final List<RevenueMonthlyTotalEntry> _monthlyTotalEntries = [];

  bool _loaded = false;
  int _seed = 1000;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();
    final rawDaily = prefs.getString(_dailyEntriesKey);
    final rawMonthly = prefs.getString(_monthlyTotalsKey);

    if (rawDaily != null || rawMonthly != null) {
      if (rawDaily != null) {
        final decoded = jsonDecode(rawDaily) as List<dynamic>;
        _dailyEntries
          ..clear()
          ..addAll(
            decoded.map(
              (e) => RevenueEntry.fromJson(Map<String, dynamic>.from(e)),
            ),
          );
      }

      if (rawMonthly != null) {
        final decoded = jsonDecode(rawMonthly) as List<dynamic>;
        _monthlyTotalEntries
          ..clear()
          ..addAll(
            decoded.map(
              (e) => RevenueMonthlyTotalEntry.fromJson(
                Map<String, dynamic>.from(e),
              ),
            ),
          );
      }

      _seed = _deriveSeed();
      _loaded = true;
      return;
    }

    final rawLegacy = prefs.getString(_legacyEntriesKey);
    if (rawLegacy != null) {
      final decoded = jsonDecode(rawLegacy) as List<dynamic>;

      for (final item in decoded) {
        final json = Map<String, dynamic>.from(item);
        final type = json['type'] as String? ?? 'daily';

        if (type == 'monthlyTotal') {
          final month = DateTime.parse(json['date'] as String);
          final amount = json['amount'] as int?;

          if (amount != null) {
            _monthlyTotalEntries.add(
              RevenueMonthlyTotalEntry(
                id: json['id'] as String,
                month: DateTime(month.year, month.month, 1),
                amount: amount,
              ),
            );
          }
        } else {
          _dailyEntries.add(
            RevenueEntry(
              id: json['id'] as String,
              date: DateTime.parse(json['date'] as String),
              amount: json['amount'] as int?,
              isClosed: json['isClosed'] as bool? ?? false,
            ),
          );
        }
      }

      _seed = _deriveSeed();
      await _persist();
      _loaded = true;
      return;
    }

    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();

    final rawDaily = jsonEncode(
      _dailyEntries.map((e) => e.toJson()).toList(),
    );

    final rawMonthly = jsonEncode(
      _monthlyTotalEntries.map((e) => e.toJson()).toList(),
    );

    await prefs.setString(_dailyEntriesKey, rawDaily);
    await prefs.setString(_monthlyTotalsKey, rawMonthly);
  }

  int _deriveSeed() {
    int maxSeed = 1000;

    for (final id in [
      ..._dailyEntries.map((e) => e.id),
      ..._monthlyTotalEntries.map((e) => e.id),
    ]) {
      final parts = id.split('_');
      if (parts.length < 2) continue;

      final parsed = int.tryParse(parts.last);
      if (parsed != null && parsed > maxSeed) {
        maxSeed = parsed;
      }
    }

    return maxSeed;
  }

  String _nextId() {
    _seed++;
    return 'revenue_$_seed';
  }

  @override
  Future<List<RevenueEntry>> fetchDailyEntries() async {
    await _ensureLoaded();

    final copied = [..._dailyEntries];
    copied.sort((a, b) => b.date.compareTo(a.date));
    return copied;
  }

  @override
  Future<List<RevenueMonthlyTotalEntry>> fetchMonthlyTotalEntries() async {
    await _ensureLoaded();

    final copied = [..._monthlyTotalEntries];
    copied.sort((a, b) => b.month.compareTo(a.month));
    return copied;
  }

  @override
  Future<RevenueEntry> saveDailyEntry({
    required DateTime date,
    required int? amount,
    required bool isClosed,
  }) async {
    await _ensureLoaded();

    final dayKey = DateTime(date.year, date.month, date.day);

    final existing = _dailyEntries.firstWhere(
      (e) {
        return e.date.year == dayKey.year &&
            e.date.month == dayKey.month &&
            e.date.day == dayKey.day;
      },
      orElse: () => RevenueEntry(
        id: _nextId(),
        date: dayKey,
        amount: isClosed ? null : amount,
        isClosed: isClosed,
      ),
    );

    _dailyEntries.removeWhere((e) {
      return e.date.year == dayKey.year &&
          e.date.month == dayKey.month &&
          e.date.day == dayKey.day;
    });

    final saved = RevenueEntry(
      id: existing.id,
      date: dayKey,
      amount: isClosed ? null : amount,
      isClosed: isClosed,
    );

    _dailyEntries.add(saved);

    await _persist();

    return saved;
  }

  @override
  Future<RevenueMonthlyTotalEntry> saveMonthlyTotalEntry({
    required DateTime month,
    required int amount,
  }) async {
    await _ensureLoaded();

    final monthKey = DateTime(month.year, month.month, 1);

    final existing = _monthlyTotalEntries.firstWhere(
      (e) {
        return e.month.year == monthKey.year && e.month.month == monthKey.month;
      },
      orElse: () => RevenueMonthlyTotalEntry(
        id: _nextId(),
        month: monthKey,
        amount: amount,
      ),
    );

    _monthlyTotalEntries.removeWhere((e) {
      return e.month.year == monthKey.year && e.month.month == monthKey.month;
    });

    final saved = RevenueMonthlyTotalEntry(
      id: existing.id,
      month: monthKey,
      amount: amount,
    );

    _monthlyTotalEntries.add(saved);

    await _persist();

    return saved;
  }

  @override
  Future<void> deleteDailyEntry({
    required DateTime date,
  }) async {
    await _ensureLoaded();

    final dayKey = DateTime(date.year, date.month, date.day);

    _dailyEntries.removeWhere((e) {
      return e.date.year == dayKey.year &&
          e.date.month == dayKey.month &&
          e.date.day == dayKey.day;
    });

    await _persist();
  }

  @override
  Future<void> deleteMonthlyTotalEntry({
    required DateTime month,
  }) async {
    await _ensureLoaded();

    final monthKey = DateTime(month.year, month.month, 1);

    _monthlyTotalEntries.removeWhere((e) {
      return e.month.year == monthKey.year && e.month.month == monthKey.month;
    });

    await _persist();
  }

  final List<RevenueMarketRecord> _marketRecords = _buildMarketRecords();

  @override
  Future<List<RevenueMarketRecord>> fetchMarketRecords({
    required DateTime from,
    required DateTime to,
  }) async {
    final start = _dateOnly(from);
    final end = _dateOnly(to);

    return _marketRecords.where((record) {
      final d = _dateOnly(record.date);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
  }

  @override
  Future<RevenueComparisonSummary> fetchComparisonSummary({
    required RevenueComparisonMode mode,
    required String industry,
    required String region,
    required DateTime from,
    required DateTime to,
    required int myAmount,
  }) async {
    final normalizedIndustry = industry.trim();
    final normalizedRegion = region.trim();

    final start = _dateOnly(from);
    final end = _dateOnly(to);

    if (normalizedIndustry.isEmpty ||
        normalizedIndustry == '-' ||
        normalizedRegion.isEmpty ||
        normalizedRegion == '-') {
      return RevenueComparisonSummary.empty(
        mode: mode,
        from: start,
        to: end,
      );
    }

    final market = await fetchMarketRecords(
      from: start,
      to: end,
    );

    final industryTotalsByStore = _sumByStore(
      market.where((e) => e.industry == normalizedIndustry),
    );

    final regionTotalsByStore = _sumByStore(
      market.where((e) => e.region == normalizedRegion),
    );

    final industryValues = industryTotalsByStore.values
        .where((amount) => amount > 0)
        .toList(growable: false);

    final regionValues = regionTotalsByStore.values
        .where((amount) => amount > 0)
        .toList(growable: false);

    final industryAverage = _trimmedAverage(industryValues);
    final regionAverage = _trimmedAverage(regionValues);

    final topPercent = _topPercent(
      values: industryValues,
      myAmount: myAmount,
    );

    final outlierState = _outlierState(
      values: industryValues,
      myAmount: myAmount,
    );

    final outlierGuideMessage = _outlierGuideMessage(
      topPercent: topPercent,
      isTopOutlier: outlierState.isTopOutlier,
      isBottomOutlier: outlierState.isBottomOutlier,
    );

    return RevenueComparisonSummary(
      mode: mode,
      from: start,
      to: end,
      industryAverage: industryAverage,
      regionAverage: regionAverage,
      topPercent: topPercent,
      isOutlier: outlierState.isOutlier,
      isTopOutlier: outlierState.isTopOutlier,
      isBottomOutlier: outlierState.isBottomOutlier,
      outlierGuideMessage: outlierGuideMessage,
      industrySampleSize: industryValues.length,
      regionSampleSize: regionValues.length,
    );
  }

  @override
  Future<List<RevenueWeeklyComparisonPoint>> fetchRecentWeeklyComparison({
    required String industry,
    required DateTime today,
    required List<RevenueEntry> myDailyEntries,
  }) async {
    final normalizedIndustry = industry.trim();
    if (normalizedIndustry.isEmpty || normalizedIndustry == '-') {
      return const <RevenueWeeklyComparisonPoint>[];
    }

    final normalizedToday = _dateOnly(today);
    final currentWeekStart = _startOfWeek(normalizedToday);

    final from = currentWeekStart.subtract(const Duration(days: 21));
    final to = currentWeekStart.add(const Duration(days: 6));

    final market = await fetchMarketRecords(
      from: from,
      to: to,
    );

    final points = <RevenueWeeklyComparisonPoint>[];

    for (int i = 3; i >= 0; i--) {
      final weekStart = currentWeekStart.subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final myTotal = myDailyEntries
          .where(
            (entry) =>
                !entry.isClosed &&
                entry.amount != null &&
                !_dateOnly(entry.date).isBefore(weekStart) &&
                !_dateOnly(entry.date).isAfter(weekEnd),
          )
          .fold<int>(0, (sum, entry) => sum + (entry.amount ?? 0));

      final industryWeekRecords = market.where(
        (record) =>
            record.industry == normalizedIndustry &&
            !_dateOnly(record.date).isBefore(weekStart) &&
            !_dateOnly(record.date).isAfter(weekEnd) &&
            record.amount > 0,
      );

      final storeTotals = _sumByStore(industryWeekRecords);
      final values = storeTotals.values
          .where((amount) => amount > 0)
          .toList(growable: false);

      final industryAverage = _trimmedAverage(values) ?? 0;

      points.add(
        RevenueWeeklyComparisonPoint(
          weekStart: weekStart,
          weekEnd: weekEnd,
          label: _buildWeekLabel(weekStart, weekEnd),
          myTotal: myTotal,
          industryAverage: industryAverage,
          sampleSize: values.length,
        ),
      );
    }

    return points;
  }

  Map<String, int> _sumByStore(Iterable<RevenueMarketRecord> records) {
    final result = <String, int>{};

    for (final record in records) {
      final storeId = record.storeId.trim();
      if (storeId.isEmpty) continue;

      result[storeId] = (result[storeId] ?? 0) + record.amount;
    }

    return result;
  }

  int? _trimmedAverage(List<int> values) {
    if (values.isEmpty) return null;

    final sorted = [...values]..sort();

    if (sorted.length < _trimMinSampleSize) {
      final sum = sorted.fold<int>(0, (a, b) => a + b);
      return (sum / sorted.length).round();
    }

    final trimCount = max(1, (sorted.length * _trimPercent / 100).floor());

    if (sorted.length <= trimCount * 2) {
      final sum = sorted.fold<int>(0, (a, b) => a + b);
      return (sum / sorted.length).round();
    }

    final trimmed = sorted.sublist(trimCount, sorted.length - trimCount);
    if (trimmed.isEmpty) return null;

    final sum = trimmed.fold<int>(0, (a, b) => a + b);
    return (sum / trimmed.length).round();
  }

  int? _topPercent({
    required List<int> values,
    required int myAmount,
  }) {
    if (values.isEmpty) return null;
    if (myAmount <= 0) return null;

    final sorted = [...values]..sort();
    final lessThanCount = sorted.where((e) => e < myAmount).length;
    final greaterThanOrEqualCount = sorted.length - lessThanCount;
    final topPercent = (greaterThanOrEqualCount / sorted.length) * 100;

    return topPercent.round().clamp(1, 99);
  }

  _OutlierState _outlierState({
    required List<int> values,
    required int myAmount,
  }) {
    if (values.length < _trimMinSampleSize) {
      return const _OutlierState.none();
    }

    if (myAmount <= 0) {
      return const _OutlierState.none();
    }

    final sorted = [...values]..sort();
    final trimCount = max(1, (sorted.length * _trimPercent / 100).floor());

    if (sorted.length <= trimCount * 2) {
      return const _OutlierState.none();
    }

    final lowerBound = sorted[trimCount];
    final upperBound = sorted[sorted.length - trimCount - 1];

    final isBottomOutlier = myAmount < lowerBound;
    final isTopOutlier = myAmount > upperBound;

    return _OutlierState(
      isOutlier: isBottomOutlier || isTopOutlier,
      isTopOutlier: isTopOutlier,
      isBottomOutlier: isBottomOutlier,
    );
  }

  String? _outlierGuideMessage({
    required int? topPercent,
    required bool isTopOutlier,
    required bool isBottomOutlier,
  }) {
    if (topPercent == null) return null;

    if (isTopOutlier) {
      return '사장님 매출은 상위 $topPercent%에 해당해 평균에서 제외됩니다.';
    }

    if (isBottomOutlier) {
      return '사장님 매출은 하위 $topPercent% 구간에 해당해 평균에서 제외됩니다.';
    }

    return null;
  }

  static List<RevenueMarketRecord> _buildMarketRecords() {
    final records = <RevenueMarketRecord>[];

    final regions = RegionCatalog.labels;
    final industries = IndustryCatalog.ordered().map((e) => e.name).toList();

    final today = DateTime.now();

    for (int r = 0; r < regions.length; r++) {
      for (int i = 0; i < industries.length; i++) {
        for (int s = 0; s < 5; s++) {
          final storeId = 'store_${r}_${i}_$s';

          for (int d = 0; d < 90; d++) {
            final date = today.subtract(Duration(days: d));

            final base = 85000 + (r * 3200) + (i * 5400);
            final noise = (d * 137 + s * 29) % 60000 - 12000;

            final amount = (base + noise).clamp(30000, 400000).toInt();

            records.add(
              RevenueMarketRecord(
                storeId: storeId,
                region: regions[r],
                industry: industries[i],
                date: date,
                amount: amount,
              ),
            );
          }
        }
      }
    }

    return records;
  }

  DateTime _dateOnly(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = _dateOnly(date);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  String _buildWeekLabel(DateTime start, DateTime end) {
    final startLabel = '${start.month}.${start.day}';
    final endLabel = '${end.month}.${end.day}';
    return '$startLabel|$endLabel';
  }
}

class _OutlierState {
  final bool isOutlier;
  final bool isTopOutlier;
  final bool isBottomOutlier;

  const _OutlierState({
    required this.isOutlier,
    required this.isTopOutlier,
    required this.isBottomOutlier,
  });

  const _OutlierState.none()
      : isOutlier = false,
        isTopOutlier = false,
        isBottomOutlier = false;
}
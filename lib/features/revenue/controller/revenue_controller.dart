import 'dart:math';

import 'package:get/get.dart';

import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';
import 'package:yupgagae/features/revenue/domain/revenue_entry.dart';
import 'package:yupgagae/features/revenue/domain/revenue_monthly_total_entry.dart';
import 'package:yupgagae/features/revenue/domain/revenue_repository.dart';

enum RevenueInputMode {
  daily,
  monthlyTotal,
}

class RevenueWeeklyTrendPoint {
  final String label;
  final int myTotal;
  final int industryAverage;

  const RevenueWeeklyTrendPoint({
    required this.label,
    required this.myTotal,
    required this.industryAverage,
  });
}

class RevenueMonthlyTrendPoint {
  final DateTime month;
  final String label;
  final int total;

  const RevenueMonthlyTrendPoint({
    required this.month,
    required this.label,
    required this.total,
  });
}

class RevenueWeekdayPatternPoint {
  final int weekday;
  final String label;
  final int total;
  final int enteredDays;
  final int average;

  const RevenueWeekdayPatternPoint({
    required this.weekday,
    required this.label,
    required this.total,
    required this.enteredDays,
    required this.average,
  });
}

class RevenueController extends GetxController {
  final RevenueRepository repo;
  final StoreProfileRepository storeProfileRepo;

  RevenueController({
    required this.repo,
    required this.storeProfileRepo,
  });

  static const int _trimPercent = 5;
  static const int _trimMinSampleSize = 40;
  static const int dailyComparisonMinEnteredDays = 10;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final error = RxnString();

  final selectedInputMode = RevenueInputMode.daily.obs;

  final selectedDate = DateTime.now().obs;
  final selectedDailyMonthRx = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  ).obs;
  final selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  ).obs;

  final dailyEntriesRx = <RevenueEntry>[].obs;
  final monthlyTotalEntriesRx = <RevenueMonthlyTotalEntry>[].obs;
  final marketRecords = <RevenueMarketRecord>[].obs;
  final profile = Rxn<StoreProfile>();

  bool _marketLoaded = false;

  int _dailyEntriesVersion = 0;
  int _marketRecordsVersion = 0;
  int _profileVersion = 0;

  DateTime? _selectedDailyMonthEntriesCacheMonth;
  int _selectedDailyMonthEntriesCacheVersion = -1;
  List<RevenueEntry> _selectedDailyMonthEntriesCache = const <RevenueEntry>[];

  DateTime? _selectedDailyMonthEntryMapCacheMonth;
  int _selectedDailyMonthEntryMapCacheVersion = -1;
  Map<int, RevenueEntry> _selectedDailyMonthEntryMapCache =
      const <int, RevenueEntry>{};

  DateTime? _weekdayPatternCacheMonth;
  int _weekdayPatternCacheVersion = -1;
  List<RevenueWeekdayPatternPoint> _weekdayPatternCachePoints =
      const <RevenueWeekdayPatternPoint>[];
  bool _weekdayPatternCacheHasData = false;
  int _weekdayPatternCacheAxisMax = 0;
  int _weekdayPatternCacheTopAverage = 0;

  DateTime? _recent4WeekTrendCacheWeekStart;
  String _recent4WeekTrendCacheIndustry = '';
  int _recent4WeekTrendDailyVersion = -1;
  int _recent4WeekTrendMarketVersion = -1;
  int _recent4WeekTrendProfileVersion = -1;
  List<RevenueWeeklyTrendPoint> _recent4WeekTrendCache =
      const <RevenueWeeklyTrendPoint>[];

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final dailyResult = await repo.fetchDailyEntries();
      final monthlyResult = await repo.fetchMonthlyTotalEntries();
      final storeProfile = await storeProfileRepo.fetchProfile();

      dailyEntriesRx.assignAll(dailyResult);
      monthlyTotalEntriesRx.assignAll(monthlyResult);
      profile.value = storeProfile;

      _dailyEntriesVersion++;
      _profileVersion++;
      _invalidateDailyDerivedCaches();
      _invalidateRecent4WeekTrendCache();

      if (!_marketLoaded) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final market = await repo.fetchMarketRecords(
          from: today.subtract(const Duration(days: 90)),
          to: today,
        );

        marketRecords.assignAll(market);
        _marketLoaded = true;
        _marketRecordsVersion++;
        _invalidateRecent4WeekTrendCache();
      }
    } catch (_) {
      error.value = '매출 데이터를 불러오지 못했습니다.';
    } finally {
      isLoading.value = false;
    }
  }

  bool get isDailyMode => selectedInputMode.value == RevenueInputMode.daily;

  bool get isMonthlyTotalMode =>
      selectedInputMode.value == RevenueInputMode.monthlyTotal;

  void setInputMode(RevenueInputMode mode) {
    selectedInputMode.value = mode;
    error.value = null;

    if (mode == RevenueInputMode.monthlyTotal) {
      selectedMonth.value = DateTime(
        selectedDailyMonthRx.value.year,
        selectedDailyMonthRx.value.month,
        1,
      );
    }
  }

  void setSelectedDate(DateTime date) {
    final next = _dateOnly(date);
    final currentMonth = selectedDailyMonthRx.value;
    final nextMonth = DateTime(next.year, next.month, 1);

    selectedDate.value = next;

    if (currentMonth.year != nextMonth.year ||
        currentMonth.month != nextMonth.month) {
      selectedDailyMonthRx.value = nextMonth;
    }
  }

  void setSelectedMonth(DateTime month) {
    selectedMonth.value = DateTime(month.year, month.month, 1);
  }

  void moveDailyMonth(int offset) {
    final current = selectedDailyMonthRx.value;
    final nextMonth = DateTime(current.year, current.month + offset, 1);
    selectedDailyMonthRx.value = nextMonth;

    final selected = selectedDate.value;
    if (selected.year != nextMonth.year || selected.month != nextMonth.month) {
      selectedDate.value = nextMonth;
    }
  }

  void moveMonthlyTotalMonth(int offset) {
    final current = selectedMonth.value;
    selectedMonth.value = DateTime(current.year, current.month + offset, 1);
  }

  List<RevenueEntry> get dailyEntries => dailyEntriesRx.toList();

  List<RevenueMonthlyTotalEntry> get monthlyTotalEntries =>
      monthlyTotalEntriesRx.toList();

  Future<bool> saveDailyEntry({
    required String rawAmount,
    required bool isClosed,
  }) async {
    final targetDate = _dateOnly(selectedDate.value);
    final targetMonth = DateTime(
      targetDate.year,
      targetDate.month,
      1,
    );

    if (_hasMonthlyTotalForMonth(targetMonth)) {
      error.value = '이 달에는 이미 월별 입력 데이터가 있습니다. 먼저 월별 데이터를 삭제해주세요.';
      return false;
    }

    int? amount;

    if (!isClosed) {
      final normalized = rawAmount.replaceAll(',', '').trim();
      amount = int.tryParse(normalized);

      if (amount == null || amount < 0) {
        error.value = '매출 금액을 올바르게 입력해주세요.';
        return false;
      }
    }

    try {
      isSaving.value = true;
      error.value = null;

      await repo.saveDailyEntry(
        date: targetDate,
        amount: isClosed ? null : amount,
        isClosed: isClosed,
      );

      final newEntry = RevenueEntry(
        id: selectedDateEntry?.id ?? _tempDailyId(targetDate),
        date: targetDate,
        amount: isClosed ? null : amount,
        isClosed: isClosed,
      );

      _upsertDailyEntry(newEntry);
      return true;
    } catch (_) {
      error.value = '매출 저장에 실패했습니다.';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> saveMonthlyTotalEntry({
    required String rawAmount,
  }) async {
    final normalized = rawAmount.replaceAll(',', '').trim();
    final amount = int.tryParse(normalized);
    final targetMonth = DateTime(
      selectedMonth.value.year,
      selectedMonth.value.month,
      1,
    );

    if (amount == null || amount < 0) {
      error.value = '이번 달 매출을 올바르게 입력해주세요.';
      return false;
    }

    if (_hasAnyDailyEntryForMonth(targetMonth)) {
      error.value = '이 달에는 이미 일별 매출이 입력되어 있습니다. 한 달에는 한 가지 입력 방식만 사용할 수 있습니다.';
      return false;
    }

    try {
      isSaving.value = true;
      error.value = null;

      await repo.saveMonthlyTotalEntry(
        month: targetMonth,
        amount: amount,
      );

      final newEntry = RevenueMonthlyTotalEntry(
        id: selectedMonthlyTotalEntry?.id ?? _tempMonthlyId(targetMonth),
        month: targetMonth,
        amount: amount,
      );

      _upsertMonthlyTotalEntry(newEntry);
      return true;
    } catch (_) {
      error.value = '월 매출 저장에 실패했습니다.';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteSelectedDailyEntry() async {
    final entry = selectedDateEntry;
    if (entry == null) return false;

    try {
      isSaving.value = true;
      error.value = null;

      await repo.deleteDailyEntry(date: selectedDate.value);
      _removeDailyEntry(selectedDate.value);
      return true;
    } catch (_) {
      error.value = '일별 매출 삭제에 실패했습니다.';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteSelectedMonthlyTotalEntry() async {
    final entry = selectedMonthlyTotalEntry;
    if (entry == null) return false;

    try {
      isSaving.value = true;
      error.value = null;

      await repo.deleteMonthlyTotalEntry(month: selectedMonth.value);
      _removeMonthlyTotalEntry(selectedMonth.value);
      return true;
    } catch (_) {
      error.value = '월별 매출 삭제에 실패했습니다.';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  void _upsertDailyEntry(RevenueEntry entry) {
    final list = dailyEntriesRx.toList();
    final index = list.indexWhere((e) => _isSameDate(e.date, entry.date));

    if (index >= 0) {
      list[index] = entry;
    } else {
      list.add(entry);
    }

    list.sort((a, b) => a.date.compareTo(b.date));
    dailyEntriesRx.assignAll(list);

    _dailyEntriesVersion++;
    _invalidateDailyDerivedCaches();
    _invalidateRecent4WeekTrendCache();
  }

  void _removeDailyEntry(DateTime date) {
    final list = dailyEntriesRx
        .where((e) => !_isSameDate(e.date, date))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    dailyEntriesRx.assignAll(list);

    _dailyEntriesVersion++;
    _invalidateDailyDerivedCaches();
    _invalidateRecent4WeekTrendCache();
  }

  void _upsertMonthlyTotalEntry(RevenueMonthlyTotalEntry entry) {
    final list = monthlyTotalEntriesRx.toList();
    final index = list.indexWhere(
      (e) => e.month.year == entry.month.year && e.month.month == entry.month.month,
    );

    if (index >= 0) {
      list[index] = entry;
    } else {
      list.add(entry);
    }

    list.sort((a, b) => a.month.compareTo(b.month));
    monthlyTotalEntriesRx.assignAll(list);
  }

  void _removeMonthlyTotalEntry(DateTime month) {
    final key = DateTime(month.year, month.month, 1);

    final list = monthlyTotalEntriesRx
        .where((e) => !(e.month.year == key.year && e.month.month == key.month))
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    monthlyTotalEntriesRx.assignAll(list);
  }

  void _invalidateDailyDerivedCaches() {
    _selectedDailyMonthEntriesCacheMonth = null;
    _selectedDailyMonthEntriesCacheVersion = -1;
    _selectedDailyMonthEntriesCache = const <RevenueEntry>[];

    _selectedDailyMonthEntryMapCacheMonth = null;
    _selectedDailyMonthEntryMapCacheVersion = -1;
    _selectedDailyMonthEntryMapCache = const <int, RevenueEntry>{};

    _weekdayPatternCacheMonth = null;
    _weekdayPatternCacheVersion = -1;
    _weekdayPatternCachePoints = const <RevenueWeekdayPatternPoint>[];
    _weekdayPatternCacheHasData = false;
    _weekdayPatternCacheAxisMax = 0;
    _weekdayPatternCacheTopAverage = 0;
  }

  void _invalidateRecent4WeekTrendCache() {
    _recent4WeekTrendCacheWeekStart = null;
    _recent4WeekTrendCacheIndustry = '';
    _recent4WeekTrendDailyVersion = -1;
    _recent4WeekTrendMarketVersion = -1;
    _recent4WeekTrendProfileVersion = -1;
    _recent4WeekTrendCache = const <RevenueWeeklyTrendPoint>[];
  }

  String _tempDailyId(DateTime date) {
    return 'daily_${date.year}_${date.month}_${date.day}';
  }

  String _tempMonthlyId(DateTime month) {
    return 'monthly_${month.year}_${month.month}';
  }

  bool _hasMonthlyTotalForMonth(DateTime month) {
    final key = DateTime(month.year, month.month, 1);

    for (final entry in monthlyTotalEntriesRx) {
      if (entry.month.year == key.year && entry.month.month == key.month) {
        return true;
      }
    }
    return false;
  }

  bool _hasAnyDailyEntryForMonth(DateTime month) {
    final key = DateTime(month.year, month.month, 1);

    for (final entry in dailyEntriesRx) {
      if (entry.date.year == key.year && entry.date.month == key.month) {
        return true;
      }
    }
    return false;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String get currentRegion {
    return profile.value?.region ?? '-';
  }

  String get currentIndustry {
    return profile.value?.industry ?? '-';
  }

  DateTime get selectedDailyMonthStart {
    final d = selectedDailyMonthRx.value;
    return DateTime(d.year, d.month, 1);
  }

  DateTime get previousDailyMonthStart {
    final d = selectedDailyMonthRx.value;
    return DateTime(d.year, d.month - 1, 1);
  }

  DateTime get selectedMonthlyModeMonthStart {
    final d = selectedMonth.value;
    return DateTime(d.year, d.month, 1);
  }

  DateTime get previousMonthlyModeMonthStart {
    final d = selectedMonth.value;
    return DateTime(d.year, d.month - 1, 1);
  }

  List<RevenueEntry> get selectedDailyMonthEntries {
    final month = selectedDailyMonthStart;

    final shouldReuse =
        _selectedDailyMonthEntriesCacheMonth != null &&
        _selectedDailyMonthEntriesCacheMonth!.year == month.year &&
        _selectedDailyMonthEntriesCacheMonth!.month == month.month &&
        _selectedDailyMonthEntriesCacheVersion == _dailyEntriesVersion;

    if (shouldReuse) {
      return _selectedDailyMonthEntriesCache;
    }

    final result = dailyEntries.where((entry) {
      return entry.date.year == month.year && entry.date.month == month.month;
    }).toList();

    _selectedDailyMonthEntriesCacheMonth = month;
    _selectedDailyMonthEntriesCacheVersion = _dailyEntriesVersion;
    _selectedDailyMonthEntriesCache = result;

    return _selectedDailyMonthEntriesCache;
  }

  Map<int, RevenueEntry> get selectedDailyMonthEntryMap {
    final month = selectedDailyMonthStart;

    final shouldReuse =
        _selectedDailyMonthEntryMapCacheMonth != null &&
        _selectedDailyMonthEntryMapCacheMonth!.year == month.year &&
        _selectedDailyMonthEntryMapCacheMonth!.month == month.month &&
        _selectedDailyMonthEntryMapCacheVersion == _dailyEntriesVersion;

    if (shouldReuse) {
      return _selectedDailyMonthEntryMapCache;
    }

    final map = <int, RevenueEntry>{};

    for (final entry in selectedDailyMonthEntries) {
      map[entry.date.day] = entry;
    }

    _selectedDailyMonthEntryMapCacheMonth = month;
    _selectedDailyMonthEntryMapCacheVersion = _dailyEntriesVersion;
    _selectedDailyMonthEntryMapCache = map;

    return _selectedDailyMonthEntryMapCache;
  }

  RevenueEntry? get selectedDateEntry {
    final target = selectedDate.value;
    final monthMap = selectedDailyMonthEntryMap;
    return monthMap[target.day];
  }

  int? get selectedDateAmount => selectedDateEntry?.amount;

  bool get selectedDateIsClosed => selectedDateEntry?.isClosed ?? false;

  int get selectedDailyMonthTotal {
    return selectedDailyMonthEntries.fold<int>(
      0,
      (sum, entry) => sum + (entry.amount ?? 0),
    );
  }

  int get previousDailyMonthTotal {
    final prevMonth = previousDailyMonthStart;

    return dailyEntries.where((entry) {
      return entry.date.year == prevMonth.year &&
          entry.date.month == prevMonth.month;
    }).fold<int>(
      0,
      (sum, entry) => sum + (entry.amount ?? 0),
    );
  }

  double? get dailyMonthOverMonthRate {
    final prev = previousDailyMonthTotal;
    if (prev <= 0) return null;
    return ((selectedDailyMonthTotal - prev) / prev) * 100;
  }

  int get selectedDailyMonthClosedDays {
    return selectedDailyMonthEntries.where((e) => e.isClosed).length;
  }

  int get selectedDailyMonthOpenDays {
    return selectedDailyMonthEntries
        .where((e) => !e.isClosed && e.amount != null)
        .length;
  }

  int? get selectedDailyMonthAverage {
    final openEntries = selectedDailyMonthEntries
        .where((e) => !e.isClosed && e.amount != null)
        .toList();

    if (openEntries.isEmpty) return null;

    final sum = openEntries.fold<int>(0, (acc, e) => acc + (e.amount ?? 0));
    return (sum / openEntries.length).round();
  }

  RevenueMonthlyTotalEntry? get selectedMonthlyTotalEntry {
    final target = selectedMonth.value;

    for (final entry in monthlyTotalEntries) {
      if (entry.month.year == target.year && entry.month.month == target.month) {
        return entry;
      }
    }
    return null;
  }

  int? get selectedMonthlyTotalAmount => selectedMonthlyTotalEntry?.amount;

  int get selectedMonthlyModeTotal {
    return selectedMonthlyTotalEntry?.amount ?? 0;
  }

  int get enteredDailyComparisonCount {
    return selectedDailyMonthEntries
        .where((e) => e.isClosed || e.amount != null)
        .length;
  }

  bool get comparisonUnlocked {
    if (isDailyMode) {
      return enteredDailyComparisonCount >= dailyComparisonMinEnteredDays;
    }
    return selectedMonthlyTotalEntry != null;
  }

  String? get comparisonLockMessage {
    if (comparisonUnlocked) return null;

    if (isDailyMode) {
      return '10일 이상 매출 입력 후 업종·지역 매출 비교를 해보세요.';
    }

    return '월별 매출을 입력하면 업종·지역 비교를 확인할 수 있어요.';
  }

  int get visibleTopTotal => isDailyMode ? selectedDailyMonthTotal : selectedMonthlyModeTotal;

  bool get hasVisibleRevenueForComparison {
    if (!comparisonUnlocked) return false;
    return visibleTopTotal > 0;
  }

  bool get hasVisibleComparisonData {
    return visibleIndustryAverage != null || visibleRegionAverage != null;
  }

  DateTime get visibleMonth =>
      isDailyMode ? selectedDailyMonthStart : selectedMonthlyModeMonthStart;

  String get visibleTopSubTitle => isDailyMode ? '입력일수' : '입력방식';

  String get visibleTopSubValueLabel =>
      isDailyMode ? '${enteredDailyComparisonCount}일' : '월별 입력';

  String get visibleSecondarySubTitle => isDailyMode ? '일평균' : '비교 기준';

  String get visibleSecondarySubValue => visibleComparisonBaseLabel;

  int? get visibleAverage => isDailyMode ? selectedDailyMonthAverage : null;

  String get visibleComparisonBaseLabel {
    final industry = currentIndustry == '-' ? '내 업종' : currentIndustry;
    final region = currentRegion == '-' ? '내 지역' : currentRegion;
    return '$industry · $region 기준';
  }

  double? get visibleMonthOverMonthRate {
    return isDailyMode ? dailyMonthOverMonthRate : monthlyModeMonthOverMonthRate;
  }

  int? get visibleIndustryAverage {
    if (!comparisonUnlocked) return null;
    return _findAverageByIndustry();
  }

  int? get visibleRegionAverage {
    if (!comparisonUnlocked) return null;
    return _findAverageByRegion();
  }

  double? get visibleIndustryDeltaRate {
    final avg = visibleIndustryAverage;
    if (avg == null || avg <= 0) return null;
    return ((visibleTopTotal - avg) / avg) * 100;
  }

  double? get visibleRegionDeltaRate {
    final avg = visibleRegionAverage;
    if (avg == null || avg <= 0) return null;
    return ((visibleTopTotal - avg) / avg) * 100;
  }

  int? get visibleTopPercent {
    if (!comparisonUnlocked) return null;
    final avg = visibleIndustryAverage;
    if (avg == null || avg <= 0 || visibleTopTotal <= 0) return null;

    final ratio = visibleTopTotal / avg;
    if (ratio >= 1.6) return 10;
    if (ratio >= 1.3) return 20;
    if (ratio >= 1.1) return 35;
    if (ratio >= 0.9) return 50;
    if (ratio >= 0.75) return 65;
    if (ratio >= 0.6) return 80;
    return 90;
  }

  int get previousMonthlyModeTotal {
    final prev = previousMonthlyModeMonthStart;

    for (final entry in monthlyTotalEntries) {
      if (entry.month.year == prev.year && entry.month.month == prev.month) {
        return entry.amount;
      }
    }
    return 0;
  }

  double? get monthlyModeMonthOverMonthRate {
    final prev = previousMonthlyModeTotal;
    if (prev <= 0) return null;
    return ((selectedMonthlyModeTotal - prev) / prev) * 100;
  }

  List<RevenueWeeklyTrendPoint> get recent4WeekTrend => _recent4WeekTrendCache;

  List<RevenueWeekdayPatternPoint> get selectedDailyWeekdayPattern {
    _ensureWeekdayPatternCache();
    return _weekdayPatternCachePoints;
  }

  bool get hasSelectedDailyWeekdayPatternData {
    _ensureWeekdayPatternCache();
    return _weekdayPatternCacheHasData;
  }

  int get selectedDailyWeekdayPatternAxisMax {
    _ensureWeekdayPatternCache();
    return _weekdayPatternCacheAxisMax;
  }

  int get selectedDailyWeekdayPatternTopAverage {
    _ensureWeekdayPatternCache();
    return _weekdayPatternCacheTopAverage;
  }

  void _ensureWeekdayPatternCache() {
    final month = selectedDailyMonthStart;

    final shouldReuse =
        _weekdayPatternCacheMonth != null &&
        _weekdayPatternCacheMonth!.year == month.year &&
        _weekdayPatternCacheMonth!.month == month.month &&
        _weekdayPatternCacheVersion == _dailyEntriesVersion;

    if (shouldReuse) return;

    final totals = List<int>.filled(7, 0);
    final counts = List<int>.filled(7, 0);

    for (final entry in selectedDailyMonthEntries) {
      if (entry.isClosed || entry.amount == null) continue;
      final index = entry.date.weekday - 1;
      totals[index] += entry.amount!;
      counts[index] += 1;
    }

    const labels = ['월', '화', '수', '목', '금', '토', '일'];

    final points = <RevenueWeekdayPatternPoint>[];
    int maxAverage = 0;
    bool hasData = false;

    for (int i = 0; i < 7; i++) {
      final average = counts[i] == 0 ? 0 : (totals[i] / counts[i]).round();

      if (average > 0) {
        hasData = true;
        if (average > maxAverage) {
          maxAverage = average;
        }
      }

      points.add(
        RevenueWeekdayPatternPoint(
          weekday: i + 1,
          label: labels[i],
          total: totals[i],
          enteredDays: counts[i],
          average: average,
        ),
      );
    }

    _weekdayPatternCacheMonth = month;
    _weekdayPatternCacheVersion = _dailyEntriesVersion;
    _weekdayPatternCachePoints = points;
    _weekdayPatternCacheHasData = hasData;
    _weekdayPatternCacheTopAverage = maxAverage;
    _weekdayPatternCacheAxisMax = maxAverage <= 0 ? 0 : maxAverage;
  }

  int? _findAverageByIndustry() {
    final industry = currentIndustry;
    if (industry == '-') return null;

    final values = marketRecords
        .where((e) => e.industry == industry)
        .map((e) => e.amount)
        .where((e) => e > 0)
        .toList();

    return _trimmedAverage(values);
  }

  int? _findAverageByRegion() {
    final region = currentRegion;
    if (region == '-') return null;

    final values = marketRecords
        .where((e) => e.region == region)
        .map((e) => e.amount)
        .where((e) => e > 0)
        .toList();

    return _trimmedAverage(values);
  }

  int? _trimmedAverage(List<int> values) {
    if (values.isEmpty) return null;

    final sorted = [...values]..sort();
    if (sorted.length < _trimMinSampleSize) {
      final sum = sorted.fold<int>(0, (a, b) => a + b);
      return (sum / sorted.length).round();
    }

    final trimCount = max(1, (sorted.length * _trimPercent / 100).floor());
    final trimmed = sorted.sublist(trimCount, sorted.length - trimCount);
    if (trimmed.isEmpty) return null;

    final sum = trimmed.fold<int>(0, (a, b) => a + b);
    return (sum / trimmed.length).round();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
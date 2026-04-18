import 'dart:convert';

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
  Future<void> saveDailyEntry({
    required DateTime date,
    required int? amount,
    required bool isClosed,
  }) async {
    await _ensureLoaded();

    final dayKey = DateTime(date.year, date.month, date.day);

    _dailyEntries.removeWhere((e) {
      return e.date.year == dayKey.year &&
          e.date.month == dayKey.month &&
          e.date.day == dayKey.day;
    });

    _seed++;

    _dailyEntries.add(
      RevenueEntry(
        id: 'revenue_$_seed',
        date: dayKey,
        amount: isClosed ? null : amount,
        isClosed: isClosed,
      ),
    );

    await _persist();
  }

  @override
  Future<void> saveMonthlyTotalEntry({
    required DateTime month,
    required int amount,
  }) async {
    await _ensureLoaded();

    final monthKey = DateTime(month.year, month.month, 1);

    _monthlyTotalEntries.removeWhere((e) {
      return e.month.year == monthKey.year && e.month.month == monthKey.month;
    });

    _seed++;

    _monthlyTotalEntries.add(
      RevenueMonthlyTotalEntry(
        id: 'revenue_$_seed',
        month: monthKey,
        amount: amount,
      ),
    );

    await _persist();
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
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);

    return _marketRecords.where((record) {
      final d = DateTime(record.date.year, record.date.month, record.date.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
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

            final amount = (base + noise).clamp(30000, 400000);

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
}
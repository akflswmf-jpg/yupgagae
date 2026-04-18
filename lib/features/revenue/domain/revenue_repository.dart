import 'package:yupgagae/features/revenue/domain/revenue_entry.dart';
import 'package:yupgagae/features/revenue/domain/revenue_monthly_total_entry.dart';

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

abstract class RevenueRepository {
  Future<List<RevenueEntry>> fetchDailyEntries();

  Future<List<RevenueMonthlyTotalEntry>> fetchMonthlyTotalEntries();

  Future<void> saveDailyEntry({
    required DateTime date,
    required int? amount,
    required bool isClosed,
  });

  Future<void> saveMonthlyTotalEntry({
    required DateTime month,
    required int amount,
  });

  Future<void> deleteDailyEntry({
    required DateTime date,
  });

  Future<void> deleteMonthlyTotalEntry({
    required DateTime month,
  });

  Future<List<RevenueMarketRecord>> fetchMarketRecords({
    required DateTime from,
    required DateTime to,
  });
}
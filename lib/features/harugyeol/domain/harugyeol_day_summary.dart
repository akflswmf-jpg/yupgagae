import 'package:yupgagae/features/harugyeol/domain/harugyeol_enums.dart';

class HarugyeolSlotSummary {
  final int count;
  final int scoreSum;
  final double averageScore;
  final Map<HarugyeolMood, int> moodCounts;
  final Map<HarugyeolReason, int> reasonCounts;

  const HarugyeolSlotSummary({
    required this.count,
    required this.scoreSum,
    required this.averageScore,
    required this.moodCounts,
    required this.reasonCounts,
  });

  HarugyeolSlotSummary.empty()
      : count = 0,
        scoreSum = 0,
        averageScore = 0,
        moodCounts = _emptyHarugyeolMoodCounts(),
        reasonCounts = _emptyHarugyeolReasonCounts();

  factory HarugyeolSlotSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return HarugyeolSlotSummary.empty();
    }

    final count = (json['count'] as num?)?.toInt() ?? 0;
    final scoreSum = (json['scoreSum'] as num?)?.toInt() ?? 0;

    return HarugyeolSlotSummary(
      count: count,
      scoreSum: scoreSum,
      averageScore: count > 0
          ? ((json['averageScore'] as num?)?.toDouble() ?? (scoreSum / count))
          : 0,
      moodCounts: _parseHarugyeolMoodCounts(json['moodCounts']),
      reasonCounts: _parseHarugyeolReasonCounts(json['reasonCounts']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'scoreSum': scoreSum,
      'averageScore': averageScore,
      'moodCounts': moodCounts.map(
        (key, value) => MapEntry(key.key, value),
      ),
      'reasonCounts': reasonCounts.map(
        (key, value) => MapEntry(key.key, value),
      ),
    };
  }
}

class HarugyeolHourlySummary {
  final int hour;
  final HarugyeolSlot slot;
  final int count;
  final int scoreSum;
  final double averageScore;

  const HarugyeolHourlySummary({
    required this.hour,
    required this.slot,
    required this.count,
    required this.scoreSum,
    required this.averageScore,
  });

  HarugyeolHourlySummary.empty({
    required this.hour,
    required this.slot,
  })  : count = 0,
        scoreSum = 0,
        averageScore = 0;

  String get key => '${slot.key}_${hour.toString().padLeft(2, '0')}';

  factory HarugyeolHourlySummary.fromJson(
    String fallbackKey,
    Map<String, dynamic>? json,
  ) {
    final parsed = _parseHourlyKey(fallbackKey);

    if (json == null) {
      return HarugyeolHourlySummary.empty(
        hour: parsed.hour,
        slot: parsed.slot,
      );
    }

    final rawHour = (json['hour'] as num?)?.toInt();
    final hour = _normalizeHour(rawHour) ?? parsed.hour;
    final slot = harugyeolSlotFromKey(json['slot']?.toString()) ?? parsed.slot;
    final count = (json['count'] as num?)?.toInt() ?? 0;
    final scoreSum = (json['scoreSum'] as num?)?.toInt() ?? 0;

    return HarugyeolHourlySummary(
      hour: hour,
      slot: slot,
      count: count,
      scoreSum: scoreSum,
      averageScore: count > 0
          ? ((json['averageScore'] as num?)?.toDouble() ?? (scoreSum / count))
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'slot': slot.key,
      'count': count,
      'scoreSum': scoreSum,
      'averageScore': averageScore,
    };
  }
}

class HarugyeolDaySummary {
  final String dateKey;
  final int totalCount;
  final int scoreSum;
  final double averageScore;
  final Map<HarugyeolSlot, HarugyeolSlotSummary> slotStats;
  final Map<String, HarugyeolHourlySummary> hourlyStats;
  final Map<HarugyeolMood, int> moodCounts;
  final Map<HarugyeolReason, int> reasonCounts;
  final DateTime? updatedAt;

  const HarugyeolDaySummary({
    required this.dateKey,
    required this.totalCount,
    required this.scoreSum,
    required this.averageScore,
    required this.slotStats,
    required this.hourlyStats,
    required this.moodCounts,
    required this.reasonCounts,
    required this.updatedAt,
  });

  factory HarugyeolDaySummary.empty(String dateKey) {
    return HarugyeolDaySummary(
      dateKey: dateKey,
      totalCount: 0,
      scoreSum: 0,
      averageScore: 0,
      slotStats: {
        HarugyeolSlot.midday: HarugyeolSlotSummary.empty(),
        HarugyeolSlot.evening: HarugyeolSlotSummary.empty(),
      },
      hourlyStats: const <String, HarugyeolHourlySummary>{},
      moodCounts: _emptyHarugyeolMoodCounts(),
      reasonCounts: _emptyHarugyeolReasonCounts(),
      updatedAt: null,
    );
  }

  bool get hasData => totalCount > 0;

  bool get hasHourlyData {
    return hourlyStats.values.any((summary) => summary.count > 0);
  }

  String get averageScoreLabel {
    if (!hasData) return '-';
    return averageScore.toStringAsFixed(0);
  }

  double? averageScoreForHour(int hour) {
    final validHour = _normalizeHour(hour);
    if (validHour == null) return null;

    final middayStat = slotStats[HarugyeolSlot.midday];
    final eveningStat = slotStats[HarugyeolSlot.evening];

    final hasMidday = (middayStat?.count ?? 0) > 0;
    final hasEvening = (eveningStat?.count ?? 0) > 0;

    if (validHour == 17 && hasMidday) {
      return middayStat!.averageScore;
    }

    if (validHour == 23 && hasEvening) {
      return eveningStat!.averageScore;
    }

    var count = 0;
    var scoreSum = 0;

    for (final summary in hourlyStats.values) {
      if (summary.hour != validHour) continue;
      if (summary.count <= 0) continue;

      count += summary.count;
      scoreSum += summary.scoreSum;
    }

    if (count <= 0) return null;
    return scoreSum / count;
  }

  List<MapEntry<HarugyeolReason, int>> get topReasons {
    final entries = reasonCounts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;

        return HarugyeolReason.values
            .indexOf(a.key)
            .compareTo(HarugyeolReason.values.indexOf(b.key));
      });

    return entries.take(3).toList(growable: false);
  }

  HarugyeolDaySummary filteredBySlots(
    Iterable<HarugyeolSlot> visibleSlots,
  ) {
    final slotSet = visibleSlots.toSet();

    if (slotSet.isEmpty) {
      return HarugyeolDaySummary.empty(dateKey);
    }

    final nextSlotStats = <HarugyeolSlot, HarugyeolSlotSummary>{
      for (final slot in HarugyeolSlot.values)
        slot: slotSet.contains(slot)
            ? (slotStats[slot] ?? HarugyeolSlotSummary.empty())
            : HarugyeolSlotSummary.empty(),
    };

    final nextHourlyStats = <String, HarugyeolHourlySummary>{
      for (final entry in hourlyStats.entries)
        if (slotSet.contains(entry.value.slot)) entry.key: entry.value,
    };

    var nextTotalCount = 0;
    var nextScoreSum = 0;
    final nextMoodCounts = _emptyHarugyeolMoodCounts();
    final nextReasonCounts = _emptyHarugyeolReasonCounts();

    for (final slot in slotSet) {
      final stat = slotStats[slot] ?? HarugyeolSlotSummary.empty();

      nextTotalCount += stat.count;
      nextScoreSum += stat.scoreSum;

      for (final mood in HarugyeolMood.values) {
        nextMoodCounts[mood] =
            (nextMoodCounts[mood] ?? 0) + (stat.moodCounts[mood] ?? 0);
      }

      for (final reason in HarugyeolReason.values) {
        nextReasonCounts[reason] =
            (nextReasonCounts[reason] ?? 0) + (stat.reasonCounts[reason] ?? 0);
      }
    }

    final hasSlotScopedCounts = nextMoodCounts.values.any((value) => value > 0) ||
        nextReasonCounts.values.any((value) => value > 0);

    final shouldUseFullDayFallback =
        slotSet.length == HarugyeolSlot.values.length && !hasSlotScopedCounts;

    final visibleMoodCounts = shouldUseFullDayFallback
        ? Map<HarugyeolMood, int>.from(moodCounts)
        : nextMoodCounts;

    final visibleReasonCounts = shouldUseFullDayFallback
        ? Map<HarugyeolReason, int>.from(reasonCounts)
        : nextReasonCounts;

    return HarugyeolDaySummary(
      dateKey: dateKey,
      totalCount: nextTotalCount,
      scoreSum: nextScoreSum,
      averageScore: nextTotalCount > 0 ? nextScoreSum / nextTotalCount : 0,
      slotStats: nextSlotStats,
      hourlyStats: nextHourlyStats,
      moodCounts: visibleMoodCounts,
      reasonCounts: visibleReasonCounts,
      updatedAt: updatedAt,
    );
  }

  factory HarugyeolDaySummary.fromJson(
    String dateKey,
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return HarugyeolDaySummary.empty(dateKey);
    }

    return HarugyeolDaySummary(
      dateKey: (json['dateKey'] ?? dateKey).toString(),
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      scoreSum: (json['scoreSum'] as num?)?.toInt() ?? 0,
      averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0,
      slotStats: _parseSlotStats(json['slotStats']),
      hourlyStats: _parseHourlyStats(json['hourlyStats']),
      moodCounts: _parseHarugyeolMoodCounts(json['moodCounts']),
      reasonCounts: _parseHarugyeolReasonCounts(json['reasonCounts']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateKey': dateKey,
      'totalCount': totalCount,
      'scoreSum': scoreSum,
      'averageScore': averageScore,
      'slotStats': slotStats.map(
        (key, value) => MapEntry(key.key, value.toJson()),
      ),
      'hourlyStats': hourlyStats.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'moodCounts': moodCounts.map(
        (key, value) => MapEntry(key.key, value),
      ),
      'reasonCounts': reasonCounts.map(
        (key, value) => MapEntry(key.key, value),
      ),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static Map<HarugyeolSlot, HarugyeolSlotSummary> _parseSlotStats(
    dynamic raw,
  ) {
    final result = <HarugyeolSlot, HarugyeolSlotSummary>{
      HarugyeolSlot.midday: HarugyeolSlotSummary.empty(),
      HarugyeolSlot.evening: HarugyeolSlotSummary.empty(),
    };

    if (raw is! Map) return result;

    for (final slot in HarugyeolSlot.values) {
      final value = raw[slot.key];

      if (value is Map) {
        result[slot] = HarugyeolSlotSummary.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
    }

    return result;
  }

  static Map<String, HarugyeolHourlySummary> _parseHourlyStats(dynamic raw) {
    final result = <String, HarugyeolHourlySummary>{};

    if (raw is! Map) return result;

    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value is! Map) continue;

      final summary = HarugyeolHourlySummary.fromJson(
        key,
        Map<String, dynamic>.from(value),
      );

      if (summary.count <= 0) continue;

      result[summary.key] = summary;
    }

    return result;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    try {
      final dynamic maybeTimestamp = value;
      final converted = maybeTimestamp.toDate();
      if (converted is DateTime) {
        return converted;
      }
    } catch (_) {
      // Ignore non-Firestore Timestamp values.
    }

    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}

Map<HarugyeolMood, int> _emptyHarugyeolMoodCounts() {
  return {
    for (final mood in HarugyeolMood.values) mood: 0,
  };
}

Map<HarugyeolReason, int> _emptyHarugyeolReasonCounts() {
  return {
    for (final reason in HarugyeolReason.values) reason: 0,
  };
}

Map<HarugyeolMood, int> _parseHarugyeolMoodCounts(dynamic raw) {
  final result = _emptyHarugyeolMoodCounts();

  if (raw is! Map) return result;

  for (final mood in HarugyeolMood.values) {
    result[mood] = (raw[mood.key] as num?)?.toInt() ?? 0;
  }

  return result;
}

Map<HarugyeolReason, int> _parseHarugyeolReasonCounts(dynamic raw) {
  final result = _emptyHarugyeolReasonCounts();

  if (raw is! Map) return result;

  for (final entry in raw.entries) {
    final reason = harugyeolReasonFromKey(entry.key.toString());
    result[reason] =
        (result[reason] ?? 0) + ((entry.value as num?)?.toInt() ?? 0);
  }

  return result;
}

({int hour, HarugyeolSlot slot}) _parseHourlyKey(String key) {
  final parts = key.split('_');

  if (parts.length >= 2) {
    final slot = harugyeolSlotFromKey(parts.first) ?? HarugyeolSlot.midday;
    final hour = _normalizeHour(int.tryParse(parts[1])) ?? 11;

    return (hour: hour, slot: slot);
  }

  return (hour: 11, slot: HarugyeolSlot.midday);
}

int? _normalizeHour(int? hour) {
  if (hour == null) return null;
  if (hour < 0 || hour > 23) return null;
  return hour;
}
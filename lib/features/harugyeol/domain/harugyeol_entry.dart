import 'package:yupgagae/features/harugyeol/domain/harugyeol_enums.dart';

class HarugyeolEntry {
  final String id;
  final String dateKey;
  final String userId;
  final String authorLabel;
  final String? industryId;
  final String? locationLabel;
  final bool isOwnerVerified;
  final HarugyeolSlot slot;
  final HarugyeolMood mood;
  final int score;
  final List<HarugyeolReason> reasons;
  final String oneLineText;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HarugyeolEntry({
    required this.id,
    required this.dateKey,
    required this.userId,
    required this.authorLabel,
    required this.industryId,
    required this.locationLabel,
    required this.isOwnerVerified,
    required this.slot,
    required this.mood,
    required this.score,
    required this.reasons,
    required this.oneLineText,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasOneLineText => oneLineText.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateKey': dateKey,
      'userId': userId,
      'authorLabel': authorLabel,
      'industryId': industryId,
      'locationLabel': locationLabel,
      'isOwnerVerified': isOwnerVerified,
      'slot': slot.key,
      'mood': mood.key,
      'score': score,
      'reasons': reasons.map((e) => e.key).toList(),
      'oneLineText': oneLineText,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HarugyeolEntry.fromJson(Map<String, dynamic> json) {
    final mood = harugyeolMoodFromKey(json['mood']?.toString());
    final slot = harugyeolSlotFromKey(json['slot']?.toString());

    final rawReasons = json['reasons'];
    final reasons = rawReasons is List
        ? rawReasons
            .map((e) => harugyeolReasonFromKey(e?.toString()))
            .toList(growable: false)
        : const <HarugyeolReason>[];

    final createdAt = _parseDateTime(json['createdAt']) ?? DateTime.now();
    final updatedAt = _parseDateTime(json['updatedAt']) ?? createdAt;

    return HarugyeolEntry(
      id: (json['id'] ?? '').toString(),
      dateKey: (json['dateKey'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      authorLabel: (json['authorLabel'] ?? '익명').toString(),
      industryId: _nullableString(json['industryId']),
      locationLabel: _nullableString(json['locationLabel']),
      isOwnerVerified: json['isOwnerVerified'] == true,
      slot: slot ?? HarugyeolSlot.midday,
      mood: mood,
      score: (json['score'] as num?)?.toInt() ?? mood.score,
      reasons: reasons,
      oneLineText: (json['oneLineText'] ?? '').toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
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
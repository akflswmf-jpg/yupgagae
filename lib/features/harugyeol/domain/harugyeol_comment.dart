import 'package:yupgagae/features/harugyeol/domain/harugyeol_enums.dart';

class HarugyeolComment {
  final String id;
  final String dateKey;
  final String entryId;
  final String userId;
  final String authorLabel;
  final String? industryId;
  final String? locationLabel;
  final bool isOwnerVerified;
  final HarugyeolSlot slot;
  final HarugyeolMood mood;
  final String text;
  final int likeCount;
  final bool isLikedByMe;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HarugyeolComment({
    required this.id,
    required this.dateKey,
    required this.entryId,
    required this.userId,
    required this.authorLabel,
    required this.industryId,
    required this.locationLabel,
    required this.isOwnerVerified,
    required this.slot,
    required this.mood,
    required this.text,
    required this.likeCount,
    required this.isLikedByMe,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';

  factory HarugyeolComment.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final createdAt = _parseDateTime(json['createdAt']) ?? DateTime.now();
    final updatedAt = _parseDateTime(json['updatedAt']) ?? createdAt;

    final safeCurrentUserId = currentUserId.trim();
    final likedUserIds = json['likedUserIds'];
    final likedByMe = likedUserIds is List &&
        safeCurrentUserId.isNotEmpty &&
        likedUserIds.map((e) => e.toString().trim()).contains(safeCurrentUserId);

    return HarugyeolComment(
      id: (json['id'] ?? '').toString(),
      dateKey: (json['dateKey'] ?? '').toString(),
      entryId: (json['entryId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      authorLabel: (json['authorLabel'] ?? '익명').toString(),
      industryId: _nullableString(json['industryId']),
      locationLabel: _nullableString(json['locationLabel']),
      isOwnerVerified: json['isOwnerVerified'] == true,
      slot: harugyeolSlotFromKey(json['slot']?.toString()) ?? HarugyeolSlot.midday,
      mood: harugyeolMoodFromKey(json['mood']?.toString()),
      text: (json['text'] ?? '').toString(),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: likedByMe,
      status: (json['status'] ?? 'active').toString(),
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
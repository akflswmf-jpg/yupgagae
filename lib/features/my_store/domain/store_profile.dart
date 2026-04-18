// lib/features/my_store/domain/store_profile.dart

import 'package:yupgagae/features/community/domain/region_catalog.dart';
import 'package:yupgagae/features/my_store/domain/app_notification_item.dart';
import 'package:yupgagae/features/my_store/domain/blocked_user_item.dart';

class StoreProfile {
  static const List<String> regionOptions = RegionCatalog.labels;

  final String nickname;
  final String region;
  final String industry;
  final bool isOwnerVerified;
  final bool isIdentityVerified;
  final bool notificationsEnabled;
  final List<BlockedUserItem> blockedUsers;
  final List<AppNotificationItem> notifications;

  const StoreProfile({
    required this.nickname,
    required this.region,
    required this.industry,
    required this.isOwnerVerified,
    required this.isIdentityVerified,
    required this.notificationsEnabled,
    required this.blockedUsers,
    required this.notifications,
  });

  StoreProfile copyWith({
    String? nickname,
    String? region,
    String? industry,
    bool? isOwnerVerified,
    bool? isIdentityVerified,
    bool? notificationsEnabled,
    List<BlockedUserItem>? blockedUsers,
    List<AppNotificationItem>? notifications,
  }) {
    return StoreProfile(
      nickname: nickname ?? this.nickname,
      region: region ?? this.region,
      industry: industry ?? this.industry,
      isOwnerVerified: isOwnerVerified ?? this.isOwnerVerified,
      isIdentityVerified: isIdentityVerified ?? this.isIdentityVerified,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      notifications: notifications ?? this.notifications,
    );
  }

  // =========================
  // 🔥 JSON 직렬화 추가 (핵심)
  // =========================

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'region': region,
      'industry': industry,
      'isOwnerVerified': isOwnerVerified,
      'isIdentityVerified': isIdentityVerified,
      'notificationsEnabled': notificationsEnabled,
      'blockedUsers': blockedUsers.map((e) => e.toJson()).toList(),
      'notifications': notifications.map((e) => e.toJson()).toList(),
    };
  }

  factory StoreProfile.fromJson(Map<String, dynamic> json) {
    return StoreProfile(
      nickname: (json['nickname'] ?? '').toString(),
      region: (json['region'] ?? '').toString(),
      industry: (json['industry'] ?? '').toString(),
      isOwnerVerified: json['isOwnerVerified'] == true,
      isIdentityVerified: json['isIdentityVerified'] == true,
      notificationsEnabled: json['notificationsEnabled'] != false,
      blockedUsers: (json['blockedUsers'] as List<dynamic>? ?? [])
          .map((e) => BlockedUserItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      notifications: (json['notifications'] as List<dynamic>? ?? [])
          .map((e) => AppNotificationItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
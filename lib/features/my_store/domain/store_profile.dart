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
    final nickname = _readString(json['nickname']).trim();
    final region = _readString(json['region']).trim();
    final industry = _readString(json['industry']).trim();

    return StoreProfile(
      nickname: nickname.isEmpty ? '익명' : nickname,
      region: region.isEmpty ? '서울' : region,
      industry: industry.isEmpty ? '미용/헤어' : industry,
      isOwnerVerified: _readBool(json['isOwnerVerified']),
      isIdentityVerified: _readBool(json['isIdentityVerified']),
      notificationsEnabled: json['notificationsEnabled'] != false,
      blockedUsers: _decodeBlockedUsers(json['blockedUsers']),
      notifications: _decodeNotifications(json['notifications']),
    );
  }

  static String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static List<BlockedUserItem> _decodeBlockedUsers(dynamic raw) {
    if (raw is! List) {
      return const <BlockedUserItem>[];
    }

    final result = <BlockedUserItem>[];

    for (final item in raw) {
      try {
        if (item is! Map) continue;

        final decoded = BlockedUserItem.fromJson(
          Map<String, dynamic>.from(item),
        );

        result.add(decoded);
      } catch (_) {
        // 오래된 로컬 데이터나 깨진 항목 하나 때문에 전체 프로필을 버리지 않는다.
      }
    }

    return List<BlockedUserItem>.unmodifiable(result);
  }

  static List<AppNotificationItem> _decodeNotifications(dynamic raw) {
    if (raw is! List) {
      return const <AppNotificationItem>[];
    }

    final result = <AppNotificationItem>[];

    for (final item in raw) {
      try {
        if (item is! Map) continue;

        final decoded = AppNotificationItem.fromJson(
          Map<String, dynamic>.from(item),
        );

        result.add(decoded);
      } catch (_) {
        // 오래된 로컬 데이터나 깨진 알림 하나 때문에 전체 프로필을 버리지 않는다.
      }
    }

    return List<AppNotificationItem>.unmodifiable(result);
  }
}
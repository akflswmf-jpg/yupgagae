// lib/features/my_store/domain/store_profile_repository.dart

import 'package:yupgagae/features/my_store/domain/app_notification_item.dart';
import 'package:yupgagae/features/my_store/domain/blocked_user_item.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';

abstract class StoreProfileRepository {
  Future<void> warmUp();

  // =========================
  // 프로필 기본
  // =========================

  Future<StoreProfile> fetchProfile();

  Future<StoreProfile> updateNickname(String nickname);

  Future<StoreProfile> updateNotificationsEnabled(bool enabled);

  Future<StoreProfile> updateIndustry(String industry);

  Future<StoreProfile> updateRegion(String region);

  // =========================
  // 차단
  // =========================

  Future<List<BlockedUserItem>> getBlockedUsers();

  Future<StoreProfile> blockUser(BlockedUserItem user);

  Future<StoreProfile> unblockUser(String userId);

  // =========================
  // 알림
  // =========================

  Future<List<AppNotificationItem>> getNotifications();

  Future<StoreProfile> addNotification(AppNotificationItem item);

  Future<StoreProfile> markAsRead(String notificationId);

  Future<StoreProfile> markAllRead();

  Future<StoreProfile> clearNotifications();

  // =========================
  // 멀티유저 확장
  // =========================

  /// 특정 유저에게 알림 추가
  Future<void> addNotificationToUser(
    String userId,
    AppNotificationItem item,
  );

  /// 특정 유저 알림 조회
  Future<List<AppNotificationItem>> getNotificationsByUserId(String userId);

  /// 특정 유저 차단 목록
  Future<List<BlockedUserItem>> getBlockedUsersByUserId(String userId);
}
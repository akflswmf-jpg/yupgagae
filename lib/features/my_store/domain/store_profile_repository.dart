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
  // 인증 상태
  // =========================
  // 서버 전환 후에는 Firebase Auth / 본인인증 / 사업자 인증 결과를 통해
  // 서버가 최종 권한을 결정한다.
  // 현재 InMemory 구현에서는 로컬 개발/테스트용 상태 변경으로만 사용한다.

  Future<StoreProfile> updateIdentityVerified(bool verified);

  Future<StoreProfile> updateOwnerVerified(bool verified);

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
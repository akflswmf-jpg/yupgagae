import 'package:cloud_functions/cloud_functions.dart';

import 'package:yupgagae/features/my_store/domain/app_notification_item.dart';
import 'package:yupgagae/features/my_store/domain/blocked_user_item.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class ServerBackedStoreProfileRepository implements StoreProfileRepository {
  final StoreProfileRepository local;
  final FirebaseFunctions functions;

  ServerBackedStoreProfileRepository({
    required this.local,
    FirebaseFunctions? functions,
  }) : functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  @override
  Future<void> warmUp() async {
    await local.warmUp();

    try {
      await getBlockedUsers();
    } catch (_) {
      // 차단 목록 예열 실패가 앱 시작을 막으면 안 된다.
    }
  }

  @override
  Future<StoreProfile> fetchProfile() async {
    final base = await local.fetchProfile();

    try {
      final blockedUsers = await getBlockedUsers();

      return base.copyWith(
        blockedUsers: blockedUsers,
      );
    } catch (_) {
      return base;
    }
  }

  @override
  Future<StoreProfile> updateNickname(String nickname) async {
    final updated = await local.updateNickname(nickname);
    return _mergeServerBlockedUsers(updated);
  }

  @override
  Future<StoreProfile> updateNotificationsEnabled(bool enabled) async {
    final updated = await local.updateNotificationsEnabled(enabled);
    return _mergeServerBlockedUsers(updated);
  }

  @override
  Future<StoreProfile> updateIndustry(String industry) async {
    final updated = await local.updateIndustry(industry);
    return _mergeServerBlockedUsers(updated);
  }

  @override
  Future<StoreProfile> updateRegion(String region) async {
    final updated = await local.updateRegion(region);
    return _mergeServerBlockedUsers(updated);
  }

  @override
  Future<List<BlockedUserItem>> getBlockedUsers() async {
    try {
      final callable = functions.httpsCallable('fetchMyBlockedUsersOnServer');
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{},
      );

      final data = Map<String, dynamic>.from(result.data);
      final rawItems = data['items'];

      if (rawItems is! List) {
        return const <BlockedUserItem>[];
      }

      return rawItems
          .whereType<Map>()
          .map((raw) {
            return _blockedUserFromServer(
              Map<String, dynamic>.from(raw),
            );
          })
          .where((item) => item.userId.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return local.getBlockedUsers();
    }
  }

  @override
  Future<StoreProfile> blockUser(BlockedUserItem user) async {
    final targetId = user.userId.trim();

    if (targetId.isEmpty) {
      return fetchProfile();
    }

    try {
      final callable = functions.httpsCallable('blockUserOnServer');
      await callable.call<Map<String, dynamic>>(
        <String, dynamic>{
          'userId': targetId,
          'nickname': user.nickname.trim().isEmpty ? '익명' : user.nickname.trim(),
          'industry': user.industry?.trim(),
          'region': user.region?.trim(),
          'reason': '사용자 직접 차단',
        },
      );

      final localUpdated = await local.blockUser(user);
      final blockedUsers = await getBlockedUsers();

      return localUpdated.copyWith(
        blockedUsers: blockedUsers,
      );
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim();

      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }

      throw Exception('사용자 차단에 실패했습니다.');
    } catch (_) {
      throw Exception('사용자 차단에 실패했습니다.');
    }
  }

  @override
  Future<StoreProfile> unblockUser(String userId) async {
    final targetId = userId.trim();

    if (targetId.isEmpty) {
      return fetchProfile();
    }

    try {
      final callable = functions.httpsCallable('unblockUserOnServer');
      await callable.call<Map<String, dynamic>>(
        <String, dynamic>{
          'userId': targetId,
        },
      );

      final localUpdated = await local.unblockUser(targetId);
      final blockedUsers = await getBlockedUsers();

      return localUpdated.copyWith(
        blockedUsers: blockedUsers,
      );
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim();

      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }

      throw Exception('차단 해제에 실패했습니다.');
    } catch (_) {
      throw Exception('차단 해제에 실패했습니다.');
    }
  }

  @override
  Future<List<AppNotificationItem>> getNotifications() {
    return local.getNotifications();
  }

  @override
  Future<StoreProfile> addNotification(AppNotificationItem item) async {
    final updated = await local.addNotification(item);
    return _mergeServerBlockedUsers(updated);
  }

  @override
  Future<StoreProfile> markAsRead(String notificationId) async {
    final updated = await local.markAsRead(notificationId);
    return _mergeServerBlockedUsers(updated);
  }

  @override
  Future<StoreProfile> markAllRead() async {
    final updated = await local.markAllRead();
    return _mergeServerBlockedUsers(updated);
  }

  @override
  Future<StoreProfile> clearNotifications() async {
    final updated = await local.clearNotifications();
    return _mergeServerBlockedUsers(updated);
  }

  @override
  Future<void> addNotificationToUser(
    String userId,
    AppNotificationItem item,
  ) {
    return local.addNotificationToUser(userId, item);
  }

  @override
  Future<List<AppNotificationItem>> getNotificationsByUserId(String userId) {
    return local.getNotificationsByUserId(userId);
  }

  @override
  Future<List<BlockedUserItem>> getBlockedUsersByUserId(String userId) {
    return local.getBlockedUsersByUserId(userId);
  }

  Future<StoreProfile> _mergeServerBlockedUsers(StoreProfile base) async {
    try {
      final blockedUsers = await getBlockedUsers();

      return base.copyWith(
        blockedUsers: blockedUsers,
      );
    } catch (_) {
      return base;
    }
  }

  BlockedUserItem _blockedUserFromServer(Map<String, dynamic> json) {
    final blockedAtText = _stringValue(json['blockedAtIso']).isNotEmpty
        ? _stringValue(json['blockedAtIso'])
        : _stringValue(json['blockedAt']);

    final blockedAt = DateTime.tryParse(blockedAtText) ?? DateTime.now();

    final nickname = _stringValue(json['nickname']).isNotEmpty
        ? _stringValue(json['nickname'])
        : _stringValue(json['targetNickname']).isNotEmpty
            ? _stringValue(json['targetNickname'])
            : '익명';

    return BlockedUserItem(
      userId: _stringValue(json['userId']).isNotEmpty
          ? _stringValue(json['userId'])
          : _stringValue(json['targetUserId']),
      nickname: nickname,
      industry: _nullableStringValue(json['industry']) ??
          _nullableStringValue(json['targetIndustry']),
      region: _nullableStringValue(json['region']) ??
          _nullableStringValue(json['targetRegion']),
      blockedAt: blockedAt,
    );
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String? _nullableStringValue(dynamic value) {
    final text = _stringValue(value);
    if (text.isEmpty) return null;
    return text;
  }
}
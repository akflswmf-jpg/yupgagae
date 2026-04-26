import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/community/domain/region_catalog.dart';
import 'package:yupgagae/features/my_store/domain/app_notification_item.dart';
import 'package:yupgagae/features/my_store/domain/blocked_user_item.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class InMemoryStoreProfileRepository implements StoreProfileRepository {
  static const String _profilesKey = 'my_store.multi_profiles_v1';
  static const String _profilesBackupKey = 'my_store.multi_profiles_v1.backup';
  static const String _profilesCorruptBackupKey =
      'my_store.multi_profiles_v1.corrupt_backup';

  final AnonSessionService session;

  InMemoryStoreProfileRepository({
    required this.session,
  }) {
    _loadFuture = _loadFromPrefs();
  }

  final Map<String, StoreProfile> _profiles = <String, StoreProfile>{};

  bool _loaded = false;
  Future<void>? _loadFuture;

  Future<void> _saveChain = Future<void>.value();

  String get _me => session.anonId;

  @override
  Future<void> warmUp() async {
    await _ensureLoaded();
  }

  StoreProfile _defaultProfile(String userId) {
    final safeUserId = userId.trim();
    final suffix = safeUserId.length >= 4
        ? safeUserId.substring(safeUserId.length - 4)
        : safeUserId;

    return StoreProfile(
      nickname: suffix.isEmpty ? '익명' : '익명-$suffix',
      region: '서울',
      industry: '미용/헤어',
      isOwnerVerified: false,
      isIdentityVerified: false,
      notificationsEnabled: true,
      blockedUsers: const <BlockedUserItem>[],
      notifications: const <AppNotificationItem>[],
    );
  }

  Future<void> _ensureLoaded() async {
    final future = _loadFuture;
    if (future != null) {
      await future;
    }

    if (!_loaded) {
      _loadFuture = _loadFromPrefs();
      await _loadFuture;
    }
  }

  Future<void> _loadFromPrefs() async {
    var shouldPersist = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profilesKey);

      if (raw != null && raw.trim().isNotEmpty) {
        final decodedProfiles = await compute(
          _decodeStoreProfilesOnWorker,
          raw,
        );

        if (decodedProfiles.isNotEmpty) {
          _profiles
            ..clear()
            ..addAll(decodedProfiles);
        } else {
          await prefs.setString(_profilesCorruptBackupKey, raw);
          _debugLog(
            'profile decode returned empty. raw backed up to $_profilesCorruptBackupKey',
          );
        }
      }

      if (!_profiles.containsKey(_me)) {
        _profiles[_me] = _defaultProfile(_me);
        shouldPersist = true;
        _debugLog('default profile created for $_me');
      }

      if (shouldPersist) {
        await _persist();
      }
    } catch (e, st) {
      _debugLog('load failed: $e');
      _debugLog('$st');

      await _recoverAfterLoadFailure();
    } finally {
      _loaded = true;
    }
  }

  Future<void> _recoverAfterLoadFailure() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profilesKey);

      if (raw != null && raw.trim().isNotEmpty) {
        await prefs.setString(_profilesCorruptBackupKey, raw);
      }

      final backupRaw = prefs.getString(_profilesBackupKey);
      if (backupRaw != null && backupRaw.trim().isNotEmpty) {
        final decodedBackup = await compute(
          _decodeStoreProfilesOnWorker,
          backupRaw,
        );

        if (decodedBackup.isNotEmpty) {
          _profiles
            ..clear()
            ..addAll(decodedBackup);

          _debugLog('profile recovered from backup');

          if (!_profiles.containsKey(_me)) {
            _profiles[_me] = _defaultProfile(_me);
            await _persist();
          }

          return;
        }
      }

      if (!_profiles.containsKey(_me)) {
        _profiles[_me] = _defaultProfile(_me);
        await _persist();
      }
    } catch (e, st) {
      _debugLog('recover failed: $e');
      _debugLog('$st');

      if (!_profiles.containsKey(_me)) {
        _profiles[_me] = _defaultProfile(_me);
      }
    }
  }

  Future<void> _persist() async {
    _saveChain = _saveChain.then((_) async {
      final prefs = await SharedPreferences.getInstance();

      final currentRaw = prefs.getString(_profilesKey);
      if (currentRaw != null && currentRaw.trim().isNotEmpty) {
        await prefs.setString(_profilesBackupKey, currentRaw);
      }

      final payload = <String, dynamic>{};
      _profiles.forEach((key, value) {
        final safeKey = key.trim();
        if (safeKey.isEmpty) return;

        payload[safeKey] = value.toJson();
      });

      final encoded = await compute(
        _encodeStoreProfilesOnWorker,
        payload,
      );

      await prefs.setString(_profilesKey, encoded);
    }).catchError((e, st) {
      _debugLog('persist failed: $e');
      _debugLog('$st');
    });

    await _saveChain;
  }

  StoreProfile _get(String userId) {
    final safeUserId = userId.trim();

    if (safeUserId.isEmpty) {
      return _profiles.putIfAbsent(
        _me,
        () => _defaultProfile(_me),
      );
    }

    return _profiles.putIfAbsent(
      safeUserId,
      () => _defaultProfile(safeUserId),
    );
  }

  List<AppNotificationItem> _sortedNotifications(List<AppNotificationItem> src) {
    final next = List<AppNotificationItem>.from(src)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<AppNotificationItem>.unmodifiable(next);
  }

  List<BlockedUserItem> _normalizedBlockedUsers(List<BlockedUserItem> src) {
    final map = <String, BlockedUserItem>{};

    for (final item in src) {
      final id = item.userId.trim();
      if (id.isEmpty) continue;
      map[id] = item.copyWith(userId: id);
    }

    final next = map.values.toList()
      ..sort((a, b) => b.blockedAt.compareTo(a.blockedAt));

    return List<BlockedUserItem>.unmodifiable(next);
  }

  @override
  Future<StoreProfile> fetchProfile() async {
    await _ensureLoaded();
    return _get(_me);
  }

  @override
  Future<StoreProfile> updateNickname(String nickname) async {
    await _ensureLoaded();

    final normalized = nickname.trim();

    if (normalized.isEmpty) {
      throw Exception('닉네임을 입력하세요');
    }

    if (normalized.length < 2) {
      throw Exception('닉네임은 2자 이상이어야 합니다');
    }

    if (normalized.length > 12) {
      throw Exception('닉네임은 12자 이하로 입력하세요');
    }

    final p = _get(_me);
    final updated = p.copyWith(nickname: normalized);

    _profiles[_me] = updated;
    await _persist();

    return updated;
  }

  @override
  Future<StoreProfile> updateNotificationsEnabled(bool enabled) async {
    await _ensureLoaded();

    final p = _get(_me);
    final updated = p.copyWith(notificationsEnabled: enabled);

    _profiles[_me] = updated;
    await _persist();

    return updated;
  }

  @override
  Future<StoreProfile> updateIndustry(String industry) async {
    await _ensureLoaded();

    final normalized = industry.trim();

    if (normalized.isEmpty) {
      throw Exception('업종을 선택하세요');
    }

    final valid = IndustryCatalog.ordered().any((e) => e.name == normalized);

    if (!valid) {
      throw Exception('유효하지 않은 업종입니다');
    }

    final p = _get(_me);
    final updated = p.copyWith(industry: normalized);

    _profiles[_me] = updated;
    await _persist();

    return updated;
  }

  @override
  Future<StoreProfile> updateRegion(String region) async {
    await _ensureLoaded();

    final normalized = RegionCatalog.normalize(region);

    if (normalized == null || normalized.isEmpty) {
      throw Exception('지역을 선택하세요');
    }

    if (!StoreProfile.regionOptions.contains(normalized)) {
      throw Exception('유효하지 않은 지역입니다');
    }

    final p = _get(_me);
    final updated = p.copyWith(region: normalized);

    _profiles[_me] = updated;
    await _persist();

    return updated;
  }

  @override
  Future<StoreProfile> updateIdentityVerified(bool verified) async {
    await _ensureLoaded();

    final p = _get(_me);
    final updated = p.copyWith(
      isIdentityVerified: verified,
      isOwnerVerified: verified ? p.isOwnerVerified : false,
    );

    _profiles[_me] = updated;
    await _persist();

    return updated;
  }

  @override
  Future<StoreProfile> updateOwnerVerified(bool verified) async {
    await _ensureLoaded();

    final p = _get(_me);

    if (verified && !p.isIdentityVerified) {
      throw Exception('본인인증 후 사업자 인증을 진행할 수 있습니다');
    }

    final updated = p.copyWith(
      isOwnerVerified: verified,
    );

    _profiles[_me] = updated;
    await _persist();

    return updated;
  }

  @override
  Future<List<BlockedUserItem>> getBlockedUsers() async {
    await _ensureLoaded();
    return List<BlockedUserItem>.unmodifiable(_get(_me).blockedUsers);
  }

  @override
  Future<StoreProfile> blockUser(BlockedUserItem user) async {
    await _ensureLoaded();

    final normalizedUserId = user.userId.trim();

    if (normalizedUserId.isEmpty) {
      throw Exception('차단할 사용자 ID가 비어 있습니다');
    }

    final p = _get(_me);
    final next = List<BlockedUserItem>.from(p.blockedUsers)
      ..removeWhere((e) => e.userId == normalizedUserId)
      ..insert(0, user.copyWith(userId: normalizedUserId));

    final updated = p.copyWith(
      blockedUsers: _normalizedBlockedUsers(next),
    );

    _profiles[_me] = updated;
    await _persist();

    return updated;
  }

  @override
  Future<StoreProfile> unblockUser(String userId) async {
    await _ensureLoaded();

    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw Exception('해제할 사용자 ID가 비어 있습니다');
    }

    final p = _get(_me);
    final next = p.blockedUsers
        .where((e) => e.userId != normalizedUserId)
        .toList(growable: false);

    final updated = p.copyWith(
      blockedUsers: List<BlockedUserItem>.unmodifiable(next),
    );

    _profiles[_me] = updated;
    await _persist();

    return updated;
  }

  @override
  Future<List<AppNotificationItem>> getNotifications() async {
    await _ensureLoaded();
    return List<AppNotificationItem>.unmodifiable(_get(_me).notifications);
  }

  @override
  Future<StoreProfile> addNotification(AppNotificationItem item) async {
    await _ensureLoaded();

    final normalizedId = item.id.trim();

    if (normalizedId.isEmpty) {
      throw Exception('알림 ID가 비어 있습니다');
    }

    final p = _get(_me);
    final next = List<AppNotificationItem>.from(p.notifications)
      ..removeWhere((e) => e.id == normalizedId)
      ..insert(0, item.copyWith(id: normalizedId));

    final updated = p.copyWith(
      notifications: _sortedNotifications(next),
    );

    _profiles[_me] = updated;
    await _persist();

    return updated;
  }

  @override
  Future<StoreProfile> markAsRead(String notificationId) async {
    await _ensureLoaded();

    final normalizedId = notificationId.trim();

    if (normalizedId.isEmpty) {
      throw Exception('알림 ID가 비어 있습니다');
    }

    final p = _get(_me);
    final next = p.notifications
        .map((e) => e.id == normalizedId ? e.copyWith(isRead: true) : e)
        .toList(growable: false);

    final updated = p.copyWith(
      notifications: List<AppNotificationItem>.unmodifiable(next),
    );

    _profiles[_me] = updated;
    await _persist();

    return updated;
  }

  @override
  Future<StoreProfile> markAllRead() async {
    await _ensureLoaded();

    final p = _get(_me);
    final next = p.notifications
        .map((e) => e.copyWith(isRead: true))
        .toList(growable: false);

    final updated = p.copyWith(
      notifications: List<AppNotificationItem>.unmodifiable(next),
    );

    _profiles[_me] = updated;
    await _persist();

    return updated;
  }

  @override
  Future<StoreProfile> clearNotifications() async {
    await _ensureLoaded();

    final p = _get(_me);
    final updated = p.copyWith(
      notifications: const <AppNotificationItem>[],
    );

    _profiles[_me] = updated;
    await _persist();

    return updated;
  }

  @override
  Future<void> addNotificationToUser(
    String userId,
    AppNotificationItem item,
  ) async {
    await _ensureLoaded();

    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;

    final normalizedId = item.id.trim();
    if (normalizedId.isEmpty) return;

    final p = _get(normalizedUserId);
    final next = List<AppNotificationItem>.from(p.notifications)
      ..removeWhere((e) => e.id == normalizedId)
      ..insert(0, item.copyWith(id: normalizedId));

    _profiles[normalizedUserId] = p.copyWith(
      notifications: _sortedNotifications(next),
    );

    await _persist();
  }

  @override
  Future<List<AppNotificationItem>> getNotificationsByUserId(
    String userId,
  ) async {
    await _ensureLoaded();
    return List<AppNotificationItem>.unmodifiable(_get(userId).notifications);
  }

  @override
  Future<List<BlockedUserItem>> getBlockedUsersByUserId(String userId) async {
    await _ensureLoaded();
    return List<BlockedUserItem>.unmodifiable(_get(userId).blockedUsers);
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[InMemoryStoreProfileRepository] $message');
    }
  }
}

String _encodeStoreProfilesOnWorker(Map<String, dynamic> payload) {
  return jsonEncode(payload);
}

Map<String, StoreProfile> _decodeStoreProfilesOnWorker(String raw) {
  final decoded = jsonDecode(raw);

  if (decoded is! Map) {
    return <String, StoreProfile>{};
  }

  final profiles = <String, StoreProfile>{};

  decoded.forEach((key, value) {
    try {
      final userId = key.toString().trim();

      if (userId.isEmpty) return;
      if (value is! Map) return;

      profiles[userId] = StoreProfile.fromJson(
        Map<String, dynamic>.from(value),
      );
    } catch (_) {
      // 한 유저의 오래된/깨진 프로필 때문에 전체 프로필을 버리지 않는다.
    }
  });

  return profiles;
}
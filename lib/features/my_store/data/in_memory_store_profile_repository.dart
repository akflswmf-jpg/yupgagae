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

  final AnonSessionService session;

  InMemoryStoreProfileRepository({
    required this.session,
  }) {
    // 생성 즉시 SharedPreferences 로딩을 시작한다.
    // fetchProfile() 호출 시점엔 이미 완료되어 있거나 in-flight future를 공유한다.
    _loadFuture = _loadFromPrefs();
  }

  final Map<String, StoreProfile> _profiles = {};
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
      isOwnerVerified: true,
      isIdentityVerified: true,
      notificationsEnabled: true,
      blockedUsers: const [],
      notifications: const [],
    );
  }

  Future<void> _ensureLoaded() async {
    // 생성자에서 항상 _loadFuture를 set하므로 null 체크 불필요.
    await _loadFuture;
  }

  Future<void> _loadFromPrefs() async {
    var shouldPersist = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profilesKey);

      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final decodedProfiles = await compute(
            _decodeStoreProfilesOnWorker,
            raw,
          );

          _profiles
            ..clear()
            ..addAll(decodedProfiles);
        } catch (_) {
          _profiles.clear();
          shouldPersist = true;
        }
      }

      if (!_profiles.containsKey(_me)) {
        _profiles[_me] = _defaultProfile(_me);
        shouldPersist = true;
      }

      if (shouldPersist) {
        await _persist();
      }
    } finally {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    _saveChain = _saveChain.then((_) async {
      final prefs = await SharedPreferences.getInstance();

      final payload = <String, dynamic>{};
      _profiles.forEach((k, v) {
        payload[k] = v.toJson();
      });

      final encoded = await compute(
        _encodeStoreProfilesOnWorker,
        payload,
      );

      await prefs.setString(_profilesKey, encoded);
    }).catchError((_) {
      // 로컬 저장 실패는 앱 흐름을 막지 않는다.
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
    return next;
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

    return next;
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
      blockedUsers: List<BlockedUserItem>.unmodifiable(
        _normalizedBlockedUsers(next),
      ),
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
      notifications: List<AppNotificationItem>.unmodifiable(
        _sortedNotifications(next),
      ),
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
    final updated = p.copyWith(notifications: const []);

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
      notifications: List<AppNotificationItem>.unmodifiable(
        _sortedNotifications(next),
      ),
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
    final userId = key.toString().trim();

    if (userId.isEmpty) return;
    if (value is! Map) return;

    profiles[userId] = StoreProfile.fromJson(
      Map<String, dynamic>.from(value),
    );
  });

  return profiles;
}
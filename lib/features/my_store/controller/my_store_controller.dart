import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/app_notification_item.dart';
import 'package:yupgagae/features/my_store/domain/blocked_user_item.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class MyStoreController extends GetxController {
  final StoreProfileRepository repo;
  final PostRepository postRepo;
  final AuthSessionService auth;

  MyStoreController({
    required this.repo,
    required this.postRepo,
    required this.auth,
  });

  final isLoading = false.obs;
  final isSavingNickname = false.obs;
  final isSavingNotification = false.obs;
  final isSavingIndustry = false.obs;
  final isSavingRegion = false.obs;
  final isSavingVerification = false.obs;

  final isLoadingMyPosts = false.obs;
  final isLoadingMyComments = false.obs;

  final error = RxnString();
  final myActivityError = RxnString();

  final profile = Rxn<StoreProfile>();

  final notifications = <AppNotificationItem>[].obs;
  final blockedUsers = <BlockedUserItem>[].obs;

  final myPosts = <Post>[].obs;
  final myComments = <Comment>[].obs;

  bool _didLoadMyPosts = false;
  bool _didLoadMyComments = false;

  String get currentUserId => auth.currentUserId;

  int get unreadNotificationCount {
    return notifications.where((e) => !e.isRead).length;
  }

  bool get isIdentityVerified {
    return profile.value?.isIdentityVerified ?? false;
  }

  bool get isOwnerVerified {
    return profile.value?.isOwnerVerified ?? false;
  }

  bool get hasLoadedMyPosts {
    return _didLoadMyPosts;
  }

  bool get hasLoadedMyComments {
    return _didLoadMyComments;
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;
      error.value = null;

      final result = await repo.fetchProfile();
      _applyProfile(result);
    } catch (_) {
      error.value = '내가게 정보를 불러오지 못했습니다.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshProfile() async {
    await load();
  }

  Future<void> loadMyPosts({bool force = false}) async {
    if (isLoadingMyPosts.value) return;
    if (!force && _didLoadMyPosts) return;

    try {
      isLoadingMyPosts.value = true;
      myActivityError.value = null;

      final result = await postRepo.fetchMyPosts();
      myPosts.assignAll(result);
      _didLoadMyPosts = true;
    } catch (e) {
      myActivityError.value = e.toString();
    } finally {
      isLoadingMyPosts.value = false;
    }
  }

  Future<void> loadMyComments({bool force = false}) async {
    if (isLoadingMyComments.value) return;
    if (!force && _didLoadMyComments) return;

    try {
      isLoadingMyComments.value = true;
      myActivityError.value = null;

      final result = await postRepo.fetchMyComments();
      myComments.assignAll(result);
      _didLoadMyComments = true;
    } catch (e) {
      myActivityError.value = e.toString();
    } finally {
      isLoadingMyComments.value = false;
    }
  }

  Future<void> refreshMyPosts() async {
    await loadMyPosts(force: true);
  }

  Future<void> refreshMyComments() async {
    await loadMyComments(force: true);
  }

  Future<void> changeNickname(String nickname) async {
    final normalized = nickname.trim();

    if (normalized.isEmpty) {
      throw Exception('닉네임을 입력하세요.');
    }

    if (normalized.length > 10) {
      throw Exception('닉네임은 10글자 이하로 입력해주세요.');
    }

    try {
      isSavingNickname.value = true;
      error.value = null;

      final updated = await repo.updateNickname(normalized);
      _applyProfile(updated);
    } finally {
      isSavingNickname.value = false;
    }
  }

  Future<void> changeIndustry(String industry) async {
    final normalized = industry.trim();

    if (normalized.isEmpty) {
      throw Exception('업종을 선택하세요.');
    }

    try {
      isSavingIndustry.value = true;
      error.value = null;

      final updated = await repo.updateIndustry(normalized);
      _applyProfile(updated);
    } finally {
      isSavingIndustry.value = false;
    }
  }

  Future<void> changeRegion(String region) async {
    final normalized = region.trim();

    if (normalized.isEmpty) {
      throw Exception('지역을 선택하세요.');
    }

    try {
      isSavingRegion.value = true;
      error.value = null;

      final updated = await repo.updateRegion(normalized);
      _applyProfile(updated);
    } finally {
      isSavingRegion.value = false;
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      isSavingNotification.value = true;
      error.value = null;

      final updated = await repo.updateNotificationsEnabled(enabled);
      _applyProfile(updated);
    } finally {
      isSavingNotification.value = false;
    }
  }

  Future<void> updateNotificationEnabled(bool enabled) async {
    await setNotificationsEnabled(enabled);
  }

  Future<void> setIdentityVerifiedForDev(bool verified) async {
    if (isSavingVerification.value) return;

    try {
      isSavingVerification.value = true;
      error.value = null;

      final updated = await repo.updateIdentityVerified(verified);
      _applyProfile(updated);
    } finally {
      isSavingVerification.value = false;
    }
  }

  Future<void> setOwnerVerifiedForDev(bool verified) async {
    if (isSavingVerification.value) return;

    try {
      isSavingVerification.value = true;
      error.value = null;

      final updated = await repo.updateOwnerVerified(verified);
      _applyProfile(updated);
    } finally {
      isSavingVerification.value = false;
    }
  }

  Future<void> verifyIdentityForDev() async {
    await setIdentityVerifiedForDev(true);
  }

  Future<void> clearIdentityVerificationForDev() async {
    await setIdentityVerifiedForDev(false);
  }

  Future<void> verifyOwnerForDev() async {
    if (!isIdentityVerified) {
      await setIdentityVerifiedForDev(true);
    }

    await setOwnerVerifiedForDev(true);
  }

  Future<void> clearOwnerVerificationForDev() async {
    await setOwnerVerifiedForDev(false);
  }

  Future<void> clearAllVerificationForDev() async {
    if (isSavingVerification.value) return;

    try {
      isSavingVerification.value = true;
      error.value = null;

      final identityCleared = await repo.updateIdentityVerified(false);
      _applyProfile(identityCleared);
    } finally {
      isSavingVerification.value = false;
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;

    final updated = await repo.markAsRead(id);
    _applyProfile(updated);
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await markNotificationRead(notificationId);
  }

  Future<void> markAllNotificationsRead() async {
    final updated = await repo.markAllRead();
    _applyProfile(updated);
  }

  Future<void> markAllNotificationsAsRead() async {
    await markAllNotificationsRead();
  }

  Future<void> addNotification(AppNotificationItem item) async {
    final updated = await repo.addNotification(item);
    _applyProfile(updated);
  }

  Future<void> removeNotification(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;

    final p = profile.value;
    if (p == null) return;

    final nextNotifications =
        p.notifications.where((e) => e.id != id).toList(growable: false);

    final updated = p.copyWith(
      notifications: nextNotifications,
    );

    profile.value = updated;
    notifications.assignAll(updated.notifications);
  }

  Future<void> clearNotifications() async {
    final updated = await repo.clearNotifications();
    _applyProfile(updated);
  }

  Future<void> blockUser(BlockedUserItem user) async {
    final targetId = user.userId.trim();
    if (targetId.isEmpty) return;

    final updated = await repo.blockUser(user);
    _applyProfile(updated);
  }

  Future<void> blockUserByInfo({
    required String userId,
    required String nickname,
    String? industry,
    String? region,
    String? reason,
  }) async {
    final targetId = userId.trim();
    if (targetId.isEmpty) return;

    await blockUser(
      BlockedUserItem(
        userId: targetId,
        nickname: nickname.trim().isEmpty ? '익명' : nickname.trim(),
        industry: industry,
        region: region,
        blockedAt: DateTime.now(),
      ),
    );
  }

  Future<void> unblockUser(String userId) async {
    final targetId = userId.trim();
    if (targetId.isEmpty) return;

    final updated = await repo.unblockUser(targetId);
    _applyProfile(updated);
  }

  void applyDeletedPost(String postId) {
    final id = postId.trim();
    if (id.isEmpty) return;

    myPosts.removeWhere((e) => e.id == id);
  }

  void applyUpdatedPost(Post updated) {
    final index = myPosts.indexWhere((e) => e.id == updated.id);
    if (index == -1) return;

    final next = List<Post>.from(myPosts);
    next[index] = updated;
    myPosts.assignAll(next);
  }

  void _applyProfile(StoreProfile updated) {
    profile.value = updated;
    notifications.assignAll(updated.notifications);
    blockedUsers.assignAll(updated.blockedUsers);
  }
}
import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/auth/app_user.dart';
import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/core/auth/permission_policy.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/app_notification_item.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class PostDetailController extends GetxController {
  final PostRepository repo;
  final AuthSessionService auth;
  final StoreProfileRepository storeProfileRepo;

  PostDetailController({
    required this.repo,
    required this.auth,
    required this.storeProfileRepo,
  });

  final post = Rxn<Post>();
  final isLoading = false.obs;
  final error = RxnString();

  final isDeleting = false.obs;
  final isReporting = false.obs;
  final isTogglingLike = false.obs;
  final isTogglingSold = false.obs;

  String? _postId;
  bool _didInitialize = false;
  bool _didIncrementView = false;

  int _loadGeneration = 0;

  final Set<String> _blockedAuthorIds = <String>{};
  bool _isBlockedAuthorPost = false;

  AppUser? get _currentAuthUser {
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>().currentUser.value;
  }

  String get currentUserId {
    final user = _currentAuthUser;
    if (user == null) return '';

    return user.userId.trim();
  }

  String get postId => _postId ?? '';

  bool get isReady {
    final id = _postId;
    return id != null && id.trim().isNotEmpty;
  }

  bool get isOwner {
    final p = post.value;
    final userId = currentUserId;

    if (p == null) return false;
    if (userId.isEmpty) return false;

    return p.authorId == userId;
  }

  bool get isAuthor => isOwner;

  bool get likedByMe {
    final p = post.value;
    final userId = currentUserId;

    if (p == null) return false;
    if (userId.isEmpty) return false;

    return p.likedUserIds.contains(userId);
  }

  bool get canToggleSold {
    final p = post.value;
    if (p == null) return false;

    return PermissionPolicy.canToggleSold(
      user: _currentAuthUser,
      post: p,
    );
  }

  bool get canParticipate {
    return PermissionPolicy.canParticipate(_currentAuthUser);
  }

  bool get canReportCurrentPost {
    final p = post.value;
    if (p == null) return false;

    return PermissionPolicy.canReportPost(
      user: _currentAuthUser,
      post: p,
    );
  }

  bool get canDeleteCurrentPost {
    final p = post.value;
    if (p == null) return false;

    return PermissionPolicy.canDeletePost(
      user: _currentAuthUser,
      post: p,
    );
  }

  bool get isBlockedAuthorPost {
    return _isBlockedAuthorPost;
  }

  void _ensureParticipationAllowed() {
    final user = _currentAuthUser;

    if (!PermissionPolicy.canParticipate(user)) {
      throw Exception(PermissionPolicy.participationBlockedMessage(user));
    }
  }

  void _ensureLikeAllowed() {
    final user = _currentAuthUser;

    if (!PermissionPolicy.canTogglePostLike(user)) {
      throw Exception(PermissionPolicy.participationBlockedMessage(user));
    }
  }

  void _ensureReportAllowed(Post targetPost) {
    final user = _currentAuthUser;

    if (!PermissionPolicy.canReportPost(
      user: user,
      post: targetPost,
    )) {
      if (!PermissionPolicy.canParticipate(user)) {
        throw Exception(PermissionPolicy.participationBlockedMessage(user));
      }

      if (targetPost.authorId == currentUserId) {
        throw Exception('본인 글은 신고할 수 없습니다.');
      }

      throw Exception('신고 권한이 없습니다.');
    }
  }

  void _ensureDeleteAllowed(Post targetPost) {
    final user = _currentAuthUser;

    if (!PermissionPolicy.canDeletePost(
      user: user,
      post: targetPost,
    )) {
      if (!PermissionPolicy.canParticipate(user)) {
        throw Exception(PermissionPolicy.participationBlockedMessage(user));
      }

      throw Exception('삭제 권한이 없습니다.');
    }
  }

  void _ensureToggleSoldAllowed(Post targetPost) {
    final user = _currentAuthUser;

    if (!PermissionPolicy.canToggleSold(
      user: user,
      post: targetPost,
    )) {
      if (!PermissionPolicy.canParticipate(user)) {
        throw Exception(PermissionPolicy.participationBlockedMessage(user));
      }

      throw Exception('거래완료 처리 권한이 없습니다.');
    }
  }

  Future<void> initialize(
    String postId, {
    Post? initialPost,
  }) async {
    final normalized = postId.trim();

    if (normalized.isEmpty) {
      error.value = 'postId required';
      post.value = null;
      return;
    }

    final usableInitialPost =
        initialPost != null && initialPost.id.trim() == normalized
            ? initialPost
            : null;

    await _loadBlockedAuthorIds();

    if (usableInitialPost != null && _isBlockedPost(usableInitialPost)) {
      _postId = normalized;
      _didInitialize = true;
      _didIncrementView = false;
      _applyBlockedPostState();
      return;
    }

    final isSameTarget = _didInitialize && _postId == normalized;

    _postId = normalized;
    _didInitialize = true;

    if (!isSameTarget) {
      _didIncrementView = false;
    }

    if (usableInitialPost != null) {
      _isBlockedAuthorPost = false;
      post.value = usableInitialPost;
      error.value = null;
      isLoading.value = false;

      // 목록에서 이미 들고 있던 게시글을 먼저 보여주고,
      // 서버 최신값/조회수 증가는 첫 프레임을 막지 않고 뒤에서 맞춘다.
      unawaited(load(showLoading: false));
      return;
    }

    if (isSameTarget && post.value != null) {
      unawaited(load(showLoading: false));
      return;
    }

    await load();
  }

  void applyInitialPost(Post initialPost) {
    final normalized = initialPost.id.trim();
    if (normalized.isEmpty) return;

    _postId = normalized;
    _didInitialize = true;

    if (_isBlockedPost(initialPost)) {
      _applyBlockedPostState();
      return;
    }

    _isBlockedAuthorPost = false;
    post.value = initialPost;
    error.value = null;
    isLoading.value = false;
  }

  Future<void> load({bool showLoading = true}) async {
    final targetPostId = postId.trim();

    if (targetPostId.isEmpty) {
      error.value = 'postId required';
      post.value = null;
      return;
    }

    final generation = ++_loadGeneration;

    if (showLoading) {
      isLoading.value = true;
    }
    error.value = null;

    try {
      await _ensureRepositoryReady();

      final loaded = await repo.getPostById(targetPostId);

      if (!_isCurrentLoadTarget(
        generation: generation,
        targetPostId: targetPostId,
      )) {
        return;
      }

      await _loadBlockedAuthorIds();

      if (_isBlockedPost(loaded)) {
        _applyBlockedPostState();
        return;
      }

      _isBlockedAuthorPost = false;
      post.value = loaded;

      unawaited(
        _incrementViewSilently(
          targetPostId: targetPostId,
          generation: generation,
          baseViewCount: loaded.viewCount,
        ),
      );
    } catch (e) {
      if (!_isCurrentLoadTarget(
        generation: generation,
        targetPostId: targetPostId,
      )) {
        return;
      }

      error.value = e.toString();

      // initialPost로 이미 화면을 그리고 있는 상태의 백그라운드 갱신 실패는
      // 상세 본문을 비우지 않는다. 빈 화면으로 갈아엎는 순간 체감 버벅임이 생긴다.
      if (showLoading || post.value == null) {
        post.value = null;
      }
    } finally {
      if (_loadGeneration == generation && showLoading) {
        isLoading.value = false;
      }
    }
  }

  Future<void> refreshPost() async {
    final targetPostId = postId.trim();

    if (targetPostId.isEmpty) {
      error.value = 'postId required';
      post.value = null;
      return;
    }

    error.value = null;

    try {
      final loaded = await repo.getPostById(targetPostId);

      if (_postId != targetPostId) {
        return;
      }

      await _loadBlockedAuthorIds();

      if (_isBlockedPost(loaded)) {
        _applyBlockedPostState();
        return;
      }

      _isBlockedAuthorPost = false;
      post.value = loaded;
    } catch (e) {
      if (_postId != targetPostId) {
        return;
      }

      error.value = e.toString();
    }
  }

  Future<void> reload() async {
    await refreshPost();
  }

  Future<void> forceRefresh() async {
    await refreshPost();
  }

  Future<void> _ensureRepositoryReady() async {
    try {
      final dynamic repoDyn = repo;
      await repoDyn.ensureReady();
    } catch (_) {}
  }

  Future<void> _incrementViewSilently({
    required String targetPostId,
    required int generation,
    required int baseViewCount,
  }) async {
    if (targetPostId.trim().isEmpty) return;
    if (_postId != targetPostId) return;
    if (_didIncrementView) return;

    _didIncrementView = true;

    try {
      await repo.incrementView(targetPostId);

      if (!_isCurrentLoadTarget(
        generation: generation,
        targetPostId: targetPostId,
      )) {
        return;
      }

      // 조회수 증가는 서버에만 조용히 반영한다.
      //
      // 상세 진입 직후 post.value를 다시 갱신하면 본문/댓글 영역이 한 번 더
      // rebuild되면서 Firestore 전환 후 체감 버벅임이 커진다. 조회수 숫자 1 증가를
      // 즉시 보여주는 것보다 상세 진입 프레임 안정성이 더 중요하다.
    } catch (_) {}
  }

  Future<Post> toggleLike() async {
    _ensureLikeAllowed();

    final current = post.value;
    final targetPostId = postId.trim();
    final userId = currentUserId;

    if (targetPostId.isEmpty || current == null) {
      throw Exception('게시글을 찾을 수 없습니다.');
    }

    if (_isBlockedPost(current)) {
      _applyBlockedPostState();
      throw Exception('차단한 사용자의 글입니다.');
    }

    if (userId.isEmpty) {
      throw Exception('로그인이 필요한 기능입니다.');
    }

    if (isTogglingLike.value) {
      return current;
    }

    final before = current;
    final wasLiked = before.likedUserIds.contains(userId);
    final optimisticLikedUserIds = Set<String>.from(before.likedUserIds);

    if (wasLiked) {
      optimisticLikedUserIds.remove(userId);
    } else {
      optimisticLikedUserIds.add(userId);
    }

    final optimistic = before.copyWith(
      likedUserIds: optimisticLikedUserIds,
      likeCount: optimisticLikedUserIds.length,
    );

    post.value = optimistic;
    isTogglingLike.value = true;
    error.value = null;

    try {
      final updated = await repo.toggleLike(
        postId: targetPostId,
      );

      if (_isBlockedPost(updated)) {
        _applyBlockedPostState();
        throw Exception('차단한 사용자의 글입니다.');
      }

      if (_postId == targetPostId) {
        post.value = updated;
      }

      unawaited(
        _maybeNotifyLike(
          before: before,
          after: updated,
        ),
      );

      return updated;
    } catch (e) {
      if (_postId == targetPostId && !_isBlockedAuthorPost) {
        post.value = before;
      }

      error.value = e.toString();
      rethrow;
    } finally {
      isTogglingLike.value = false;
    }
  }

  Future<Post> toggleSold() async {
    final current = post.value;
    final targetPostId = postId.trim();

    if (targetPostId.isEmpty || current == null) {
      throw Exception('게시글을 찾을 수 없습니다.');
    }

    if (_isBlockedPost(current)) {
      _applyBlockedPostState();
      throw Exception('차단한 사용자의 글입니다.');
    }

    _ensureToggleSoldAllowed(current);

    if (isTogglingSold.value) {
      return current;
    }

    isTogglingSold.value = true;
    error.value = null;

    try {
      final updated = await repo.toggleSold(
        postId: targetPostId,
      );

      if (_isBlockedPost(updated)) {
        _applyBlockedPostState();
        throw Exception('차단한 사용자의 글입니다.');
      }

      if (_postId == targetPostId) {
        post.value = updated;
      }

      return updated;
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isTogglingSold.value = false;
    }
  }

  Future<bool> canDeletePost() async {
    final targetPostId = postId.trim();
    if (targetPostId.isEmpty) return false;

    final current = post.value;
    if (current == null) return false;

    if (!PermissionPolicy.canDeletePost(
      user: _currentAuthUser,
      post: current,
    )) {
      return false;
    }

    try {
      return await repo.canDeletePost(
        postId: targetPostId,
      );
    } catch (e) {
      error.value = e.toString();
      return false;
    }
  }

  Future<bool> deletePost() async {
    final current = post.value;
    final targetPostId = postId.trim();

    if (targetPostId.isEmpty) return false;
    if (current == null) return false;
    if (isDeleting.value) return false;

    try {
      _ensureDeleteAllowed(current);
    } catch (e) {
      error.value = e.toString();
      return false;
    }

    isDeleting.value = true;
    error.value = null;

    try {
      await repo.deletePost(
        postId: targetPostId,
      );

      if (_postId == targetPostId) {
        post.value = null;
      }

      return true;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      isDeleting.value = false;
    }
  }

  Future<bool> deleteThisPost() async {
    return deletePost();
  }

  Future<void> reportPost(String reason) async {
    final current = post.value;
    final targetPostId = postId.trim();

    if (targetPostId.isEmpty) return;
    if (current == null) return;
    if (isReporting.value) return;

    if (_isBlockedPost(current)) {
      _applyBlockedPostState();
      throw Exception('차단한 사용자의 글입니다.');
    }

    _ensureReportAllowed(current);

    final normalizedReason = reason.trim();

    if (normalizedReason.isEmpty) {
      throw Exception('신고 사유를 선택하세요.');
    }

    isReporting.value = true;
    error.value = null;

    try {
      await repo.reportPost(
        postId: targetPostId,
        reason: normalizedReason,
      );

      if (_postId != targetPostId) {
        return;
      }

      final latest = post.value;
      if (latest == null || latest.id != targetPostId) return;

      final userId = currentUserId;
      if (userId.isEmpty) return;

      if (latest.reportedUserIds.contains(userId)) {
        return;
      }

      final reporters = Set<String>.from(latest.reportedUserIds)..add(userId);

      final nextReportCount = latest.reportCount + 1;

      post.value = latest.copyWith(
        reportedUserIds: reporters,
        reportCount: nextReportCount,
        isReportThresholdReached:
            latest.isReportThresholdReached || nextReportCount >= 3,
      );
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isReporting.value = false;
    }
  }

  Future<void> reportThisPost(String reason) async {
    await reportPost(reason);
  }

  void applyUpdatedPost(Post updated) {
    if (!isReady) return;
    if (updated.id != postId) return;

    if (_isBlockedPost(updated)) {
      _applyBlockedPostState();
      return;
    }

    _isBlockedAuthorPost = false;
    post.value = updated;
  }

  Future<void> updatePostInMemory(Post updated) async {
    applyUpdatedPost(updated);
  }

  void applyUpdatedCommentCount(int count) {
    final current = post.value;
    if (current == null) return;

    final safeCount = count < 0 ? 0 : count;

    post.value = current.copyWith(
      commentCount: safeCount,
    );
  }

  void increaseCommentCount([int amount = 1]) {
    final current = post.value;
    if (current == null) return;

    final next = current.commentCount + amount;

    post.value = current.copyWith(
      commentCount: next < 0 ? 0 : next,
    );
  }

  void decreaseCommentCount([int amount = 1]) {
    increaseCommentCount(-amount);
  }

  Future<void> _loadBlockedAuthorIds() async {
    try {
      final blockedUsers = await storeProfileRepo.getBlockedUsers();

      _blockedAuthorIds
        ..clear()
        ..addAll(
          blockedUsers
              .map((e) => e.userId.trim())
              .where((e) => e.isNotEmpty),
        );
    } catch (_) {
      _blockedAuthorIds.clear();
    }
  }

  bool _isBlockedPost(Post targetPost) {
    final authorId = targetPost.authorId.trim();
    if (authorId.isEmpty) return false;
    if (authorId == currentUserId) return false;

    return _blockedAuthorIds.contains(authorId);
  }

  void _applyBlockedPostState() {
    _isBlockedAuthorPost = true;
    post.value = null;
    error.value = '차단한 사용자의 글입니다.';
    isLoading.value = false;
  }

  bool _isCurrentLoadTarget({
    required int generation,
    required String targetPostId,
  }) {
    return _loadGeneration == generation && _postId == targetPostId;
  }

  Future<void> _maybeNotifyLike({
    required Post? before,
    required Post after,
  }) async {
    final userId = currentUserId;

    if (before == null) return;
    if (userId.isEmpty) return;
    if (after.authorId == userId) return;

    final wasLiked = before.likedUserIds.contains(userId);
    final isLiked = after.likedUserIds.contains(userId);

    if (wasLiked || !isLiked) return;

    try {
      final StoreProfile myProfile = await storeProfileRepo.fetchProfile();
      final nickname = myProfile.nickname.trim().isEmpty
          ? '익명'
          : myProfile.nickname.trim();

      await storeProfileRepo.addNotificationToUser(
        after.authorId,
        AppNotificationItem(
          id: 'like_${after.id}_${userId}_${DateTime.now().microsecondsSinceEpoch}',
          type: 'post_like',
          message: '$nickname님이 회원님의 글을 좋아합니다.',
          targetUserId: after.authorId,
          targetPostId: after.id,
          targetCommentId: null,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}
  }
}
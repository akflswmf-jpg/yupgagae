import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
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

  String get currentUserId => auth.currentUserId;

  String get postId => _postId ?? '';

  bool get isReady {
    final id = _postId;
    return id != null && id.trim().isNotEmpty;
  }

  bool get isOwner {
    final p = post.value;
    if (p == null) return false;
    return p.authorId == currentUserId;
  }

  bool get isAuthor => isOwner;

  bool get likedByMe {
    final p = post.value;
    if (p == null) return false;
    return p.likedUserIds.contains(currentUserId);
  }

  bool get canToggleSold {
    final p = post.value;
    if (p == null) return false;
    return p.boardType == BoardType.used && p.authorId == currentUserId;
  }

  Future<void> initialize(String postId) async {
    final normalized = postId.trim();

    if (normalized.isEmpty) {
      error.value = 'postId required';
      post.value = null;
      return;
    }

    if (_didInitialize && _postId == normalized && post.value != null) {
      return;
    }

    _postId = normalized;
    _didInitialize = true;
    _didIncrementView = false;

    await load();
  }

  Future<void> load() async {
    final targetPostId = postId.trim();

    if (targetPostId.isEmpty) {
      error.value = 'postId required';
      post.value = null;
      return;
    }

    final generation = ++_loadGeneration;

    isLoading.value = true;
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
      post.value = null;
    } finally {
      if (_loadGeneration == generation) {
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
    } catch (_) {
      // 서버 구현체에서는 ensureReady가 없을 수 있다.
    }
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

      final current = post.value;
      if (current == null || current.id != targetPostId) return;

      final nextViewCount =
          current.viewCount <= baseViewCount ? baseViewCount + 1 : current.viewCount;

      post.value = current.copyWith(
        viewCount: nextViewCount,
      );
    } catch (_) {}
  }

  Future<Post> toggleLike() async {
    final current = post.value;
    final targetPostId = postId.trim();

    if (targetPostId.isEmpty || current == null) {
      throw Exception('게시글을 찾을 수 없습니다.');
    }

    if (isTogglingLike.value) {
      return current;
    }

    isTogglingLike.value = true;
    error.value = null;

    try {
      final before = post.value;

      final updated = await repo.toggleLike(
        postId: targetPostId,
      );

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

    if (isTogglingSold.value) {
      return current;
    }

    isTogglingSold.value = true;
    error.value = null;

    try {
      final updated = await repo.toggleSold(
        postId: targetPostId,
      );

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
    final targetPostId = postId.trim();

    if (targetPostId.isEmpty) return false;
    if (isDeleting.value) return false;

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
    final targetPostId = postId.trim();

    if (targetPostId.isEmpty) return;
    if (isReporting.value) return;

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

      final current = post.value;
      if (current == null || current.id != targetPostId) return;

      if (current.reportedUserIds.contains(currentUserId)) {
        return;
      }

      final reporters = Set<String>.from(current.reportedUserIds)
        ..add(currentUserId);

      final nextReportCount = current.reportCount + 1;

      post.value = current.copyWith(
        reportedUserIds: reporters,
        reportCount: nextReportCount,
        isReportThresholdReached:
            current.isReportThresholdReached || nextReportCount >= 3,
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
    if (before == null) return;
    if (after.authorId == currentUserId) return;

    final wasLiked = before.likedUserIds.contains(currentUserId);
    final isLiked = after.likedUserIds.contains(currentUserId);

    if (wasLiked || !isLiked) return;

    try {
      final StoreProfile myProfile = await storeProfileRepo.fetchProfile();
      final nickname = myProfile.nickname.trim().isEmpty
          ? '익명'
          : myProfile.nickname.trim();

      await storeProfileRepo.addNotificationToUser(
        after.authorId,
        AppNotificationItem(
          id: 'like_${after.id}_${currentUserId}_${DateTime.now().microsecondsSinceEpoch}',
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
import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/app_notification_item.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class PostDetailController extends GetxController {
  final PostRepository repo;
  final AnonSessionService session;
  final StoreProfileRepository storeProfileRepo;

  PostDetailController({
    required this.repo,
    required this.session,
    required this.storeProfileRepo,
  });

  final post = Rxn<Post>();
  final isLoading = false.obs;
  final error = RxnString();
  final isDeleting = false.obs;
  final isReporting = false.obs;
  final isTogglingSold = false.obs;

  String? _postId;
  bool _didInitialize = false;

  String get currentUserId => session.anonId;
  String get postId => _postId ?? '';
  bool get isReady => _postId != null && _postId!.trim().isNotEmpty;

  bool get isOwner {
    final p = post.value;
    if (p == null) return false;
    return p.authorId == currentUserId;
  }

  Future<void> initialize(String postId) async {
    final normalized = postId.trim();
    if (normalized.isEmpty) {
      error.value = 'postId required';
      post.value = null;
      return;
    }

    if (_didInitialize && _postId == normalized) {
      return;
    }

    _postId = normalized;
    _didInitialize = true;
    await load();
  }

  Future<void> load() async {
    if (!isReady) {
      error.value = 'postId required';
      post.value = null;
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      final dynamic repoDyn = repo;

      try {
        await repoDyn.ensureReady();
      } catch (_) {}

      final loaded = await repo.getPostById(postId);
      post.value = loaded;

      unawaited(_incrementViewSilently());
    } catch (e) {
      error.value = e.toString();
      post.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshPost() async {
    if (!isReady) {
      error.value = 'postId required';
      post.value = null;
      return;
    }

    error.value = null;

    try {
      final loaded = await repo.getPostById(postId);
      post.value = loaded;
    } catch (e) {
      error.value = e.toString();
      post.value = null;
    }
  }

  Future<void> _incrementViewSilently() async {
    if (!isReady) return;

    try {
      await repo.incrementView(postId);

      final current = post.value;
      if (current == null) return;

      post.value = current.copyWith(
        viewCount: current.viewCount + 1,
      );
    } catch (_) {}
  }

  Future<void> _notifyPostAuthorForLike({
    required Post before,
    required Post after,
  }) async {
    final targetUserId = before.authorId.trim();
    if (targetUserId.isEmpty) return;
    if (targetUserId == currentUserId) return;

    final didLikeNow =
        !before.likedUserIds.contains(currentUserId) &&
        after.likedUserIds.contains(currentUserId);

    if (!didLikeNow) return;

    String actorLabel = '익명';
    try {
      final StoreProfile profile = await storeProfileRepo.fetchProfile();
      final nickname = profile.nickname.trim();
      if (nickname.isNotEmpty) {
        actorLabel = nickname;
      }
    } catch (_) {}

    await storeProfileRepo.addNotificationToUser(
      targetUserId,
      AppNotificationItem(
        id: 'like_post_${after.id}_$currentUserId',
        type: 'like_post',
        message: '$actorLabel님이 내 게시글을 좋아합니다.',
        targetUserId: targetUserId,
        targetPostId: after.id,
        targetCommentId: null,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> toggleLike() async {
    final current = post.value;
    if (current == null) return;

    try {
      final updated = await repo.toggleLike(
        postId: current.id,
        userId: currentUserId,
      );
      post.value = updated;

      try {
        await _notifyPostAuthorForLike(
          before: current,
          after: updated,
        );
      } catch (_) {}
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<Post> toggleSold() async {
    final current = post.value;
    if (current == null) {
      throw Exception('게시글이 없습니다.');
    }

    if (current.boardType != BoardType.used) {
      throw Exception('거래 게시글만 처리할 수 있습니다.');
    }

    if (!isOwner) {
      throw Exception('처리 권한이 없습니다.');
    }

    if (isTogglingSold.value) {
      throw Exception('처리 중입니다.');
    }

    isTogglingSold.value = true;
    error.value = null;

    try {
      final updated = await repo.toggleSold(
        postId: current.id,
        userId: currentUserId,
      );
      post.value = updated;
      return updated;
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isTogglingSold.value = false;
    }
  }

  void increaseCommentCount() {
    final current = post.value;
    if (current == null) return;

    post.value = current.copyWith(
      commentCount: current.commentCount + 1,
    );
  }

  void decreaseCommentCount() {
    final current = post.value;
    if (current == null) return;

    final next = current.commentCount > 0 ? current.commentCount - 1 : 0;
    post.value = current.copyWith(
      commentCount: next,
    );
  }

  void applyUpdatedCommentCount(int count) {
    final current = post.value;
    if (current == null) return;

    post.value = current.copyWith(
      commentCount: count < 0 ? 0 : count,
    );
  }

  Future<void> reportThisPost(String reason) async {
    final current = post.value;
    if (current == null) {
      throw Exception('게시글이 없습니다.');
    }

    if (isOwner) {
      throw Exception('본인 게시글은 신고할 수 없습니다.');
    }

    if (isReporting.value) return;

    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('신고 사유를 선택하세요.');
    }

    isReporting.value = true;
    error.value = null;

    try {
      await repo.reportPost(
        postId: current.id,
        reporterId: currentUserId,
        reason: normalizedReason,
      );

      final reporters = Set<String>.from(current.reportedUserIds)
        ..add(currentUserId);
      final nextCount = current.reportCount + 1;

      post.value = current.copyWith(
        reportCount: nextCount,
        reportedUserIds: reporters,
        isReportThresholdReached:
            current.isReportThresholdReached || nextCount >= 3,
      );
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isReporting.value = false;
    }
  }

  Future<bool> deleteThisPost() async {
    final current = post.value;
    if (current == null) return false;

    if (isDeleting.value) return false;
    isDeleting.value = true;
    error.value = null;

    try {
      final ok = await repo.canDeletePost(
        postId: current.id,
        userId: currentUserId,
      );

      if (!ok) {
        error.value = '삭제 권한이 없습니다.';
        return false;
      }

      await repo.deletePost(
        postId: current.id,
        userId: currentUserId,
      );

      return true;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      isDeleting.value = false;
    }
  }
}
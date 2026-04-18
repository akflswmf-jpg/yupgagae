import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/domain/region_catalog.dart';
import 'package:yupgagae/features/my_store/domain/app_notification_item.dart';
import 'package:yupgagae/features/my_store/domain/blocked_user_item.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class CommentViewItem {
  final Comment comment;
  final int depth;

  const CommentViewItem({
    required this.comment,
    required this.depth,
  });
}

class CommentController extends GetxController {
  final PostRepository repo;
  final StoreProfileRepository storeProfileRepo;

  CommentController({
    required this.repo,
    required this.storeProfileRepo,
  });

  final comments = <Comment>[].obs;
  final flattenedComments = <CommentViewItem>[].obs;
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final error = RxnString();

  String? _postId;
  bool _didInitialize = false;

  final _blockedCache = <String>{};
  _AuthorSnapshot? _cachedAuthor;

  AnonSessionService? get _session => Get.isRegistered<AnonSessionService>()
      ? Get.find<AnonSessionService>()
      : null;

  String get currentUserId => _session?.anonId ?? 'anon_local';
  String get postId => _postId ?? '';
  bool get isReady => _postId != null && _postId!.trim().isNotEmpty;

  Future<void> initialize(String postId) async {
    final normalized = postId.trim();
    if (normalized.isEmpty) {
      error.value = 'postId required';
      return;
    }

    if (_didInitialize && _postId == normalized) {
      return;
    }

    _postId = normalized;
    _didInitialize = true;

    await _loadBlockedCache();
    await load();
  }

  Future<void> _loadBlockedCache() async {
    try {
      final List<BlockedUserItem> blocked =
          await storeProfileRepo.getBlockedUsers();

      _blockedCache
        ..clear()
        ..addAll(
          blocked.map((e) => e.userId.trim()).where((e) => e.isNotEmpty),
        );
    } catch (_) {
      _blockedCache.clear();
    }
  }

  Future<_AuthorSnapshot> _getAuthorSnapshot() async {
    final cached = _cachedAuthor;
    if (cached != null) return cached;

    try {
      final StoreProfile profile = await storeProfileRepo.fetchProfile();

      final nickname = profile.nickname.trim().isEmpty
          ? '익명'
          : profile.nickname.trim();

      String? industryId;
      final profileIndustry = profile.industry.trim();
      if (profileIndustry.isNotEmpty) {
        for (final item in IndustryCatalog.ordered()) {
          if (item.name == profileIndustry) {
            industryId = item.id;
            break;
          }
        }
      }

      final locationLabel = RegionCatalog.normalize(profile.region);

      final snapshot = _AuthorSnapshot(
        authorLabel: nickname,
        industryId: industryId,
        locationLabel: locationLabel,
        isOwnerVerified: profile.isOwnerVerified,
      );

      _cachedAuthor = snapshot;
      return snapshot;
    } catch (_) {
      return const _AuthorSnapshot(
        authorLabel: '익명',
        industryId: null,
        locationLabel: null,
        isOwnerVerified: false,
      );
    }
  }

  void clearAuthorCache() {
    _cachedAuthor = null;
  }

  List<CommentViewItem> _flattenForView(List<Comment> list) {
    final visible = list
        .where((c) => !_blockedCache.contains(c.authorId.trim()))
        .toList(growable: false);

    final roots = visible
        .where((c) => c.parentId == null || c.parentId!.trim().isEmpty)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final repliesByRoot = <String, List<Comment>>{};
    for (final comment in visible) {
      final parentId = comment.parentId?.trim();
      if (parentId == null || parentId.isEmpty) continue;

      repliesByRoot.putIfAbsent(parentId, () => <Comment>[]).add(comment);
    }

    for (final entry in repliesByRoot.entries) {
      entry.value.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final out = <CommentViewItem>[];
    for (final root in roots) {
      out.add(CommentViewItem(comment: root, depth: 0));

      final replies = repliesByRoot[root.id] ?? const <Comment>[];
      for (final reply in replies) {
        out.add(CommentViewItem(comment: reply, depth: 1));
      }
    }

    return out;
  }

  void _applyComments(List<Comment> next) {
    next.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    comments.assignAll(next);
    flattenedComments.assignAll(_flattenForView(next));
  }

  void _replaceComment(Comment updated) {
    final next = List<Comment>.from(comments);
    final idx = next.indexWhere((c) => c.id == updated.id);
    if (idx == -1) return;

    next[idx] = updated;
    _applyComments(next);
  }

  Future<void> _notifyPostAuthorForComment({
    required Post post,
    required Comment createdComment,
  }) async {
    final targetUserId = post.authorId.trim();
    if (targetUserId.isEmpty) return;
    if (targetUserId == currentUserId) return;

    String actorLabel = '익명';
    try {
      final profile = await storeProfileRepo.fetchProfile();
      final nickname = profile.nickname.trim();
      if (nickname.isNotEmpty) {
        actorLabel = nickname;
      }
    } catch (_) {}

    await storeProfileRepo.addNotificationToUser(
      targetUserId,
      AppNotificationItem(
        id: 'comment_${createdComment.id}_$currentUserId',
        type: 'comment',
        message: '$actorLabel님이 내 게시글에 댓글을 남겼습니다.',
        targetUserId: targetUserId,
        targetPostId: post.id,
        targetCommentId: createdComment.id,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _notifyCommentAuthorForReply({
    required Comment targetComment,
    required Comment createdReply,
  }) async {
    final targetUserId = targetComment.authorId.trim();
    if (targetUserId.isEmpty) return;
    if (targetUserId == currentUserId) return;

    String actorLabel = '익명';
    try {
      final profile = await storeProfileRepo.fetchProfile();
      final nickname = profile.nickname.trim();
      if (nickname.isNotEmpty) {
        actorLabel = nickname;
      }
    } catch (_) {}

    await storeProfileRepo.addNotificationToUser(
      targetUserId,
      AppNotificationItem(
        id: 'reply_${createdReply.id}_$currentUserId',
        type: 'reply',
        message: '$actorLabel님이 내 댓글에 답글을 남겼습니다.',
        targetUserId: targetUserId,
        targetPostId: createdReply.postId,
        targetCommentId: createdReply.id,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _notifyCommentAuthorForLike({
    required Comment before,
    required Comment after,
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
      final profile = await storeProfileRepo.fetchProfile();
      final nickname = profile.nickname.trim();
      if (nickname.isNotEmpty) {
        actorLabel = nickname;
      }
    } catch (_) {}

    await storeProfileRepo.addNotificationToUser(
      targetUserId,
      AppNotificationItem(
        id: 'like_comment_${after.id}_$currentUserId',
        type: 'like_comment',
        message: '$actorLabel님이 내 댓글을 좋아합니다.',
        targetUserId: targetUserId,
        targetPostId: after.postId,
        targetCommentId: after.id,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> load() async {
    if (!isReady) {
      error.value = 'postId required';
      comments.clear();
      flattenedComments.clear();
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      final loaded = await repo.fetchComments(postId);

      final filtered = loaded
          .where((c) => !_blockedCache.contains(c.authorId.trim()))
          .toList(growable: false);

      _applyComments(filtered);
    } catch (e) {
      error.value = e.toString();
      comments.clear();
      flattenedComments.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Comment? commentById(String commentId) {
    try {
      return comments.firstWhere((c) => c.id == commentId);
    } catch (_) {
      return null;
    }
  }

  List<Comment> repliesOf(String rootCommentId) {
    final normalizedRootId = rootCommentId.trim();
    final out = comments
        .where((c) => (c.parentId?.trim() ?? '') == normalizedRootId)
        .where((c) => !_blockedCache.contains(c.authorId.trim()))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  String resolveReplyRootId(String commentId) {
    final start = commentById(commentId);
    if (start == null) return commentId;

    final parentId = start.parentId?.trim();
    if (parentId == null || parentId.isEmpty) {
      return start.id;
    }

    return parentId;
  }

  String replyTargetLabelOf(String commentId) {
    final target = commentById(commentId);
    final name = target?.authorLabel.trim() ?? '';
    return name.isEmpty ? '익명' : name;
  }

  Future<void> add(String text) async {
    if (!isReady) {
      throw Exception('postId required');
    }
    if (isSubmitting.value) return;

    final normalized = text.trim();
    if (normalized.isEmpty) {
      throw Exception('댓글 내용을 입력하세요.');
    }

    isSubmitting.value = true;
    error.value = null;

    try {
      final author = await _getAuthorSnapshot();
      final Post targetPost = await repo.getPostById(postId);

      final created = await repo.addComment(
        postId: postId,
        authorId: currentUserId,
        authorLabel: author.authorLabel,
        isOwnerVerified: author.isOwnerVerified,
        industryId: author.industryId,
        locationLabel: author.locationLabel,
        text: normalized,
      );

      final next = List<Comment>.from(comments)..add(created);
      _applyComments(next);

      await _notifyPostAuthorForComment(
        post: targetPost,
        createdComment: created,
      );
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> reply({
    required String parentCommentId,
    required String text,
  }) async {
    if (!isReady) {
      throw Exception('postId required');
    }
    if (isSubmitting.value) return;

    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw Exception('답글 내용을 입력하세요.');
    }

    final normalizedParentId = parentCommentId.trim();
    if (normalizedParentId.isEmpty) {
      throw Exception('parentCommentId required');
    }

    isSubmitting.value = true;
    error.value = null;

    try {
      final author = await _getAuthorSnapshot();

      final tappedTarget = commentById(normalizedParentId);
      final rootParentId = resolveReplyRootId(normalizedParentId);

      final created = await repo.addReply(
        postId: postId,
        parentCommentId: rootParentId,
        authorId: currentUserId,
        authorLabel: author.authorLabel,
        isOwnerVerified: author.isOwnerVerified,
        industryId: author.industryId,
        locationLabel: author.locationLabel,
        text: normalizedText,
      );

      final normalizedCreated = created.copyWith(parentId: rootParentId);

      final next = List<Comment>.from(comments)..add(normalizedCreated);
      _applyComments(next);

      if (tappedTarget != null) {
        await _notifyCommentAuthorForReply(
          targetComment: tappedTarget,
          createdReply: normalizedCreated,
        );
      }
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> toggleLike(String commentId) async {
    if (!isReady) return;

    final before = commentById(commentId);
    if (before == null) return;

    final updated = await repo.toggleCommentLike(
      postId: postId,
      commentId: commentId,
      userId: currentUserId,
    );

    _replaceComment(updated);

    try {
      await _notifyCommentAuthorForLike(
        before: before,
        after: updated,
      );
    } catch (_) {}
  }

  Future<void> delete(String commentId) async {
    if (!isReady) return;

    await repo.deleteComment(
      postId: postId,
      commentId: commentId,
      userId: currentUserId,
    );

    final current = commentById(commentId);
    if (current == null || current.isDeleted) return;

    _replaceComment(current.copyWith(isDeleted: true));
  }

  Future<void> report({
    required String commentId,
    required String reason,
  }) async {
    if (!isReady) return;

    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('신고 사유를 선택하세요.');
    }

    await repo.reportComment(
      postId: postId,
      commentId: commentId,
      reporterId: currentUserId,
      reason: normalizedReason,
    );

    final current = commentById(commentId);
    if (current == null) return;
    if (current.isDeleted) return;
    if (current.reportedUserIds.contains(currentUserId)) return;

    final reporters = Set<String>.from(current.reportedUserIds)
      ..add(currentUserId);
    final newCount = current.reportCount + 1;

    _replaceComment(
      current.copyWith(
        reportedUserIds: reporters,
        reportCount: newCount,
        isReportThresholdReached:
            current.isReportThresholdReached || newCount >= 3,
      ),
    );
  }

  Future<void> updateComment({
    required String commentId,
    required String text,
  }) async {
    if (!isReady) {
      throw Exception('postId required');
    }

    final t = text.trim();
    if (t.isEmpty) {
      throw Exception('내용이 비어 있습니다.');
    }

    final dynamic repoDyn = repo;

    final updated = await repoDyn.updateComment(
      postId: postId,
      commentId: commentId,
      userId: currentUserId,
      text: t,
    );

    _replaceComment(updated);
  }

  int get activeCommentCount {
    return comments.where((c) => !c.isDeleted).length;
  }
}

class _AuthorSnapshot {
  final String authorLabel;
  final String? industryId;
  final String? locationLabel;
  final bool isOwnerVerified;

  const _AuthorSnapshot({
    required this.authorLabel,
    required this.industryId,
    required this.locationLabel,
    required this.isOwnerVerified,
  });
}
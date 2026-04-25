import 'dart:async';

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
  static const int maxCommentLength = 300;

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
  final _commentById = <String, Comment>{};
  final _repliesByRoot = <String, List<Comment>>{};
  final _rootIds = <String>{};

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
      unawaited(_prewarmAuthorSnapshot());
      return;
    }

    _postId = normalized;
    _didInitialize = true;

    await _loadBlockedCache();
    await load();

    unawaited(_prewarmAuthorSnapshot());
  }

  Future<void> _prewarmAuthorSnapshot() async {
    try {
      await _getAuthorSnapshot();
    } catch (_) {}
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
      const fallback = _AuthorSnapshot(
        authorLabel: '익명',
        industryId: null,
        locationLabel: null,
        isOwnerVerified: false,
      );

      _cachedAuthor = fallback;
      return fallback;
    }
  }

  _AuthorSnapshot _authorSnapshotForFastSubmit() {
    final cached = _cachedAuthor;
    if (cached != null) return cached;

    unawaited(_prewarmAuthorSnapshot());

    return const _AuthorSnapshot(
      authorLabel: '익명',
      industryId: null,
      locationLabel: null,
      isOwnerVerified: false,
    );
  }

  void clearAuthorCache() {
    _cachedAuthor = null;
    unawaited(_prewarmAuthorSnapshot());
  }

  String _normalizeInputText(String text) {
    return text.trim();
  }

  void _ensureValidCommentText({
    required String text,
    required String emptyMessage,
  }) {
    final normalized = _normalizeInputText(text);

    if (normalized.isEmpty) {
      throw Exception(emptyMessage);
    }

    if (normalized.length > maxCommentLength) {
      throw Exception('댓글은 $maxCommentLength자 이내로 입력해주세요.');
    }
  }

  bool _isVisibleComment(Comment comment) {
    return !_blockedCache.contains(comment.authorId.trim());
  }

  bool _isLocalCommentId(String id) {
    return id.startsWith('local_comment_') || id.startsWith('local_reply_');
  }

  String _makeLocalId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$currentUserId';
  }

  void _rebuildIndexes(List<Comment> visibleSorted) {
    _commentById
      ..clear()
      ..addEntries(
        visibleSorted.map((comment) => MapEntry(comment.id, comment)),
      );

    _rootIds.clear();
    _repliesByRoot.clear();

    for (final comment in visibleSorted) {
      final parentId = comment.parentId?.trim();
      if (parentId == null || parentId.isEmpty) {
        _rootIds.add(comment.id);
        continue;
      }

      _repliesByRoot.putIfAbsent(parentId, () => <Comment>[]).add(comment);
    }

    for (final entry in _repliesByRoot.entries) {
      entry.value.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
  }

  List<CommentViewItem> _flattenForViewFromIndexes(List<Comment> visibleSorted) {
    final out = <CommentViewItem>[];

    for (final comment in visibleSorted) {
      final parentId = comment.parentId?.trim();
      if (parentId != null && parentId.isNotEmpty) {
        continue;
      }

      out.add(CommentViewItem(comment: comment, depth: 0));

      final replies = _repliesByRoot[comment.id] ?? const <Comment>[];
      for (final reply in replies) {
        out.add(CommentViewItem(comment: reply, depth: 1));
      }
    }

    return out;
  }

  void _clearCommentState() {
    comments.clear();
    flattenedComments.clear();
    _commentById.clear();
    _repliesByRoot.clear();
    _rootIds.clear();
  }

  void _applyComments(List<Comment> next) {
    final visibleSorted = next
        .where(_isVisibleComment)
        .toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _rebuildIndexes(visibleSorted);

    comments.assignAll(visibleSorted);
    flattenedComments.assignAll(_flattenForViewFromIndexes(visibleSorted));
  }

  int _flattenInsertIndexForReply(String rootCommentId) {
    final rootIndex = flattenedComments.indexWhere(
      (item) => item.comment.id == rootCommentId,
    );

    if (rootIndex < 0) {
      return flattenedComments.length;
    }

    var insertIndex = rootIndex + 1;
    while (insertIndex < flattenedComments.length) {
      if (flattenedComments[insertIndex].depth == 0) {
        break;
      }
      insertIndex++;
    }

    return insertIndex;
  }

  void _insertCommentFast(Comment comment) {
    if (!_isVisibleComment(comment)) return;

    comments.add(comment);
    _commentById[comment.id] = comment;

    final parentId = comment.parentId?.trim();
    if (parentId == null || parentId.isEmpty) {
      _rootIds.add(comment.id);
      flattenedComments.add(CommentViewItem(comment: comment, depth: 0));
      return;
    }

    final replies = _repliesByRoot.putIfAbsent(parentId, () => <Comment>[]);
    replies.add(comment);
    replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final insertIndex = _flattenInsertIndexForReply(parentId);
    flattenedComments.insert(
      insertIndex,
      CommentViewItem(comment: comment, depth: 1),
    );
  }

  void _removeCommentById(String commentId) {
    final id = commentId.trim();
    if (id.isEmpty) return;

    final existing = _commentById[id];
    if (existing == null) return;

    final next = comments.where((comment) => comment.id != id).toList();
    _applyComments(next);
  }

  void _replaceLocalComment({
    required String localId,
    required Comment realComment,
  }) {
    final index = comments.indexWhere((comment) => comment.id == localId);
    if (index < 0) return;

    final next = List<Comment>.from(comments);
    next[index] = realComment;
    _applyComments(next);
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

    String actorLabel = _cachedAuthor?.authorLabel.trim() ?? '';
    if (actorLabel.isEmpty) {
      actorLabel = '익명';
    }

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

    String actorLabel = _cachedAuthor?.authorLabel.trim() ?? '';
    if (actorLabel.isEmpty) {
      actorLabel = '익명';
    }

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

    String actorLabel = _cachedAuthor?.authorLabel.trim() ?? '';
    if (actorLabel.isEmpty) {
      actorLabel = '익명';
    }

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
      _clearCommentState();
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      final loaded = await repo.fetchComments(postId);
      _applyComments(loaded);
    } catch (e) {
      error.value = e.toString();
      _clearCommentState();
    } finally {
      isLoading.value = false;
    }
  }

  Comment? commentById(String commentId) {
    final id = commentId.trim();
    if (id.isEmpty) return null;
    return _commentById[id];
  }

  List<Comment> repliesOf(String rootCommentId) {
    final normalizedRootId = rootCommentId.trim();
    if (normalizedRootId.isEmpty) return const <Comment>[];

    final replies = _repliesByRoot[normalizedRootId];
    if (replies == null || replies.isEmpty) {
      return const <Comment>[];
    }

    return List<Comment>.unmodifiable(replies);
  }

  int replyCountOf(String rootCommentId) {
    final normalizedRootId = rootCommentId.trim();
    if (normalizedRootId.isEmpty) return 0;
    return _repliesByRoot[normalizedRootId]?.length ?? 0;
  }

  int replyIndexOf({
    required String rootCommentId,
    required String replyId,
  }) {
    final replies = repliesOf(rootCommentId);
    return replies.indexWhere((comment) => comment.id == replyId);
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

  Future<String?> add(String text) async {
    if (!isReady) {
      throw Exception('postId required');
    }
    if (isSubmitting.value) return null;

    final normalized = _normalizeInputText(text);

    _ensureValidCommentText(
      text: normalized,
      emptyMessage: '댓글 내용을 입력하세요.',
    );

    isSubmitting.value = true;
    error.value = null;

    try {
      final author = _authorSnapshotForFastSubmit();
      final localId = _makeLocalId('local_comment');

      final optimisticComment = Comment(
        id: localId,
        postId: postId,
        authorId: currentUserId,
        authorLabel: author.authorLabel,
        isOwnerVerified: author.isOwnerVerified,
        industryId: author.industryId,
        locationLabel: author.locationLabel,
        text: normalized,
        parentId: null,
        createdAt: DateTime.now(),
      );

      _insertCommentFast(optimisticComment);

      unawaited(
        _commitOptimisticComment(
          localId: localId,
          author: author,
          text: normalized,
        ),
      );

      return localId;
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _commitOptimisticComment({
    required String localId,
    required _AuthorSnapshot author,
    required String text,
  }) async {
    try {
      final created = await repo.addComment(
        postId: postId,
        authorId: currentUserId,
        authorLabel: author.authorLabel,
        isOwnerVerified: author.isOwnerVerified,
        industryId: author.industryId,
        locationLabel: author.locationLabel,
        text: text,
      );

      _replaceLocalComment(
        localId: localId,
        realComment: created,
      );

      unawaited(_notifyPostAuthorAfterCommentCreated(created));
    } catch (e) {
      error.value = e.toString();
      _removeCommentById(localId);
    }
  }

  Future<void> _notifyPostAuthorAfterCommentCreated(Comment created) async {
    try {
      final Post targetPost = await repo.getPostById(postId);
      await _notifyPostAuthorForComment(
        post: targetPost,
        createdComment: created,
      );
    } catch (_) {}
  }

  Future<String?> reply({
    required String parentCommentId,
    required String text,
  }) async {
    if (!isReady) {
      throw Exception('postId required');
    }
    if (isSubmitting.value) return null;

    final normalizedText = _normalizeInputText(text);

    _ensureValidCommentText(
      text: normalizedText,
      emptyMessage: '답글 내용을 입력하세요.',
    );

    final normalizedParentId = parentCommentId.trim();
    if (normalizedParentId.isEmpty) {
      throw Exception('parentCommentId required');
    }

    isSubmitting.value = true;
    error.value = null;

    try {
      final author = _authorSnapshotForFastSubmit();

      final tappedTarget = commentById(normalizedParentId);
      final rootParentId = resolveReplyRootId(normalizedParentId);
      final localId = _makeLocalId('local_reply');

      final optimisticReply = Comment(
        id: localId,
        postId: postId,
        authorId: currentUserId,
        authorLabel: author.authorLabel,
        isOwnerVerified: author.isOwnerVerified,
        industryId: author.industryId,
        locationLabel: author.locationLabel,
        text: normalizedText,
        parentId: rootParentId,
        createdAt: DateTime.now(),
      );

      _insertCommentFast(optimisticReply);

      unawaited(
        _commitOptimisticReply(
          localId: localId,
          rootParentId: rootParentId,
          tappedTarget: tappedTarget,
          author: author,
          text: normalizedText,
        ),
      );

      return localId;
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _commitOptimisticReply({
    required String localId,
    required String rootParentId,
    required Comment? tappedTarget,
    required _AuthorSnapshot author,
    required String text,
  }) async {
    try {
      final created = await repo.addReply(
        postId: postId,
        parentCommentId: rootParentId,
        authorId: currentUserId,
        authorLabel: author.authorLabel,
        isOwnerVerified: author.isOwnerVerified,
        industryId: author.industryId,
        locationLabel: author.locationLabel,
        text: text,
      );

      final normalizedCreated = created.copyWith(parentId: rootParentId);

      _replaceLocalComment(
        localId: localId,
        realComment: normalizedCreated,
      );

      if (tappedTarget != null) {
        unawaited(
          _notifyCommentAuthorForReply(
            targetComment: tappedTarget,
            createdReply: normalizedCreated,
          ),
        );
      }
    } catch (e) {
      error.value = e.toString();
      _removeCommentById(localId);
    }
  }

  Future<void> toggleLike(String commentId) async {
    if (!isReady) return;
    if (_isLocalCommentId(commentId)) return;

    final before = commentById(commentId);
    if (before == null) return;

    final updated = await repo.toggleCommentLike(
      postId: postId,
      commentId: commentId,
      userId: currentUserId,
    );

    _replaceComment(updated);

    unawaited(
      _notifyCommentAuthorForLike(
        before: before,
        after: updated,
      ),
    );
  }

  Future<void> delete(String commentId) async {
    if (!isReady) return;

    if (_isLocalCommentId(commentId)) {
      _removeCommentById(commentId);
      return;
    }

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
    if (_isLocalCommentId(commentId)) return;

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
    if (_isLocalCommentId(commentId)) {
      throw Exception('잠시 후 다시 시도해주세요.');
    }

    final t = _normalizeInputText(text);

    _ensureValidCommentText(
      text: t,
      emptyMessage: '내용이 비어 있습니다.',
    );

    final updated = await repo.updateComment(
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
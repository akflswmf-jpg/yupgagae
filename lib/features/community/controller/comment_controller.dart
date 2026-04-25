import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
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

  final activeEditingId = RxnString();

  // 중요:
  // 기존 View가 activeReplyTo.value를 String처럼 사용한다.
  // 따라서 Comment가 아니라 String commentId로 유지한다.
  final activeReplyTo = RxnString();

  String? _postId;
  bool _didInitialize = false;

  final _blockedCache = <String>{};
  final _commentById = <String, Comment>{};
  final _repliesByRoot = <String, List<Comment>>{};
  final _rootIds = <String>{};

  _AuthorSnapshot? _cachedAuthor;

  AnonSessionService? get _session {
    if (!Get.isRegistered<AnonSessionService>()) return null;
    return Get.find<AnonSessionService>();
  }

  String get currentUserId => _session?.anonId ?? 'anon_local';

  String get postId => _postId ?? '';

  bool get isReady {
    final id = _postId;
    return id != null && id.trim().isNotEmpty;
  }

  int get activeCommentCount {
    return comments.where((c) {
      return !c.isDeleted && !c.isReportThresholdReached;
    }).length;
  }

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

  Future<void> load() async {
    if (!isReady) {
      error.value = 'postId required';
      return;
    }

    if (isLoading.value) return;

    isLoading.value = true;
    error.value = null;

    try {
      final list = await repo.fetchComments(postId);
      _applyComments(list);
    } catch (e) {
      error.value = e.toString();
      _clearCommentState();
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void refresh() {
    unawaited(load());
  }

  Future<void> reload() async {
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

  Future<void> _prewarmAuthorSnapshot() async {
    try {
      await _getAuthorSnapshot();
    } catch (_) {}
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
          if (item.name == profileIndustry || item.id == profileIndustry) {
            industryId = item.id;
            break;
          }
        }
      }

      final snapshot = _AuthorSnapshot(
        authorId: currentUserId,
        authorLabel: nickname,
        industryId: industryId,
        locationLabel: RegionCatalog.normalize(profile.region),
        isOwnerVerified: profile.isOwnerVerified,
      );

      _cachedAuthor = snapshot;
      return snapshot;
    } catch (_) {
      final fallback = _AuthorSnapshot.fallback(currentUserId);
      _cachedAuthor = fallback;
      return fallback;
    }
  }

  _AuthorSnapshot _authorSnapshotForFastSubmit() {
    final cached = _cachedAuthor;
    if (cached != null) return cached;

    unawaited(_prewarmAuthorSnapshot());

    return _AuthorSnapshot.fallback(currentUserId);
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

  void _clearCommentState() {
    comments.clear();
    flattenedComments.clear();
    _commentById.clear();
    _repliesByRoot.clear();
    _rootIds.clear();
  }

  void _applyComments(List<Comment> next) {
    final visibleSorted = next.where(_isVisibleComment).toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _rebuildIndexes(visibleSorted);

    comments.assignAll(visibleSorted);
    flattenedComments.assignAll(_flattenForViewFromIndexes(visibleSorted));
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

    _repliesByRoot.putIfAbsent(parentId, () => <Comment>[]).add(comment);

    final insertIndex = _flattenInsertIndexForReply(parentId);
    flattenedComments.insert(
      insertIndex,
      CommentViewItem(comment: comment, depth: 1),
    );
  }

  void _replaceComment(Comment updated) {
    if (!_isVisibleComment(updated)) {
      _removeCommentById(updated.id);
      return;
    }

    final listIndex = comments.indexWhere((e) => e.id == updated.id);
    if (listIndex >= 0) {
      comments[listIndex] = updated;
    } else {
      comments.add(updated);
    }

    _commentById[updated.id] = updated;

    final parentId = updated.parentId?.trim();

    if (parentId == null || parentId.isEmpty) {
      _rootIds.add(updated.id);
    } else {
      final replies = _repliesByRoot.putIfAbsent(parentId, () => <Comment>[]);
      final replyIndex = replies.indexWhere((e) => e.id == updated.id);

      if (replyIndex >= 0) {
        replies[replyIndex] = updated;
      } else {
        replies.add(updated);
      }

      replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    _rebuildFlattenedOnly();
  }

  void _replaceLocalComment({
    required String localId,
    required Comment realComment,
  }) {
    final listIndex = comments.indexWhere((e) => e.id == localId);

    if (listIndex >= 0) {
      comments[listIndex] = realComment;
    } else {
      comments.add(realComment);
    }

    _commentById.remove(localId);
    _commentById[realComment.id] = realComment;

    final parentId = realComment.parentId?.trim();

    if (parentId == null || parentId.isEmpty) {
      _rootIds.remove(localId);
      _rootIds.add(realComment.id);
    } else {
      final replies = _repliesByRoot[parentId];

      if (replies != null) {
        final replyIndex = replies.indexWhere((e) => e.id == localId);
        if (replyIndex >= 0) {
          replies[replyIndex] = realComment;
        } else {
          replies.add(realComment);
        }

        replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } else {
        _repliesByRoot[parentId] = <Comment>[realComment];
      }
    }

    _rebuildFlattenedOnly();
  }

  void _removeCommentById(String commentId) {
    comments.removeWhere((e) => e.id == commentId);
    _commentById.remove(commentId);
    _rootIds.remove(commentId);

    for (final replies in _repliesByRoot.values) {
      replies.removeWhere((e) => e.id == commentId);
    }

    _rebuildFlattenedOnly();
  }

  void _rebuildFlattenedOnly() {
    final visibleSorted = comments.where(_isVisibleComment).toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _rebuildIndexes(visibleSorted);

    comments.assignAll(visibleSorted);
    flattenedComments.assignAll(_flattenForViewFromIndexes(visibleSorted));
  }

  Future<Comment> submit(String text) async {
    return add(text);
  }

  Future<Comment> add(String text) async {
    return addComment(text);
  }

  Future<Comment> addComment(String text) async {
    if (!isReady) {
      throw Exception('postId required');
    }

    _ensureValidCommentText(
      text: text,
      emptyMessage: '댓글을 입력하세요.',
    );

    final normalizedText = _normalizeInputText(text);

    if (isSubmitting.value) {
      throw Exception('댓글 등록 중입니다.');
    }

    isSubmitting.value = true;
    error.value = null;

    final author = _authorSnapshotForFastSubmit();
    final localId = _makeLocalId('local_comment');

    final localComment = Comment(
      id: localId,
      postId: postId,
      parentId: null,
      authorId: author.authorId,
      authorLabel: author.authorLabel,
      isOwnerVerified: author.isOwnerVerified,
      industryId: author.industryId,
      locationLabel: author.locationLabel,
      text: normalizedText,
      createdAt: DateTime.now(),
      likeCount: 0,
      likedUserIds: <String>{},
      reportCount: 0,
      reportedUserIds: <String>{},
      isReportThresholdReached: false,
      isDeleted: false,
    );

    _insertCommentFast(localComment);

    try {
      final created = await repo.addComment(
        postId: postId,
        text: normalizedText,
      );

      _replaceLocalComment(
        localId: localId,
        realComment: created,
      );

      unawaited(
        _notifyPostAuthorForComment(createdComment: created),
      );

      return created;
    } catch (e) {
      error.value = e.toString();
      _removeCommentById(localId);
      rethrow;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<Comment> reply({
    required String parentCommentId,
    required String text,
  }) async {
    return addReply(
      parentCommentId: parentCommentId,
      text: text,
    );
  }

  Future<Comment> addReply({
    required String parentCommentId,
    required String text,
  }) async {
    if (!isReady) {
      throw Exception('postId required');
    }

    final tappedTarget = commentById(parentCommentId.trim());
    final rootParentId = resolveReplyRootId(parentCommentId.trim());

    if (rootParentId.trim().isEmpty) {
      throw Exception('답글을 달 댓글을 찾을 수 없습니다.');
    }

    _ensureValidCommentText(
      text: text,
      emptyMessage: '답글을 입력하세요.',
    );

    final normalizedText = _normalizeInputText(text);

    if (isSubmitting.value) {
      throw Exception('답글 등록 중입니다.');
    }

    isSubmitting.value = true;
    error.value = null;

    final author = _authorSnapshotForFastSubmit();
    final localId = _makeLocalId('local_reply');

    final localReply = Comment(
      id: localId,
      postId: postId,
      parentId: rootParentId,
      authorId: author.authorId,
      authorLabel: author.authorLabel,
      isOwnerVerified: author.isOwnerVerified,
      industryId: author.industryId,
      locationLabel: author.locationLabel,
      text: normalizedText,
      createdAt: DateTime.now(),
      likeCount: 0,
      likedUserIds: <String>{},
      reportCount: 0,
      reportedUserIds: <String>{},
      isReportThresholdReached: false,
      isDeleted: false,
    );

    _insertCommentFast(localReply);

    try {
      final created = await repo.addReply(
        postId: postId,
        parentCommentId: rootParentId,
        text: normalizedText,
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

      return normalizedCreated;
    } catch (e) {
      error.value = e.toString();
      _removeCommentById(localId);
      rethrow;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<Comment> toggleLike(dynamic target) async {
    if (!isReady) {
      throw Exception('postId required');
    }

    final commentId = _commentIdFromTarget(target);
    if (commentId == null || commentId.isEmpty) {
      throw Exception('댓글을 찾을 수 없습니다.');
    }

    if (_isLocalCommentId(commentId)) {
      final current = commentById(commentId);
      if (current == null) {
        throw Exception('댓글을 찾을 수 없습니다.');
      }
      return current;
    }

    final before = commentById(commentId);

    if (before == null) {
      throw Exception('댓글을 찾을 수 없습니다.');
    }

    error.value = null;

    try {
      final updated = await repo.toggleCommentLike(
        postId: postId,
        commentId: commentId,
      );

      _replaceComment(updated);

      unawaited(
        _notifyCommentAuthorForLike(
          before: before,
          after: updated,
        ),
      );

      return updated;
    } catch (e) {
      error.value = e.toString();
      rethrow;
    }
  }

  Future<Comment> toggleLikeOnComment(Comment comment) async {
    return toggleLike(comment);
  }

  Future<void> delete(dynamic target) async {
    if (!isReady) return;

    final commentId = _commentIdFromTarget(target);
    if (commentId == null || commentId.isEmpty) return;

    if (_isLocalCommentId(commentId)) {
      _removeCommentById(commentId);
      return;
    }

    error.value = null;

    try {
      await repo.deleteComment(
        postId: postId,
        commentId: commentId,
      );

      final current = commentById(commentId);
      if (current == null || current.isDeleted) return;

      _replaceComment(
        current.copyWith(
          text: '삭제된 댓글입니다.',
          isDeleted: true,
        ),
      );
    } catch (e) {
      error.value = e.toString();
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId) async {
    await delete(commentId);
  }

  Future<void> report({
    String? commentId,
    Comment? comment,
    required String reason,
  }) async {
    if (!isReady) return;

    final targetId = commentId?.trim().isNotEmpty == true
        ? commentId!.trim()
        : comment?.id.trim();

    if (targetId == null || targetId.isEmpty) {
      throw Exception('댓글을 찾을 수 없습니다.');
    }

    if (_isLocalCommentId(targetId)) return;

    final normalizedReason = reason.trim();

    if (normalizedReason.isEmpty) {
      throw Exception('신고 사유를 선택하세요.');
    }

    error.value = null;

    try {
      await repo.reportComment(
        postId: postId,
        commentId: targetId,
        reason: normalizedReason,
      );

      final current = commentById(targetId);
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
    } catch (e) {
      error.value = e.toString();
      rethrow;
    }
  }

  Future<void> reportComment({
    required String commentId,
    required String reason,
  }) async {
    await report(
      commentId: commentId,
      reason: reason,
    );
  }

  Future<Comment> updateComment({
    required String commentId,
    required String text,
  }) async {
    if (!isReady) {
      throw Exception('postId required');
    }

    if (_isLocalCommentId(commentId)) {
      throw Exception('잠시 후 다시 시도해주세요.');
    }

    _ensureValidCommentText(
      text: text,
      emptyMessage: '수정할 내용을 입력하세요.',
    );

    final normalizedText = _normalizeInputText(text);

    if (isSubmitting.value) {
      throw Exception('댓글 수정 중입니다.');
    }

    isSubmitting.value = true;
    error.value = null;

    try {
      final updated = await repo.updateComment(
        postId: postId,
        commentId: commentId,
        text: normalizedText,
      );

      _replaceComment(updated);
      return updated;
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> canDelete(dynamic target) async {
    if (!isReady) return false;

    final commentId = _commentIdFromTarget(target);
    if (commentId == null || commentId.isEmpty) return false;

    if (_isLocalCommentId(commentId)) {
      final current = commentById(commentId);
      return current?.authorId == currentUserId;
    }

    try {
      return await repo.canDeleteComment(
        postId: postId,
        commentId: commentId,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> canDeleteComment(String commentId) async {
    return canDelete(commentId);
  }

  Comment? commentById(String commentId) {
    final id = commentId.trim();

    if (id.isEmpty) return null;

    return _commentById[id];
  }

  List<Comment> repliesOf(String rootCommentId) {
    final id = rootCommentId.trim();

    if (id.isEmpty) return const <Comment>[];

    return List<Comment>.from(_repliesByRoot[id] ?? const <Comment>[]);
  }

  int replyCountOf(String rootCommentId) {
    return repliesOf(rootCommentId).where((e) => !e.isDeleted).length;
  }

  int replyIndexOf({
    required String rootCommentId,
    required String replyId,
  }) {
    final rootId = rootCommentId.trim();
    final targetId = replyId.trim();

    if (rootId.isEmpty || targetId.isEmpty) return -1;

    final replies = _repliesByRoot[rootId] ?? const <Comment>[];
    return replies.indexWhere((comment) => comment.id == targetId);
  }

  List<Comment> rootComments() {
    return comments.where((comment) {
      final parentId = comment.parentId?.trim();
      return parentId == null || parentId.isEmpty;
    }).toList(growable: false);
  }

  String resolveReplyRootId(String commentId) {
    return _rootCommentIdOf(commentId) ?? commentId.trim();
  }

  String? rootCommentIdOf(String commentId) {
    return _rootCommentIdOf(commentId);
  }

  String? _rootCommentIdOf(String commentId) {
    final id = commentId.trim();

    if (id.isEmpty) return null;

    final target = _commentById[id];

    if (target == null) return id;

    final parentId = target.parentId?.trim();

    if (parentId == null || parentId.isEmpty) {
      return target.id;
    }

    return parentId;
  }

  bool isLikedByMe(Comment comment) {
    return comment.likedUserIds.contains(currentUserId);
  }

  bool isMine(Comment comment) {
    return comment.authorId == currentUserId;
  }

  void startReply(Comment comment) {
    activeReplyTo.value = comment.id;
    activeEditingId.value = null;
  }

  void startReplyById(String commentId) {
    final id = commentId.trim();
    activeReplyTo.value = id.isEmpty ? null : id;
    activeEditingId.value = null;
  }

  void startEdit(Comment comment) {
    activeEditingId.value = comment.id;
    activeReplyTo.value = null;
  }

  void startEditById(String commentId) {
    final id = commentId.trim();
    activeEditingId.value = id.isEmpty ? null : id;
    activeReplyTo.value = null;
  }

  void cancelComposeMode() {
    activeEditingId.value = null;
    activeReplyTo.value = null;
  }

  void clearActiveModes() {
    cancelComposeMode();
  }

  void clear() {
    _postId = null;
    _didInitialize = false;
    _cachedAuthor = null;

    activeEditingId.value = null;
    activeReplyTo.value = null;

    _clearCommentState();

    error.value = null;
    isLoading.value = false;
    isSubmitting.value = false;
  }

  String? _commentIdFromTarget(dynamic target) {
    if (target == null) return null;

    if (target is String) {
      return target.trim();
    }

    if (target is Comment) {
      return target.id.trim();
    }

    return target.toString().trim();
  }

  Future<void> _notifyPostAuthorForComment({
    required Comment createdComment,
  }) async {
    if (createdComment.authorId == currentUserId) return;

    try {
      final post = await repo.getPostById(postId);

      if (post.authorId == currentUserId) return;
      if (post.authorId.trim().isEmpty) return;

      final StoreProfile myProfile = await storeProfileRepo.fetchProfile();
      final nickname = myProfile.nickname.trim().isEmpty
          ? '익명'
          : myProfile.nickname.trim();

      await storeProfileRepo.addNotificationToUser(
        post.authorId,
        AppNotificationItem(
          id: 'comment_${post.id}_${createdComment.id}_${DateTime.now().microsecondsSinceEpoch}',
          type: 'post_comment',
          message: '$nickname님이 회원님의 글에 댓글을 남겼습니다.',
          targetUserId: post.authorId,
          targetPostId: post.id,
          targetCommentId: createdComment.id,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}
  }

  Future<void> _notifyCommentAuthorForReply({
    required Comment targetComment,
    required Comment createdReply,
  }) async {
    if (targetComment.authorId == currentUserId) return;
    if (targetComment.authorId.trim().isEmpty) return;

    try {
      final StoreProfile myProfile = await storeProfileRepo.fetchProfile();
      final nickname = myProfile.nickname.trim().isEmpty
          ? '익명'
          : myProfile.nickname.trim();

      await storeProfileRepo.addNotificationToUser(
        targetComment.authorId,
        AppNotificationItem(
          id: 'reply_${targetComment.id}_${createdReply.id}_${DateTime.now().microsecondsSinceEpoch}',
          type: 'comment_reply',
          message: '$nickname님이 회원님의 댓글에 답글을 남겼습니다.',
          targetUserId: targetComment.authorId,
          targetPostId: postId,
          targetCommentId: createdReply.id,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}
  }

  Future<void> _notifyCommentAuthorForLike({
    required Comment before,
    required Comment after,
  }) async {
    if (after.authorId == currentUserId) return;
    if (after.authorId.trim().isEmpty) return;

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
          id: 'comment_like_${after.id}_${currentUserId}_${DateTime.now().microsecondsSinceEpoch}',
          type: 'comment_like',
          message: '$nickname님이 회원님의 댓글을 좋아합니다.',
          targetUserId: after.authorId,
          targetPostId: postId,
          targetCommentId: after.id,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}
  }
}

class _AuthorSnapshot {
  final String authorId;
  final String authorLabel;
  final String? industryId;
  final String? locationLabel;
  final bool isOwnerVerified;

  const _AuthorSnapshot({
    required this.authorId,
    required this.authorLabel,
    required this.industryId,
    required this.locationLabel,
    required this.isOwnerVerified,
  });

  factory _AuthorSnapshot.fallback(String userId) {
    return _AuthorSnapshot(
      authorId: userId,
      authorLabel: '익명',
      industryId: null,
      locationLabel: null,
      isOwnerVerified: false,
    );
  }
}
import 'dart:async';
import 'dart:math';

import 'package:get/get.dart';

import 'package:yupgagae/core/auth/app_user.dart';
import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/core/auth/permission_policy.dart';
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
  static const int replyPreviewSize = 5;
  static const int commentPageSize = 20;

  final PostRepository repo;
  final StoreProfileRepository storeProfileRepo;
  final AuthSessionService auth;

  CommentController({
    required this.repo,
    required this.storeProfileRepo,
    required this.auth,
  });

  final comments = <Comment>[].obs;
  final flattenedComments = <CommentViewItem>[].obs;

  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final isSubmitting = false.obs;
  final hasMoreComments = false.obs;
  final error = RxnString();

  final activeEditingId = RxnString();
  final activeReplyTo = RxnString();

  String? _postId;
  String? _commentCursor;
  Post? _permissionPost;
  bool _didInitialize = false;

  final _blockedCache = <String>{};
  final _commentById = <String, Comment>{};
  final _repliesByRoot = <String, List<Comment>>{};
  final _rootIds = <String>{};

  final _visibleReplyLimitByRoot = <String, int>{};

  _AuthorSnapshot? _cachedAuthor;
  Future<_AuthorSnapshot>? _authorSnapshotFuture;

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

  int get activeCommentCount {
    return comments.where(_isActivePublicComment).length;
  }

  bool get canParticipate {
    return PermissionPolicy.canParticipate(_currentAuthUser);
  }

  bool get canWriteCurrentPostComment {
    final post = _permissionPost;
    if (post == null) {
      return PermissionPolicy.canWriteComment(_currentAuthUser);
    }

    return _canWriteCommentForPost(post);
  }

  bool _canWriteCommentForPost(Post post) {
    final user = _currentAuthUser;

    switch (post.boardType) {
      case BoardType.owner:
        return PermissionPolicy.canWriteOwnerBoardComment(user);
      case BoardType.free:
      case BoardType.used:
        return PermissionPolicy.canWriteComment(user);
    }
  }

  String _commentWriteBlockedMessage(Post? post) {
    final user = _currentAuthUser;

    if (post == null) {
      return PermissionPolicy.writeCommentBlockedMessage(
        user: user,
        boardType: BoardType.free,
      );
    }

    return PermissionPolicy.writeCommentBlockedMessage(
      user: user,
      boardType: post.boardType,
    );
  }

  void _ensureParticipationAllowed() {
    final user = _currentAuthUser;

    if (!PermissionPolicy.canParticipate(user)) {
      throw Exception(PermissionPolicy.participationBlockedMessage(user));
    }
  }

  Future<Post> _ensurePermissionPostLoaded() async {
    final cached = _permissionPost;
    if (cached != null && cached.id == postId) {
      return cached;
    }

    if (!isReady) {
      throw Exception('postId required');
    }

    final loaded = await repo.getPostById(postId);
    _permissionPost = loaded;
    return loaded;
  }

  Future<void> _ensureCommentWriteAllowed() async {
    final user = _currentAuthUser;

    if (!PermissionPolicy.canParticipate(user)) {
      throw Exception(PermissionPolicy.participationBlockedMessage(user));
    }

    final post = await _ensurePermissionPostLoaded();

    if (!_canWriteCommentForPost(post)) {
      throw Exception(_commentWriteBlockedMessage(post));
    }
  }

  void _ensureCommentLikeAllowed() {
    final user = _currentAuthUser;

    if (!PermissionPolicy.canToggleCommentLike(user)) {
      throw Exception(PermissionPolicy.participationBlockedMessage(user));
    }
  }

  int totalReplyCountOf(String rootCommentId) {
    final rootId = rootCommentId.trim();
    if (rootId.isEmpty) return 0;

    return (_repliesByRoot[rootId] ?? const <Comment>[])
        .where(_isVisibleThreadComment)
        .length;
  }

  int visibleReplyCountOf(String rootCommentId) {
    final rootId = rootCommentId.trim();
    if (rootId.isEmpty) return 0;

    final total = totalReplyCountOf(rootId);
    final limit = _visibleReplyLimitByRoot[rootId] ?? replyPreviewSize;

    return min(limit, total);
  }

  int hiddenReplyCountOf(String rootCommentId) {
    final rootId = rootCommentId.trim();
    if (rootId.isEmpty) return 0;

    final hidden = totalReplyCountOf(rootId) - visibleReplyCountOf(rootId);
    return hidden < 0 ? 0 : hidden;
  }

  bool hasMoreReplies(String rootCommentId) {
    return hiddenReplyCountOf(rootCommentId) > 0;
  }

  void showMoreReplies(String rootCommentId) {
    final rootId = rootCommentId.trim();
    if (rootId.isEmpty) return;
    if (!hasMoreReplies(rootId)) return;

    final currentLimit = _visibleReplyLimitByRoot[rootId] ?? replyPreviewSize;
    final total = totalReplyCountOf(rootId);

    _visibleReplyLimitByRoot[rootId] = min(
      currentLimit + replyPreviewSize,
      total,
    );

    _rebuildFlattenedOnly();
  }

  Future<void> initialize(
    String postId, {
    Post? permissionPost,
  }) async {
    final normalized = postId.trim();

    if (normalized.isEmpty) {
      error.value = 'postId required';
      return;
    }

    final usablePermissionPost =
        permissionPost != null && permissionPost.id.trim() == normalized
            ? permissionPost
            : null;

    if (_didInitialize && _postId == normalized) {
      if (usablePermissionPost != null) {
        _permissionPost = usablePermissionPost;
      } else {
        unawaited(_loadPermissionPostSilently());
      }

      unawaited(_loadBlockedCache());

      if (PermissionPolicy.canParticipate(_currentAuthUser)) {
        unawaited(_prewarmAuthorSnapshot());
      }

      if (comments.isEmpty) {
        await load();
      } else {
        unawaited(load(showLoading: false));
      }

      return;
    }

    _postId = normalized;
    _commentCursor = null;
    _permissionPost = usablePermissionPost;
    _didInitialize = true;
    _visibleReplyLimitByRoot.clear();
    hasMoreComments.value = false;
    isLoadingMore.value = false;

    final blockedFuture = _loadBlockedCache();
    final permissionPostFuture = usablePermissionPost == null
        ? _loadPermissionPostSilently()
        : Future<void>.value();

    if (PermissionPolicy.canParticipate(_currentAuthUser)) {
      unawaited(_prewarmAuthorSnapshot());
    }

    await Future.wait<void>([
      blockedFuture,
      permissionPostFuture,
    ]);

    await load();
  }

  Future<void> _loadPermissionPostSilently() async {
    if (!isReady) return;

    try {
      _permissionPost = await repo.getPostById(postId);
    } catch (_) {
      _permissionPost = null;
    }
  }

  Future<void> load({bool showLoading = true}) async {
    if (!isReady) {
      error.value = 'postId required';
      return;
    }

    if (isLoading.value) return;

    if (showLoading) {
      isLoading.value = true;
    }

    error.value = null;
    _commentCursor = null;
    hasMoreComments.value = false;

    try {
      final fetched = await repo.fetchComments(
        postId,
        limit: commentPageSize + 1,
      );

      final hasMore = fetched.length > commentPageSize;
      final pageItems = hasMore
          ? fetched.take(commentPageSize).toList(growable: false)
          : fetched;

      _commentCursor = pageItems.isEmpty ? null : pageItems.last.id;
      hasMoreComments.value = hasMore;

      _applyComments(pageItems);
    } catch (e) {
      error.value = e.toString();

      if (comments.isEmpty) {
        _clearCommentState();
      }
    } finally {
      if (showLoading) {
        isLoading.value = false;
      }
    }
  }

  Future<void> loadMoreComments() async {
    if (!isReady) {
      error.value = 'postId required';
      return;
    }

    if (isLoading.value || isLoadingMore.value) return;
    if (!hasMoreComments.value) return;

    final cursor = _commentCursor?.trim();
    if (cursor == null || cursor.isEmpty) return;

    isLoadingMore.value = true;
    error.value = null;

    try {
      final fetched = await repo.fetchComments(
        postId,
        cursor: cursor,
        limit: commentPageSize + 1,
      );

      final hasMore = fetched.length > commentPageSize;
      final pageItems = hasMore
          ? fetched.take(commentPageSize).toList(growable: false)
          : fetched;

      if (pageItems.isNotEmpty) {
        _commentCursor = pageItems.last.id;
      }

      hasMoreComments.value = hasMore;

      if (pageItems.isEmpty) {
        return;
      }

      final merged = <Comment>[
        ...comments,
        ...pageItems.where(
          (next) => comments.every((current) => current.id != next.id),
        ),
      ];

      _applyComments(merged);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoadingMore.value = false;
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
    if (!PermissionPolicy.canParticipate(_currentAuthUser)) return;

    try {
      await _getAuthorSnapshot();
    } catch (_) {}
  }

  Future<_AuthorSnapshot> _getAuthorSnapshot() async {
    _ensureParticipationAllowed();

    final cached = _cachedAuthor;
    if (cached != null && cached.authorId == currentUserId) return cached;

    final inFlight = _authorSnapshotFuture;
    if (inFlight != null) return inFlight;

    final future = _loadAuthorSnapshot();

    _authorSnapshotFuture = future;

    try {
      final snapshot = await future;
      _cachedAuthor = snapshot;
      return snapshot;
    } catch (_) {
      final fallback = _AuthorSnapshot.fallback(currentUserId);
      _cachedAuthor = fallback;
      return fallback;
    } finally {
      if (_authorSnapshotFuture == future) {
        _authorSnapshotFuture = null;
      }
    }
  }

  Future<_AuthorSnapshot> _loadAuthorSnapshot() async {
    _ensureParticipationAllowed();

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

    return _AuthorSnapshot(
      authorId: currentUserId,
      authorLabel: nickname,
      industryId: industryId,
      locationLabel: RegionCatalog.normalize(profile.region),
      isOwnerVerified: profile.isOwnerVerified,
    );
  }

  _AuthorSnapshot _authorSnapshotForFastSubmit() {
    _ensureParticipationAllowed();

    final cached = _cachedAuthor;
    if (cached != null && cached.authorId == currentUserId) return cached;

    return _AuthorSnapshot.fallback(currentUserId);
  }

  void clearAuthorCache() {
    _cachedAuthor = null;
    _authorSnapshotFuture = null;

    if (PermissionPolicy.canParticipate(_currentAuthUser)) {
      unawaited(_prewarmAuthorSnapshot());
    }
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

  bool _isAuthorBlocked(Comment comment) {
    return _blockedCache.contains(comment.authorId.trim());
  }

  bool _isDeletedByAuthorPlaceholder(Comment comment) {
    return comment.isDeleted ||
        comment.status == CommentStatus.deletedByAuthor ||
        comment.deletedAt != null;
  }

  bool _isModerationHiddenComment(Comment comment) {
    return comment.status == CommentStatus.hiddenByReport ||
        comment.status == CommentStatus.hiddenByAdmin ||
        comment.status == CommentStatus.removedByAdmin ||
        comment.isReportThresholdReached ||
        comment.isHiddenByAdmin ||
        comment.isRemovedByAdmin ||
        comment.adminRemovedAt != null;
  }

  bool _isVisibleThreadComment(Comment comment) {
    if (_isAuthorBlocked(comment)) return false;
    if (_isModerationHiddenComment(comment)) return false;

    return true;
  }

  bool _isActivePublicComment(Comment comment) {
    if (!_isVisibleThreadComment(comment)) return false;
    if (_isDeletedByAuthorPlaceholder(comment)) return false;

    return true;
  }

  bool _isVisibleComment(Comment comment) {
    return _isVisibleThreadComment(comment);
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
    _visibleReplyLimitByRoot.clear();
    _commentCursor = null;
    hasMoreComments.value = false;
    isLoadingMore.value = false;
  }

  void _applyComments(List<Comment> next) {
    final visibleSorted = next.where(_isVisibleComment).toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _rebuildIndexes(visibleSorted);
    _pruneReplyPaginationState();

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

  void _pruneReplyPaginationState() {
    final validRootIds = _rootIds.toSet();

    _visibleReplyLimitByRoot.removeWhere((key, value) {
      return !validRootIds.contains(key);
    });
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
      final visibleReplyLimit =
          _visibleReplyLimitByRoot[comment.id] ?? replyPreviewSize;

      final visibleReplies =
          replies.where(_isVisibleThreadComment).take(visibleReplyLimit);

      for (final reply in visibleReplies) {
        out.add(CommentViewItem(comment: reply, depth: 1));
      }
    }

    return out;
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

    final currentLimit = _visibleReplyLimitByRoot[parentId] ?? replyPreviewSize;
    final total = totalReplyCountOf(parentId);

    _visibleReplyLimitByRoot[parentId] = min(
      max(currentLimit, visibleReplyCountOf(parentId) + 1),
      total,
    );

    _rebuildFlattenedOnly();
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

    final flatIndex = flattenedComments.indexWhere(
      (item) => item.comment.id == updated.id,
    );
    if (flatIndex >= 0) {
      flattenedComments[flatIndex] = CommentViewItem(
        comment: updated,
        depth: flattenedComments[flatIndex].depth,
      );
    } else if (listIndex < 0) {
      _rebuildFlattenedOnly();
    }
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

    final flatIndex = flattenedComments.indexWhere(
      (item) => item.comment.id == localId,
    );
    if (flatIndex >= 0) {
      flattenedComments[flatIndex] = CommentViewItem(
        comment: realComment,
        depth: flattenedComments[flatIndex].depth,
      );
    } else {
      _rebuildFlattenedOnly();
    }
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
    final visibleSorted =
        comments.where(_isVisibleComment).toList(growable: false)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _rebuildIndexes(visibleSorted);
    _pruneReplyPaginationState();

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
    await _ensureCommentWriteAllowed();

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
      reportReasons: const <String>[],
      reportReasonCounts: const <String, int>{},
      isReportThresholdReached: false,
      isHiddenByAdmin: false,
      adminHiddenReason: null,
      adminHiddenAt: null,
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
    await _ensureCommentWriteAllowed();

    if (!isReady) {
      throw Exception('postId required');
    }

    final tappedTarget = commentById(parentCommentId.trim());
    final rootParentId = resolveReplyRootId(parentCommentId.trim());
    final rootTarget = commentById(rootParentId);

    if (rootParentId.trim().isEmpty) {
      throw Exception('답글을 달 댓글을 찾을 수 없습니다.');
    }

    if (tappedTarget == null || rootTarget == null) {
      throw Exception('답글을 달 댓글을 찾을 수 없습니다.');
    }

    if (tappedTarget.isDeleted || tappedTarget.isHiddenFromPublic) {
      throw Exception('숨김 처리된 댓글에는 답글을 작성할 수 없습니다.');
    }

    if (rootTarget.isDeleted || rootTarget.isHiddenFromPublic) {
      throw Exception('숨김 처리된 댓글에는 답글을 작성할 수 없습니다.');
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
      reportReasons: const <String>[],
      reportReasonCounts: const <String, int>{},
      isReportThresholdReached: false,
      isHiddenByAdmin: false,
      adminHiddenReason: null,
      adminHiddenAt: null,
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

      unawaited(
        _notifyCommentAuthorForReply(
          targetComment: tappedTarget,
          createdReply: normalizedCreated,
        ),
      );

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
    _ensureCommentLikeAllowed();

    if (!isReady) {
      throw Exception('postId required');
    }

    final userId = currentUserId;
    if (userId.isEmpty) {
      throw Exception('로그인이 필요한 기능입니다.');
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

    if (before.isDeleted || before.isHiddenFromPublic) {
      throw Exception('숨김 처리된 댓글에는 좋아요를 누를 수 없습니다.');
    }

    final optimisticLikedUserIds = Set<String>.from(before.likedUserIds);

    if (optimisticLikedUserIds.contains(userId)) {
      optimisticLikedUserIds.remove(userId);
    } else {
      optimisticLikedUserIds.add(userId);
    }

    final optimistic = before.copyWith(
      likedUserIds: optimisticLikedUserIds,
      likeCount: optimisticLikedUserIds.length,
    );

    _replaceComment(optimistic);
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
      _replaceComment(before);
      error.value = e.toString();
      rethrow;
    }
  }

  Future<Comment> toggleLikeOnComment(Comment comment) async {
    return toggleLike(comment);
  }

  Future<void> delete(dynamic target) async {
    _ensureParticipationAllowed();

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

      final now = DateTime.now();

      _replaceComment(
        current.copyWith(
          text: '삭제된 댓글입니다.',
          isDeleted: true,
          status: CommentStatus.deletedByAuthor,
          deletedAt: now,
          updatedAt: now,
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
    _ensureParticipationAllowed();

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

    final current = commentById(targetId);
    if (current == null) {
      throw Exception('댓글을 찾을 수 없습니다.');
    }

    if (current.isDeleted || current.isHiddenFromPublic) {
      throw Exception('이미 숨김 처리된 댓글입니다.');
    }

    error.value = null;

    try {
      await repo.reportComment(
        postId: postId,
        commentId: targetId,
        reason: normalizedReason,
      );

      final latest = commentById(targetId);
      if (latest == null) return;
      if (latest.isDeleted) return;
      if (latest.reportedUserIds.contains(currentUserId)) return;

      final reporters = Set<String>.from(latest.reportedUserIds)
        ..add(currentUserId);
      final reasons = List<String>.from(latest.reportReasons)
        ..add(normalizedReason);
      final reasonCounts = Map<String, int>.from(latest.reportReasonCounts);
      reasonCounts[normalizedReason] =
          (reasonCounts[normalizedReason] ?? 0) + 1;

      final newCount = latest.reportCount + 1;

      _replaceComment(
        latest.copyWith(
          reportedUserIds: reporters,
          reportCount: newCount,
          reportReasons: reasons,
          reportReasonCounts: reasonCounts,
          isReportThresholdReached:
              latest.isReportThresholdReached || newCount >= 3,
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
    _ensureParticipationAllowed();

    if (!isReady) {
      throw Exception('postId required');
    }

    if (_isLocalCommentId(commentId)) {
      throw Exception('잠시 후 다시 시도해주세요.');
    }

    final current = commentById(commentId);
    if (current == null) {
      throw Exception('댓글을 찾을 수 없습니다.');
    }

    if (current.isDeleted) {
      throw Exception('삭제된 댓글은 수정할 수 없습니다.');
    }

    if (current.isHiddenFromPublic) {
      throw Exception('숨김 처리된 댓글은 수정할 수 없습니다.');
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
    if (!PermissionPolicy.canParticipate(_currentAuthUser)) return false;
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
    return repliesOf(rootCommentId).where(_isActivePublicComment).length;
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
    final userId = currentUserId;
    if (userId.isEmpty) return false;

    return comment.likedUserIds.contains(userId);
  }

  bool isMine(Comment comment) {
    final userId = currentUserId;
    if (userId.isEmpty) return false;

    return comment.authorId == userId;
  }

  void startReply(Comment comment) {
    if (!canWriteCurrentPostComment) return;
    if (comment.isDeleted || comment.isHiddenFromPublic) return;

    final rootId = resolveReplyRootId(comment.id);
    final root = commentById(rootId);

    if (root == null || root.isDeleted || root.isHiddenFromPublic) return;

    activeReplyTo.value = comment.id;
    activeEditingId.value = null;
  }

  void startReplyById(String commentId) {
    if (!canWriteCurrentPostComment) return;

    final id = commentId.trim();
    if (id.isEmpty) {
      activeReplyTo.value = null;
      return;
    }

    final comment = commentById(id);
    if (comment == null) return;
    if (comment.isDeleted || comment.isHiddenFromPublic) return;

    final rootId = resolveReplyRootId(comment.id);
    final root = commentById(rootId);

    if (root == null || root.isDeleted || root.isHiddenFromPublic) return;

    activeReplyTo.value = id;
    activeEditingId.value = null;
  }

  void startEdit(Comment comment) {
    if (!PermissionPolicy.canParticipate(_currentAuthUser)) return;
    if (comment.isDeleted || comment.isHiddenFromPublic) return;

    activeEditingId.value = comment.id;
    activeReplyTo.value = null;
  }

  void startEditById(String commentId) {
    if (!PermissionPolicy.canParticipate(_currentAuthUser)) return;

    final id = commentId.trim();
    final comment = commentById(id);
    if (comment == null) return;
    if (comment.isDeleted || comment.isHiddenFromPublic) return;

    activeEditingId.value = id;
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
    _commentCursor = null;
    _permissionPost = null;
    _didInitialize = false;
    _cachedAuthor = null;
    _authorSnapshotFuture = null;
    _visibleReplyLimitByRoot.clear();

    activeEditingId.value = null;
    activeReplyTo.value = null;

    _clearCommentState();

    error.value = null;
    isLoading.value = false;
    isLoadingMore.value = false;
    isSubmitting.value = false;
    hasMoreComments.value = false;
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
    final userId = currentUserId;
    if (userId.isEmpty) return;
    if (createdComment.authorId == userId) return;

    try {
      final post = await repo.getPostById(postId);

      if (post.authorId == userId) return;
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
    final userId = currentUserId;
    if (userId.isEmpty) return;
    if (targetComment.authorId == userId) return;
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
    final userId = currentUserId;
    if (userId.isEmpty) return;
    if (after.authorId == userId) return;
    if (after.authorId.trim().isEmpty) return;

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
          id: 'comment_like_${after.id}_${userId}_${DateTime.now().microsecondsSinceEpoch}',
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
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_page.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/domain/region_catalog.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class InMemoryPostRepository implements PostRepository {
  final ModerationService? moderation;
  final String currentUserId;
  final StoreProfileRepository? storeProfileRepo;

  InMemoryPostRepository({
    this.moderation,
    String? currentUserId,
    this.storeProfileRepo,
  }) : currentUserId = currentUserId ?? 'anon_local' {
    _kickOffColdStart();
  }

  final _posts = <Post>[];
  final _commentsByPostId = <String, List<Comment>>{};
  final _rand = Random();

  bool _isLoaded = false;
  Future<void>? _loadFuture;

  _LocalAuthorSnapshot? _authorSnapshotCache;
  Future<_LocalAuthorSnapshot>? _authorSnapshotFuture;

  Future<void> _saveChain = Future<void>.value();

  String get _me {
    final authUser = _currentAuthUserOrNull();
    final authUserId = authUser?.userId.trim();

    if (authUserId != null && authUserId.isNotEmpty) {
      return authUserId;
    }

    return currentUserId.trim().isEmpty ? 'anon_local' : currentUserId.trim();
  }

  void _kickOffColdStart() {
    _loadFuture ??= _loadFromDisk();

    _authorSnapshotFuture ??= _loadCurrentAuthorSnapshot().then((snapshot) {
      _authorSnapshotCache = snapshot;
      return snapshot;
    }).catchError((_) {
      final fallback = _LocalAuthorSnapshot.fallback(_me);
      _authorSnapshotCache = fallback;
      return fallback;
    });
  }

  @override
  Future<void> warmUp() async {
    await _ensureLoaded();
  }

  Future<void> ensureReady() async {
    await warmUp();
  }

  Future<void> prewarmCurrentAuthorSnapshot() async {
    await _currentAuthorSnapshot();
  }

  void invalidateCurrentAuthorSnapshot() {
    _authorSnapshotCache = null;
    _authorSnapshotFuture = null;
  }

  Future<void> flushPendingWrites() async {
    await _saveChain;
  }

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}${_rand.nextInt(9999)}';

  int _indexOfPost(String postId) => _posts.indexWhere((p) => p.id == postId);

  Future<File> _storeFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/community_store_v1.json');
  }

  List<String> _normalizeImageUrls({
    List<String>? imageUrls,
    List<String>? imagePaths,
  }) {
    final rawList = imageUrls ?? imagePaths ?? const <String>[];

    return rawList
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(5)
        .toList(growable: false);
  }

  Future<void> _saveToDisk() async {
    try {
      final postsJson = _posts.map((e) => e.toJson()).toList();
      final commentsJson = _commentsByPostId.map(
        (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
      );

      final encoded = await compute(
        _encodeCommunityStoreOnWorker,
        <String, dynamic>{
          'posts': postsJson,
          'commentsByPostId': commentsJson,
        },
      );

      final file = await _storeFile();
      await file.writeAsString(encoded);
    } catch (_) {
      // 로컬 저장 실패는 앱 흐름을 막지 않는다.
    }
  }

  void _saveToDiskLater() {
    _saveChain = _saveChain.then((_) => _saveToDisk()).catchError((_) {
      // 저장 실패는 앱 흐름을 막지 않는다.
    });
  }

  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;

    _loadFuture ??= _loadFromDisk();
    await _loadFuture;
  }

  Future<void> _loadFromDisk() async {
    var shouldPersistRepairedStore = false;

    try {
      final file = await _storeFile();

      if (!await file.exists()) {
        _isLoaded = true;
        return;
      }

      final raw = await file.readAsString();

      if (raw.trim().isEmpty) {
        _isLoaded = true;
        return;
      }

      final decoded = await compute(_decodeCommunityStoreOnWorker, raw);

      _posts
        ..clear()
        ..addAll(decoded.posts);

      _commentsByPostId
        ..clear()
        ..addAll(decoded.commentsByPostId);

      shouldPersistRepairedStore = _repairCommunityStoreAfterLoad();
    } catch (_) {
      _posts.clear();
      _commentsByPostId.clear();
    } finally {
      _isLoaded = true;
    }

    if (shouldPersistRepairedStore) {
      _saveToDiskLater();
    }
  }

  bool _repairCommunityStoreAfterLoad() {
    var changed = false;

    changed = _removeCommentsForMissingPosts() || changed;
    changed = _repairCommentPostIdsFromMapKey() || changed;
    changed = _repairCommentCountsFromActualComments() || changed;

    return changed;
  }

  bool _removeCommentsForMissingPosts() {
    final validPostIds = _posts.map((post) => post.id).toSet();
    final beforeLength = _commentsByPostId.length;

    _commentsByPostId.removeWhere((postId, _) {
      return !validPostIds.contains(postId);
    });

    return beforeLength != _commentsByPostId.length;
  }

  bool _repairCommentPostIdsFromMapKey() {
    var changed = false;

    final repaired = <String, List<Comment>>{};

    for (final entry in _commentsByPostId.entries) {
      final postId = entry.key;
      final comments = <Comment>[];

      for (final comment in entry.value) {
        if (comment.postId == postId) {
          comments.add(comment);
          continue;
        }

        comments.add(
          comment.copyWith(
            postId: postId,
            updatedAt: DateTime.now(),
          ),
        );
        changed = true;
      }

      comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      repaired[postId] = comments;
    }

    if (changed) {
      _commentsByPostId
        ..clear()
        ..addAll(repaired);
    }

    return changed;
  }

  bool _repairCommentCountsFromActualComments() {
    var changed = false;

    for (var i = 0; i < _posts.length; i++) {
      final post = _posts[i];
      final comments = _commentsByPostId[post.id] ?? const <Comment>[];

      final visibleCount = comments.where((comment) {
        return !comment.isDeleted;
      }).length;

      if (post.commentCount == visibleCount) {
        continue;
      }

      _posts[i] = post.copyWith(
        commentCount: visibleCount,
      );
      changed = true;
    }

    return changed;
  }

  Future<_LocalAuthorSnapshot> _currentAuthorSnapshot({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _authorSnapshotCache;
      if (cached != null) return cached;

      final inFlight = _authorSnapshotFuture;
      if (inFlight != null) return inFlight;
    }

    final future = _loadCurrentAuthorSnapshot().then((snapshot) {
      _authorSnapshotCache = snapshot;
      return snapshot;
    }).catchError((_) {
      final fallback = _LocalAuthorSnapshot.fallback(_me);
      _authorSnapshotCache = fallback;
      return fallback;
    });

    _authorSnapshotFuture = future;

    try {
      return await future;
    } finally {
      if (_authorSnapshotFuture == future) {
        _authorSnapshotFuture = null;
      }
    }
  }

  Future<_LocalAuthorSnapshot> _loadCurrentAuthorSnapshot() async {
    final authUser = _currentAuthUserOrNull();

    if (authUser != null) {
      final userId = authUser.userId.trim();
      final nickname = authUser.nickname?.trim();
      final industry = authUser.industry?.trim();
      final region = authUser.region?.trim();

      if (userId.isNotEmpty) {
        return _LocalAuthorSnapshot(
          authorId: userId,
          authorLabel: nickname == null || nickname.isEmpty ? '익명' : nickname,
          isOwnerVerified: authUser.isBusinessVerified,
          industryId: _industryIdFromRaw(industry),
          locationLabel: RegionCatalog.normalize(region ?? ''),
        );
      }
    }

    try {
      final repo = storeProfileRepo;
      if (repo == null) {
        return _LocalAuthorSnapshot.fallback(_me);
      }

      final StoreProfile profile = await repo.fetchProfile();

      final nickname =
          profile.nickname.trim().isEmpty ? '익명' : profile.nickname.trim();

      return _LocalAuthorSnapshot(
        authorId: _me,
        authorLabel: nickname,
        isOwnerVerified: profile.isOwnerVerified,
        industryId: _industryIdFromRaw(profile.industry),
        locationLabel: RegionCatalog.normalize(profile.region),
      );
    } catch (_) {
      return _LocalAuthorSnapshot.fallback(_me);
    }
  }

  dynamic _currentAuthUserOrNull() {
    if (!Get.isRegistered<AuthController>()) {
      return null;
    }

    return Get.find<AuthController>().currentUser.value;
  }

  String? _industryIdFromRaw(String? rawValue) {
    final raw = rawValue?.trim();
    if (raw == null || raw.isEmpty) return null;

    for (final item in IndustryCatalog.ordered()) {
      if (item.id.trim() == raw) {
        return item.id;
      }
    }

    final normalizedRaw = raw.toLowerCase().replaceAll(' ', '');

    for (final item in IndustryCatalog.ordered()) {
      final normalizedName = item.name.toLowerCase().replaceAll(' ', '');
      if (normalizedName == normalizedRaw) {
        return item.id;
      }
    }

    for (final item in IndustryCatalog.ordered()) {
      if (item.name.trim() == raw) {
        return item.id;
      }
    }

    return null;
  }

  List<Post> _applyBoardFilter(
    List<Post> source, {
    BoardType? boardType,
  }) {
    if (boardType == null) return source;
    return source.where((p) => p.boardType == boardType).toList();
  }

  List<Post> _applyUsedTypeFilter(
    List<Post> source, {
    UsedPostType? usedType,
  }) {
    if (usedType == null) return source;
    return source.where((p) => p.usedType == usedType).toList();
  }

  bool _matchesSearch(
    Post post,
    String query,
    PostSearchField searchField,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final title = post.title.toLowerCase();
    final body = post.body.toLowerCase();

    switch (searchField) {
      case PostSearchField.title:
        return title.contains(q);
      case PostSearchField.body:
        return body.contains(q);
      case PostSearchField.all:
        return title.contains(q) || body.contains(q);
    }
  }

  bool _matchesIndustry(Post post, String? industryId) {
    final value = industryId?.trim();
    if (value == null || value.isEmpty) return true;
    return post.industryId == value;
  }

  bool _matchesLocation(Post post, String? locationLabel) {
    final value = locationLabel?.trim();
    if (value == null || value.isEmpty) return true;
    return post.locationLabel == value;
  }

  bool _isPublicPost(Post post) {
    return !post.isHiddenFromPublic && !post.isDeleted;
  }

  int _compareLatest(Post a, Post b) => b.createdAt.compareTo(a.createdAt);

  void _syncPostCommentCount(String postId) {
    final idx = _indexOfPost(postId);
    if (idx < 0) return;

    final list = _commentsByPostId[postId] ?? const <Comment>[];
    final count = list.where((c) => !c.isDeleted).length;

    _posts[idx] = _posts[idx].copyWith(
      commentCount: count,
      updatedAt: DateTime.now(),
    );
  }

  List<Post> _filteredPublicPosts({
    BoardType? boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,
    String searchQuery = '',
    PostSearchField searchField = PostSearchField.all,
  }) {
    var list = _posts.where(_isPublicPost).toList();

    list = _applyBoardFilter(list, boardType: boardType);
    list = _applyUsedTypeFilter(list, usedType: usedType);
    list = list
        .where((post) => _matchesIndustry(post, industryId))
        .where((post) => _matchesLocation(post, locationLabel))
        .where((post) => _matchesSearch(post, searchQuery, searchField))
        .toList();

    return list;
  }

  PostPage _pageFromSortedPosts({
    required List<Post> sortedPosts,
    required String? cursor,
    required int limit,
  }) {
    final safeLimit = limit <= 0 ? 20 : limit;
    final safeCursor = cursor?.trim();

    var startIndex = 0;

    if (safeCursor != null && safeCursor.isNotEmpty) {
      final idx = sortedPosts.indexWhere((post) => post.id == safeCursor);
      if (idx >= 0) {
        startIndex = idx + 1;
      }
    }

    final pageItems = sortedPosts.skip(startIndex).take(safeLimit).toList();
    final nextIndex = startIndex + pageItems.length;
    final nextCursor =
        nextIndex < sortedPosts.length && pageItems.isNotEmpty
            ? pageItems.last.id
            : null;

    return PostPage(
      items: pageItems,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<List<Post>> fetchHomeTopPosts({int limit = 100}) async {
    await _ensureLoaded();

    final safeLimit = limit <= 0 ? 100 : limit;

    final list = _posts.where(_isPublicPost).toList()
      ..sort((a, b) {
        final aScore = (a.likeCount * 3) + (a.commentCount * 2) + a.viewCount;
        final bScore = (b.likeCount * 3) + (b.commentCount * 2) + b.viewCount;
        final scoreCompare = bScore.compareTo(aScore);
        if (scoreCompare != 0) return scoreCompare;
        return b.createdAt.compareTo(a.createdAt);
      });

    return list.take(safeLimit).toList();
  }

  @override
  Future<List<Post>> fetchPosts({
    PostSort sort = PostSort.latest,
    BoardType? boardType,
  }) async {
    await _ensureLoaded();

    var list = _posts.where(_isPublicPost).toList();
    list = _applyBoardFilter(list, boardType: boardType);

    switch (sort) {
      case PostSort.latest:
        list.sort(_compareLatest);
        break;
      case PostSort.hot:
        list.sort((a, b) {
          final aScore = (a.likeCount * 3) + (a.commentCount * 2) + a.viewCount;
          final bScore = (b.likeCount * 3) + (b.commentCount * 2) + b.viewCount;
          final scoreCompare = bScore.compareTo(aScore);
          if (scoreCompare != 0) return scoreCompare;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case PostSort.mostCommented:
        list.sort((a, b) {
          final commentCompare = b.commentCount.compareTo(a.commentCount);
          if (commentCompare != 0) return commentCompare;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }

    return list;
  }

  @override
  Future<List<Post>> fetchReportedPosts() async {
    await _ensureLoaded();

    final list = _posts.where((post) {
      return post.reportCount > 0 ||
          post.isReportThresholdReached ||
          post.isHiddenByAdmin ||
          post.isRemovedByAdmin ||
          post.status == PostStatus.hiddenByReport ||
          post.status == PostStatus.hiddenByAdmin ||
          post.status == PostStatus.removedByAdmin;
    }).toList();

    list.sort((a, b) {
      final priorityCompare =
          _adminPostPriorityScore(b).compareTo(_adminPostPriorityScore(a));
      if (priorityCompare != 0) return priorityCompare;

      final reportCompare = b.reportCount.compareTo(a.reportCount);
      if (reportCompare != 0) return reportCompare;

      return b.createdAt.compareTo(a.createdAt);
    });

    return list;
  }

  @override
  Future<List<ReportedCommentItem>> fetchReportedComments() async {
    await _ensureLoaded();

    final items = <ReportedCommentItem>[];

    for (final entry in _commentsByPostId.entries) {
      final postId = entry.key;
      final postIdx = _indexOfPost(postId);
      if (postIdx < 0) continue;

      final post = _posts[postIdx];

      for (final comment in entry.value) {
        final managed = comment.reportCount > 0 ||
            comment.isReportThresholdReached ||
            comment.isHiddenByAdmin ||
            comment.isRemovedByAdmin ||
            comment.status == CommentStatus.hiddenByReport ||
            comment.status == CommentStatus.hiddenByAdmin ||
            comment.status == CommentStatus.removedByAdmin;

        if (!managed) continue;

        items.add(
          ReportedCommentItem(
            post: post,
            comment: comment,
          ),
        );
      }
    }

    items.sort((a, b) {
      final priorityCompare = _adminCommentPriorityScore(b.comment)
          .compareTo(_adminCommentPriorityScore(a.comment));
      if (priorityCompare != 0) return priorityCompare;

      final reportCompare =
          b.comment.reportCount.compareTo(a.comment.reportCount);
      if (reportCompare != 0) return reportCompare;

      return b.comment.createdAt.compareTo(a.comment.createdAt);
    });

    return items;
  }

  int _adminPostPriorityScore(Post post) {
    if (post.status == PostStatus.removedByAdmin || post.isRemovedByAdmin) {
      return 4;
    }
    if (post.status == PostStatus.hiddenByAdmin || post.isHiddenByAdmin) {
      return 3;
    }
    if (post.status == PostStatus.hiddenByReport ||
        post.isReportThresholdReached) {
      return 2;
    }
    if (post.reportCount > 0) return 1;
    return 0;
  }

  int _adminCommentPriorityScore(Comment comment) {
    if (comment.status == CommentStatus.removedByAdmin ||
        comment.isRemovedByAdmin) {
      return 4;
    }
    if (comment.status == CommentStatus.hiddenByAdmin ||
        comment.isHiddenByAdmin) {
      return 3;
    }
    if (comment.status == CommentStatus.hiddenByReport ||
        comment.isReportThresholdReached) {
      return 2;
    }
    if (comment.reportCount > 0) return 1;
    return 0;
  }

  @override
  Future<Post> getPostById(String postId) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) {
      throw Exception('Post not found');
    }

    return _posts[idx];
  }

  @override
  Future<Post> createPost({
    String? postId,
    required String title,
    required String body,
    required BoardType boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,
    List<String>? imageUrls,
    List<String>? imagePaths,
  }) async {
    await _ensureLoaded();

    final author = await _currentAuthorSnapshot(forceRefresh: true);
    final now = DateTime.now();
    final normalizedPostId = postId?.trim();
    final id = normalizedPostId == null || normalizedPostId.isEmpty
        ? _id()
        : normalizedPostId;

    final post = Post(
      id: id,
      authorId: author.authorId,
      authorLabel: author.authorLabel,
      isOwnerVerified: author.isOwnerVerified,
      title: title,
      body: body,
      boardType: boardType,
      usedType: boardType == BoardType.used ? usedType : null,
      isSold: false,
      industryId: author.industryId ?? industryId,
      locationLabel: author.locationLabel ?? locationLabel,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      status: PostStatus.active,
      commentCount: 0,
      likeCount: 0,
      viewCount: 0,
      reportCount: 0,
      reportedUserIds: <String>{},
      reportReasons: const <String>[],
      reportReasonCounts: const <String, int>{},
      isReportThresholdReached: false,
      isHiddenByAdmin: false,
      adminHiddenReason: null,
      adminHiddenAt: null,
      imageUrls: _normalizeImageUrls(
        imageUrls: imageUrls,
        imagePaths: imagePaths,
      ),
      likedUserIds: <String>{},
    );

    _posts.insert(0, post);
    _saveToDiskLater();

    return post;
  }

  @override
  Future<Post> updatePost({
    required String postId,
    required String title,
    required String body,
    UsedPostType? usedType,
    List<String>? imageUrls,
    List<String>? imagePaths,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) {
      throw Exception('Post not found');
    }

    final current = _posts[idx];

    if (current.authorId != _me) {
      throw Exception('수정 권한이 없습니다.');
    }

    if (current.isDeleted) {
      throw Exception('삭제된 게시글은 수정할 수 없습니다.');
    }

    if (current.isHiddenFromPublic) {
      throw Exception('숨김 처리된 게시글은 수정할 수 없습니다.');
    }

    final hasIncomingImages = imageUrls != null || imagePaths != null;

    final updated = current.copyWith(
      title: title,
      body: body,
      usedType: current.boardType == BoardType.used ? usedType : current.usedType,
      imageUrls: hasIncomingImages
          ? _normalizeImageUrls(
              imageUrls: imageUrls,
              imagePaths: imagePaths,
            )
          : current.imageUrls,
      updatedAt: DateTime.now(),
    );

    _posts[idx] = updated;
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<Post> toggleLike({
    required String postId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) {
      throw Exception('Post not found');
    }

    final current = _posts[idx];

    if (current.isDeleted || current.isHiddenFromPublic) {
      throw Exception('숨김 처리된 게시글에는 좋아요를 누를 수 없습니다.');
    }

    final liked = Set<String>.from(current.likedUserIds);

    if (liked.contains(_me)) {
      liked.remove(_me);
    } else {
      liked.add(_me);
    }

    final updated = current.copyWith(
      likedUserIds: liked,
      likeCount: liked.length,
      updatedAt: DateTime.now(),
    );

    _posts[idx] = updated;
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<Post> toggleSold({
    required String postId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) {
      throw Exception('Post not found');
    }

    final current = _posts[idx];

    if (current.authorId != _me) {
      throw Exception('판매 상태 변경 권한이 없습니다.');
    }

    if (current.isDeleted || current.isHiddenFromPublic) {
      throw Exception('숨김 처리된 게시글은 판매 상태를 변경할 수 없습니다.');
    }

    if (current.boardType != BoardType.used) {
      throw Exception('거래 게시글만 판매 상태를 변경할 수 있습니다.');
    }

    final updated = current.copyWith(
      isSold: !current.isSold,
      updatedAt: DateTime.now(),
    );

    _posts[idx] = updated;
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<void> incrementView(String postId) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) return;

    final current = _posts[idx];

    if (current.isDeleted || current.isHiddenFromPublic) return;

    _posts[idx] = current.copyWith(
      viewCount: current.viewCount + 1,
      updatedAt: DateTime.now(),
    );

    _saveToDiskLater();
  }

  @override
  Future<PostPage> fetchLatestPage({
    String? cursor,
    int limit = 20,
    String? searchQuery,
    BoardType? boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,
    PostSearchField searchField = PostSearchField.all,
  }) async {
    await _ensureLoaded();

    final list = _filteredPublicPosts(
      boardType: boardType,
      usedType: usedType,
      industryId: industryId,
      locationLabel: locationLabel,
      searchQuery: searchQuery ?? '',
      searchField: searchField,
    )..sort(_compareLatest);

    return _pageFromSortedPosts(
      sortedPosts: list,
      cursor: cursor,
      limit: limit,
    );
  }

  @override
  Future<PostPage> fetchHotPage({
    String? cursor,
    int limit = 20,
    BoardType? boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,
  }) async {
    await _ensureLoaded();

    final list = _filteredPublicPosts(
      boardType: boardType,
      usedType: usedType,
      industryId: industryId,
      locationLabel: locationLabel,
    )..sort((a, b) {
        final likeCompare = b.likeCount.compareTo(a.likeCount);
        if (likeCompare != 0) return likeCompare;

        final aScore = (a.likeCount * 3) + (a.commentCount * 2) + a.viewCount;
        final bScore = (b.likeCount * 3) + (b.commentCount * 2) + b.viewCount;
        final scoreCompare = bScore.compareTo(aScore);
        if (scoreCompare != 0) return scoreCompare;

        return b.createdAt.compareTo(a.createdAt);
      });

    return _pageFromSortedPosts(
      sortedPosts: list,
      cursor: cursor,
      limit: limit,
    );
  }

  @override
  Future<PostPage> fetchMostCommentedPage({
    String? cursor,
    int limit = 20,
    BoardType? boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,
  }) async {
    await _ensureLoaded();

    final list = _filteredPublicPosts(
      boardType: boardType,
      usedType: usedType,
      industryId: industryId,
      locationLabel: locationLabel,
    )..sort((a, b) {
        final commentCompare = b.commentCount.compareTo(a.commentCount);
        if (commentCompare != 0) return commentCompare;

        return b.createdAt.compareTo(a.createdAt);
      });

    return _pageFromSortedPosts(
      sortedPosts: list,
      cursor: cursor,
      limit: limit,
    );
  }

  @override
  Future<bool> canDeletePost({
    required String postId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) return false;

    final post = _posts[idx];
    if (post.isDeleted) return false;

    return post.authorId == _me;
  }

  @override
  Future<void> deletePost({
    required String postId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) {
      throw Exception('Post not found');
    }

    final current = _posts[idx];

    if (current.authorId != _me) {
      throw Exception('삭제 권한이 없습니다.');
    }

    if (current.isDeleted) return;

    final now = DateTime.now();

    final updated = current.copyWith(
      title: '삭제된 게시글입니다.',
      body: '',
      imageUrls: const <String>[],
      status: PostStatus.deletedByAuthor,
      deletedAt: now,
      updatedAt: now,
      isSold: false,
    );

    _posts[idx] = updated;
    _saveToDiskLater();
  }

  @override
  Future<void> reportPost({
    required String postId,
    required String reason,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) {
      throw Exception('Post not found');
    }

    final current = _posts[idx];

    if (current.isDeleted || current.isHiddenFromPublic) {
      throw Exception('이미 숨김 처리된 게시글입니다.');
    }

    if (current.authorId == _me) {
      throw Exception('본인 글은 신고할 수 없습니다.');
    }

    if (current.reportedUserIds.contains(_me)) {
      throw Exception('이미 신고한 게시글입니다.');
    }

    final normalizedReason = reason.trim();

    if (normalizedReason.isEmpty) {
      throw Exception('신고 사유를 선택하세요.');
    }

    final reporters = Set<String>.from(current.reportedUserIds)..add(_me);

    final reasons = List<String>.from(current.reportReasons)
      ..add(normalizedReason);

    final reasonCounts = Map<String, int>.from(current.reportReasonCounts);
    reasonCounts[normalizedReason] = (reasonCounts[normalizedReason] ?? 0) + 1;

    final nextCount = current.reportCount + 1;
    final thresholdReached = current.isReportThresholdReached || nextCount >= 3;

    final updated = current.copyWith(
      reportCount: nextCount,
      reportedUserIds: reporters,
      reportReasons: reasons,
      reportReasonCounts: reasonCounts,
      isReportThresholdReached: thresholdReached,
      status: thresholdReached ? PostStatus.hiddenByReport : PostStatus.active,
      updatedAt: DateTime.now(),
    );

    _posts[idx] = updated;
    _saveToDiskLater();
  }

  @override
  Future<Post> hidePostByAdmin({
    required String postId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) {
      throw Exception('Post not found');
    }

    final current = _posts[idx];

    if (current.isDeleted || current.isRemovedByAdmin) {
      throw Exception('삭제 또는 제거된 게시글은 숨김 처리할 수 없습니다.');
    }

    final hiddenReason = current.primaryReportReason?.trim().isNotEmpty == true
        ? current.primaryReportReason!.trim()
        : Post.defaultHiddenReason;

    final updated = current.copyWith(
      isHiddenByAdmin: true,
      status: PostStatus.hiddenByAdmin,
      adminHiddenReason: hiddenReason,
      adminHiddenAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _posts[idx] = updated;
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<Post> unhidePostByAdmin({
    required String postId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) {
      throw Exception('Post not found');
    }

    final current = _posts[idx];

    if (current.isDeleted || current.isRemovedByAdmin) {
      throw Exception('삭제 또는 제거된 게시글은 숨김 해제할 수 없습니다.');
    }

    final nextStatus = current.isReportThresholdReached
        ? PostStatus.hiddenByReport
        : PostStatus.active;

    final updated = current.copyWith(
      isHiddenByAdmin: false,
      status: nextStatus,
      clearAdminHiddenReason: true,
      clearAdminHiddenAt: true,
      updatedAt: DateTime.now(),
    );

    _posts[idx] = updated;
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<Post> clearPostReportThresholdByAdmin({
    required String postId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) {
      throw Exception('Post not found');
    }

    final current = _posts[idx];

    if (current.isDeleted || current.isRemovedByAdmin) {
      throw Exception('삭제 또는 제거된 게시글은 신고 블라인드를 해제할 수 없습니다.');
    }

    final nextStatus = current.isHiddenByAdmin
        ? PostStatus.hiddenByAdmin
        : PostStatus.active;

    final updated = current.copyWith(
      isReportThresholdReached: false,
      status: nextStatus,
      updatedAt: DateTime.now(),
    );

    _posts[idx] = updated;
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<Post> removePostByAdmin({
    required String postId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) {
      throw Exception('Post not found');
    }

    final current = _posts[idx];

    if (current.isRemovedByAdmin) {
      return current;
    }

    final now = DateTime.now();

    final removedReason =
        current.primaryReportReason?.trim().isNotEmpty == true
            ? current.primaryReportReason!.trim()
            : Post.defaultRemovedReason;

    final updated = current.copyWith(
      status: PostStatus.removedByAdmin,
      isReportThresholdReached: false,
      isHiddenByAdmin: false,
      clearAdminHiddenReason: true,
      clearAdminHiddenAt: true,
      adminRemovedAt: now,
      adminRemovedReason: removedReason,
      updatedAt: now,
      isSold: false,
    );

    _posts[idx] = updated;
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<void> sanctionUserByAdmin({
    required String userId,
    required AdminUserSanctionType sanctionType,
    required String reason,
  }) async {
    await _ensureLoaded();
    return;
  }

  @override
  Future<void> clearUserSanctionByAdmin({
    required String userId,
    required String reason,
  }) async {
    await _ensureLoaded();
    return;
  }

  @override
  Future<List<Comment>> fetchComments(
    String postId, {
    String? cursor,
    int limit = 20,
  }) async {
    await _ensureLoaded();

    final normalizedPostId = postId.trim();

    if (normalizedPostId.isEmpty) {
      return const <Comment>[];
    }

    final safeLimit = limit <= 0 ? 20 : limit;

    final list = List<Comment>.from(
      _commentsByPostId[normalizedPostId] ?? const <Comment>[],
    )..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final safeCursor = cursor?.trim();
    var startIndex = 0;

    if (safeCursor != null && safeCursor.isNotEmpty) {
      final idx = list.indexWhere((comment) => comment.id == safeCursor);
      if (idx >= 0) {
        startIndex = idx + 1;
      }
    }

    return list.skip(startIndex).take(safeLimit).toList(growable: false);
  }

  @override
  Future<Comment> addComment({
    required String postId,
    required String text,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) {
      throw Exception('Post not found');
    }

    final post = _posts[idx];

    if (post.isDeleted || post.isHiddenFromPublic) {
      throw Exception('숨김 처리된 게시글에는 댓글을 작성할 수 없습니다.');
    }

    final author = await _currentAuthorSnapshot(forceRefresh: true);
    final list = _commentsByPostId.putIfAbsent(postId, () => <Comment>[]);
    final now = DateTime.now();

    final comment = Comment(
      id: _id(),
      postId: postId,
      authorId: author.authorId,
      authorLabel: author.authorLabel,
      isOwnerVerified: author.isOwnerVerified,
      industryId: author.industryId,
      locationLabel: author.locationLabel,
      text: text,
      parentId: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      status: CommentStatus.active,
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

    list.add(comment);

    _syncPostCommentCount(postId);
    _saveToDiskLater();

    return comment;
  }

  @override
  Future<Comment> addReply({
    required String postId,
    required String parentCommentId,
    required String text,
  }) async {
    await _ensureLoaded();

    final postIdx = _indexOfPost(postId);
    if (postIdx < 0) {
      throw Exception('Post not found');
    }

    final post = _posts[postIdx];

    if (post.isDeleted || post.isHiddenFromPublic) {
      throw Exception('숨김 처리된 게시글에는 답글을 작성할 수 없습니다.');
    }

    final list = _commentsByPostId.putIfAbsent(postId, () => <Comment>[]);
    final parent = list.firstWhereOrNull((c) => c.id == parentCommentId);

    if (parent == null) {
      throw Exception('Parent comment not found');
    }

    if (parent.isDeleted || parent.isHiddenFromPublic) {
      throw Exception('숨김 처리된 댓글에는 답글을 작성할 수 없습니다.');
    }

    final author = await _currentAuthorSnapshot(forceRefresh: true);
    final now = DateTime.now();

    final comment = Comment(
      id: _id(),
      postId: postId,
      parentId: parentCommentId,
      authorId: author.authorId,
      authorLabel: author.authorLabel,
      isOwnerVerified: author.isOwnerVerified,
      industryId: author.industryId,
      locationLabel: author.locationLabel,
      text: text,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      status: CommentStatus.active,
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

    list.add(comment);

    _syncPostCommentCount(postId);
    _saveToDiskLater();

    return comment;
  }

  @override
  Future<Comment> toggleCommentLike({
    required String postId,
    required String commentId,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) {
      throw Exception('Comment not found');
    }

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) {
      throw Exception('Comment not found');
    }

    final current = list[idx];

    if (current.isDeleted || current.isHiddenFromPublic) {
      throw Exception('숨김 처리된 댓글에는 좋아요를 누를 수 없습니다.');
    }

    final liked = Set<String>.from(current.likedUserIds);

    if (liked.contains(_me)) {
      liked.remove(_me);
    } else {
      liked.add(_me);
    }

    final updated = current.copyWith(
      likedUserIds: liked,
      likeCount: liked.length,
      updatedAt: DateTime.now(),
    );

    list[idx] = updated;
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<bool> canDeleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) return false;

    final comment = list.firstWhereOrNull((c) => c.id == commentId);
    if (comment == null) return false;
    if (comment.isDeleted) return false;

    return comment.authorId == _me;
  }

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) {
      throw Exception('Comment not found');
    }

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) {
      throw Exception('Comment not found');
    }

    final current = list[idx];

    if (current.authorId != _me) {
      throw Exception('삭제 권한이 없습니다.');
    }

    if (current.isDeleted) return;

    final now = DateTime.now();

    final updated = current.copyWith(
      text: '삭제된 댓글입니다.',
      isDeleted: true,
      status: CommentStatus.deletedByAuthor,
      deletedAt: now,
      updatedAt: now,
    );

    list[idx] = updated;

    _syncPostCommentCount(postId);
    _saveToDiskLater();
  }

  @override
  Future<void> reportComment({
    required String postId,
    required String commentId,
    required String reason,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) {
      throw Exception('Comment not found');
    }

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) {
      throw Exception('Comment not found');
    }

    final current = list[idx];

    if (current.isDeleted || current.isHiddenFromPublic) {
      throw Exception('이미 숨김 처리된 댓글입니다.');
    }

    if (current.authorId == _me) {
      throw Exception('본인 댓글은 신고할 수 없습니다.');
    }

    if (current.reportedUserIds.contains(_me)) {
      throw Exception('이미 신고한 댓글입니다.');
    }

    final normalizedReason = reason.trim();

    if (normalizedReason.isEmpty) {
      throw Exception('신고 사유를 선택하세요.');
    }

    final reporters = Set<String>.from(current.reportedUserIds)..add(_me);

    final reasons = List<String>.from(current.reportReasons)
      ..add(normalizedReason);

    final reasonCounts = Map<String, int>.from(current.reportReasonCounts);
    reasonCounts[normalizedReason] = (reasonCounts[normalizedReason] ?? 0) + 1;

    final nextCount = current.reportCount + 1;
    final thresholdReached = current.isReportThresholdReached || nextCount >= 3;

    final updated = current.copyWith(
      reportCount: nextCount,
      reportedUserIds: reporters,
      reportReasons: reasons,
      reportReasonCounts: reasonCounts,
      isReportThresholdReached: thresholdReached,
      status:
          thresholdReached ? CommentStatus.hiddenByReport : CommentStatus.active,
      updatedAt: DateTime.now(),
    );

    list[idx] = updated;

    _syncPostCommentCount(postId);
    _saveToDiskLater();
  }

  @override
  Future<Comment> hideCommentByAdmin({
    required String postId,
    required String commentId,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) {
      throw Exception('Comment not found');
    }

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) {
      throw Exception('Comment not found');
    }

    final current = list[idx];

    if (current.isDeleted || current.isRemovedByAdmin) {
      throw Exception('삭제 또는 제거된 댓글은 숨김 처리할 수 없습니다.');
    }

    final hiddenReason = current.primaryReportReason?.trim().isNotEmpty == true
        ? current.primaryReportReason!.trim()
        : Comment.defaultHiddenReason;

    final updated = current.copyWith(
      isHiddenByAdmin: true,
      status: CommentStatus.hiddenByAdmin,
      adminHiddenReason: hiddenReason,
      adminHiddenAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    list[idx] = updated;

    _syncPostCommentCount(postId);
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<Comment> unhideCommentByAdmin({
    required String postId,
    required String commentId,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) {
      throw Exception('Comment not found');
    }

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) {
      throw Exception('Comment not found');
    }

    final current = list[idx];

    if (current.isDeleted || current.isRemovedByAdmin) {
      throw Exception('삭제 또는 제거된 댓글은 숨김 해제할 수 없습니다.');
    }

    final nextStatus = current.isReportThresholdReached
        ? CommentStatus.hiddenByReport
        : CommentStatus.active;

    final updated = current.copyWith(
      isHiddenByAdmin: false,
      status: nextStatus,
      clearAdminHiddenReason: true,
      clearAdminHiddenAt: true,
      updatedAt: DateTime.now(),
    );

    list[idx] = updated;

    _syncPostCommentCount(postId);
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<Comment> clearCommentReportThresholdByAdmin({
    required String postId,
    required String commentId,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) {
      throw Exception('Comment not found');
    }

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) {
      throw Exception('Comment not found');
    }

    final current = list[idx];

    if (current.isDeleted || current.isRemovedByAdmin) {
      throw Exception('삭제 또는 제거된 댓글은 신고 블라인드를 해제할 수 없습니다.');
    }

    final nextStatus = current.isHiddenByAdmin
        ? CommentStatus.hiddenByAdmin
        : CommentStatus.active;

    final updated = current.copyWith(
      isReportThresholdReached: false,
      status: nextStatus,
      updatedAt: DateTime.now(),
    );

    list[idx] = updated;

    _syncPostCommentCount(postId);
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<Comment> removeCommentByAdmin({
    required String postId,
    required String commentId,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) {
      throw Exception('Comment not found');
    }

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) {
      throw Exception('Comment not found');
    }

    final current = list[idx];

    if (current.isRemovedByAdmin) {
      return current;
    }

    final now = DateTime.now();

    final removedReason =
        current.primaryReportReason?.trim().isNotEmpty == true
            ? current.primaryReportReason!.trim()
            : Comment.defaultRemovedReason;

    final updated = current.copyWith(
      status: CommentStatus.removedByAdmin,
      isReportThresholdReached: false,
      isHiddenByAdmin: false,
      clearAdminHiddenReason: true,
      clearAdminHiddenAt: true,
      adminRemovedAt: now,
      adminRemovedReason: removedReason,
      updatedAt: now,
    );

    list[idx] = updated;

    _syncPostCommentCount(postId);
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<Comment> updateComment({
    required String postId,
    required String commentId,
    required String text,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) {
      throw Exception('Comment not found');
    }

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) {
      throw Exception('Comment not found');
    }

    final current = list[idx];

    if (current.authorId != _me) {
      throw Exception('수정 권한이 없습니다.');
    }

    if (current.isDeleted) {
      throw Exception('삭제된 댓글은 수정할 수 없습니다.');
    }

    if (current.isHiddenFromPublic) {
      throw Exception('숨김 처리된 댓글은 수정할 수 없습니다.');
    }

    final updated = current.copyWith(
      text: text,
      updatedAt: DateTime.now(),
    );

    list[idx] = updated;
    _saveToDiskLater();

    return updated;
  }

  @override
  Future<List<Post>> fetchMyPosts() async {
    await _ensureLoaded();

    final list = _posts.where((p) => p.authorId == _me && !p.isDeleted).toList()
      ..sort(_compareLatest);

    return list;
  }

  @override
  Future<List<Comment>> fetchMyComments() async {
    await _ensureLoaded();

    final list = <Comment>[];

    for (final comments in _commentsByPostId.values) {
      list.addAll(
        comments.where((c) => c.authorId == _me && !c.isDeleted),
      );
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return list;
  }
}

class _LocalAuthorSnapshot {
  final String authorId;
  final String authorLabel;
  final bool isOwnerVerified;
  final String? industryId;
  final String? locationLabel;

  const _LocalAuthorSnapshot({
    required this.authorId,
    required this.authorLabel,
    required this.isOwnerVerified,
    required this.industryId,
    required this.locationLabel,
  });

  factory _LocalAuthorSnapshot.fallback(String userId) {
    return _LocalAuthorSnapshot(
      authorId: userId,
      authorLabel: '익명',
      isOwnerVerified: false,
      industryId: null,
      locationLabel: null,
    );
  }
}

class _DecodedCommunityStore {
  final List<Post> posts;
  final Map<String, List<Comment>> commentsByPostId;

  const _DecodedCommunityStore({
    required this.posts,
    required this.commentsByPostId,
  });
}

String _encodeCommunityStoreOnWorker(Map<String, dynamic> payload) {
  return jsonEncode(payload);
}

_DecodedCommunityStore _decodeCommunityStoreOnWorker(String raw) {
  final decoded = jsonDecode(raw);

  if (decoded is! Map) {
    return const _DecodedCommunityStore(
      posts: <Post>[],
      commentsByPostId: <String, List<Comment>>{},
    );
  }

  final json = Map<String, dynamic>.from(decoded);

  final loadedPosts = ((json['posts'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
      .toList(growable: true);

  final commentsByPostId = <String, List<Comment>>{};

  final rawComments = (json['commentsByPostId'] as Map?) ?? const {};
  rawComments.forEach((key, value) {
    final list = ((value as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Comment.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: true)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    commentsByPostId[key.toString()] = list;
  });

  return _DecodedCommunityStore(
    posts: loadedPosts,
    commentsByPostId: commentsByPostId,
  );
}
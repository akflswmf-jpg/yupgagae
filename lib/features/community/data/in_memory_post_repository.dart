import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

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
  }) : currentUserId = currentUserId ?? 'anon_local';

  final _posts = <Post>[];
  final _commentsByPostId = <String, List<Comment>>{};
  final _rand = Random();

  bool _isLoaded = false;
  Future<void>? _loadFuture;

  String get _me => currentUserId;

  @override
  Future<void> warmUp() async {
    await _ensureLoaded();
  }

  Future<void> ensureReady() async {
    await warmUp();
  }

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}${_rand.nextInt(9999)}';

  int _indexOfPost(String postId) => _posts.indexWhere((p) => p.id == postId);

  Future<File> _storeFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/community_store_v1.json');
  }

  Future<void> _saveToDisk() async {
    try {
      final file = await _storeFile();

      final data = {
        'posts': _posts.map((e) => e.toJson()).toList(),
        'commentsByPostId': _commentsByPostId.map(
          (key, value) => MapEntry(
            key,
            value.map((e) => e.toJson()).toList(),
          ),
        ),
      };

      await file.writeAsString(jsonEncode(data));
    } catch (_) {
      // 로컬 저장 실패는 앱 흐름을 막지 않는다.
    }
  }

  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;

    _loadFuture ??= _loadFromDisk();
    await _loadFuture;
  }

  Future<void> _loadFromDisk() async {
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

      final Map<String, dynamic> json =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);

      final loadedPosts = ((json['posts'] as List?) ?? const [])
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      _posts
        ..clear()
        ..addAll(loadedPosts);

      _commentsByPostId.clear();

      final rawComments = (json['commentsByPostId'] as Map?) ?? const {};
      rawComments.forEach((key, value) {
        final list = ((value as List?) ?? const [])
            .map((e) => Comment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        _commentsByPostId[key.toString()] = list;
      });
    } catch (_) {
      _posts.clear();
      _commentsByPostId.clear();
    } finally {
      _isLoaded = true;
    }
  }

  Future<_LocalAuthorSnapshot> _currentAuthorSnapshot() async {
    try {
      final repo = storeProfileRepo;
      if (repo == null) {
        return _LocalAuthorSnapshot.fallback(_me);
      }

      final StoreProfile profile = await repo.fetchProfile();

      final nickname = profile.nickname.trim().isEmpty
          ? '익명'
          : profile.nickname.trim();

      String? industryId;
      final profileIndustry = profile.industry.trim();

      if (profileIndustry.isNotEmpty) {
        for (final item in IndustryCatalog.ordered()) {
          if (item.id == profileIndustry || item.name == profileIndustry) {
            industryId = item.id;
            break;
          }
        }
      }

      return _LocalAuthorSnapshot(
        authorId: _me,
        authorLabel: nickname,
        isOwnerVerified: profile.isOwnerVerified,
        industryId: industryId,
        locationLabel: RegionCatalog.normalize(profile.region),
      );
    } catch (_) {
      return _LocalAuthorSnapshot.fallback(_me);
    }
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

  int _compareLatest(Post a, Post b) {
    return b.createdAt.compareTo(a.createdAt);
  }

  int _compareHot(Post a, Post b) {
    final aScore = (a.likeCount * 3) + (a.commentCount * 2) + a.viewCount;
    final bScore = (b.likeCount * 3) + (b.commentCount * 2) + b.viewCount;

    final scoreCompare = bScore.compareTo(aScore);
    if (scoreCompare != 0) return scoreCompare;

    return _compareLatest(a, b);
  }

  int _compareMostCommented(Post a, Post b) {
    final commentCompare = b.commentCount.compareTo(a.commentCount);
    if (commentCompare != 0) return commentCompare;

    return _compareLatest(a, b);
  }

  List<Post> _visiblePosts() {
    return _posts
        .where((p) => !p.isReportThresholdReached)
        .toList(growable: false);
  }

  void _syncPostCommentCount(String postId) {
    final idx = _indexOfPost(postId);
    if (idx < 0) return;

    final comments = _commentsByPostId[postId] ?? const <Comment>[];
    final visibleCount = comments.where((c) => !c.isDeleted).length;

    _posts[idx] = _posts[idx].copyWith(
      commentCount: visibleCount,
    );
  }

  void _replacePostInMemory(Post updated) {
    final idx = _indexOfPost(updated.id);
    if (idx < 0) return;

    _posts[idx] = updated;
  }

  @override
  Future<List<Post>> fetchHomeTopPosts({int limit = 100}) async {
    await _ensureLoaded();

    final list = _visiblePosts()..sort(_compareLatest);

    return list.take(limit).toList(growable: false);
  }

  @override
  Future<List<Post>> fetchPosts({
    PostSort sort = PostSort.latest,
    BoardType? boardType,
  }) async {
    await _ensureLoaded();

    final list = _applyBoardFilter(
      _visiblePosts(),
      boardType: boardType,
    );

    switch (sort) {
      case PostSort.latest:
        list.sort(_compareLatest);
        break;
      case PostSort.hot:
        list.sort(_compareHot);
        break;
      case PostSort.mostCommented:
        list.sort(_compareMostCommented);
        break;
    }

    return list;
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
    required String title,
    required String body,
    required BoardType boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,
    List<String>? imagePaths,
  }) async {
    await _ensureLoaded();

    final author = await _currentAuthorSnapshot();

    final post = Post(
      id: _id(),
      authorId: author.authorId,
      authorLabel: author.authorLabel,
      isOwnerVerified: author.isOwnerVerified,
      title: title,
      body: body,
      boardType: boardType,
      usedType: boardType == BoardType.used ? usedType : null,
      isSold: false,
      industryId: industryId ?? author.industryId,
      locationLabel: locationLabel ?? author.locationLabel,
      createdAt: DateTime.now(),
      commentCount: 0,
      likeCount: 0,
      viewCount: 0,
      reportCount: 0,
      reportedUserIds: <String>{},
      isReportThresholdReached: false,
      imagePaths: imagePaths ?? const <String>[],
      likedUserIds: <String>{},
    );

    _posts.insert(0, post);
    await _saveToDisk();

    return post;
  }

  @override
  Future<Post> updatePost({
    required String postId,
    required String title,
    required String body,
    UsedPostType? usedType,
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

    final updated = current.copyWith(
      title: title,
      body: body,
      usedType: current.boardType == BoardType.used ? usedType : current.usedType,
      imagePaths: imagePaths ?? current.imagePaths,
    );

    _posts[idx] = updated;
    await _saveToDisk();

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
    final liked = Set<String>.from(current.likedUserIds);

    if (liked.contains(_me)) {
      liked.remove(_me);
    } else {
      liked.add(_me);
    }

    final updated = current.copyWith(
      likedUserIds: liked,
      likeCount: liked.length,
    );

    _posts[idx] = updated;
    await _saveToDisk();

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

    if (current.boardType != BoardType.used) {
      throw Exception('거래 게시글만 판매 상태를 변경할 수 있습니다.');
    }

    final updated = current.copyWith(
      isSold: !current.isSold,
    );

    _posts[idx] = updated;
    await _saveToDisk();

    return updated;
  }

  @override
  Future<void> incrementView(String postId) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) return;

    final current = _posts[idx];

    final updated = current.copyWith(
      viewCount: current.viewCount + 1,
    );

    _posts[idx] = updated;
    await _saveToDisk();
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

    var list = _visiblePosts();

    list = _applyBoardFilter(
      list,
      boardType: boardType,
    );

    list = _applyUsedTypeFilter(
      list,
      usedType: usedType,
    );

    final industry = industryId?.trim();
    if (industry != null && industry.isNotEmpty) {
      list = list.where((p) => p.industryId == industry).toList();
    }

    final location = locationLabel?.trim();
    if (location != null && location.isNotEmpty) {
      list = list.where((p) => p.locationLabel == location).toList();
    }

    final query = searchQuery?.trim() ?? '';
    if (query.isNotEmpty) {
      list = list
          .where((p) => _matchesSearch(p, query, searchField))
          .toList(growable: false);
    }

    list.sort(_compareLatest);

    final safeLimit = limit <= 0 ? 20 : limit;

    var startIndex = 0;
    final safeCursor = cursor?.trim();

    if (safeCursor != null && safeCursor.isNotEmpty) {
      final cursorIndex = list.indexWhere((p) => p.id == safeCursor);
      if (cursorIndex >= 0) {
        startIndex = cursorIndex + 1;
      }
    }

    final endIndex = min(startIndex + safeLimit, list.length);

    final items = startIndex >= list.length
        ? <Post>[]
        : list.sublist(startIndex, endIndex);

    final nextCursor =
        endIndex < list.length && items.isNotEmpty ? items.last.id : null;

    return PostPage(
      items: items,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<bool> canDeletePost({
    required String postId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) return false;

    return _posts[idx].authorId == _me;
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

    _posts.removeAt(idx);
    _commentsByPostId.remove(postId);

    await _saveToDisk();
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

    if (current.authorId == _me) {
      throw Exception('본인 글은 신고할 수 없습니다.');
    }

    if (current.reportedUserIds.contains(_me)) {
      throw Exception('이미 신고한 게시글입니다.');
    }

    if (reason.trim().isEmpty) {
      throw Exception('신고 사유를 선택하세요.');
    }

    final reporters = Set<String>.from(current.reportedUserIds)..add(_me);
    final nextCount = current.reportCount + 1;

    final updated = current.copyWith(
      reportCount: nextCount,
      reportedUserIds: reporters,
      isReportThresholdReached:
          current.isReportThresholdReached || nextCount >= 3,
    );

    _posts[idx] = updated;
    await _saveToDisk();
  }

  @override
  Future<List<Comment>> fetchComments(String postId) async {
    await _ensureLoaded();

    final list = List<Comment>.from(
      _commentsByPostId[postId] ?? const <Comment>[],
    )..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return list;
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

    final author = await _currentAuthorSnapshot();
    final list = _commentsByPostId.putIfAbsent(postId, () => <Comment>[]);

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
      createdAt: DateTime.now(),
      likeCount: 0,
      likedUserIds: <String>{},
      reportCount: 0,
      reportedUserIds: <String>{},
      isReportThresholdReached: false,
      isDeleted: false,
    );

    list.add(comment);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _syncPostCommentCount(postId);
    await _saveToDisk();

    return comment;
  }

  @override
  Future<Comment> addReply({
    required String postId,
    required String parentCommentId,
    required String text,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) {
      throw Exception('Post not found');
    }

    final list = _commentsByPostId.putIfAbsent(postId, () => <Comment>[]);

    final parentExists = list.any((c) => c.id == parentCommentId);
    if (!parentExists) {
      throw Exception('Parent comment not found');
    }

    final author = await _currentAuthorSnapshot();

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
      createdAt: DateTime.now(),
      likeCount: 0,
      likedUserIds: <String>{},
      reportCount: 0,
      reportedUserIds: <String>{},
      isReportThresholdReached: false,
      isDeleted: false,
    );

    list.add(comment);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _syncPostCommentCount(postId);
    await _saveToDisk();

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
    final liked = Set<String>.from(current.likedUserIds);

    if (liked.contains(_me)) {
      liked.remove(_me);
    } else {
      liked.add(_me);
    }

    final updated = current.copyWith(
      likedUserIds: liked,
      likeCount: liked.length,
    );

    list[idx] = updated;
    await _saveToDisk();

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

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) return false;

    return list[idx].authorId == _me;
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

    final updated = current.copyWith(
      text: '삭제된 댓글입니다.',
      isDeleted: true,
    );

    list[idx] = updated;

    _syncPostCommentCount(postId);
    await _saveToDisk();
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

    if (current.authorId == _me) {
      throw Exception('본인 댓글은 신고할 수 없습니다.');
    }

    if (current.reportedUserIds.contains(_me)) {
      throw Exception('이미 신고한 댓글입니다.');
    }

    if (reason.trim().isEmpty) {
      throw Exception('신고 사유를 선택하세요.');
    }

    final reporters = Set<String>.from(current.reportedUserIds)..add(_me);
    final nextCount = current.reportCount + 1;

    final updated = current.copyWith(
      reportCount: nextCount,
      reportedUserIds: reporters,
      isReportThresholdReached:
          current.isReportThresholdReached || nextCount >= 3,
    );

    list[idx] = updated;
    await _saveToDisk();
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

    final updated = current.copyWith(
      text: text,
    );

    list[idx] = updated;
    await _saveToDisk();

    return updated;
  }

  @override
  Future<List<Post>> fetchMyPosts() async {
    await _ensureLoaded();

    final list = _posts.where((p) => p.authorId == _me).toList()
      ..sort(_compareLatest);

    return list;
  }

  @override
  Future<List<Comment>> fetchMyComments() async {
    await _ensureLoaded();

    final list = <Comment>[];

    for (final comments in _commentsByPostId.values) {
      list.addAll(comments.where((c) => c.authorId == _me));
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
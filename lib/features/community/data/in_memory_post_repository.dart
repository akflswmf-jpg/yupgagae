import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_page.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';

class InMemoryPostRepository implements PostRepository {
  final ModerationService? moderation;
  final String currentUserId;

  InMemoryPostRepository({
    this.moderation,
    String? currentUserId,
  }) : currentUserId = currentUserId ?? 'anon_local';

  final _posts = <Post>[];
  final _commentsByPostId = <String, List<Comment>>{};
  final _rand = Random();

  bool _isLoaded = false;
  Future<void>? _loadFuture;

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
    } catch (_) {}
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

      final Map<String, dynamic> json = jsonDecode(raw);

      final loadedPosts = ((json['posts'] as List?) ?? [])
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      _posts
        ..clear()
        ..addAll(loadedPosts);

      _commentsByPostId.clear();
      final rawComments = (json['commentsByPostId'] as Map?) ?? {};
      rawComments.forEach((key, value) {
        final list = (value as List)
            .map((e) => Comment.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _commentsByPostId[key.toString()] = list;
      });
    } catch (_) {
    } finally {
      _isLoaded = true;
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

  void _syncPostCommentCount(String postId) {
    final idx = _indexOfPost(postId);
    if (idx < 0) return;

    final comments = _commentsByPostId[postId] ?? const <Comment>[];
    final activeCount = comments.where((c) => !c.isDeleted).length;

    _posts[idx] = _posts[idx].copyWith(
      commentCount: activeCount,
    );
  }

  @override
  Future<List<Post>> fetchPosts({
    PostSort sort = PostSort.latest,
    BoardType? boardType,
  }) async {
    await _ensureLoaded();

    final list = _applyBoardFilter(
      List<Post>.from(_posts),
      boardType: boardType,
    );

    switch (sort) {
      case PostSort.latest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case PostSort.hot:
        list.sort((a, b) {
          final aScore = (a.likeCount * 3) + (a.commentCount * 4) + a.viewCount;
          final bScore = (b.likeCount * 3) + (b.commentCount * 4) + b.viewCount;
          final byScore = bScore.compareTo(aScore);
          if (byScore != 0) return byScore;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case PostSort.mostCommented:
        list.sort((a, b) {
          final byCount = b.commentCount.compareTo(a.commentCount);
          if (byCount != 0) return byCount;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }

    return list;
  }

  @override
  Future<List<Post>> fetchHomeTopPosts({int limit = 100}) async {
    await _ensureLoaded();

    final list = List<Post>.from(_posts)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return list.take(limit).toList();
  }

  @override
  Future<Post> getPostById(String postId) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx >= 0) return _posts[idx];

    throw Exception('Post not found');
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

    var sorted = _applyBoardFilter(
      List<Post>.from(_posts),
      boardType: boardType,
    );

    sorted = _applyUsedTypeFilter(
      sorted,
      usedType: usedType,
    );

    if (industryId != null && industryId.trim().isNotEmpty) {
      sorted = sorted
          .where((p) => (p.industryId ?? '').trim() == industryId.trim())
          .toList();
    }

    if (locationLabel != null && locationLabel.trim().isNotEmpty) {
      sorted = sorted
          .where((p) => (p.locationLabel ?? '').trim() == locationLabel.trim())
          .toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      sorted = sorted
          .where((p) => _matchesSearch(p, searchQuery, searchField))
          .toList();
    }

    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final start = cursor == null
        ? 0
        : max(0, sorted.indexWhere((p) => p.id == cursor) + 1);

    final items = sorted.skip(start).take(limit).toList();
    final nextCursor = items.length == limit ? items.last.id : null;

    return PostPage(
      items: items,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<Post> createPost({
    required String authorId,
    required String authorLabel,
    required bool isOwnerVerified,
    required String title,
    required String body,
    required BoardType boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,
    List<String>? imagePaths,
  }) async {
    await _ensureLoaded();

    final post = Post(
      id: _id(),
      authorId: authorId,
      authorLabel: authorLabel,
      isOwnerVerified: isOwnerVerified,
      title: title,
      body: body,
      boardType: boardType,
      usedType: boardType == BoardType.used ? usedType : null,
      isSold: false,
      createdAt: DateTime.now(),
      imagePaths: imagePaths ?? const [],
      industryId: industryId,
      locationLabel: locationLabel,
    );

    _posts.insert(0, post);
    _commentsByPostId[post.id] = <Comment>[];

    await _saveToDisk();
    return post;
  }

  @override
  Future<Post> updatePost({
    required String postId,
    required String userId,
    required String title,
    required String body,
    UsedPostType? usedType,
    List<String>? imagePaths,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) throw Exception('Post not found');

    final current = _posts[idx];
    if (current.authorId != userId) {
      throw Exception('수정 권한이 없습니다.');
    }

    final updated = current.copyWith(
      title: title,
      body: body,
      usedType: current.boardType == BoardType.used
          ? (usedType ?? current.usedType)
          : null,
      imagePaths: imagePaths ?? current.imagePaths,
    );

    _posts[idx] = updated;
    await _saveToDisk();
    return updated;
  }

  @override
  Future<Post> toggleLike({
    required String postId,
    required String userId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) throw Exception('Post not found');

    final p = _posts[idx];
    final liked = Set<String>.from(p.likedUserIds);

    if (liked.contains(userId)) {
      liked.remove(userId);
    } else {
      liked.add(userId);
    }

    final updated = p.copyWith(
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
    required String userId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) throw Exception('Post not found');

    final current = _posts[idx];

    if (current.authorId != userId) {
      throw Exception('처리 권한이 없습니다.');
    }

    if (current.boardType != BoardType.used) {
      throw Exception('거래 게시글만 처리할 수 있습니다.');
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
    _posts[idx] = current.copyWith(
      viewCount: current.viewCount + 1,
    );

    await _saveToDisk();
  }

  @override
  Future<bool> canDeletePost({
    required String postId,
    required String userId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) return false;

    return _posts[idx].authorId == userId;
  }

  @override
  Future<void> deletePost({
    required String postId,
    required String userId,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) throw Exception('Post not found');

    final current = _posts[idx];
    if (current.authorId != userId) {
      throw Exception('삭제 권한이 없습니다.');
    }

    _posts.removeAt(idx);
    _commentsByPostId.remove(postId);

    await _saveToDisk();
  }

  @override
  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
  }) async {
    await _ensureLoaded();

    final idx = _indexOfPost(postId);
    if (idx < 0) throw Exception('Post not found');

    final current = _posts[idx];
    if (current.authorId == reporterId) {
      throw Exception('본인 게시글은 신고할 수 없습니다.');
    }
    if (current.reportedUserIds.contains(reporterId)) {
      throw Exception('이미 신고한 게시글입니다.');
    }
    if (reason.trim().isEmpty) {
      throw Exception('신고 사유를 선택하세요.');
    }

    final reporters = Set<String>.from(current.reportedUserIds)..add(reporterId);
    final nextCount = current.reportCount + 1;

    _posts[idx] = current.copyWith(
      reportCount: nextCount,
      reportedUserIds: reporters,
      isReportThresholdReached:
          current.isReportThresholdReached || nextCount >= 3,
    );

    await _saveToDisk();
  }

  @override
  Future<List<Comment>> fetchComments(String postId) async {
    await _ensureLoaded();
    final list = List<Comment>.from(_commentsByPostId[postId] ?? const <Comment>[])
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<Comment> addComment({
    required String postId,
    required String authorId,
    required String authorLabel,
    bool isOwnerVerified = false,
    String? industryId,
    String? locationLabel,
    required String text,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId.putIfAbsent(postId, () => <Comment>[]);

    final c = Comment(
      id: _id(),
      postId: postId,
      authorId: authorId,
      authorLabel: authorLabel,
      isOwnerVerified: isOwnerVerified,
      industryId: industryId,
      locationLabel: locationLabel,
      text: text,
      createdAt: DateTime.now(),
    );

    list.add(c);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _syncPostCommentCount(postId);
    await _saveToDisk();
    return c;
  }

  @override
  Future<Comment> addReply({
    required String postId,
    required String parentCommentId,
    required String authorId,
    required String authorLabel,
    bool isOwnerVerified = false,
    String? industryId,
    String? locationLabel,
    required String text,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId.putIfAbsent(postId, () => <Comment>[]);

    final c = Comment(
      id: _id(),
      postId: postId,
      parentId: parentCommentId,
      authorId: authorId,
      authorLabel: authorLabel,
      isOwnerVerified: isOwnerVerified,
      industryId: industryId,
      locationLabel: locationLabel,
      text: text,
      createdAt: DateTime.now(),
    );

    list.add(c);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _syncPostCommentCount(postId);
    await _saveToDisk();
    return c;
  }

  @override
  Future<Comment> toggleCommentLike({
    required String postId,
    required String commentId,
    required String userId,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) throw Exception('Comment not found');

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) throw Exception('Comment not found');

    final c = list[idx];
    final liked = Set<String>.from(c.likedUserIds);

    if (liked.contains(userId)) {
      liked.remove(userId);
    } else {
      liked.add(userId);
    }

    final updated = c.copyWith(
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
    required String userId,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) return false;

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) return false;

    return list[idx].authorId == userId;
  }

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
    required String userId,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) throw Exception('Comment not found');

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) throw Exception('Comment not found');

    final current = list[idx];
    if (current.authorId != userId) {
      throw Exception('삭제 권한이 없습니다.');
    }

    if (!current.isDeleted) {
      list[idx] = current.copyWith(isDeleted: true);
      _syncPostCommentCount(postId);
      await _saveToDisk();
    }
  }

  @override
  Future<void> reportComment({
    required String postId,
    required String commentId,
    required String reporterId,
    required String reason,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) throw Exception('Comment not found');

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) throw Exception('Comment not found');

    final current = list[idx];
    if (current.authorId == reporterId) {
      throw Exception('본인 댓글은 신고할 수 없습니다.');
    }
    if (current.reportedUserIds.contains(reporterId)) {
      throw Exception('이미 신고한 댓글입니다.');
    }
    if (reason.trim().isEmpty) {
      throw Exception('신고 사유를 선택하세요.');
    }

    final reporters = Set<String>.from(current.reportedUserIds)
      ..add(reporterId);
    final nextCount = current.reportCount + 1;

    list[idx] = current.copyWith(
      reportCount: nextCount,
      reportedUserIds: reporters,
      isReportThresholdReached:
          current.isReportThresholdReached || nextCount >= 3,
    );

    await _saveToDisk();
  }

  @override
  Future<Comment> updateComment({
    required String postId,
    required String commentId,
    required String userId,
    required String text,
  }) async {
    await _ensureLoaded();

    final list = _commentsByPostId[postId];
    if (list == null) throw Exception('Comment not found');

    final idx = list.indexWhere((c) => c.id == commentId);
    if (idx < 0) throw Exception('Comment not found');

    final current = list[idx];
    if (current.authorId != userId) {
      throw Exception('수정 권한이 없습니다.');
    }
    if (current.isDeleted) {
      throw Exception('삭제된 댓글은 수정할 수 없습니다.');
    }

    final updated = current.copyWith(
      text: text.trim(),
    );

    list[idx] = updated;
    await _saveToDisk();
    return updated;
  }

  @override
  Future<List<Post>> fetchMyPosts(String userId) async {
    await _ensureLoaded();

    final normalized = userId.trim();
    if (normalized.isEmpty) return <Post>[];

    final list = _posts
        .where((p) => p.authorId == normalized)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return list;
  }

  @override
  Future<List<Comment>> fetchMyComments(String userId) async {
    await _ensureLoaded();

    final normalized = userId.trim();
    if (normalized.isEmpty) return <Comment>[];

    final allComments = _commentsByPostId.values.expand((e) => e);

    final list = allComments
        .where((c) => c.authorId == normalized && !c.isDeleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return list;
  }
}
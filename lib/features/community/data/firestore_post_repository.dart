import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_page.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/domain/region_catalog.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class FirestorePostRepository implements PostRepository {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final StoreProfileRepository storeProfileRepo;

  FirestorePostRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    required this.storeProfileRepo,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  CollectionReference<Map<String, dynamic>> get _postsCol {
    return firestore.collection('posts');
  }

  CollectionReference<Map<String, dynamic>> get _commentsCol {
    return firestore.collection('comments');
  }


  String get _me {
    final authUser = _currentAuthUserOrNull();
    final authUserId = authUser?.userId.trim();

    if (authUserId != null && authUserId.isNotEmpty) {
      return authUserId;
    }

    return '';
  }

  @override
  Future<void> warmUp() async {
    return;
  }

  Future<void> ensureReady() async {
    await warmUp();
  }

  dynamic _currentAuthUserOrNull() {
    if (!Get.isRegistered<AuthController>()) {
      return null;
    }

    return Get.find<AuthController>().currentUser.value;
  }

  String _requireCurrentUserId() {
    final userId = _me.trim();

    if (userId.isEmpty) {
      throw Exception('濡쒓렇?몄씠 ?꾩슂??湲곕뒫?낅땲??');
    }

    return userId;
  }


  Future<void> _callCommunityFunction({
    required String name,
    required Map<String, dynamic> data,
    required String fallbackMessage,
  }) async {
    try {
      final callable = functions.httpsCallable(name);
      await callable.call(data);
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim();

      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }

      throw Exception(fallbackMessage);
    }
  }

  Future<Comment> _getCommentById(String commentId) async {
    final id = commentId.trim();

    if (id.isEmpty) {
      throw Exception('commentId required');
    }

    final snap = await _commentsCol.doc(id).get();

    if (!snap.exists) {
      throw Exception('Comment not found');
    }

    return _commentFromDoc(snap);
  }

  Future<_FirestoreAuthorSnapshot> _currentAuthorSnapshot() async {
    final userId = _requireCurrentUserId();

    final authUser = _currentAuthUserOrNull();

    final nickname = authUser?.nickname?.trim();
    final industry = authUser?.industry?.trim();
    final region = authUser?.region?.trim();

    if (nickname != null && nickname.isNotEmpty) {
      return _FirestoreAuthorSnapshot(
        authorId: userId,
        authorLabel: nickname,
        isOwnerVerified: authUser?.isBusinessVerified == true,
        industryId: _industryIdFromRaw(industry),
        locationLabel: RegionCatalog.normalize(region ?? ''),
      );
    }

    try {
      final StoreProfile profile = await storeProfileRepo.fetchProfile();

      final profileNickname =
          profile.nickname.trim().isEmpty ? '?듬챸' : profile.nickname.trim();

      return _FirestoreAuthorSnapshot(
        authorId: userId,
        authorLabel: profileNickname,
        isOwnerVerified: profile.isOwnerVerified,
        industryId: _industryIdFromRaw(profile.industry),
        locationLabel: RegionCatalog.normalize(profile.region),
      );
    } catch (_) {
      return _FirestoreAuthorSnapshot.fallback(userId);
    }
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

  String _nowIso() {
    return DateTime.now().toIso8601String();
  }

  DateTime _now() {
    return DateTime.now();
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

  Post _postFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    if (data == null) {
      throw Exception('Post not found');
    }

    return Post.fromJson({
      ...data,
      'id': (data['id'] ?? doc.id).toString(),
    });
  }

  Comment _commentFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    if (data == null) {
      throw Exception('Comment not found');
    }

    return Comment.fromJson({
      ...data,
      'id': (data['id'] ?? doc.id).toString(),
    });
  }

  Future<Post> _getPostInTransaction(
    Transaction tx,
    String postId,
  ) async {
    final ref = _postsCol.doc(postId);
    final snap = await tx.get(ref);

    if (!snap.exists) {
      throw Exception('Post not found');
    }

    return _postFromDoc(snap);
  }

  Future<Comment> _getCommentInTransaction(
    Transaction tx,
    String commentId,
  ) async {
    final ref = _commentsCol.doc(commentId);
    final snap = await tx.get(ref);

    if (!snap.exists) {
      throw Exception('Comment not found');
    }

    return _commentFromDoc(snap);
  }

  bool _isPublicPost(Post post) {
    return !post.isHiddenFromPublic && !post.isDeleted;
  }

  bool _isReportManagedPost(Post post) {
    return post.reportCount > 0 ||
        post.isReportThresholdReached ||
        post.isHiddenByAdmin ||
        post.isRemovedByAdmin ||
        post.status == PostStatus.hiddenByReport ||
        post.status == PostStatus.hiddenByAdmin ||
        post.status == PostStatus.removedByAdmin;
  }

  bool _isReportManagedComment(Comment comment) {
    return comment.reportCount > 0 ||
        comment.isReportThresholdReached ||
        comment.isHiddenByAdmin ||
        comment.isRemovedByAdmin ||
        comment.status == CommentStatus.hiddenByReport ||
        comment.status == CommentStatus.hiddenByAdmin ||
        comment.status == CommentStatus.removedByAdmin;
  }

  Query<Map<String, dynamic>> _activePostsBaseQuery() {
  return _postsCol
      .where('status', isEqualTo: PostStatus.active.key)
      .where('deletedAt', isNull: true)
      .where('isHiddenByAdmin', isEqualTo: false)
      .where('isReportThresholdReached', isEqualTo: false)
      .where('adminRemovedAt', isNull: true);
}

  @override
  Future<List<Post>> fetchHomeTopPosts({int limit = 100}) async {
    final safeLimit = limit <= 0 ? 100 : limit;

    final snap = await _activePostsBaseQuery()
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .get();

    return snap.docs.map(_postFromDoc).where(_isPublicPost).toList();
  }

  @override
  Future<List<Post>> fetchPosts({
    PostSort sort = PostSort.latest,
    BoardType? boardType,
  }) async {
    Query<Map<String, dynamic>> query = _activePostsBaseQuery();

    if (boardType != null) {
      query = query.where('boardType', isEqualTo: boardType.key);
    }

    switch (sort) {
      case PostSort.latest:
        query = query.orderBy('createdAt', descending: true);
        break;
      case PostSort.hot:
      case PostSort.mostCommented:
        query = query.orderBy('createdAt', descending: true);
        break;
    }

    final snap = await query.limit(200).get();
    final list = snap.docs.map(_postFromDoc).where(_isPublicPost).toList();

    switch (sort) {
      case PostSort.latest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
    final snap =
        await _postsCol.orderBy('updatedAt', descending: true).limit(500).get();

    final list =
        snap.docs.map(_postFromDoc).where(_isReportManagedPost).toList();

    list.sort((a, b) {
      final priorityCompare =
          _adminPostPriorityScore(b).compareTo(_adminPostPriorityScore(a));
      if (priorityCompare != 0) return priorityCompare;

      final reportCompare = b.reportCount.compareTo(a.reportCount);
      if (reportCompare != 0) return reportCompare;

      return b.updatedAt.compareTo(a.updatedAt);
    });

    return list;
  }

  @override
  Future<List<ReportedCommentItem>> fetchReportedComments() async {
    final snap = await _commentsCol
        .orderBy('updatedAt', descending: true)
        .limit(500)
        .get();

    final comments =
        snap.docs.map(_commentFromDoc).where(_isReportManagedComment).toList();

    final postIds = comments.map((e) => e.postId).toSet();
    final postById = <String, Post>{};

    for (final postId in postIds) {
      try {
        postById[postId] = await getPostById(postId);
      } catch (_) {}
    }

    final items = <ReportedCommentItem>[];

    for (final comment in comments) {
      final post = postById[comment.postId];
      if (post == null) continue;

      items.add(
        ReportedCommentItem(
          post: post,
          comment: comment,
        ),
      );
    }

    items.sort((a, b) {
      final priorityCompare = _adminCommentPriorityScore(b.comment)
          .compareTo(_adminCommentPriorityScore(a.comment));
      if (priorityCompare != 0) return priorityCompare;

      final reportCompare =
          b.comment.reportCount.compareTo(a.comment.reportCount);
      if (reportCompare != 0) return reportCompare;

      return b.comment.updatedAt.compareTo(a.comment.updatedAt);
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
    final id = postId.trim();
    if (id.isEmpty) {
      throw Exception('postId required');
    }

    final snap = await _postsCol.doc(id).get();

    if (!snap.exists) {
      throw Exception('Post not found');
    }

    return _postFromDoc(snap);
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
    final author = await _currentAuthorSnapshot();

    final normalizedPostId = postId?.trim();
    final ref = normalizedPostId == null || normalizedPostId.isEmpty
        ? _postsCol.doc()
        : _postsCol.doc(normalizedPostId);

    final now = _now();

    final post = Post(
      id: ref.id,
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

    await ref.set(post.toJson());

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
    final userId = _requireCurrentUserId();

    final updated = await firestore.runTransaction<Post>((tx) async {
      final current = await _getPostInTransaction(tx, postId);

      if (current.authorId != userId) {
        throw Exception('?섏젙 沅뚰븳???놁뒿?덈떎.');
      }

      if (current.isDeleted) {
        throw Exception('??젣??寃뚯떆湲? ?섏젙?????놁뒿?덈떎.');
      }

      if (current.isHiddenFromPublic) {
        throw Exception('?④? 泥섎━??寃뚯떆湲? ?섏젙?????놁뒿?덈떎.');
      }

      final hasIncomingImages = imageUrls != null || imagePaths != null;

      final next = current.copyWith(
        title: title,
        body: body,
        usedType:
            current.boardType == BoardType.used ? usedType : current.usedType,
        imageUrls: hasIncomingImages
            ? _normalizeImageUrls(
                imageUrls: imageUrls,
                imagePaths: imagePaths,
              )
            : current.imageUrls,
        updatedAt: _now(),
      );

      tx.update(_postsCol.doc(postId), next.toJson());

      return next;
    });

    return updated;
  }

  @override
  Future<Post> toggleLike({
    required String postId,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();

    if (normalizedPostId.isEmpty) {
      throw Exception('게시글 정보를 찾을 수 없습니다.');
    }

    await _callCommunityFunction(
      name: 'togglePostLikeOnServer',
      data: <String, dynamic>{
        'postId': normalizedPostId,
      },
      fallbackMessage: '좋아요 처리에 실패했습니다.',
    );

    return getPostById(normalizedPostId);
  }
  @override
  Future<Post> toggleSold({
    required String postId,
  }) async {
    final userId = _requireCurrentUserId();

    return firestore.runTransaction<Post>((tx) async {
      final current = await _getPostInTransaction(tx, postId);

      if (current.authorId != userId) {
        throw Exception('?먮ℓ ?곹깭 蹂寃?沅뚰븳???놁뒿?덈떎.');
      }

      if (current.isDeleted || current.isHiddenFromPublic) {
        throw Exception('?④? 泥섎━??寃뚯떆湲? ?먮ℓ ?곹깭瑜?蹂寃쏀븷 ???놁뒿?덈떎.');
      }

      if (current.boardType != BoardType.used) {
        throw Exception('嫄곕옒 寃뚯떆湲留??먮ℓ ?곹깭瑜?蹂寃쏀븷 ???덉뒿?덈떎.');
      }

      final next = current.copyWith(
        isSold: !current.isSold,
        updatedAt: _now(),
      );

      tx.update(_postsCol.doc(postId), next.toJson());

      return next;
    });
  }

    @override
  Future<void> incrementView(String postId) async {
    final id = postId.trim();
    if (id.isEmpty) return;

    try {
      final callable = functions.httpsCallable('incrementPostViewOnServer');

      await callable.call<Map<String, dynamic>>(
        <String, dynamic>{
          'postId': id,
        },
      );
    } catch (_) {
      return;
    }
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
    final safeLimit = limit <= 0 ? 20 : limit;

    Query<Map<String, dynamic>> query = _activePostsBaseQuery();

    if (boardType != null) {
      query = query.where('boardType', isEqualTo: boardType.key);
    }

    if (usedType != null) {
      query = query.where('usedType', isEqualTo: usedType.key);
    }

    final industry = industryId?.trim();
    if (industry != null && industry.isNotEmpty) {
      query = query.where('industryId', isEqualTo: industry);
    }

    final location = locationLabel?.trim();
    if (location != null && location.isNotEmpty) {
      query = query.where('locationLabel', isEqualTo: location);
    }

    query = query.orderBy('createdAt', descending: true);

    final safeCursor = cursor?.trim();
    if (safeCursor != null && safeCursor.isNotEmpty) {
      final cursorDoc = await _postsCol.doc(safeCursor).get();
      if (cursorDoc.exists) {
        query = query.startAfterDocument(cursorDoc);
      }
    }

    final snap = await query.limit(safeLimit).get();

    var items = snap.docs.map(_postFromDoc).where(_isPublicPost).toList();

    final queryText = searchQuery?.trim().toLowerCase() ?? '';
    if (queryText.isNotEmpty) {
      items = items.where((post) {
        final title = post.title.toLowerCase();
        final body = post.body.toLowerCase();

        switch (searchField) {
          case PostSearchField.title:
            return title.contains(queryText);
          case PostSearchField.body:
            return body.contains(queryText);
          case PostSearchField.all:
            return title.contains(queryText) || body.contains(queryText);
        }
      }).toList(growable: false);
    }

    final nextCursor = snap.docs.length == safeLimit && snap.docs.isNotEmpty
        ? snap.docs.last.id
        : null;

    return PostPage(
      items: items,
      nextCursor: nextCursor,
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
    final safeLimit = limit <= 0 ? 20 : limit;

    Query<Map<String, dynamic>> query = _activePostsBaseQuery();

    if (boardType != null) {
      query = query.where('boardType', isEqualTo: boardType.key);
    }

    if (usedType != null) {
      query = query.where('usedType', isEqualTo: usedType.key);
    }

    final industry = industryId?.trim();
    if (industry != null && industry.isNotEmpty) {
      query = query.where('industryId', isEqualTo: industry);
    }

    final location = locationLabel?.trim();
    if (location != null && location.isNotEmpty) {
      query = query.where('locationLabel', isEqualTo: location);
    }

    query = query
        .orderBy('likeCount', descending: true)
        .orderBy('createdAt', descending: true);

    final safeCursor = cursor?.trim();
    if (safeCursor != null && safeCursor.isNotEmpty) {
      final cursorDoc = await _postsCol.doc(safeCursor).get();
      if (cursorDoc.exists) {
        query = query.startAfterDocument(cursorDoc);
      }
    }

    final snap = await query.limit(safeLimit).get();

    final items = snap.docs
        .map(_postFromDoc)
        .where(_isPublicPost)
        .toList(growable: false);

    final nextCursor = snap.docs.length == safeLimit && snap.docs.isNotEmpty
        ? snap.docs.last.id
        : null;

    return PostPage(
      items: items,
      nextCursor: nextCursor,
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
    final safeLimit = limit <= 0 ? 20 : limit;

    Query<Map<String, dynamic>> query = _activePostsBaseQuery();

    if (boardType != null) {
      query = query.where('boardType', isEqualTo: boardType.key);
    }

    if (usedType != null) {
      query = query.where('usedType', isEqualTo: usedType.key);
    }

    final industry = industryId?.trim();
    if (industry != null && industry.isNotEmpty) {
      query = query.where('industryId', isEqualTo: industry);
    }

    final location = locationLabel?.trim();
    if (location != null && location.isNotEmpty) {
      query = query.where('locationLabel', isEqualTo: location);
    }

    query = query
        .orderBy('commentCount', descending: true)
        .orderBy('createdAt', descending: true);

    final safeCursor = cursor?.trim();
    if (safeCursor != null && safeCursor.isNotEmpty) {
      final cursorDoc = await _postsCol.doc(safeCursor).get();
      if (cursorDoc.exists) {
        query = query.startAfterDocument(cursorDoc);
      }
    }

    final snap = await query.limit(safeLimit).get();

    final items = snap.docs
        .map(_postFromDoc)
        .where(_isPublicPost)
        .toList(growable: false);

    final nextCursor = snap.docs.length == safeLimit && snap.docs.isNotEmpty
        ? snap.docs.last.id
        : null;

    return PostPage(
      items: items,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<bool> canDeletePost({
    required String postId,
  }) async {
    final userId = _me;
    if (userId.isEmpty) return false;

    try {
      final post = await getPostById(postId);
      if (post.isDeleted) return false;

      return post.authorId == userId;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> deletePost({
    required String postId,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();

    if (normalizedPostId.isEmpty) {
      throw Exception('寃뚯떆湲 ?뺣낫瑜?李얠쓣 ???놁뒿?덈떎.');
    }

    await _callCommunityFunction(
      name: 'deletePostOnServer',
      data: <String, dynamic>{
        'postId': normalizedPostId,
      },
      fallbackMessage: '寃뚯떆湲 ??젣???ㅽ뙣?덉뒿?덈떎.',
    );
  }

  @override
  Future<void> reportPost({
    required String postId,
    required String reason,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();
    final normalizedReason = reason.trim();

    if (normalizedPostId.isEmpty) {
      throw Exception('寃뚯떆湲 ?뺣낫瑜?李얠쓣 ???놁뒿?덈떎.');
    }

    if (normalizedReason.isEmpty) {
      throw Exception('?좉퀬 ?ъ쑀瑜??좏깮?섏꽭??');
    }

    await _callCommunityFunction(
      name: 'reportPost',
      data: <String, dynamic>{
        'postId': normalizedPostId,
        'reason': normalizedReason,
      },
      fallbackMessage: '?좉퀬 泥섎━???ㅽ뙣?덉뒿?덈떎.',
    );
  }

  @override
  Future<Post> hidePostByAdmin({
    required String postId,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();

    if (normalizedPostId.isEmpty) {
      throw Exception('寃뚯떆湲 ?뺣낫瑜?李얠쓣 ???놁뒿?덈떎.');
    }

    await _callCommunityFunction(
      name: 'hidePostByAdminOnServer',
      data: <String, dynamic>{
        'postId': normalizedPostId,
      },
      fallbackMessage: '愿由ъ옄 寃뚯떆湲 ?④? 泥섎━???ㅽ뙣?덉뒿?덈떎.',
    );

    return getPostById(normalizedPostId);
  }

  @override
  Future<Post> unhidePostByAdmin({
    required String postId,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();

    if (normalizedPostId.isEmpty) {
      throw Exception('寃뚯떆湲 ?뺣낫瑜?李얠쓣 ???놁뒿?덈떎.');
    }

    await _callCommunityFunction(
      name: 'unhidePostByAdminOnServer',
      data: <String, dynamic>{
        'postId': normalizedPostId,
      },
      fallbackMessage: '愿由ъ옄 寃뚯떆湲 ?④? ?댁젣???ㅽ뙣?덉뒿?덈떎.',
    );

    return getPostById(normalizedPostId);
  }

  @override
  Future<Post> clearPostReportThresholdByAdmin({
    required String postId,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();

    if (normalizedPostId.isEmpty) {
      throw Exception('寃뚯떆湲 ?뺣낫瑜?李얠쓣 ???놁뒿?덈떎.');
    }

    await _callCommunityFunction(
      name: 'clearPostReportThresholdByAdminOnServer',
      data: <String, dynamic>{
        'postId': normalizedPostId,
      },
      fallbackMessage: '寃뚯떆湲 ?좉퀬 釉붾씪?몃뱶 ?댁젣???ㅽ뙣?덉뒿?덈떎.',
    );

    return getPostById(normalizedPostId);
  }

  @override
  Future<Post> removePostByAdmin({
    required String postId,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();

    if (normalizedPostId.isEmpty) {
      throw Exception('寃뚯떆湲 ?뺣낫瑜?李얠쓣 ???놁뒿?덈떎.');
    }

    await _callCommunityFunction(
      name: 'removePostByAdminOnServer',
      data: <String, dynamic>{
        'postId': normalizedPostId,
      },
      fallbackMessage: '愿由ъ옄 寃뚯떆湲 ?쒓굅???ㅽ뙣?덉뒿?덈떎.',
    );

    return getPostById(normalizedPostId);
  }

  @override
  Future<void> sanctionUserByAdmin({
    required String userId,
    required AdminUserSanctionType sanctionType,
    required String reason,
  }) async {
    _requireCurrentUserId();

    final normalizedUserId = userId.trim();
    final normalizedReason = reason.trim();

    if (normalizedUserId.isEmpty) {
      throw Exception('?쒖옱???ъ슜?먮? 李얠쓣 ???놁뒿?덈떎.');
    }

    if (normalizedReason.isEmpty) {
      throw Exception('?쒖옱 ?ъ쑀瑜??낅젰?섏꽭??');
    }

    await _callCommunityFunction(
      name: 'sanctionUserByAdminOnServer',
      data: <String, dynamic>{
        'userId': normalizedUserId,
        'sanctionType': sanctionType.key,
        'reason': normalizedReason,
      },
      fallbackMessage: '?ъ슜???쒖옱 泥섎━???ㅽ뙣?덉뒿?덈떎.',
    );
  }

  @override
  Future<void> clearUserSanctionByAdmin({
    required String userId,
    required String reason,
  }) async {
    _requireCurrentUserId();

    final normalizedUserId = userId.trim();
    final normalizedReason = reason.trim();

    if (normalizedUserId.isEmpty) {
      throw Exception('?쒖옱 ?댁젣???ъ슜?먮? 李얠쓣 ???놁뒿?덈떎.');
    }

    await _callCommunityFunction(
      name: 'clearUserSanctionByAdminOnServer',
      data: <String, dynamic>{
        'userId': normalizedUserId,
        'reason': normalizedReason.isEmpty ? '愿由ъ옄 ?쒖옱 ?댁젣' : normalizedReason,
      },
      fallbackMessage: '?ъ슜???쒖옱 ?댁젣???ㅽ뙣?덉뒿?덈떎.',
    );
  }

  @override
  Future<List<Comment>> fetchComments(
    String postId, {
    String? cursor,
    int limit = 20,
  }) async {
    final normalizedPostId = postId.trim();

    if (normalizedPostId.isEmpty) {
      return const <Comment>[];
    }

    final safeLimit = limit <= 0 ? 20 : (limit > 50 ? 50 : limit);

    Query<Map<String, dynamic>> query = _commentsCol
    .where('postId', isEqualTo: normalizedPostId)
    .where('status', isEqualTo: CommentStatus.active.key)
    .where('isDeleted', isEqualTo: false)
    .where('deletedAt', isNull: true)
    .where('isHiddenByAdmin', isEqualTo: false)
    .where('isReportThresholdReached', isEqualTo: false)
    .where('adminRemovedAt', isNull: true)
    .orderBy('createdAt')
    .orderBy(FieldPath.documentId);

    final safeCursor = cursor?.trim();
    if (safeCursor != null && safeCursor.isNotEmpty) {
      final cursorDoc = await _commentsCol.doc(safeCursor).get();

      if (cursorDoc.exists) {
        query = query.startAfterDocument(cursorDoc);
      }
    }

    final snap = await query.limit(safeLimit).get();

    return snap.docs.map(_commentFromDoc).toList(growable: false);
  }

  @override
  Future<Comment> addComment({
    required String postId,
    required String text,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();
    final normalizedText = text.trim();

    if (normalizedPostId.isEmpty) {
      throw Exception('게시글 정보를 찾을 수 없습니다.');
    }

    if (normalizedText.isEmpty) {
      throw Exception('댓글 내용을 입력해주세요.');
    }

    final callable = functions.httpsCallable('addCommentOnServer');

    final result = await callable.call<Map<String, dynamic>>(
      <String, dynamic>{
        'postId': normalizedPostId,
        'text': normalizedText,
      },
    );

    final data = Map<String, dynamic>.from(result.data);
    final rawComment = data['comment'];

    if (rawComment is! Map) {
      throw Exception('댓글 작성 결과를 확인할 수 없습니다.');
    }

    return Comment.fromJson(
      Map<String, dynamic>.from(rawComment),
    );
  }

  @override
  Future<Comment> addReply({
    required String postId,
    required String parentCommentId,
    required String text,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();
    final normalizedParentCommentId = parentCommentId.trim();
    final normalizedText = text.trim();

    if (normalizedPostId.isEmpty || normalizedParentCommentId.isEmpty) {
      throw Exception('댓글 정보를 찾을 수 없습니다.');
    }

    if (normalizedText.isEmpty) {
      throw Exception('답글 내용을 입력해주세요.');
    }

    final callable = functions.httpsCallable('addReplyOnServer');

    final result = await callable.call<Map<String, dynamic>>(
      <String, dynamic>{
        'postId': normalizedPostId,
        'parentCommentId': normalizedParentCommentId,
        'text': normalizedText,
      },
    );

    final data = Map<String, dynamic>.from(result.data);
    final rawComment = data['comment'];

    if (rawComment is! Map) {
      throw Exception('답글 작성 결과를 확인할 수 없습니다.');
    }

    return Comment.fromJson(
      Map<String, dynamic>.from(rawComment),
    );
  }
  @override
  Future<Comment> toggleCommentLike({
    required String postId,
    required String commentId,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();
    final normalizedCommentId = commentId.trim();

    if (normalizedPostId.isEmpty || normalizedCommentId.isEmpty) {
      throw Exception('댓글 정보를 찾을 수 없습니다.');
    }

    await _callCommunityFunction(
      name: 'toggleCommentLikeOnServer',
      data: <String, dynamic>{
        'postId': normalizedPostId,
        'commentId': normalizedCommentId,
      },
      fallbackMessage: '좋아요 처리에 실패했습니다.',
    );

    return _getCommentById(normalizedCommentId);
  }
  @override
  Future<bool> canDeleteComment({
    required String postId,
    required String commentId,
  }) async {
    final userId = _me;
    if (userId.isEmpty) return false;

    try {
      final snap = await _commentsCol.doc(commentId).get();
      if (!snap.exists) return false;

      final comment = _commentFromDoc(snap);
      if (comment.postId != postId) return false;
      if (comment.isDeleted) return false;

      return comment.authorId == userId;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();
    final normalizedCommentId = commentId.trim();

    if (normalizedPostId.isEmpty || normalizedCommentId.isEmpty) {
      throw Exception('?볤? ?뺣낫瑜?李얠쓣 ???놁뒿?덈떎.');
    }

    await _callCommunityFunction(
      name: 'deleteCommentOnServer',
      data: <String, dynamic>{
        'postId': normalizedPostId,
        'commentId': normalizedCommentId,
      },
      fallbackMessage: '?볤? ??젣???ㅽ뙣?덉뒿?덈떎.',
    );
  }

  @override
  Future<void> reportComment({
    required String postId,
    required String commentId,
    required String reason,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();
    final normalizedCommentId = commentId.trim();
    final normalizedReason = reason.trim();

    if (normalizedPostId.isEmpty || normalizedCommentId.isEmpty) {
      throw Exception('?볤? ?뺣낫瑜?李얠쓣 ???놁뒿?덈떎.');
    }

    if (normalizedReason.isEmpty) {
      throw Exception('?좉퀬 ?ъ쑀瑜??좏깮?섏꽭??');
    }

    await _callCommunityFunction(
      name: 'reportComment',
      data: <String, dynamic>{
        'postId': normalizedPostId,
        'commentId': normalizedCommentId,
        'reason': normalizedReason,
      },
      fallbackMessage: '?좉퀬 泥섎━???ㅽ뙣?덉뒿?덈떎.',
    );
  }

  @override
  Future<Comment> hideCommentByAdmin({
    required String postId,
    required String commentId,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();
    final normalizedCommentId = commentId.trim();

    if (normalizedPostId.isEmpty || normalizedCommentId.isEmpty) {
      throw Exception('?볤? ?뺣낫瑜?李얠쓣 ???놁뒿?덈떎.');
    }

    await _callCommunityFunction(
      name: 'hideCommentByAdminOnServer',
      data: <String, dynamic>{
        'postId': normalizedPostId,
        'commentId': normalizedCommentId,
      },
      fallbackMessage: '愿由ъ옄 ?볤? ?④? 泥섎━???ㅽ뙣?덉뒿?덈떎.',
    );

    return _getCommentById(normalizedCommentId);
  }

  @override
  Future<Comment> unhideCommentByAdmin({
    required String postId,
    required String commentId,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();
    final normalizedCommentId = commentId.trim();

    if (normalizedPostId.isEmpty || normalizedCommentId.isEmpty) {
      throw Exception('?볤? ?뺣낫瑜?李얠쓣 ???놁뒿?덈떎.');
    }

    await _callCommunityFunction(
      name: 'unhideCommentByAdminOnServer',
      data: <String, dynamic>{
        'postId': normalizedPostId,
        'commentId': normalizedCommentId,
      },
      fallbackMessage: '愿由ъ옄 ?볤? ?④? ?댁젣???ㅽ뙣?덉뒿?덈떎.',
    );

    return _getCommentById(normalizedCommentId);
  }

  @override
  Future<Comment> clearCommentReportThresholdByAdmin({
    required String postId,
    required String commentId,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();
    final normalizedCommentId = commentId.trim();

    if (normalizedPostId.isEmpty || normalizedCommentId.isEmpty) {
      throw Exception('?볤? ?뺣낫瑜?李얠쓣 ???놁뒿?덈떎.');
    }

    await _callCommunityFunction(
      name: 'clearCommentReportThresholdByAdminOnServer',
      data: <String, dynamic>{
        'postId': normalizedPostId,
        'commentId': normalizedCommentId,
      },
      fallbackMessage: '?볤? ?좉퀬 釉붾씪?몃뱶 ?댁젣???ㅽ뙣?덉뒿?덈떎.',
    );

    return _getCommentById(normalizedCommentId);
  }

  @override
  Future<Comment> removeCommentByAdmin({
    required String postId,
    required String commentId,
  }) async {
    _requireCurrentUserId();

    final normalizedPostId = postId.trim();
    final normalizedCommentId = commentId.trim();

    if (normalizedPostId.isEmpty || normalizedCommentId.isEmpty) {
      throw Exception('?볤? ?뺣낫瑜?李얠쓣 ???놁뒿?덈떎.');
    }

    await _callCommunityFunction(
      name: 'removeCommentByAdminOnServer',
      data: <String, dynamic>{
        'postId': normalizedPostId,
        'commentId': normalizedCommentId,
      },
      fallbackMessage: '愿由ъ옄 ?볤? ?쒓굅???ㅽ뙣?덉뒿?덈떎.',
    );

    return _getCommentById(normalizedCommentId);
  }

  @override
  Future<Comment> updateComment({
    required String postId,
    required String commentId,
    required String text,
  }) async {
    final userId = _requireCurrentUserId();

    return firestore.runTransaction<Comment>((tx) async {
      final current = await _getCommentInTransaction(tx, commentId);

      if (current.postId != postId) {
        throw Exception('Comment not found');
      }

      if (current.authorId != userId) {
        throw Exception('?섏젙 沅뚰븳???놁뒿?덈떎.');
      }

      if (current.isDeleted) {
        throw Exception('??젣???볤?? ?섏젙?????놁뒿?덈떎.');
      }

      if (current.isHiddenFromPublic) {
        throw Exception('?④? 泥섎━???볤?? ?섏젙?????놁뒿?덈떎.');
      }

      final next = current.copyWith(
        text: text,
        updatedAt: _now(),
      );

      tx.update(_commentsCol.doc(commentId), next.toJson());

      return next;
    });
  }

  @override
  Future<List<Post>> fetchMyPosts() async {
    final userId = _requireCurrentUserId();

    final snap = await _postsCol
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();

    return snap.docs
        .map(_postFromDoc)
        .where((post) => !post.isDeleted)
        .toList();
  }

  @override
  Future<List<Comment>> fetchMyComments() async {
    final userId = _requireCurrentUserId();

    final snap = await _commentsCol
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(300)
        .get();

    return snap.docs
        .map(_commentFromDoc)
        .where((comment) => !comment.isDeleted)
        .toList();
  }
}

class _FirestoreAuthorSnapshot {
  final String authorId;
  final String authorLabel;
  final bool isOwnerVerified;
  final String? industryId;
  final String? locationLabel;

  const _FirestoreAuthorSnapshot({
    required this.authorId,
    required this.authorLabel,
    required this.isOwnerVerified,
    required this.industryId,
    required this.locationLabel,
  });

  factory _FirestoreAuthorSnapshot.fallback(String userId) {
    return _FirestoreAuthorSnapshot(
      authorId: userId,
      authorLabel: '?듬챸',
      isOwnerVerified: false,
      industryId: null,
      locationLabel: null,
    );
  }
}

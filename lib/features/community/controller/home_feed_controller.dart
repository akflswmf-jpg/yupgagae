import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_page.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class HomeFeedController extends GetxController {
  final PostRepository repo;
  final AnonSessionService anonSessionService;
  final StoreProfileRepository storeProfileRepo;

  HomeFeedController({
    required this.repo,
    required this.anonSessionService,
    required this.storeProfileRepo,
  });

  final hot = <Post>[].obs;
  final mostCommented = <Post>[].obs;
  final ownerHot = <Post>[].obs;
  final latest = <Post>[].obs;
  final usedLatest = <Post>[].obs;
  final ownerLatest = <Post>[].obs;

  final isOwnerVerified = false.obs;

  String? _cursor;
  String? _usedCursor;
  String? _ownerCursor;

  final hasMore = true.obs;
  final hasMoreUsed = true.obs;
  final hasMoreOwner = true.obs;

  final isLoadingTop = false.obs;
  final isLoadingLatest = false.obs;
  final isLoadingUsedLatest = false.obs;
  final isLoadingOwnerLatest = false.obs;
  final isLoadingMore = false.obs;
  final isLoadingMoreUsed = false.obs;
  final isLoadingMoreOwner = false.obs;

  final error = RxnString();

  static const int topLimit = 5;
  static const int latestLimit = 20;

  static const int _topWindowHours = 72;
  static const int _hotLikeWeight = 3;
  static const int _hotCommentWeight = 2;

  String get currentUserId => anonSessionService.anonId;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    error.value = null;

    await Future.wait([
      refreshOwnerVerification(),
      loadTop(),
      refreshLatest(),
      refreshUsedLatest(),
      refreshOwnerLatest(),
    ]);
  }

  Future<void> refreshOwnerVerification() async {
    try {
      final profile = await storeProfileRepo.fetchProfile();
      isOwnerVerified.value = profile.isOwnerVerified;
    } catch (_) {
      isOwnerVerified.value = false;
    }
  }

  Future<void> loadTop() async {
    if (isLoadingTop.value) return;

    isLoadingTop.value = true;
    error.value = null;

    try {
      final allPosts = await repo.fetchHomeTopPosts(limit: 100);
      final recentPosts = _filterRecentPosts(allPosts);

      final recentFreePosts =
          recentPosts.where((p) => p.boardType == BoardType.free).toList();

      final recentOwnerPosts =
          recentPosts.where((p) => p.boardType == BoardType.owner).toList();

      final hotList = List<Post>.from(recentFreePosts)..sort(_compareHotPosts);
      final mostCommentedList = List<Post>.from(recentFreePosts)
        ..sort(_compareMostCommentedPosts);
      final ownerHotList = List<Post>.from(recentOwnerPosts)
        ..sort(_compareHotPosts);

      hot.assignAll(_dedupeById(hotList.take(topLimit).toList()));
      mostCommented.assignAll(
        _dedupeById(mostCommentedList.take(topLimit).toList()),
      );
      ownerHot.assignAll(_dedupeById(ownerHotList.take(topLimit).toList()));

      _debugLoadTop(
        allPosts: allPosts,
        recentFreePosts: recentFreePosts,
        recentOwnerPosts: recentOwnerPosts,
      );
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoadingTop.value = false;
    }
  }

  Future<void> refreshLatest() async {
    if (isLoadingLatest.value) return;

    isLoadingLatest.value = true;
    error.value = null;

    try {
      final page = await repo.fetchLatestPage(
        cursor: null,
        limit: latestLimit,
        boardType: BoardType.free,
      );

      latest.assignAll(_dedupeById(page.items));
      _cursor = page.nextCursor;
      hasMore.value = page.nextCursor != null;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoadingLatest.value = false;
    }
  }

  Future<void> refreshUsedLatest() async {
    if (isLoadingUsedLatest.value) return;

    isLoadingUsedLatest.value = true;
    error.value = null;

    try {
      final page = await repo.fetchLatestPage(
        cursor: null,
        limit: latestLimit,
        boardType: BoardType.used,
      );

      usedLatest.assignAll(_dedupeById(page.items));
      _usedCursor = page.nextCursor;
      hasMoreUsed.value = page.nextCursor != null;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoadingUsedLatest.value = false;
    }
  }

  Future<void> refreshOwnerLatest() async {
    if (isLoadingOwnerLatest.value) return;

    isLoadingOwnerLatest.value = true;
    error.value = null;

    try {
      final page = await repo.fetchLatestPage(
        cursor: null,
        limit: latestLimit,
        boardType: BoardType.owner,
      );

      ownerLatest.assignAll(_dedupeById(page.items));
      _ownerCursor = page.nextCursor;
      hasMoreOwner.value = page.nextCursor != null;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoadingOwnerLatest.value = false;
    }
  }

  Future<void> loadMoreLatest() async {
    if (isLoadingMore.value || !hasMore.value) return;

    isLoadingMore.value = true;
    error.value = null;

    try {
      final page = await repo.fetchLatestPage(
        cursor: _cursor,
        limit: latestLimit,
        boardType: BoardType.free,
      );

      _appendPage(
        target: latest,
        page: page,
        setCursor: (cursor) => _cursor = cursor,
        setHasMore: (value) => hasMore.value = value,
      );
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMoreUsedLatest() async {
    if (isLoadingMoreUsed.value || !hasMoreUsed.value) return;

    isLoadingMoreUsed.value = true;
    error.value = null;

    try {
      final page = await repo.fetchLatestPage(
        cursor: _usedCursor,
        limit: latestLimit,
        boardType: BoardType.used,
      );

      _appendPage(
        target: usedLatest,
        page: page,
        setCursor: (cursor) => _usedCursor = cursor,
        setHasMore: (value) => hasMoreUsed.value = value,
      );
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoadingMoreUsed.value = false;
    }
  }

  Future<void> loadMoreOwnerLatest() async {
    if (isLoadingMoreOwner.value || !hasMoreOwner.value) return;

    isLoadingMoreOwner.value = true;
    error.value = null;

    try {
      final page = await repo.fetchLatestPage(
        cursor: _ownerCursor,
        limit: latestLimit,
        boardType: BoardType.owner,
      );

      _appendPage(
        target: ownerLatest,
        page: page,
        setCursor: (cursor) => _ownerCursor = cursor,
        setHasMore: (value) => hasMoreOwner.value = value,
      );
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoadingMoreOwner.value = false;
    }
  }

  Future<void> toggleLike(Post post) async {
    try {
      final updated = await repo.toggleLike(
        postId: post.id,
      );

      _replacePost(latest, updated);
      _replacePost(usedLatest, updated);
      _replacePost(ownerLatest, updated);
      _replacePost(hot, updated);
      _replacePost(mostCommented, updated);
      _replacePost(ownerHot, updated);

      _resortTopLists();
    } catch (e) {
      error.value = e.toString();
    }
  }

  List<Post> _filterRecentPosts(List<Post> posts) {
    final now = DateTime.now();
    return posts.where((post) {
      final diff = now.difference(post.createdAt);
      return diff.inHours <= _topWindowHours;
    }).toList();
  }

  int _compareHotPosts(Post a, Post b) {
    final aScore =
        (a.likeCount * _hotLikeWeight) + (a.commentCount * _hotCommentWeight);
    final bScore =
        (b.likeCount * _hotLikeWeight) + (b.commentCount * _hotCommentWeight);

    final scoreCompare = bScore.compareTo(aScore);
    if (scoreCompare != 0) return scoreCompare;

    return b.createdAt.compareTo(a.createdAt);
  }

  int _compareMostCommentedPosts(Post a, Post b) {
    final commentCompare = b.commentCount.compareTo(a.commentCount);
    if (commentCompare != 0) return commentCompare;

    return b.createdAt.compareTo(a.createdAt);
  }

  void _appendPage({
    required RxList<Post> target,
    required PostPage page,
    required void Function(String? cursor) setCursor,
    required void Function(bool hasMore) setHasMore,
  }) {
    final merged = <Post>[
      ...target,
      ...page.items,
    ];

    target.assignAll(_dedupeById(merged));
    setCursor(page.nextCursor);
    setHasMore(page.nextCursor != null);
  }

  void _replacePost(RxList<Post> list, Post updated) {
    final index = list.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      list[index] = updated;
    }
  }

  void _resortTopLists() {
    final resortedHot = List<Post>.from(hot)..sort(_compareHotPosts);
    final resortedMostCommented = List<Post>.from(mostCommented)
      ..sort(_compareMostCommentedPosts);
    final resortedOwnerHot = List<Post>.from(ownerHot)..sort(_compareHotPosts);

    hot.assignAll(_dedupeById(resortedHot.take(topLimit).toList()));
    mostCommented.assignAll(
      _dedupeById(resortedMostCommented.take(topLimit).toList()),
    );
    ownerHot.assignAll(_dedupeById(resortedOwnerHot.take(topLimit).toList()));
  }

  List<Post> _dedupeById(List<Post> items) {
    final seen = <String>{};
    final result = <Post>[];

    for (final item in items) {
      if (seen.add(item.id)) {
        result.add(item);
      }
    }

    return result;
  }

  void _debugLoadTop({
    required List<Post> allPosts,
    required List<Post> recentFreePosts,
    required List<Post> recentOwnerPosts,
  }) {
    if (!kDebugMode) return;

    debugPrint('================ HOME loadTop DEBUG ================');
    debugPrint('Total candidate posts: ${allPosts.length}');
    debugPrint('Recent free posts (72h): ${recentFreePosts.length}');
    debugPrint('Recent owner posts (72h): ${recentOwnerPosts.length}');
    debugPrint('Assigned hot count: ${hot.length}');
    debugPrint('Assigned comment count: ${mostCommented.length}');
    debugPrint('Assigned owner hot count: ${ownerHot.length}');
    debugPrint('Assigned used latest count: ${usedLatest.length}');
    debugPrint('Assigned owner latest count: ${ownerLatest.length}');
    debugPrint('====================================================');
  }
}
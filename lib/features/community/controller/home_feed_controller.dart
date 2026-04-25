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
      final ownerHotList =
          List<Post>.from(recentOwnerPosts)..sort(_compareHotPosts);

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
    } catch (e, s) {
      error.value = e.toString();
      debugPrint('HOME loadTop error: $e\n$s');
    } finally {
      isLoadingTop.value = false;
    }
  }

  Future<void> refreshLatest() async {
    isLoadingLatest.value = true;
    error.value = null;

    try {
      _cursor = null;
      hasMore.value = true;

      final PostPage page = await repo.fetchLatestPage(
        cursor: _cursor,
        limit: latestLimit,
      );

      latest.assignAll(_dedupeById(page.items));
      _cursor = page.nextCursor;
      hasMore.value = page.nextCursor != null;
    } catch (e, s) {
      error.value = e.toString();
      debugPrint('HOME refreshLatest error: $e\n$s');
    } finally {
      isLoadingLatest.value = false;
    }
  }

  Future<void> refreshUsedLatest() async {
    isLoadingUsedLatest.value = true;
    error.value = null;

    try {
      _usedCursor = null;
      hasMoreUsed.value = true;

      final PostPage page = await repo.fetchLatestPage(
        cursor: _usedCursor,
        limit: latestLimit,
        boardType: BoardType.used,
      );

      usedLatest.assignAll(_dedupeById(page.items));
      _usedCursor = page.nextCursor;
      hasMoreUsed.value = page.nextCursor != null;
    } catch (e, s) {
      error.value = e.toString();
      debugPrint('HOME refreshUsedLatest error: $e\n$s');
    } finally {
      isLoadingUsedLatest.value = false;
    }
  }

  Future<void> refreshOwnerLatest() async {
    isLoadingOwnerLatest.value = true;
    error.value = null;

    try {
      _ownerCursor = null;
      hasMoreOwner.value = true;

      final PostPage page = await repo.fetchLatestPage(
        cursor: _ownerCursor,
        limit: latestLimit,
        boardType: BoardType.owner,
      );

      ownerLatest.assignAll(_dedupeById(page.items));
      _ownerCursor = page.nextCursor;
      hasMoreOwner.value = page.nextCursor != null;
    } catch (e, s) {
      error.value = e.toString();
      debugPrint('HOME refreshOwnerLatest error: $e\n$s');
    } finally {
      isLoadingOwnerLatest.value = false;
    }
  }

  Future<void> loadMoreLatest() async {
    if (!hasMore.value || isLoadingLatest.value || isLoadingMore.value) return;

    isLoadingMore.value = true;

    try {
      final PostPage page = await repo.fetchLatestPage(
        cursor: _cursor,
        limit: latestLimit,
      );

      if (page.items.isNotEmpty) {
        final merged = <Post>[
          ...latest,
          ...page.items,
        ];
        latest.assignAll(_dedupeById(merged));
      }

      _cursor = page.nextCursor;
      hasMore.value = page.nextCursor != null;
    } catch (e, s) {
      debugPrint('HOME loadMoreLatest error: $e\n$s');
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMoreUsedLatest() async {
    if (!hasMoreUsed.value ||
        isLoadingUsedLatest.value ||
        isLoadingMoreUsed.value) {
      return;
    }

    isLoadingMoreUsed.value = true;

    try {
      final PostPage page = await repo.fetchLatestPage(
        cursor: _usedCursor,
        limit: latestLimit,
        boardType: BoardType.used,
      );

      if (page.items.isNotEmpty) {
        final merged = <Post>[
          ...usedLatest,
          ...page.items,
        ];
        usedLatest.assignAll(_dedupeById(merged));
      }

      _usedCursor = page.nextCursor;
      hasMoreUsed.value = page.nextCursor != null;
    } catch (e, s) {
      debugPrint('HOME loadMoreUsedLatest error: $e\n$s');
    } finally {
      isLoadingMoreUsed.value = false;
    }
  }

  Future<void> loadMoreOwnerLatest() async {
    if (!hasMoreOwner.value ||
        isLoadingOwnerLatest.value ||
        isLoadingMoreOwner.value) {
      return;
    }

    isLoadingMoreOwner.value = true;

    try {
      final PostPage page = await repo.fetchLatestPage(
        cursor: _ownerCursor,
        limit: latestLimit,
        boardType: BoardType.owner,
      );

      if (page.items.isNotEmpty) {
        final merged = <Post>[
          ...ownerLatest,
          ...page.items,
        ];
        ownerLatest.assignAll(_dedupeById(merged));
      }

      _ownerCursor = page.nextCursor;
      hasMoreOwner.value = page.nextCursor != null;
    } catch (e, s) {
      debugPrint('HOME loadMoreOwnerLatest error: $e\n$s');
    } finally {
      isLoadingMoreOwner.value = false;
    }
  }

  Future<void> toggleLike(Post post) async {
    try {
      final updated = await repo.toggleLike(
        postId: post.id,
        userId: currentUserId,
      );

      applyPost(updated);
    } catch (e, s) {
      debugPrint('HOME toggleLike error: $e\n$s');
    }
  }

  void applyPost(Post updated) {
    _replacePostInList(latest, updated);
    _replacePostInList(usedLatest, updated);
    _replacePostInList(ownerLatest, updated);
    _replacePostInList(hot, updated);
    _replacePostInList(mostCommented, updated);
    _replacePostInList(ownerHot, updated);

    _resortTopLists();
  }

  void removePost(String postId) {
    latest.removeWhere((p) => p.id == postId);
    usedLatest.removeWhere((p) => p.id == postId);
    ownerLatest.removeWhere((p) => p.id == postId);
    hot.removeWhere((p) => p.id == postId);
    mostCommented.removeWhere((p) => p.id == postId);
    ownerHot.removeWhere((p) => p.id == postId);
  }

  List<Post> _filterRecentPosts(List<Post> posts) {
    final now = DateTime.now();

    return posts.where((post) {
      final diff = now.difference(post.createdAt);
      return diff.inHours >= 0 && diff.inHours < _topWindowHours;
    }).toList();
  }

  int _compareHotPosts(Post a, Post b) {
    final scoreB = _hotScore(b);
    final scoreA = _hotScore(a);

    if (scoreB != scoreA) return scoreB.compareTo(scoreA);
    if (b.likeCount != a.likeCount) return b.likeCount.compareTo(a.likeCount);
    if (b.commentCount != a.commentCount) {
      return b.commentCount.compareTo(a.commentCount);
    }
    return b.createdAt.compareTo(a.createdAt);
  }

  int _compareMostCommentedPosts(Post a, Post b) {
    if (b.commentCount != a.commentCount) {
      return b.commentCount.compareTo(a.commentCount);
    }
    if (b.likeCount != a.likeCount) return b.likeCount.compareTo(a.likeCount);
    return b.createdAt.compareTo(a.createdAt);
  }

  int _hotScore(Post post) {
    final baseScore =
        (post.likeCount * _hotLikeWeight) +
        (post.commentCount * _hotCommentWeight);

    final age = _ageHours(post.createdAt);
    final penalty = (age / 3).floor();

    return (baseScore - penalty).clamp(0, 99999).toInt();
  }

  int _ageHours(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    return diff.isNegative ? 0 : diff.inHours;
  }

  void _replacePostInList(RxList<Post> list, Post updated) {
    final index = list.indexWhere((item) => item.id == updated.id);
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
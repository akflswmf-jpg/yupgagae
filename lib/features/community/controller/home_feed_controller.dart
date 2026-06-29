import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/core/auth/permission_policy.dart';
import 'package:yupgagae/features/admin/domain/admin_notice.dart';
import 'package:yupgagae/features/admin/domain/admin_notice_repository.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_page.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class HomeFeedController extends GetxController {
  final PostRepository repo;
  final AuthSessionService auth;
  final AuthController authController;
  final StoreProfileRepository storeProfileRepo;
  final AdminNoticeRepository noticeRepo;

  HomeFeedController({
    required this.repo,
    required this.auth,
    required this.authController,
    required this.storeProfileRepo,
    AdminNoticeRepository? noticeRepo,
  }) : noticeRepo = noticeRepo ?? FirebaseAdminNoticeRepository();

  final hot = <Post>[].obs;
  final mostCommented = <Post>[].obs;
  final ownerHot = <Post>[].obs;
  final latest = <Post>[].obs;
  final usedLatest = <Post>[].obs;
  final ownerLatest = <Post>[].obs;

  final latestNotice = Rxn<AdminNotice>();
  final isNoticeLoading = false.obs;
  final noticeError = RxnString();

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

  final hasCompletedInitialLoad = false.obs;
  final isInitialLoading = true.obs;
  final initialLoadCompletedCount = 0.obs;

  Future<void>? _loadAllFuture;
  StreamSubscription<AdminNotice?>? _noticeSubscription;

  DateTime? _lastFullLoadAt;

  late final Worker _ownerVerificationWorker;

  Timer? _authChangeReloadDebounce;

  int _loadGeneration = 0;

  final Set<String> _blockedAuthorIds = <String>{};

  static const int topLimit = 5;
  static const int latestLimit = 20;

  static const int _topWindowHours = 72;
  static const int _hotLikeWeight = 3;
  static const int _hotCommentWeight = 4;

  static const Duration _staleAfter = Duration(seconds: 30);
  static const Duration _feedLoadTimeout = Duration(seconds: 12);
  static const Duration _emptyConfirmRetryDelay = Duration(milliseconds: 1400);

  bool get _canReadFeed {
    return true;
  }

  bool get _hasParticipationUser {
    final user = authController.currentUser.value;
    if (user == null) return false;

    final userId = user.userId.trim();
    if (userId.isEmpty) return false;

    if (user.needsProfileSetup) return false;
    if (user.isWithdrawn) return false;

    return PermissionPolicy.canParticipate(user);
  }

  String get currentUserId {
    final user = authController.currentUser.value;
    if (user == null) return '';

    final userId = user.userId.trim();
    return userId;
  }

  bool get hasAnyContent {
    return hot.isNotEmpty ||
        mostCommented.isNotEmpty ||
        ownerHot.isNotEmpty ||
        latest.isNotEmpty ||
        usedLatest.isNotEmpty ||
        ownerLatest.isNotEmpty;
  }

  bool get isAnyLoading {
    return isLoadingTop.value ||
        isLoadingLatest.value ||
        isLoadingUsedLatest.value ||
        isLoadingOwnerLatest.value ||
        isLoadingMore.value ||
        isLoadingMoreUsed.value ||
        isLoadingMoreOwner.value;
  }

  bool get shouldShowInitialLoading {
    if (hasAnyContent) return false;

    if (isInitialLoading.value) return true;
    if (isAnyLoading) return true;

    // 첫 진입에서 한 번 빈 결과가 나와도 바로 "아직 글이 없습니다"로 확정하지 않는다.
    // 초기 2회 확인 전까지는 로딩으로 유지한다.
    if (!canShowEmptyState) return true;

    return false;
  }

  bool get hasTriedInitialLoad {
    return hasCompletedInitialLoad.value;
  }

  bool get canShowEmptyState {
    return hasCompletedInitialLoad.value &&
        !isInitialLoading.value &&
        !isAnyLoading &&
        initialLoadCompletedCount.value >= 2;
  }

  bool get isStale {
    final last = _lastFullLoadAt;
    if (last == null) return true;

    return DateTime.now().difference(last) >= _staleAfter;
  }

  void _ensureParticipationAllowed() {
    final user = authController.currentUser.value;

    if (!_hasParticipationUser) {
      throw Exception(PermissionPolicy.participationBlockedMessage(user));
    }
  }

  @override
  void onInit() {
    super.onInit();

    refreshOwnerVerification();

    _ownerVerificationWorker = ever(
      authController.currentUser,
      (_) {
        refreshOwnerVerification();
        _handleAuthUserChanged();
      },
    );

    unawaited(_bootstrapInitialFeed());
    _watchLatestNotice();
  }

  @override
  void onClose() {
    _authChangeReloadDebounce?.cancel();
    _noticeSubscription?.cancel();
    _ownerVerificationWorker.dispose();
    _invalidateLoad();
    _loadAllFuture = null;
    super.onClose();
  }

  Future<void> _bootstrapInitialFeed() async {
    hasCompletedInitialLoad.value = false;
    isInitialLoading.value = true;
    initialLoadCompletedCount.value = 0;
    error.value = null;

    await loadAll();

    if (isClosed) return;
    if (hasAnyContent) return;

    await Future<void>.delayed(_emptyConfirmRetryDelay);

    if (isClosed) return;
    if (hasAnyContent) return;

    await _forceReloadAll();
  }

  Future<void> _forceReloadAll() async {
    if (!_canReadFeed) {
      _resetFeedState();
      return;
    }

    _invalidateLoad();

    _loadAllFuture = null;
    _lastFullLoadAt = null;

    if (!hasAnyContent) {
      hasCompletedInitialLoad.value = false;
      isInitialLoading.value = true;
    }

    await loadAll();
  }

  Future<void> loadAll() {
    if (!_canReadFeed) {
      _resetFeedState();
      return Future<void>.value();
    }

    final running = _loadAllFuture;
    if (running != null) {
      return running;
    }

    if (!hasCompletedInitialLoad.value && !hasAnyContent) {
      isInitialLoading.value = true;
    }

    final future = _doLoadAll().whenComplete(() {
      _loadAllFuture = null;
    });

    _loadAllFuture = future;
    return future;
  }

  Future<void> refreshIfStale({
    bool force = false,
  }) async {
    if (!_canReadFeed) {
      _resetFeedState();
      return;
    }

    final running = _loadAllFuture;
    if (running != null) {
      await running.timeout(
        _feedLoadTimeout,
        onTimeout: () async {},
      );

      if (!force && hasAnyContent && !isStale) {
        return;
      }
    }

    if (!force && hasAnyContent && !isStale) {
      return;
    }

    if (force) {
      await _forceReloadAll();
      return;
    }

    await loadAll();
  }

  Future<void> refreshAll() async {
    await refreshIfStale(force: true);
  }

  void _watchLatestNotice() {
    isNoticeLoading.value = true;
    noticeError.value = null;

    _noticeSubscription?.cancel();
    _noticeSubscription = noticeRepo.watchLatestVisibleNotice().listen(
      (notice) {
        latestNotice.value = notice;
        isNoticeLoading.value = false;
        noticeError.value = null;
      },
      onError: (e) {
        isNoticeLoading.value = false;
        noticeError.value = e.toString();
      },
    );
  }

  Future<void> _doLoadAll() async {
    if (!_canReadFeed) {
      _resetFeedState();
      return;
    }

    final generation = ++_loadGeneration;
    final wasInitialLoad = !hasCompletedInitialLoad.value && !hasAnyContent;

    if (wasInitialLoad) {
      isInitialLoading.value = true;
    }

    error.value = null;

    try {
      refreshOwnerVerification();
      await _loadBlockedAuthorIds();

      await Future.wait<void>([
        loadTop(generation: generation),
        refreshLatest(generation: generation),
        refreshUsedLatest(generation: generation),
        refreshOwnerLatest(generation: generation),
      ]).timeout(_feedLoadTimeout);

      if (_isCurrentGeneration(generation) && _canReadFeed) {
        _lastFullLoadAt = DateTime.now();
      }
    } on TimeoutException {
      if (_isCurrentGeneration(generation) && _canReadFeed) {
        error.value = '홈 글을 불러오는 시간이 길어지고 있습니다.';
      }
    } catch (e) {
      if (_isCurrentGeneration(generation) && _canReadFeed) {
        error.value = e.toString();
      }
    } finally {
      if (_isCurrentGeneration(generation) && _canReadFeed) {
        _clearPrimaryLoadingFlags();

        hasCompletedInitialLoad.value = true;
        isInitialLoading.value = false;

        if (!hasAnyContent) {
          initialLoadCompletedCount.value =
              initialLoadCompletedCount.value + 1;
        } else if (initialLoadCompletedCount.value < 2) {
          initialLoadCompletedCount.value = 2;
        }
      }
    }
  }

  Future<void> _loadBlockedAuthorIds() async {
    try {
      final blockedUsers = await storeProfileRepo.getBlockedUsers();

      _blockedAuthorIds
        ..clear()
        ..addAll(
          blockedUsers
              .map((e) => e.userId.trim())
              .where((e) => e.isNotEmpty),
        );
    } catch (_) {
      _blockedAuthorIds.clear();
    }
  }

  void refreshOwnerVerification() {
    isOwnerVerified.value =
        authController.currentUser.value?.isBusinessVerified ?? false;
  }

  Future<void> loadTop({
    int? generation,
  }) async {
    if (isLoadingTop.value) return;

    if (!_canReadFeed) {
      _resetFeedState();
      return;
    }

    final requestGeneration = generation ?? _loadGeneration;

    isLoadingTop.value = true;
    error.value = null;

    try {
      if (generation == null) {
        await _loadBlockedAuthorIds();
      }

      final allPosts = await repo.fetchHomeTopPosts(limit: 100);

      if (!_isCurrentGeneration(requestGeneration) || !_canReadFeed) {
        return;
      }

      final visiblePosts = _filterBlockedPosts(allPosts);
      final recentPosts = _filterRecentPosts(visiblePosts);

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
      if (_isCurrentGeneration(requestGeneration) && _canReadFeed) {
        error.value = e.toString();
      }
    } finally {
      if (_isCurrentGeneration(requestGeneration)) {
        isLoadingTop.value = false;
      }
    }
  }

  Future<void> refreshLatest({
    int? generation,
  }) async {
    if (isLoadingLatest.value) return;

    if (!_canReadFeed) {
      _resetFeedState();
      return;
    }

    final requestGeneration = generation ?? _loadGeneration;

    isLoadingLatest.value = true;
    error.value = null;

    try {
      if (generation == null) {
        await _loadBlockedAuthorIds();
      }

      final page = await repo.fetchLatestPage(
        cursor: null,
        limit: latestLimit,
        boardType: BoardType.free,
      );

      if (!_isCurrentGeneration(requestGeneration) || !_canReadFeed) {
        return;
      }

      latest.assignAll(_dedupeById(_filterBlockedPosts(page.items)));
      _cursor = page.nextCursor;
      hasMore.value = page.nextCursor != null;
    } catch (e) {
      if (_isCurrentGeneration(requestGeneration) && _canReadFeed) {
        error.value = e.toString();
      }
    } finally {
      if (_isCurrentGeneration(requestGeneration)) {
        isLoadingLatest.value = false;
      }
    }
  }

  Future<void> refreshUsedLatest({
    int? generation,
  }) async {
    if (isLoadingUsedLatest.value) return;

    if (!_canReadFeed) {
      _resetFeedState();
      return;
    }

    final requestGeneration = generation ?? _loadGeneration;

    isLoadingUsedLatest.value = true;
    error.value = null;

    try {
      if (generation == null) {
        await _loadBlockedAuthorIds();
      }

      final page = await repo.fetchLatestPage(
        cursor: null,
        limit: latestLimit,
        boardType: BoardType.used,
      );

      if (!_isCurrentGeneration(requestGeneration) || !_canReadFeed) {
        return;
      }

      usedLatest.assignAll(_dedupeById(_filterBlockedPosts(page.items)));
      _usedCursor = page.nextCursor;
      hasMoreUsed.value = page.nextCursor != null;
    } catch (e) {
      if (_isCurrentGeneration(requestGeneration) && _canReadFeed) {
        error.value = e.toString();
      }
    } finally {
      if (_isCurrentGeneration(requestGeneration)) {
        isLoadingUsedLatest.value = false;
      }
    }
  }

  Future<void> refreshOwnerLatest({
    int? generation,
  }) async {
    if (isLoadingOwnerLatest.value) return;

    if (!_canReadFeed) {
      _resetFeedState();
      return;
    }

    final requestGeneration = generation ?? _loadGeneration;

    isLoadingOwnerLatest.value = true;
    error.value = null;

    try {
      if (generation == null) {
        await _loadBlockedAuthorIds();
      }

      final page = await repo.fetchLatestPage(
        cursor: null,
        limit: latestLimit,
        boardType: BoardType.owner,
      );

      if (!_isCurrentGeneration(requestGeneration) || !_canReadFeed) {
        return;
      }

      ownerLatest.assignAll(_dedupeById(_filterBlockedPosts(page.items)));
      _ownerCursor = page.nextCursor;
      hasMoreOwner.value = page.nextCursor != null;
    } catch (e) {
      if (_isCurrentGeneration(requestGeneration) && _canReadFeed) {
        error.value = e.toString();
      }
    } finally {
      if (_isCurrentGeneration(requestGeneration)) {
        isLoadingOwnerLatest.value = false;
      }
    }
  }

  Future<void> loadMoreLatest() async {
    if (!_canReadFeed) {
      _resetFeedState();
      return;
    }

    if (isLoadingMore.value || !hasMore.value) return;

    isLoadingMore.value = true;
    error.value = null;

    final requestGeneration = _loadGeneration;

    try {
      final page = await repo.fetchLatestPage(
        cursor: _cursor,
        limit: latestLimit,
        boardType: BoardType.free,
      );

      if (!_isCurrentGeneration(requestGeneration) || !_canReadFeed) {
        return;
      }

      _appendPage(
        target: latest,
        page: page,
        setCursor: (cursor) => _cursor = cursor,
        setHasMore: (value) => hasMore.value = value,
      );
    } catch (e) {
      if (_isCurrentGeneration(requestGeneration) && _canReadFeed) {
        error.value = e.toString();
      }
    } finally {
      if (_isCurrentGeneration(requestGeneration)) {
        isLoadingMore.value = false;
      }
    }
  }

  Future<void> loadMoreUsedLatest() async {
    if (!_canReadFeed) {
      _resetFeedState();
      return;
    }

    if (isLoadingMoreUsed.value || !hasMoreUsed.value) return;

    isLoadingMoreUsed.value = true;
    error.value = null;

    final requestGeneration = _loadGeneration;

    try {
      final page = await repo.fetchLatestPage(
        cursor: _usedCursor,
        limit: latestLimit,
        boardType: BoardType.used,
      );

      if (!_isCurrentGeneration(requestGeneration) || !_canReadFeed) {
        return;
      }

      _appendPage(
        target: usedLatest,
        page: page,
        setCursor: (cursor) => _usedCursor = cursor,
        setHasMore: (value) => hasMoreUsed.value = value,
      );
    } catch (e) {
      if (_isCurrentGeneration(requestGeneration) && _canReadFeed) {
        error.value = e.toString();
      }
    } finally {
      if (_isCurrentGeneration(requestGeneration)) {
        isLoadingMoreUsed.value = false;
      }
    }
  }

  Future<void> loadMoreOwnerLatest() async {
    if (!_canReadFeed) {
      _resetFeedState();
      return;
    }

    if (isLoadingMoreOwner.value || !hasMoreOwner.value) return;

    isLoadingMoreOwner.value = true;
    error.value = null;

    final requestGeneration = _loadGeneration;

    try {
      final page = await repo.fetchLatestPage(
        cursor: _ownerCursor,
        limit: latestLimit,
        boardType: BoardType.owner,
      );

      if (!_isCurrentGeneration(requestGeneration) || !_canReadFeed) {
        return;
      }

      _appendPage(
        target: ownerLatest,
        page: page,
        setCursor: (cursor) => _ownerCursor = cursor,
        setHasMore: (value) => hasMoreOwner.value = value,
      );
    } catch (e) {
      if (_isCurrentGeneration(requestGeneration) && _canReadFeed) {
        error.value = e.toString();
      }
    } finally {
      if (_isCurrentGeneration(requestGeneration)) {
        isLoadingMoreOwner.value = false;
      }
    }
  }

  Future<void> toggleLike(Post post) async {
    _ensureParticipationAllowed();

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
      rethrow;
    }
  }

  void _handleAuthUserChanged() {
    refreshOwnerVerification();

    _authChangeReloadDebounce?.cancel();

    _authChangeReloadDebounce = Timer(
      const Duration(milliseconds: 150),
      () {
        if (isClosed) return;

        _blockedAuthorIds.clear();

        if (!hasAnyContent) {
          hasCompletedInitialLoad.value = false;
          isInitialLoading.value = true;
          initialLoadCompletedCount.value = 0;
        }

        unawaited(refreshIfStale(force: true));
      },
    );
  }

  void _resetFeedState() {
    _loadAllFuture = null;
    _lastFullLoadAt = null;

    hot.clear();
    mostCommented.clear();
    ownerHot.clear();
    latest.clear();
    usedLatest.clear();
    ownerLatest.clear();

    _cursor = null;
    _usedCursor = null;
    _ownerCursor = null;

    _blockedAuthorIds.clear();

    hasMore.value = true;
    hasMoreUsed.value = true;
    hasMoreOwner.value = true;

    _clearAllLoadingFlags();

    error.value = null;

    hasCompletedInitialLoad.value = false;
    isInitialLoading.value = true;
    initialLoadCompletedCount.value = 0;
  }

  void _clearPrimaryLoadingFlags() {
    isLoadingTop.value = false;
    isLoadingLatest.value = false;
    isLoadingUsedLatest.value = false;
    isLoadingOwnerLatest.value = false;
  }

  void _clearMoreLoadingFlags() {
    isLoadingMore.value = false;
    isLoadingMoreUsed.value = false;
    isLoadingMoreOwner.value = false;
  }

  void _clearAllLoadingFlags() {
    _clearPrimaryLoadingFlags();
    _clearMoreLoadingFlags();
  }

  List<Post> _filterRecentPosts(List<Post> posts) {
    final now = DateTime.now();
    return posts.where((post) {
      final diff = now.difference(post.createdAt);
      return diff.inHours <= _topWindowHours;
    }).toList();
  }

  List<Post> _filterBlockedPosts(List<Post> source) {
    if (_blockedAuthorIds.isEmpty) {
      return source;
    }

    return source.where((post) {
      final authorId = post.authorId.trim();
      if (authorId.isEmpty) return true;
      return !_blockedAuthorIds.contains(authorId);
    }).toList(growable: false);
  }

  bool _isBlockedPost(Post post) {
    final authorId = post.authorId.trim();
    if (authorId.isEmpty) return false;
    return _blockedAuthorIds.contains(authorId);
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
      ..._filterBlockedPosts(page.items),
    ];

    target.assignAll(_dedupeById(merged));
    setCursor(page.nextCursor);
    setHasMore(page.nextCursor != null);
  }

  void _replacePost(RxList<Post> list, Post updated) {
    if (_isBlockedPost(updated)) {
      list.removeWhere((p) => p.id == updated.id);
      return;
    }

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
      if (_isBlockedPost(item)) continue;

      if (seen.add(item.id)) {
        result.add(item);
      }
    }

    return result;
  }

  void _invalidateLoad() {
    _loadGeneration++;
  }

  bool _isCurrentGeneration(int generation) {
    return _loadGeneration == generation;
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
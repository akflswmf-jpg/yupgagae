import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/auth/app_user.dart';
import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/core/auth/permission_policy.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_page.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class PostListController extends GetxController {
  final PostRepository repo;
  final AuthSessionService auth;
  final StoreProfileRepository storeProfileRepo;
  final BoardType boardType;

  PostListController({
    required this.repo,
    required this.auth,
    required this.storeProfileRepo,
    this.boardType = BoardType.free,
  });

  final posts = <Post>[].obs;

  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final error = RxnString();

  final selectedSort = PostSort.latest.obs;

  final searchQuery = ''.obs;
  final searchField = PostSearchField.all.obs;
  final searchFieldKey = 'all'.obs;

  final selectedIndustryId = RxnString();
  final selectedIndustryIds = <String>{}.obs;
  final selectedRegionLabel = RxnString();
  final selectedUsedType = Rxn<UsedPostType>();

  String? _cursor;
  bool _feedInitialized = false;
  Timer? _debounce;
  Worker? _authUserWorker;

  int _loadGeneration = 0;
  bool _resetLoadInFlight = false;

  final Set<String> _blockedAuthorIds = <String>{};

  static const int pageSize = 20;

  AppUser? get _currentAuthUser {
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>().currentUser.value;
  }

  // 조회는 누구나 가능.
  // 글쓰기/댓글/좋아요/신고 같은 참여 권한만 PermissionPolicy로 막는다.
  bool get _canReadFeed {
    return true;
  }

  String get currentUserId {
    final user = _currentAuthUser;
    if (user == null) return '';

    final userId = user.userId.trim();
    return userId;
  }

  bool get canParticipate {
    return PermissionPolicy.canParticipate(_currentAuthUser);
  }

  bool get hasInitializedFeed => _feedInitialized;

  List<Post> get visiblePosts {
    return posts.toList(growable: false);
  }

  bool get isQueryTooShort {
    final q = searchQuery.value.trim();
    return q.isNotEmpty && q.length < 2;
  }

  void _ensureParticipationAllowed() {
    final user = _currentAuthUser;

    if (!PermissionPolicy.canTogglePostLike(user)) {
      throw Exception(PermissionPolicy.participationBlockedMessage(user));
    }
  }

  @override
  void onInit() {
    super.onInit();

    ever<PostSearchField>(searchField, (field) {
      searchFieldKey.value = _toKey(field);
    });

    _bindAuthUserWatcher();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _authUserWorker?.dispose();
    _invalidateLoad();
    super.onClose();
  }

  Future<void> ensureFeedInitialized() async {
    if (_feedInitialized) return;
    if (isLoading.value || isLoadingMore.value) return;

    _feedInitialized = true;

    if (!_canReadFeed) {
      _resetFeedState(keepInitialized: true);
      return;
    }

    await initLoad();
  }

  Future<void> initLoad() async {
    _feedInitialized = true;

    if (!_canReadFeed) {
      _resetFeedState(keepInitialized: true);
      return;
    }

    _cursor = null;
    hasMore.value = true;

    await _loadPage(reset: true);
  }

  Future<void> refreshList() async {
    await initLoad();
  }

  Future<void> load({
    PostSort? newSort,
  }) async {
    if (newSort != null) {
      selectedSort.value = newSort;
    }

    await initLoad();
  }

  Future<void> resetSearchStateForFeed() async {
    _debounce?.cancel();
    _invalidateLoad();

    searchQuery.value = '';
    searchField.value = PostSearchField.all;
    searchFieldKey.value = 'all';

    selectedIndustryIds.clear();
    selectedIndustryId.value = null;
    selectedRegionLabel.value = null;
    selectedUsedType.value = null;

    await initLoad();
  }

  Future<void> loadMore() async {
    if (!_canReadFeed) {
      _resetFeedState(keepInitialized: true);
      return;
    }

    if (isLoading.value || isLoadingMore.value) return;
    if (!hasMore.value) return;

    await _loadPage(reset: false);
  }

  Future<void> setSort(PostSort sort) async {
    if (selectedSort.value == sort) return;

    selectedSort.value = sort;
    await initLoad();
  }

  Future<void> setIndustry(String? industryId) async {
    final id = (industryId == null || industryId.trim().isEmpty)
        ? null
        : industryId.trim();

    selectedIndustryId.value = id;

    selectedIndustryIds.clear();
    if (id != null) {
      selectedIndustryIds.add(id);
    }

    await initLoad();
  }

  Future<void> setIndustries(Set<String> ids) async {
    final cleaned = ids.where((e) => e.trim().isNotEmpty).toSet();

    selectedIndustryIds
      ..clear()
      ..addAll(cleaned);

    if (cleaned.length == 1) {
      selectedIndustryId.value = cleaned.first;
    } else {
      selectedIndustryId.value = null;
    }

    await initLoad();
  }

  Future<void> clearIndustries() async {
    selectedIndustryIds.clear();
    selectedIndustryId.value = null;

    await initLoad();
  }

  Future<void> setRegion(String? regionLabel) async {
    final label = (regionLabel == null || regionLabel.trim().isEmpty)
        ? null
        : regionLabel.trim();

    selectedRegionLabel.value = label;

    await initLoad();
  }

  Future<void> clearRegion() async {
    selectedRegionLabel.value = null;

    await initLoad();
  }

  Future<void> setUsedType(UsedPostType? type) async {
    if (selectedUsedType.value == type) return;

    selectedUsedType.value = type;
    await initLoad();
  }

  Future<void> clearUsedType() async {
    if (selectedUsedType.value == null) return;

    selectedUsedType.value = null;
    await initLoad();
  }

  void onSearchChanged(String value) {
    searchQuery.value = value;
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 280), () {
      final q = searchQuery.value.trim();
      if (q.isEmpty || q.length >= 2) {
        unawaited(initLoad());
      }
    });
  }

  Future<void> setSearchField(PostSearchField field) async {
    if (searchField.value == field) return;

    searchField.value = field;
    searchFieldKey.value = _toKey(field);

    if (searchQuery.value.trim().isNotEmpty) {
      await initLoad();
    }
  }

  Future<void> toggleLike(Post post) async {
    _ensureParticipationAllowed();

    final userId = currentUserId;
    if (userId.isEmpty) {
      throw Exception('로그인이 필요한 기능입니다.');
    }

    final index = posts.indexWhere((e) => e.id == post.id);
    if (index < 0) return;

    final before = posts[index];
    final likedUserIds = Set<String>.from(before.likedUserIds);

    if (likedUserIds.contains(userId)) {
      likedUserIds.remove(userId);
    } else {
      likedUserIds.add(userId);
    }

    final optimistic = before.copyWith(
      likedUserIds: likedUserIds,
      likeCount: likedUserIds.length,
    );

    _replacePost(optimistic);

    try {
      final updated = await repo.toggleLike(
        postId: post.id,
      );

      _replacePost(updated);
    } catch (e) {
      _replacePost(before);
      error.value = e.toString();
      rethrow;
    }
  }

  Future<void> toggleLikeOnList(Post post) async {
    await toggleLike(post);
  }

  Future<void> _loadPage({
    required bool reset,
  }) async {
    if (!_canReadFeed) {
      _resetFeedState(keepInitialized: true);
      return;
    }

    if (reset) {
      if (_resetLoadInFlight) return;
      _resetLoadInFlight = true;

      if (posts.isEmpty) {
        isLoading.value = true;
      }
    } else {
      if (isLoadingMore.value) return;
      isLoadingMore.value = true;
    }

    final generation = ++_loadGeneration;
    final requestedSort = selectedSort.value;
    final requestedSearchQuery = _normalizedSearchQuery();
    final requestedIndustryId = _effectiveIndustryId();
    final requestedRegionLabel = selectedRegionLabel.value?.trim();
    final requestedUsedType = _effectiveUsedType();
    final requestedSearchField = searchField.value;
    final requestedCursor = reset ? null : _cursor;

    error.value = null;

    try {
      await _loadBlockedAuthorIds();

      final page = await repo.fetchLatestPage(
        cursor: requestedCursor,
        limit: pageSize,
        searchQuery: requestedSearchQuery,
        boardType: boardType,
        usedType: requestedUsedType,
        industryId: requestedIndustryId,
        locationLabel: requestedRegionLabel,
        searchField: requestedSearchField,
      );

      if (!_isCurrentLoad(
            generation: generation,
            sort: requestedSort,
            searchQuery: requestedSearchQuery,
            industryId: requestedIndustryId,
            regionLabel: requestedRegionLabel,
            usedType: requestedUsedType,
            searchField: requestedSearchField,
          ) ||
          !_canReadFeed) {
        return;
      }

      _applyPage(
        page: page,
        reset: reset,
      );
    } catch (e) {
      if (_loadGeneration == generation && _canReadFeed) {
        error.value = e.toString();
      }
    } finally {
      if (reset) {
        isLoading.value = false;
        _resetLoadInFlight = false;
      } else {
        isLoadingMore.value = false;
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

  void _applyPage({
    required PostPage page,
    required bool reset,
  }) {
    final incoming = _filterBlockedPosts(page.items);

    final next = reset
        ? <Post>[...incoming]
        : <Post>[
            ...posts,
            ...incoming,
          ];

    posts.assignAll(_sortAndDedupe(next));
    _cursor = page.nextCursor;
    hasMore.value = page.nextCursor != null;
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

  List<Post> _sortAndDedupe(List<Post> source) {
    final seen = <String>{};
    final deduped = <Post>[];

    for (final post in source) {
      if (_isBlockedPost(post)) continue;

      if (seen.add(post.id)) {
        deduped.add(post);
      }
    }

    switch (selectedSort.value) {
      case PostSort.latest:
        deduped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case PostSort.hot:
        deduped.sort(_compareHot);
        break;
      case PostSort.mostCommented:
        deduped.sort(_compareMostCommented);
        break;
    }

    return deduped;
  }

  int _compareHot(Post a, Post b) {
    final aScore = (a.likeCount * 3) + (a.commentCount * 2) + a.viewCount;
    final bScore = (b.likeCount * 3) + (b.commentCount * 2) + b.viewCount;

    final scoreCompare = bScore.compareTo(aScore);
    if (scoreCompare != 0) return scoreCompare;

    return b.createdAt.compareTo(a.createdAt);
  }

  int _compareMostCommented(Post a, Post b) {
    final commentCompare = b.commentCount.compareTo(a.commentCount);
    if (commentCompare != 0) return commentCompare;

    return b.createdAt.compareTo(a.createdAt);
  }

  void _replacePost(Post updated) {
    if (_isBlockedPost(updated)) {
      posts.removeWhere((p) => p.id == updated.id);
      return;
    }

    final index = posts.indexWhere((p) => p.id == updated.id);

    if (index >= 0) {
      posts[index] = updated;
      posts.assignAll(_sortAndDedupe(posts));
    }
  }

  String? _normalizedSearchQuery() {
    final q = searchQuery.value.trim();
    if (q.length < 2) return null;
    return q;
  }

  String? _effectiveIndustryId() {
    if (selectedIndustryIds.length == 1) {
      final only = selectedIndustryIds.first.trim();
      return only.isEmpty ? null : only;
    }

    final id = selectedIndustryId.value?.trim();
    if (id == null || id.isEmpty) return null;

    return id;
  }

  UsedPostType? _effectiveUsedType() {
    return selectedUsedType.value;
  }

  void _bindAuthUserWatcher() {
    if (!Get.isRegistered<AuthController>()) return;

    final authController = Get.find<AuthController>();

    _authUserWorker?.dispose();
    _authUserWorker = ever(
      authController.currentUser,
      (_) => _handleAuthUserChanged(),
    );
  }

  void _handleAuthUserChanged() {
    _invalidateLoad();

    isLoading.value = false;
    isLoadingMore.value = false;
    _resetLoadInFlight = false;

    _blockedAuthorIds.clear();

    if (!_canReadFeed) {
      _resetFeedState(keepInitialized: _feedInitialized);
      return;
    }

    if (_feedInitialized) {
      unawaited(initLoad());
    }
  }

  void _resetFeedState({
    required bool keepInitialized,
  }) {
    _debounce?.cancel();

    _cursor = null;
    posts.clear();
    _blockedAuthorIds.clear();

    hasMore.value = true;
    error.value = null;

    isLoading.value = false;
    isLoadingMore.value = false;
    _resetLoadInFlight = false;

    if (!keepInitialized) {
      _feedInitialized = false;
    }
  }

  void _invalidateLoad() {
    _loadGeneration++;
  }

  bool _isCurrentLoad({
    required int generation,
    required PostSort sort,
    required String? searchQuery,
    required String? industryId,
    required String? regionLabel,
    required UsedPostType? usedType,
    required PostSearchField searchField,
  }) {
    return _loadGeneration == generation &&
        selectedSort.value == sort &&
        _normalizedSearchQuery() == searchQuery &&
        _effectiveIndustryId() == industryId &&
        selectedRegionLabel.value?.trim() == regionLabel &&
        _effectiveUsedType() == usedType &&
        this.searchField.value == searchField;
  }

  String _toKey(PostSearchField f) {
    switch (f) {
      case PostSearchField.all:
        return 'all';
      case PostSearchField.title:
        return 'title';
      case PostSearchField.body:
        return 'body';
    }
  }

  PostSearchField _fromKey(String key) {
    switch (key) {
      case 'title':
        return PostSearchField.title;
      case 'body':
        return PostSearchField.body;
      case 'all':
      default:
        return PostSearchField.all;
    }
  }
}
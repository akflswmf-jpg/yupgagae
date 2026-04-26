import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_page.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';

class PostListController extends GetxController {
  final PostRepository repo;
  final AuthSessionService auth;
  final BoardType boardType;

  PostListController({
    required this.repo,
    required this.auth,
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

  int _loadGeneration = 0;

  static const int pageSize = 20;

  String get currentUserId => auth.currentUserId;

  bool get hasInitializedFeed => _feedInitialized;

  List<Post> get visiblePosts {
    return posts.toList(growable: false);
  }

  bool get isQueryTooShort {
    final q = searchQuery.value.trim();
    return q.isNotEmpty && q.length < 2;
  }

  @override
  void onInit() {
    super.onInit();

    ever<PostSearchField>(searchField, (field) {
      searchFieldKey.value = _toKey(field);
    });
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _loadGeneration++;
    super.onClose();
  }

  Future<void> ensureFeedInitialized() async {
    if (_feedInitialized) return;
    if (isLoading.value || isLoadingMore.value) return;

    _feedInitialized = true;
    await initLoad();
  }

  Future<void> initLoad() async {
    _feedInitialized = true;
    _cursor = null;
    hasMore.value = true;
    posts.clear();

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

  Future<void> setRegion(String? label) async {
    final next = (label == null || label.trim().isEmpty)
        ? null
        : label.trim();

    selectedRegionLabel.value = next;

    await initLoad();
  }

  Future<void> clearRegion() async {
    selectedRegionLabel.value = null;

    await initLoad();
  }

  Future<void> setUsedType(UsedPostType? type) async {
    selectedUsedType.value = type;

    await initLoad();
  }

  Future<void> clearUsedType() async {
    selectedUsedType.value = null;

    await initLoad();
  }

  void setSearch(
    String value, {
    PostSearchField? field,
  }) {
    final next = value.trim();

    searchQuery.value = next;
    error.value = null;

    if (field != null) {
      searchField.value = field;
      searchFieldKey.value = _toKey(field);
    }

    _debounce?.cancel();

    if (next.isEmpty || next.length < 2) {
      _invalidateLoad();
      if (next.isEmpty) {
        unawaited(initLoad());
      } else {
        posts.clear();
        _cursor = null;
        hasMore.value = false;
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(initLoad());
    });
  }

  Future<void> submitSearch(
    String value, {
    PostSearchField? field,
  }) async {
    _debounce?.cancel();

    searchQuery.value = value.trim();
    error.value = null;

    if (field != null) {
      searchField.value = field;
      searchFieldKey.value = _toKey(field);
    }

    await initLoad();
  }

  Future<void> clearSearch() async {
    _debounce?.cancel();

    searchQuery.value = '';
    searchField.value = PostSearchField.all;
    searchFieldKey.value = 'all';

    await initLoad();
  }

  Future<void> changeSearchField(PostSearchField field) async {
    if (searchField.value == field) return;

    searchField.value = field;
    searchFieldKey.value = _toKey(field);

    if (searchQuery.value.trim().isNotEmpty) {
      await initLoad();
    }
  }

  Future<void> toggleLikeOnList(Post post) async {
    try {
      final updated = await repo.toggleLike(
        postId: post.id,
      );

      _replacePost(updated);
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> toggleLikeFromList(String postId) async {
    final post = posts.firstWhereOrNull((p) => p.id == postId);
    if (post == null) return;

    await toggleLikeOnList(post);
  }

  Future<void> toggleSoldOnList(Post post) async {
    try {
      final updated = await repo.toggleSold(
        postId: post.id,
      );

      _replacePost(updated);
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> reloadPost(String postId) async {
    try {
      final updated = await repo.getPostById(postId);
      _replacePost(updated);
    } catch (_) {
      await initLoad();
    }
  }

  Future<void> removePostFromList(String postId) async {
    posts.removeWhere((p) => p.id == postId);
  }

  Future<void> _loadPage({
    required bool reset,
  }) async {
    if (reset) {
      if (isLoading.value) return;
    } else {
      if (isLoading.value || isLoadingMore.value) return;
      if (!hasMore.value) return;
    }

    final generation = reset ? ++_loadGeneration : _loadGeneration;

    final requestedCursor = reset ? null : _cursor;
    final requestedSort = selectedSort.value;
    final requestedSearchQuery = _normalizedSearchQuery();
    final requestedIndustryId = _effectiveIndustryId();
    final requestedRegionLabel = selectedRegionLabel.value;
    final requestedUsedType = _effectiveUsedType();
    final requestedSearchField = searchField.value;

    if (reset) {
      isLoading.value = true;
      _cursor = null;
      hasMore.value = true;
    } else {
      isLoadingMore.value = true;
    }

    error.value = null;

    try {
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
      )) {
        return;
      }

      _applyPage(
        page: page,
        reset: reset,
      );
    } catch (e) {
      if (_loadGeneration == generation) {
        error.value = e.toString();
      }
    } finally {
      if (reset) {
        if (_loadGeneration == generation) {
          isLoading.value = false;
        }
      } else {
        isLoadingMore.value = false;
      }
    }
  }

  void _applyPage({
    required PostPage page,
    required bool reset,
  }) {
    final next = reset
        ? <Post>[...page.items]
        : <Post>[
            ...posts,
            ...page.items,
          ];

    posts.assignAll(_sortAndDedupe(next));
    _cursor = page.nextCursor;
    hasMore.value = page.nextCursor != null;
  }

  List<Post> _sortAndDedupe(List<Post> source) {
    final seen = <String>{};
    final deduped = <Post>[];

    for (final post in source) {
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
    final index = posts.indexWhere((p) => p.id == updated.id);

    if (index >= 0) {
      posts[index] = updated;
      posts.assignAll(_sortAndDedupe(posts));
    }
  }

  String? _normalizedSearchQuery() {
    final q = searchQuery.value.trim();

    if (q.isEmpty) return null;
    if (q.length < 2) return null;

    return q;
  }

  String? _effectiveIndustryId() {
    final single = selectedIndustryId.value?.trim();

    if (single != null && single.isNotEmpty) {
      return single;
    }

    if (selectedIndustryIds.length == 1) {
      final only = selectedIndustryIds.first.trim();
      if (only.isNotEmpty) return only;
    }

    return null;
  }

  UsedPostType? _effectiveUsedType() {
    if (boardType != BoardType.used) return null;
    return selectedUsedType.value;
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
        selectedRegionLabel.value == regionLabel &&
        _effectiveUsedType() == usedType &&
        this.searchField.value == searchField;
  }

  String _toKey(PostSearchField field) {
    switch (field) {
      case PostSearchField.all:
        return 'all';
      case PostSearchField.title:
        return 'title';
      case PostSearchField.body:
        return 'body';
    }
  }
}
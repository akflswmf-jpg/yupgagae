import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/domain/post_page.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';

class PostListController extends GetxController {
  final PostRepository repo;
  final AnonSessionService session;
  final BoardType boardType;

  PostListController({
    required this.repo,
    required this.session,
    this.boardType = BoardType.free,
  });

  final posts = <Post>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final error = RxnString();

  final selectedIndustryId = RxnString();
  final selectedIndustryIds = <String>{}.obs;
  final selectedRegionLabel = RxnString();

  final searchQuery = ''.obs;
  final searchField = PostSearchField.all.obs;
  final searchFieldKey = 'all'.obs;

  final selectedUsedType = Rxn<UsedPostType>();

  String? _cursor;
  Timer? _debounce;

  bool _feedInitialized = false;

  String get currentUserId => session.anonId;
  bool get hasInitializedFeed => _feedInitialized;
  bool get isUsedBoard => boardType == BoardType.used;

  List<Post> get visiblePosts {
    final myStore = Get.find<MyStoreController>();
    final blockedIds = myStore.blockedUsers.map((e) => e.userId).toSet();

    Iterable<Post> filtered = posts
        .where((p) => p.boardType == boardType)
        .where((p) => !blockedIds.contains(p.authorId));

    if (isUsedBoard) {
      final usedType = selectedUsedType.value;
      if (usedType != null) {
        filtered = filtered.where((p) => p.usedType == usedType);
      }
    }

    final industries = selectedIndustryIds.toSet();
    if (industries.isNotEmpty) {
      filtered = filtered.where(
        (p) => p.industryId != null && industries.contains(p.industryId),
      );
    }

    final region = selectedRegionLabel.value;
    if (region != null && region.trim().isNotEmpty) {
      filtered = filtered.where((p) => p.locationLabel == region);
    }

    final q = searchQuery.value.trim().toLowerCase();
    if (q.length >= 2) {
      filtered = filtered.where((p) {
        final title = p.title.toLowerCase();
        final body = p.body.toLowerCase();

        switch (searchField.value) {
          case PostSearchField.title:
            return title.contains(q);
          case PostSearchField.body:
            return body.contains(q);
          case PostSearchField.all:
            return title.contains(q) || body.contains(q);
        }
      });
    }

    return filtered.toList();
  }

  bool get isQueryTooShort {
    final q = searchQuery.value.trim();
    return q.isNotEmpty && q.length < 2;
  }

  @override
  void onInit() {
    super.onInit();

    ever<PostSearchField>(searchField, (f) {
      searchFieldKey.value = _toKey(f);
    });
  }

  @override
  void onClose() {
    _debounce?.cancel();
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

  Future<void> resetSearchStateForFeed() async {
    _debounce?.cancel();
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

  Future<void> setIndustry(String? industryId) async {
    final id = (industryId == null || industryId.isEmpty) ? null : industryId;
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
    final next = (label == null || label.trim().isEmpty) ? null : label.trim();
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

  void setSearch(String value, {PostSearchField? field}) {
    final v = value.trim();
    searchQuery.value = v;

    if (field != null) {
      searchField.value = field;
      searchFieldKey.value = _toKey(field);
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (v.isEmpty || v.length >= 2) {
        await initLoad();
      }
    });
  }

  void setSearchKey(String value, {String? fieldKey}) {
    final nextKey = (fieldKey ?? searchFieldKey.value).trim();
    final nextEnum = _fromKey(nextKey);

    searchFieldKey.value = nextKey;
    searchField.value = nextEnum;

    setSearch(value, field: nextEnum);
  }

  void applySearch(String value) {
    setSearchKey(value, fieldKey: searchFieldKey.value);
  }

  void clearSearch() {
    setSearchKey('', fieldKey: searchFieldKey.value);
  }

  String? _effectiveQuery() {
    final q = searchQuery.value.trim();
    if (q.length < 2) return null;
    return q;
  }

  String? _repoIndustryId() {
    final set = selectedIndustryIds;
    if (set.length == 1) {
      return set.first;
    }
    return selectedIndustryId.value;
  }

  Future<void> _loadPage({required bool reset}) async {
    error.value = null;

    if (reset) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      final PostPage page = await repo.fetchLatestPage(
        cursor: _cursor,
        limit: 20,
        searchQuery: _effectiveQuery(),
        boardType: boardType,
        usedType: isUsedBoard ? selectedUsedType.value : null,
        industryId: _repoIndustryId(),
        locationLabel: selectedRegionLabel.value,
        searchField: searchField.value,
      );

      if (reset) {
        posts.value = page.items;
      } else {
        posts.addAll(page.items);
      }

      _cursor = page.nextCursor;
      hasMore.value = page.nextCursor != null;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  void applyPostFromDetail(Post updated) {
    if (updated.boardType != boardType) return;

    final idx = posts.indexWhere((p) => p.id == updated.id);
    if (idx == -1) return;

    final next = List<Post>.from(posts);
    next[idx] = updated;
    posts.value = next;
  }

  Future<void> toggleLikeOnList(Post post) async {
    try {
      final updated = await repo.toggleLike(
        postId: post.id,
        userId: currentUserId,
      );
      applyPostFromDetail(updated);
    } catch (e) {
      error.value = e.toString();
    }
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
import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_page.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/service/search_history_service.dart';

class CommunitySearchController extends GetxController {
  final PostRepository repo;
  final AuthSessionService auth;
  final SearchHistoryService historyService;
  final BoardType boardType;

  CommunitySearchController({
    required this.repo,
    required this.auth,
    required this.historyService,
    this.boardType = BoardType.free,
  });

  final query = ''.obs;

  final searchField = PostSearchField.all.obs;
  final searchFieldKey = 'all'.obs;

  final results = <Post>[].obs;
  final recentKeywords = <String>[].obs;

  final isLoading = false.obs;
  final searchedOnce = false.obs;
  final error = RxnString();

  Timer? _debounce;

  int _searchGeneration = 0;

  String get currentUserId => auth.currentUserId;

  bool get hasQuery => query.value.trim().isNotEmpty;

  bool get isIdle {
    return !isLoading.value &&
        !searchedOnce.value &&
        query.value.trim().isEmpty &&
        results.isEmpty;
  }

  bool get isQueryTooShort {
    final q = query.value.trim();
    return q.isNotEmpty && q.length < 2;
  }

  List<String> get defaultSuggestions {
    if (boardType == BoardType.owner) {
      return const [
        '매출',
        '알바',
        '배달',
        '세금',
        '진상',
        '권리금',
        '상권',
        '인테리어',
      ];
    }

    if (boardType == BoardType.used) {
      return const [
        '가게양도',
        '중고거래',
        '냉장고',
        '커피머신',
        '집기',
        '권리금',
        '양도',
        '폐업',
      ];
    }

    return const [
      '매출',
      '알바',
      '배달',
      '상권',
      '세금',
      '진상',
      '창업',
      '폐업',
    ];
  }

  @override
  void onInit() {
    super.onInit();
    loadRecentKeywords();

    ever<PostSearchField>(searchField, (field) {
      searchFieldKey.value = _toKey(field);
    });
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _searchGeneration++;
    super.onClose();
  }

  Future<void> loadRecentKeywords() async {
    try {
      final list = await historyService.getHistory();
      recentKeywords.assignAll(list);
    } catch (_) {
      recentKeywords.clear();
    }
  }

  Future<void> rememberCurrentQuery() async {
    final q = query.value.trim();
    if (q.isEmpty) return;

    await _saveRecentKeyword(q);
  }

  void setQuery(String value) {
    final q = value.trim();

    query.value = q;
    error.value = null;

    _debounce?.cancel();

    if (q.isEmpty) {
      _invalidateSearch();
      results.clear();
      searchedOnce.value = false;
      isLoading.value = false;
      return;
    }

    if (q.length < 2) {
      _invalidateSearch();
      results.clear();
      searchedOnce.value = false;
      isLoading.value = false;
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_runSearchOnly());
    });
  }

  Future<void> submitQuery(String value) async {
    await submitSearch(value);
  }

  Future<void> submitSearch(String value) async {
    final q = value.trim();

    _debounce?.cancel();
    query.value = q;
    error.value = null;

    if (q.length < 2) {
      _invalidateSearch();
      results.clear();
      searchedOnce.value = false;
      isLoading.value = false;
      return;
    }

    await _saveRecentKeyword(q);
    await _runSearchOnly();
  }

  Future<void> searchNow() async {
    final q = query.value.trim();

    _debounce?.cancel();
    error.value = null;

    if (q.length < 2) {
      _invalidateSearch();
      results.clear();
      searchedOnce.value = false;
      isLoading.value = false;
      return;
    }

    await _saveRecentKeyword(q);
    await _runSearchOnly();
  }

  Future<void> changeSearchField(dynamic field) async {
    final resolved = _fieldFromDynamic(field);

    if (searchField.value == resolved) return;

    searchField.value = resolved;
    searchFieldKey.value = _toKey(resolved);

    final q = query.value.trim();
    if (q.length >= 2) {
      await _runSearchOnly();
    }
  }

  Future<void> setSearchFieldByKey(String key) async {
    await changeSearchField(key);
  }

  Future<void> tapRecentKeyword(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return;

    _debounce?.cancel();

    query.value = q;
    error.value = null;

    await _saveRecentKeyword(q);
    await _runSearchOnly();
  }

  Future<void> tapSuggestion(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return;

    _debounce?.cancel();

    query.value = q;
    error.value = null;

    await _saveRecentKeyword(q);
    await _runSearchOnly();
  }

  Future<void> removeRecentKeyword(String keyword) async {
    recentKeywords.remove(keyword);

    try {
      await historyService.removeKeyword(keyword);
      final list = await historyService.getHistory();
      recentKeywords.assignAll(list);
    } catch (_) {}
  }

  Future<void> clearAllRecentKeywords() async {
    recentKeywords.clear();

    try {
      await historyService.clearAll();
      recentKeywords.clear();
    } catch (_) {}
  }

  void clearQuery() {
    _debounce?.cancel();
    _invalidateSearch();

    query.value = '';
    results.clear();
    error.value = null;
    searchedOnce.value = false;
    isLoading.value = false;
  }

  Future<void> refreshSearch() async {
    final q = query.value.trim();

    if (q.length < 2) {
      _invalidateSearch();
      results.clear();
      searchedOnce.value = false;
      isLoading.value = false;
      return;
    }

    await _runSearchOnly();
  }

  Future<void> _saveRecentKeyword(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return;

    try {
      await historyService.saveKeyword(q);
      final list = await historyService.getHistory();
      recentKeywords.assignAll(list);
    } catch (_) {}
  }

  Future<void> _runSearchOnly() async {
    final q = query.value.trim();
    if (q.length < 2) return;

    final field = searchField.value;
    final generation = ++_searchGeneration;

    isLoading.value = true;
    error.value = null;

    try {
      final PostPage page = await repo.fetchLatestPage(
        cursor: null,
        limit: 30,
        searchQuery: q,
        boardType: boardType,
        industryId: null,
        searchField: field,
      );

      if (!_isCurrentSearch(
        generation: generation,
        queryText: q,
        field: field,
      )) {
        return;
      }

      results.assignAll(_dedupeById(page.items));
      searchedOnce.value = true;
    } catch (e) {
      if (!_isCurrentSearch(
        generation: generation,
        queryText: q,
        field: field,
      )) {
        return;
      }

      error.value = e.toString();
      results.clear();
      searchedOnce.value = true;
    } finally {
      if (_searchGeneration == generation) {
        isLoading.value = false;
      }
    }
  }

  Future<void> toggleLike(Post post) async {
    final index = results.indexWhere((e) => e.id == post.id);
    if (index == -1) return;

    try {
      final updated = await repo.toggleLike(
        postId: post.id,
      );

      final currentIndex = results.indexWhere((e) => e.id == updated.id);
      if (currentIndex == -1) return;

      results[currentIndex] = updated;
    } catch (e) {
      error.value = e.toString();
    }
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

  void _invalidateSearch() {
    _searchGeneration++;
  }

  bool _isCurrentSearch({
    required int generation,
    required String queryText,
    required PostSearchField field,
  }) {
    return _searchGeneration == generation &&
        query.value.trim() == queryText &&
        searchField.value == field;
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

  PostSearchField _fieldFromDynamic(dynamic value) {
    if (value is PostSearchField) {
      return value;
    }

    if (value is String) {
      return _fromKey(value);
    }

    return PostSearchField.all;
  }
}
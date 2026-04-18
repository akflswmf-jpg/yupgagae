import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_page.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/service/search_history_service.dart';

class CommunitySearchController extends GetxController {
  final PostRepository repo;
  final AnonSessionService session;
  final SearchHistoryService historyService;
  final BoardType boardType;

  CommunitySearchController({
    required this.repo,
    required this.session,
    required this.historyService,
    this.boardType = BoardType.free,
  });

  final query = ''.obs;

  final searchField = PostSearchField.all.obs;
  final searchFieldKey = 'all'.obs;

  final results = <Post>[].obs;
  final isLoading = false.obs;
  final error = RxnString();

  final searchedOnce = false.obs;
  final recentKeywords = <String>[].obs;

  Timer? _debounce;

  String get currentUserId => session.anonId;

  List<String> get defaultSuggestions => const [
        '배달',
        '매출',
        '알바',
        '사장님',
        '광고',
        '단골',
        '진상',
        '소통',
        '오픈',
        '폐업',
      ];

  bool get isQueryTooShort {
    final q = query.value.trim();
    return q.isNotEmpty && q.length < 2;
  }

  bool get isIdle {
    return query.value.trim().isEmpty;
  }

  @override
  void onInit() {
    super.onInit();

    ever<PostSearchField>(searchField, (f) {
      searchFieldKey.value = _toKey(f);
    });
  }

  @override
  void onReady() {
    super.onReady();
    _loadHistory();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> _loadHistory() async {
    try {
      final list = await historyService.getHistory();
      recentKeywords.assignAll(list);
    } catch (_) {
      recentKeywords.clear();
    }
  }

  void setQuery(String value) {
    query.value = value;

    final q = value.trim();
    error.value = null;

    if (q.isEmpty) {
      results.clear();
      searchedOnce.value = false;
      _debounce?.cancel();
      return;
    }

    if (q.length < 2) {
      results.clear();
      searchedOnce.value = false;
      _debounce?.cancel();
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      await _runSearchOnly();
    });
  }

  Future<void> submitQuery([String? value]) async {
    if (value != null) {
      query.value = value;
    }

    final q = query.value.trim();
    if (q.isEmpty) {
      clearQuery();
      return;
    }

    if (q.length < 2) {
      results.clear();
      searchedOnce.value = false;
      return;
    }

    await _saveRecentKeyword(q);
    await _runSearchOnly();
  }

  Future<void> rememberCurrentQuery() async {
    final q = query.value.trim();
    if (q.length < 2) return;
    await _saveRecentKeyword(q);
  }

  Future<void> refreshSearch() async {
    final q = query.value.trim();
    if (q.length < 2) return;
    await _runSearchOnly();
  }

  Future<void> changeSearchField(String key) async {
    final next = _fromKey(key);
    searchField.value = next;
    searchFieldKey.value = key;

    final q = query.value.trim();
    if (q.length >= 2) {
      await _runSearchOnly();
    }
  }

  Future<void> tapRecentKeyword(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return;

    query.value = q;
    await _saveRecentKeyword(q);
    await _runSearchOnly();
  }

  Future<void> tapSuggestion(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return;

    query.value = q;
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
    query.value = '';
    results.clear();
    error.value = null;
    searchedOnce.value = false;
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

    isLoading.value = true;
    error.value = null;

    try {
      final PostPage page = await repo.fetchLatestPage(
        cursor: null,
        limit: 30,
        searchQuery: q,
        boardType: boardType,
        industryId: null,
        searchField: searchField.value,
      );

      results.value = page.items;
      searchedOnce.value = true;
    } catch (e) {
      error.value = e.toString();
      results.clear();
      searchedOnce.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleLike(Post post) async {
    try {
      final updated = await repo.toggleLike(
        postId: post.id,
        userId: currentUserId,
      );

      final idx = results.indexWhere((e) => e.id == post.id);
      if (idx == -1) return;

      final next = List<Post>.from(results);
      next[idx] = updated;
      results.value = next;
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
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/community_search_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/view/widgets/post_row.dart';
import 'package:yupgagae/routes/app_routes.dart';

class CommunitySearchScreen extends StatefulWidget {
  const CommunitySearchScreen({super.key});

  @override
  State<CommunitySearchScreen> createState() => _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends State<CommunitySearchScreen> {
  final CommunitySearchController c = Get.find<CommunitySearchController>();
  late final TextEditingController _textC;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    c.clearQuery();

    _textC = TextEditingController();
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textC.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  void _applyKeywordToField(String keyword) {
    _textC.text = keyword;
    _textC.selection = TextSelection.fromPosition(
      TextPosition(offset: _textC.text.length),
    );
  }

  Future<void> _openPostDetail(Post p) async {
    await c.rememberCurrentQuery();
    await Get.toNamed(
      AppRoutes.postDetail,
      arguments: {
        'postId': p.id,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            SearchTopBar(
              controller: _textC,
              focusNode: _focusNode,
              onBack: () => Get.back(),
              onChanged: c.setQuery,
              onSubmitted: (v) => c.submitQuery(v),
              onSearchTap: () => c.submitQuery(_textC.text),
              onClear: () {
                _textC.clear();
                c.clearQuery();
                _focusNode.requestFocus();
              },
            ),
            Obx(() {
              if (c.isIdle) return const SizedBox.shrink();
              return SearchModeTabs(
                selectedKey: c.searchFieldKey.value,
                onChanged: c.changeSearchField,
              );
            }),
            Divider(height: 1, thickness: 1, color: theme.dividerColor),
            Expanded(
              child: Obx(() {
                if (c.isIdle) {
                  return SearchEntryBody(
                    onTapRecent: (keyword) async {
                      _applyKeywordToField(keyword);
                      await c.tapRecentKeyword(keyword);
                    },
                    onRemoveRecent: c.removeRecentKeyword,
                    onClearRecent: c.clearAllRecentKeywords,
                    onTapSuggestion: (keyword) async {
                      _applyKeywordToField(keyword);
                      await c.tapSuggestion(keyword);
                    },
                  );
                }

                if (c.isQueryTooShort) {
                  return const ShortQueryBody();
                }

                if (c.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (c.error.value != null) {
                  return ErrorBody(
                    message: c.error.value!,
                    onRetry: c.refreshSearch,
                  );
                }

                final list = c.results;
                if (list.isEmpty) {
                  return EmptyResultBody(query: c.query.value.trim());
                }

                return RefreshIndicator(
                  onRefresh: c.refreshSearch,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF1F3F5),
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final Post p = list[index];
                      return PostRow(
                        post: p,
                        timeLabel: _timeLabel(p.createdAt),
                        onTap: () => _openPostDetail(p),
                        onLike: () => c.toggleLike(p),
                        liked: p.likedUserIds.contains(c.currentUserId),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchTopBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearchTap;
  final VoidCallback onClear;

  const SearchTopBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onBack,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSearchTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            splashRadius: 20,
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF111111),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;

                return Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEAECEF),
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.search,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111111),
                    ),
                    decoration: InputDecoration(
                      hintText: '검색어를 입력하세요',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF9CA3AF),
                      ),
                      border: InputBorder.none,
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                      suffixIcon: hasText
                          ? IconButton(
                              onPressed: onClear,
                              splashRadius: 18,
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Color(0xFF6B7280),
                              ),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSearchTap,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                '검색',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchModeTabs extends StatelessWidget {
  final String selectedKey;
  final ValueChanged<String> onChanged;

  const SearchModeTabs({
    super.key,
    required this.selectedKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          _ModePill(
            label: '전체',
            selected: selectedKey == 'all',
            onTap: () => onChanged('all'),
          ),
          const SizedBox(width: 8),
          _ModePill(
            label: '제목',
            selected: selectedKey == 'title',
            onTap: () => onChanged('title'),
          ),
          const SizedBox(width: 8),
          _ModePill(
            label: '내용',
            selected: selectedKey == 'body',
            onTap: () => onChanged('body'),
          ),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF111111) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF111111)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }
}

class SearchEntryBody extends StatelessWidget {
  final ValueChanged<String> onTapRecent;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onTapSuggestion;

  const SearchEntryBody({
    super.key,
    required this.onTapRecent,
    required this.onRemoveRecent,
    required this.onClearRecent,
    required this.onTapSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CommunitySearchController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Row(
          children: [
            const Text(
              '최근 검색어',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const Spacer(),
            Obx(() {
              if (c.recentKeywords.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: onClearRecent,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '전체 삭제',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 10),
        Obx(() {
          final recentKeywords = c.recentKeywords.toList();

          if (recentKeywords.isEmpty) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                '최근 검색어가 없습니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: List.generate(recentKeywords.length, (index) {
                final keyword = recentKeywords[index];
                final isLast = index == recentKeywords.length - 1;

                return _RecentKeywordRow(
                  keyword: keyword,
                  onTap: () => onTapRecent(keyword),
                  onDelete: () => onRemoveRecent(keyword),
                  showDivider: !isLast,
                );
              }),
            ),
          );
        }),
        const SizedBox(height: 28),
        const Text(
          '추천 검색어',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: c.defaultSuggestions.map((keyword) {
            return ActionChip(
              label: Text(keyword),
              onPressed: () => onTapSuggestion(keyword),
              backgroundColor: const Color(0xFFF9FAFB),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RecentKeywordRow extends StatelessWidget {
  final String keyword;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool showDivider;

  const _RecentKeywordRow({
    required this.keyword,
    required this.onTap,
    required this.onDelete,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
            child: Row(
              children: [
                const Icon(
                  Icons.history,
                  size: 18,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    keyword,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  splashRadius: 18,
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF1F3F5),
          ),
      ],
    );
  }
}

class ShortQueryBody extends StatelessWidget {
  const ShortQueryBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          '검색어는 2글자 이상 입력해주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

class EmptyResultBody extends StatelessWidget {
  final String query;

  const EmptyResultBody({
    super.key,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 34,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              '\'${query}\' 검색 결과가 없습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '다른 검색어로 다시 시도해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorBody extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const ErrorBody({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 34,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              '검색 중 오류가 발생했습니다.\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
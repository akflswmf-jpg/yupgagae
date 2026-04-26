import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/image/app_image_provider_resolver.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/region_catalog.dart';
import 'package:yupgagae/features/community/view/open_post_detail.dart';
import 'package:yupgagae/features/community/view/widgets/post_row.dart';
import 'package:yupgagae/routes/app_routes.dart';

const Color kCommunityAccent = Color(0xFFA56E5F);
const Color kCommunityAccentDark = Color(0xFF875646);

class FreeBoardFeedScreen extends StatefulWidget {
  final PostListController? controller;

  const FreeBoardFeedScreen({
    super.key,
    this.controller,
  });

  @override
  State<FreeBoardFeedScreen> createState() => _FreeBoardFeedScreenState();
}

class _FreeBoardFeedScreenState extends State<FreeBoardFeedScreen> {
  late final PostListController c;
  final ScrollController _scroll = ScrollController();

  Timer? _initTimer;
  bool _didScheduleInit = false;

  @override
  void initState() {
    super.initState();

    c = widget.controller ?? Get.find<PostListController>();

    if (!c.hasInitializedFeed && !_didScheduleInit) {
      _didScheduleInit = true;
      _initTimer = Timer(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        c.ensureFeedInitialized();
      });
    }

    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      c.loadMore();
    }
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openIndustryMultiSelectSheet() async {
    final items = IndustryCatalog.ordered();
    final temp = Set<String>.from(c.selectedIndustryIds);

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          const Text(
                            '업종 선택',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setModalState(() => temp.clear()),
                            child: const Text('전체'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await c.setIndustries(temp);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text('적용'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final it = items[i];
                          final checked = temp.contains(it.id);

                          return CheckboxListTile(
                            value: checked,
                            onChanged: (v) {
                              setModalState(() {
                                if (v == true) {
                                  temp.add(it.id);
                                } else {
                                  temp.remove(it.id);
                                }
                              });
                            },
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Row(
                              children: [
                                Icon(it.icon, size: 18, color: it.color),
                                const SizedBox(width: 10),
                                Text(
                                  it.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openRegionSheet() async {
    final regions = RegionCatalog.labels;
    final temp = c.selectedRegionLabel.value;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        String? selected = temp;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        const Text(
                          '지역 선택',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setModalState(() => selected = null),
                          child: const Text('전체'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await c.setRegion(selected);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Text('적용'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: regions.length,
                      itemBuilder: (_, i) {
                        final label = regions[i];
                        return RadioListTile<String>(
                          value: label,
                          groupValue: selected,
                          onChanged: (v) {
                            setModalState(() {
                              selected = v;
                            });
                          },
                          title: Text(label),
                          dense: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _goWrite() async {
    final boardKey = c.boardType.key;
    final result = await Get.toNamed('${AppRoutes.writePost}?boardType=$boardKey');
    if (result == true) {
      await c.initLoad();
      if (_scroll.hasClients) {
        await _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _precacheImages(Post post) async {
    if (!mounted || post.imagePaths.isEmpty) return;

    for (final path in post.imagePaths) {
      final provider = AppImageProviderResolver.resolve(
        path,
        resizeWidth: 960,
      );

      if (provider == null) continue;

      try {
        await precacheImage(provider, context);
      } catch (_) {}
    }
  }

  Future<void> _openPostDetail(Post p) async {
    unawaited(Future<void>(() async {
      await _precacheImages(p);
    }));

    final result = await openPostDetail<bool>(p.id);

    if (result == true) {
      await c.initLoad();
    }
  }

  String _selectedIndustryLabel(Set<String> ids) {
    if (ids.isEmpty) return '';
    final list = ids.toList();
    if (list.length == 1) return IndustryCatalog.nameOf(list.first);
    return '${IndustryCatalog.nameOf(list.first)} 외 ${list.length - 1}';
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String _emptyMessage() {
    switch (c.boardType) {
      case BoardType.used:
        return '거래 게시글이 없습니다.';
      case BoardType.owner:
        return '사장님 게시글이 없습니다.';
      case BoardType.free:
        return '게시글이 없습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.boardType == BoardType.used) ...[
                  Obx(() {
                    final selected = c.selectedUsedType.value;

                    return Row(
                      children: [
                        _UsedBoardTab(
                          label: '전체',
                          selected: selected == null,
                          onTap: c.clearUsedType,
                        ),
                        const SizedBox(width: 8),
                        _UsedBoardTab(
                          label: '가게양도',
                          selected: selected == UsedPostType.store,
                          onTap: () => c.setUsedType(UsedPostType.store),
                        ),
                        const SizedBox(width: 8),
                        _UsedBoardTab(
                          label: '중고거래',
                          selected: selected == UsedPostType.item,
                          onTap: () => c.setUsedType(UsedPostType.item),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    _ToolbarFilterButton(
                      label: '업종',
                      onTap: _openIndustryMultiSelectSheet,
                    ),
                    const SizedBox(width: 8),
                    _ToolbarFilterButton(
                      label: '지역',
                      onTap: _openRegionSheet,
                    ),
                    const Spacer(),
                    _ToolbarIconButton(
                      icon: Icons.search,
                      onTap: () => Get.toNamed(
                        '${AppRoutes.communitySearch}?boardType=${c.boardType.key}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Obx(() {
                        final ids = c.selectedIndustryIds;
                        if (ids.isEmpty) return const SizedBox.shrink();

                        final isSingle = ids.length == 1;
                        final singleId = isSingle ? ids.first : null;
                        final item = singleId != null
                            ? IndustryCatalog.byId(singleId)
                            : null;
                        final label = _selectedIndustryLabel(ids);

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _SelectedFilterChip(
                            label: label,
                            leading: isSingle && item != null
                                ? Icon(
                                    item.icon,
                                    size: 15,
                                    color: item.color,
                                  )
                                : null,
                            onTap: _openIndustryMultiSelectSheet,
                            onClear: c.clearIndustries,
                          ),
                        );
                      }),
                      Obx(() {
                        final region = c.selectedRegionLabel.value;
                        if (region == null || region.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return _SelectedFilterChip(
                          label: region,
                          onTap: _openRegionSheet,
                          onClear: c.clearRegion,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F5)),
          Expanded(
            child: Obx(() {
              if (c.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (c.error.value != null) {
                return _FeedErrorBody(message: c.error.value!);
              }

              final list = c.visiblePosts;
              if (list.isEmpty) {
                return _FeedEmptyBody(
                  message: _emptyMessage(),
                );
              }

              return RefreshIndicator(
                onRefresh: c.initLoad,
                child: ListView.separated(
                  controller: _scroll,
                  physics: const ClampingScrollPhysics(),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F3F5),
                    ),
                  ),
                  itemBuilder: (context, index) {
                    if (index == list.length) {
                      if (c.isLoadingMore.value) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return const SizedBox(height: 24);
                    }

                    final p = list[index];

                    return PostRow(
                      post: p,
                      timeLabel: _timeLabel(p.createdAt),
                      onTap: () => _openPostDetail(p),
                      onLike: () => c.toggleLikeOnList(p),
                      liked: p.likedUserIds.contains(c.currentUserId),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goWrite,
        backgroundColor: kCommunityAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        label: const Text(
          '글쓰기',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}

class _UsedBoardTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Future<void> Function() onTap;

  const _UsedBoardTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? kCommunityAccent : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () async => onTap(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? kCommunityAccent : const Color(0xFFE5E7EB),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarFilterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ToolbarFilterButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.expand_more,
                size: 18,
                color: Color(0xFF6B7280),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ToolbarIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(
            icon,
            size: 19,
            color: const Color(0xFF111111),
          ),
        ),
      ),
    );
  }
}

class _SelectedFilterChip extends StatelessWidget {
  final String label;
  final Widget? leading;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _SelectedFilterChip({
    required this.label,
    required this.onTap,
    required this.onClear,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 10, 8),
              child: Icon(
                Icons.close,
                size: 16,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedEmptyBody extends StatelessWidget {
  final String message;

  const _FeedEmptyBody({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FeedErrorBody extends StatelessWidget {
  final String message;

  const _FeedErrorBody({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          '에러: $message',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}